#!/usr/bin/env python3
"""Phase 2 AI triage injector for WP Code Check reports.

- Reads an existing WP Code Check JSON log.
- Injects an `ai_triage` object (id-level triage for selected findings + overall summary).
- Does NOT modify findings; it annotates them.

This is intentionally conservative: it focuses on high-signal categories and treats
minified/vendor code differently.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, NamedTuple, Optional


class TriageDecision(NamedTuple):
    classification: str  # Confirmed | False Positive | Needs Review
    confidence: str      # high | medium | low
    rationale: str


VENDOR_HINTS = (
    '/vendor/',
    '/vendor_prefixed/',
    '/node_modules/',
    '/assets/lib/',
)
MINIFIED_HINTS = (
    '.min.js',
    '.min.css',
)

# WordPress hooks where the object's meta cache is already primed by WP core
# When these hooks fire, WordPress has already loaded the object and cached its meta
WP_CACHE_PRIMED_HOOKS = {
    # User profile hooks - WP_User object passed with meta already cached
    'show_user_profile': 'user',
    'edit_user_profile': 'user',
    'personal_options': 'user',
    'profile_personal_options': 'user',
    'user_profile': 'user',
    # Post edit hooks - WP_Post object passed with meta already cached
    'edit_form_after_title': 'post',
    'edit_form_after_editor': 'post',
    'add_meta_boxes': 'post',
    'save_post': 'post',
    'the_post': 'post',
    # Comment hooks - comment object passed with meta cached
    'edit_comment': 'comment',
    'comment_post': 'comment',
    # Term hooks - term object passed with meta cached
    'edit_term': 'term',
    'created_term': 'term',
}

# Patterns indicating WordPress has pre-loaded the object (meta cache is primed)
WP_OBJECT_PRELOADED_PATTERNS = (
    # Function receives WP_User object - meta already cached
    '$user->ID',
    '$user->id',
    # Function receives WP_Post object - meta already cached
    '$post->ID',
    '$post->id',
    'get_the_ID()',
    # Global post object in loop - meta cached by WP_Query
    'global $post',
    # Current user - always cached after init
    'get_current_user_id()',
    'wp_get_current_user()',
)

# Meta functions that benefit from WP's internal cache priming
WP_META_FUNCTIONS = (
    'get_user_meta',
    'get_post_meta',
    'get_term_meta',
    'get_comment_meta',
    'get_metadata',
)


def is_vendor_or_third_party(path: str) -> bool:
    p = path.replace('\\', '/')
    return any(h in p for h in VENDOR_HINTS)


def is_minified(path: str) -> bool:
    p = path.lower()
    return any(h in p for h in MINIFIED_HINTS)


def is_wp_cache_primed_context(file_path: str, code: str, context: List[Dict[str, Any]], message: str = '') -> Optional[str]:
    """Check if this code runs in a context where WordPress has already primed the meta cache.

    Returns a description of why the cache is primed, or None if not detected.

    This function uses multiple signals:
    1. File path patterns (most reliable when context is sparse)
    2. Code patterns in context
    3. Message/finding details
    """
    ctx_code = ''.join([code] + [(c.get('code') or '') for c in context])
    file_lower = file_path.lower()

    # ==========================================================================
    # FILE PATH-BASED DETECTION (works even when code/context is sparse)
    # ==========================================================================

    # Pattern: User admin views (hooked to show_user_profile/edit_user_profile)
    # These receive a WP_User object with meta already cached by WordPress
    if ('user-admin' in file_lower or 'user_admin' in file_lower or
        'user-profile' in file_lower or 'user_profile' in file_lower):
        if '/views/' in file_path or '/templates/' in file_path or 'view-' in file_lower:
            return (
                "This is a user admin/profile view file. Views in this location are typically "
                "hooked to show_user_profile or edit_user_profile actions, which receive a pre-loaded "
                "WP_User object. WordPress primes ALL user meta cache when loading the WP_User on "
                "user-edit.php, so get_user_meta() calls hit the object cache (0 DB queries)."
            )

    # Pattern: User custom fields views
    if 'custom-field' in file_lower or 'custom_field' in file_lower:
        if 'user' in file_lower and ('/views/' in file_path or 'view-' in file_lower):
            return (
                "This appears to be a user custom fields view. Custom field displays on user profile "
                "pages are hooked to show_user_profile/edit_user_profile. The WP_User object passed "
                "to these hooks has its meta cache pre-primed by WordPress core."
            )

    # Pattern: Post edit/meta box views
    if ('post-edit' in file_lower or 'meta-box' in file_lower or 'metabox' in file_lower):
        if '/views/' in file_path or '/templates/' in file_path:
            return (
                "This is a post edit/meta box view. WordPress primes post meta cache when loading "
                "the post on post.php, so get_post_meta() calls hit the object cache."
            )

    # ==========================================================================
    # CODE PATTERN-BASED DETECTION
    # ==========================================================================

    # Check for pre-loaded object patterns in code
    for pattern in WP_OBJECT_PRELOADED_PATTERNS:
        if pattern in ctx_code:
            if '$user' in pattern or 'current_user' in pattern.lower():
                return f"WP_User object is pre-loaded (detected '{pattern}'). WordPress primes user meta cache when loading WP_User objects."
            elif '$post' in pattern or 'get_the_ID' in pattern:
                return f"WP_Post object is pre-loaded (detected '{pattern}'). WordPress primes post meta cache when loading posts."

    # Check for admin user profile view patterns (fallback if file path didn't match)
    if 'user-admin' in file_lower or 'user_admin' in file_lower:
        # Even without code context, the file path is a strong signal
        if not ctx_code.strip():
            return (
                "This is a user admin file. Based on WordPress conventions, user admin views "
                "are typically rendered after WordPress has loaded and cached user data."
            )
        if any(meta_fn in ctx_code for meta_fn in ('get_user_meta', 'get_metadata')):
            return "This appears to be a user admin view. WordPress primes user meta cache on user-edit.php before hooks fire."

    # Check for view files that receive pre-loaded objects
    if '/views/' in file_path or '/templates/' in file_path:
        if '$user' in ctx_code and 'get_user_meta' in ctx_code:
            return "View receives $user object parameter. If hooked to show_user_profile/edit_user_profile, WordPress has already cached all user meta."
        if '$post' in ctx_code and 'get_post_meta' in ctx_code:
            return "View receives $post object parameter. If in the post edit screen or loop, WordPress has already cached all post meta."

    return None


def is_single_object_meta_loop(code: str, context: List[Dict[str, Any]], file_path: str = '') -> bool:
    """Check if the N+1 pattern is iterating over fields for a SINGLE object.

    When you call get_user_meta($user_id) for the same user_id multiple times,
    WordPress only queries the DB once (on first call) and caches ALL meta for that user.
    Subsequent calls for the same user_id hit the cache.

    This is different from iterating over multiple users/posts (true N+1).
    """
    ctx_code = ''.join([code] + [(c.get('code') or '') for c in context])
    file_lower = file_path.lower()

    # Pattern: foreach over fields, not over users/posts
    field_iteration_patterns = (
        '$field',
        '$custom_field',
        '$meta_key',
        '$key',
        '$registration_form_fields',
        '$file_fields',
        '$fields',
    )

    # Pattern: iterating over multiple objects (true N+1)
    object_iteration_patterns = (
        '$users',
        '$posts',
        '$orders',
        '$products',
        '$comments',
        '$terms',
        'get_users(',
        'get_posts(',
        'wc_get_orders(',
        'wc_get_products(',
        'WP_User_Query',
        'WP_Query',
    )

    has_field_iteration = any(p in ctx_code for p in field_iteration_patterns)
    has_object_iteration = any(p in ctx_code for p in object_iteration_patterns)

    # If iterating over fields (not objects), and using same ID, it's single-object
    if has_field_iteration and not has_object_iteration:
        # Check if the ID is constant within the loop
        if '$user->ID' in ctx_code or '$post->ID' in ctx_code or '$userID' in ctx_code:
            return True

    # ==========================================================================
    # FILE PATH-BASED INFERENCE (when code context is sparse)
    # ==========================================================================

    # If context code is very sparse but we have clear file path signals
    if not ctx_code.strip() or len(ctx_code) < 50:
        # User custom fields view - typically iterates over field definitions for ONE user
        if 'custom-field' in file_lower or 'custom_field' in file_lower:
            if 'user' in file_lower:
                return True

        # User admin views - typically display fields for ONE user being edited
        if 'user-admin' in file_lower or 'user_admin' in file_lower:
            if '/views/' in file_path or 'view-' in file_lower:
                return True

        # Profile views - display data for ONE user
        if 'profile' in file_lower and ('/views/' in file_path or 'view-' in file_lower):
            return True

    # If we have some context, check for explicit multi-object patterns
    if has_object_iteration:
        return False

    # If the file path strongly suggests single-object context
    if 'user-admin' in file_lower and 'view-' in file_lower:
        return True

    return False


def classify_finding(f: Dict[str, Any]) -> Optional[TriageDecision]:
    """Return a triage decision for a single finding.

    Returns None if we choose not to triage this finding (keeps it unreviewed).
    """

    fid = f.get('id', '')
    file_path = f.get('file', '')
    msg = (f.get('message') or '').strip()
    code = (f.get('code') or '').strip()
    context = f.get('context') or []

    vendor = is_vendor_or_third_party(file_path)
    minified = is_minified(file_path)

    # --- Debugger statements in shipped JS are usually real issues (even if 3rd party).
    if fid == 'spo-001-debug-code':
        return TriageDecision(
            classification='Confirmed',
            confidence='high',
            rationale=(
                "Contains a `debugger;` statement in shipped JS. This will pause execution in devtools and is "
                "normally unintended for production builds (even if located in a vendored library)."
            ),
        )  # Recommendation ID: 'debugger-statements'

    # --- Unsafe RegExp: often FP in bundled/minified libs; mixed in authored code.
    if fid == 'hcc-008-unsafe-regexp':
        # Special-case: code shows escaping.
        if 'replace(/([.*+?^${}()|\\[\\]\\/\\\\])/g' in code or any(
            'replace(/([.*+?^${}()|\\[\\]\\/\\\\])/g' in (c.get('code') or '') for c in context
        ):
            return TriageDecision(
                classification='False Positive',
                confidence='high',
                rationale="The code escapes regex metacharacters before constructing RegExp, which mitigates injection.",
            )

        if vendor or minified:
            return TriageDecision(
                classification='Needs Review',
                confidence='low',
                rationale=(
                    "The pattern is in bundled/minified or third-party code. Manual review needed to confirm whether the "
                    "RegExp inputs are attacker-controlled and whether escaping/constraints exist upstream."
                ),
            )

        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale=(
                "RegExp is constructed from a variable; confirm whether the variable is derived from user input and whether it is escaped/validated."
            ),
        )

    # --- Superglobal findings: prefer structured guarded/sanitized booleans when present.
    if fid == 'spo-002-superglobals':
        # Heuristic: docblocks/comments mentioning $_POST/$_GET; or constants containing 'POST' etc.
        if msg.lower().startswith('direct superglobal'):
            if code.strip().startswith('*') or code.strip().startswith('/*') or '$_POST' in code or '$_GET' in code:
                # If it's a docblock/comment line, it is not an access.
                if code.lstrip().startswith('*') or code.lstrip().startswith('/*'):
                    return TriageDecision(
                        classification='False Positive',
                        confidence='high',
                        rationale='This hit appears to be inside a comment/docblock (mentions superglobals but does not access them).',
                    )

            # Some hits are actually safe wrappers / validated flows.
            if 'verify_request_nonce' in code or any('verify_request_nonce' in (c.get('code') or '') for c in context):
                return TriageDecision(
                    classification='False Positive',
                    confidence='medium',
                    rationale='Nonce verification is performed via a helper (`verify_request_nonce`) in close proximity; direct access is part of a validated flow.',
                )

        # Prefer the scanner-provided guarded/sanitized booleans when available. These are
        # populated for DSM findings in v2.0.3+ and give us a more accurate picture than
        # re-deriving intent from raw code/guards arrays.
        guarded = f.get('guarded')
        sanitized = f.get('sanitized')
        guarded_b = guarded if isinstance(guarded, bool) else None
        sanitized_b = sanitized if isinstance(sanitized, bool) else None

        if guarded_b is not None or sanitized_b is not None:
            # Case 1: Guarded + sanitized DSM – usually acceptable WordPress form handling.
            if guarded_b is True and sanitized_b is True:
                return TriageDecision(
                    classification='False Positive',
                    confidence='high',
                    rationale=(
                        'Direct superglobal manipulation is both guard-protected (nonce/cap checks) '
                        'and sanitized on write; this matches standard WordPress form-handling patterns '
                        'and is unlikely to be a true issue.'
                    ),
                )

            # Case 2: Guarded but not clearly sanitized – lower risk but worth review.
            if guarded_b is True and (sanitized_b is False or sanitized_b is None):
                return TriageDecision(
                    classification='Needs Review',
                    confidence='medium',
                    rationale=(
                        'Direct superglobal manipulation is guard-protected (nonce/cap checks present) '
                        'but no write-side sanitization was detected; verify that values are constrained '
                        'before use and that bridge code does not bypass validation.'
                    ),
                )

            # Case 3: Sanitized but unguarded – input is constrained but CSRF/authz risk remains.
            if guarded_b is False and sanitized_b is True:
                return TriageDecision(
                    classification='Needs Review',
                    confidence='medium',
                    rationale=(
                        'Direct superglobal manipulation applies sanitization but no nonce/capability '
                        'guard was detected; consider adding CSRF/authz checks even if the values are '
                        'sanitized to reduce attack surface.'
                    ),
                )

            # Case 4: Unguarded and unsanitized (or unknown) – treat as confirmed high-signal.
            if guarded_b is False and (sanitized_b is False or sanitized_b is None):
                return TriageDecision(
                    classification='Confirmed',
                    confidence='high',
                    rationale=(
                        'Direct superglobal manipulation without detected guards or sanitization; '
                        'this is high-risk and should be refactored to add nonce/capability checks '
                        'and explicit sanitization or to avoid mutating superglobals directly.'
                    ),
                )

        # Fallback heuristics for older logs without guarded/sanitized booleans.

        # For actual assignments to $_REQUEST, treat as Needs Review.
        if code.strip().startswith('$_REQUEST'):
            return TriageDecision(
                classification='Needs Review',
                confidence='medium',
                rationale='Writes to $_REQUEST; verify this cannot be influenced by attackers and does not bypass validation logic.',
            )

        if vendor:
            return TriageDecision(
                classification='Needs Review',
                confidence='low',
                rationale='Located in vendored code; validate whether it is executed in your runtime context and whether upstream validation exists.',
            )

        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='Superglobal usage detected; confirm sanitization and nonce/capability checks for the execution path.',
        )

    if fid == 'unsanitized-superglobal-read':
        # Some are immediately sanitized/cast, but the tool may flag the raw read line.
        if 'absint(' in ''.join([code] + [(c.get('code') or '') for c in context]):
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale='Value is cast/sanitized (e.g., absint) in close proximity; ensure no earlier use of the raw value.',
            )

        if 'check_admin_referer' in ''.join([code] + [(c.get('code') or '') for c in context]):
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale='Nonce verification is present in the nearby control flow; remaining risk depends on usage of the value.',
            )

        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='Superglobal value is read directly; verify sanitization/validation happens before use in sensitive sinks.',
        )

    # --- REST pagination guard: often policy-driven; many routes are non-list endpoints.
    if fid == 'rest-no-pagination':
        # If it looks like a single-item or action endpoint, treat as FP-ish.
        if '/(?P<id>' in code or 'CREATABLE' in ''.join([code] + [(c.get('code') or '') for c in context]):
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale='Endpoint appears to be a single-resource/action route, not a list endpoint; pagination guards are less applicable.',
            )
        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='Check whether this endpoint returns unbounded lists; if so add per_page/limit constraints.',
        )

    # --- WPDB prepare: can be fine when no user input is interpolated, but still best practice.
    if fid == 'wpdb-query-no-prepare':
        if 'SELECT FOUND_ROWS()' in code:
            return TriageDecision(
                classification='False Positive',
                confidence='high',
                rationale='`SELECT FOUND_ROWS()` contains no external inputs; prepare() is not necessary for a constant query.',
            )
        if 'TRUNCATE TABLE' in code:
            return TriageDecision(
                classification='Needs Review',
                confidence='medium',
                rationale='TRUNCATE with interpolated table name can be safe if table name is internal/validated; confirm it is not user-controlled.',
            )
        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='Direct SQL query detected; verify no untrusted input is interpolated and prefer $wpdb->prepare() where applicable.',
        )

    # --- Missing cap check: many are not sinks; capability may be in menu registration args.
    if fid == 'spo-004-missing-cap-check':
        # If registering menu pages with explicit capability param, treat as FP-ish.
        if 'add_menu_page' in code or 'add_submenu_page' in code:
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale='Menu registration typically includes a capability argument; confirm the capability is specified and appropriate.',
            )
        # admin_notices etc: often safe, but could leak if content shows data.
        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='Heuristic check: confirm this admin hook/output is gated by capability or only displays non-sensitive content.',
        )

    # --- JS polling: could be acceptable if it checks focus/background.
    if fid == 'ajax-polling-unbounded':
        if 'isFocused' in ''.join([code] + [(c.get('code') or '') for c in context]):
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale='Polling is gated by focus/background checks; confirm interval duration and server-side throttling.',
            )
        if vendor or minified:
            return TriageDecision(
                classification='Needs Review',
                confidence='low',
                rationale='Bundled/minified code; verify interval duration and whether it can cause excessive server load.',
            )
        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='setInterval polling detected; verify interval, cancelation, and server-side rate limiting/caching.',
        )

    # --- Unbounded WP_Query/get_posts: may be mitigated with fields => ids.
    if fid == 'wp-query-unbounded':
        ctx = ''.join([code] + [(c.get('code') or '') for c in context])
        if "'fields' => 'ids'" in ctx or 'fields=>\"ids\"' in ctx:
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale='Query is unbounded but appears to be IDs-only; confirm the dataset is bounded by post_type/status and used in admin/CLI context.',
            )
        return TriageDecision(
            classification='Needs Review',
            confidence='medium',
            rationale='Unbounded posts_per_page detected; consider batching/pagination or bounding by date/status and cache results.',
        )

    # --- HTTP no timeout: generally real, but WordPress has defaults; still best practice.
    if fid == 'http-no-timeout':
        return TriageDecision(
            classification='Confirmed',
            confidence='medium',
            rationale='Remote requests should pass an explicit timeout to avoid long hangs under network issues.',
        )

    # --- N+1 query patterns: meta calls in loops can cause severe performance issues.
    # However, WordPress has internal meta caching that can make some patterns false positives.
    if fid == 'n-plus-1-pattern':
        ctx = ''.join([code] + [(c.get('code') or '') for c in context])

        # =======================================================================
        # PRIORITY 1: Check for WordPress meta cache priming (FALSE POSITIVES)
        # =======================================================================
        # WordPress automatically caches ALL meta for an object when you first
        # access it. If the object is pre-loaded (e.g., WP_User passed to hook),
        # subsequent get_*_meta() calls hit the cache, not the database.

        cache_primed_reason = is_wp_cache_primed_context(file_path, code, context, msg)
        if cache_primed_reason:
            # Additional check: is this iterating over fields for a SINGLE object?
            if is_single_object_meta_loop(code, context, file_path):
                return TriageDecision(
                    classification='False Positive',
                    confidence='high',
                    rationale=(
                        f'WordPress meta cache is pre-primed in this context. {cache_primed_reason} '
                        'The loop iterates over fields/keys for a single object (same ID), not multiple objects. '
                        'WordPress caches ALL meta for an object on first access, so subsequent get_*_meta() '
                        'calls for the same object ID hit the object cache (0 additional DB queries). '
                        'This is NOT a true N+1 pattern.'
                    ),
                )
            else:
                return TriageDecision(
                    classification='Needs Review',
                    confidence='medium',
                    rationale=(
                        f'WordPress meta cache may be pre-primed. {cache_primed_reason} '
                        'However, could not confirm this is a single-object iteration. '
                        'Verify: (1) Is the loop iterating over fields for ONE object, or multiple objects? '
                        '(2) If single object, this is a false positive. (3) If multiple objects, consider '
                        'using update_meta_cache() to batch-prime the cache before the loop.'
                    ),
                )

        # =======================================================================
        # PRIORITY 2: Check for single-object field iteration (likely FALSE POSITIVE)
        # =======================================================================
        # Even without explicit cache priming detection, if we're iterating over
        # fields for a single object, WordPress will cache on first call.

        if is_single_object_meta_loop(code, context, file_path):
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale=(
                    'This appears to iterate over fields/keys for a SINGLE object (same ID in each iteration). '
                    'WordPress caches ALL meta for an object on the first get_*_meta() call. '
                    'Subsequent calls for the same object ID hit the object cache, not the database. '
                    'Only the first iteration triggers a DB query; the rest are cache hits. '
                    'This is likely NOT a true N+1 pattern. Verify the object ID is constant within the loop.'
                ),
            )

        # =======================================================================
        # PRIORITY 3: Check for explicit caching mechanisms
        # =======================================================================
        if 'get_transient' in ctx or 'set_transient' in ctx or 'wp_cache_get' in ctx or 'wp_cache_set' in ctx:
            return TriageDecision(
                classification='False Positive',
                confidence='medium',
                rationale=(
                    'N+1 pattern detected but caching mechanism (transients or object cache) is present '
                    'in the surrounding code. Verify that the cache key is appropriate and cache invalidation '
                    'is handled correctly.'
                ),
            )

        # =======================================================================
        # PRIORITY 4: Check for email/low-frequency contexts
        # =======================================================================
        if '/email' in file_path.lower() or 'email' in file_path.lower():
            if 'attachment' in msg.lower() or 'file_field' in ctx or 'file' in ctx.lower():
                return TriageDecision(
                    classification='Needs Review',
                    confidence='medium',
                    rationale=(
                        'N+1 pattern in email generation context. Email sending is typically low-frequency, '
                        'so performance impact may be acceptable. However, if emails are sent in bulk or '
                        'triggered frequently, consider pre-fetching meta values or caching. '
                        'Verify: (1) email send frequency, (2) typical loop iteration count, (3) whether '
                        'this runs synchronously or via background job.'
                    ),
                )

        # =======================================================================
        # PRIORITY 5: Check for bounded loops
        # =======================================================================
        if 'LIMIT' in ctx.upper() or 'array_slice' in ctx or 'array_chunk' in ctx:
            return TriageDecision(
                classification='Needs Review',
                confidence='medium',
                rationale=(
                    'N+1 pattern detected but loop appears to be bounded. Verify the maximum iteration count '
                    'is small (< 20) and consider pre-fetching meta values if the bound could increase.'
                ),
            )

        # =======================================================================
        # PRIORITY 6: Check for admin-only context
        # =======================================================================
        if 'is_admin()' in ctx or '/admin/' in file_path or 'wp-admin' in file_path:
            # But NOT if it's a user-admin view (those are usually cache-primed)
            if 'user-admin' not in file_path.lower() and 'user_admin' not in file_path.lower():
                return TriageDecision(
                    classification='Needs Review',
                    confidence='medium',
                    rationale=(
                        'N+1 pattern in admin context. Admin pages typically have lower traffic, but this can '
                        'still cause slowdowns for admins managing large datasets. Consider: (1) Is this on a '
                        'high-traffic admin page? (2) Could the dataset grow large? (3) Can meta values be '
                        'pre-fetched before the loop using update_meta_cache()?'
                    ),
                )

        # =======================================================================
        # PRIORITY 7: Check for true N+1 patterns (iterating over MULTIPLE objects)
        # =======================================================================
        true_n_plus_1_patterns = (
            '$users', '$posts', '$orders', '$products', '$comments', '$terms',
            'get_users(', 'get_posts(', 'wc_get_orders(', 'wc_get_products(',
            'WP_User_Query', 'WP_Query', 'WC_Order_Query',
        )

        if any(p in ctx for p in true_n_plus_1_patterns):
            return TriageDecision(
                classification='Confirmed',
                confidence='high',
                rationale=(
                    'TRUE N+1 pattern detected: iterating over MULTIPLE objects and calling get_*_meta() '
                    'for each one. This causes N separate database queries (one per object). '
                    'Fix: Use update_meta_cache() to batch-prime the cache before the loop. Example: '
                    'update_meta_cache("user", wp_list_pluck($users, "ID")) before iterating. '
                    'This reduces N queries to 1 query.'
                ),
            )

        # =======================================================================
        # DEFAULT: Needs Review (insufficient context to determine)
        # =======================================================================
        return TriageDecision(
            classification='Needs Review',
            confidence='low',
            rationale=(
                'N+1 query pattern detected but context is ambiguous. Could not determine if this is: '
                '(1) A single-object field iteration (false positive - WP caches on first call), or '
                '(2) A multi-object iteration (true N+1 - needs fix). '
                'Manual review required. Check: Is the loop iterating over fields for ONE object, '
                'or over MULTIPLE objects? If multiple objects, use update_meta_cache() to batch-prime.'
            ),
        )

    # Default: do not triage.
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('json_path', type=Path)
    ap.add_argument('--max-findings', type=int, default=200, help='Max findings to triage (keeps report manageable).')
    args = ap.parse_args()

    print(f"[AI Triage] Reading JSON log: {args.json_path}", file=sys.stderr)
    data = json.loads(args.json_path.read_text(encoding='utf-8'))
    findings: List[Dict[str, Any]] = data.get('findings') or []
    print(f"[AI Triage] Total findings in log: {len(findings)}", file=sys.stderr)
    print(f"[AI Triage] Max findings to review: {args.max_findings}", file=sys.stderr)

    triaged_items: List[Dict[str, Any]] = []
    counts = Counter()
    confidences = Counter()

    reviewed = 0

    for f in findings:
        if reviewed >= args.max_findings:
            break

        decision = classify_finding(f)
        if decision is None:
            continue

        reviewed += 1
        counts[decision.classification] += 1
        confidences[decision.confidence] += 1

        triaged_items.append(
            {
                'finding_key': {
                    'id': f.get('id'),
                    'file': f.get('file'),
                    'line': f.get('line'),
                },
                'classification': decision.classification,
                'confidence': decision.confidence,
                'rationale': decision.rationale,
            }
        )

    print(f"[AI Triage] Findings reviewed: {reviewed}", file=sys.stderr)

    # Infer overall confidence from distribution.
    overall_conf = 'medium'
    if reviewed:
        high_ratio = confidences['high'] / reviewed
        low_ratio = confidences['low'] / reviewed
        if high_ratio >= 0.6 and low_ratio <= 0.15:
            overall_conf = 'high'
        elif low_ratio >= 0.4:
            overall_conf = 'low'

    print(f"[AI Triage] Classification breakdown:", file=sys.stderr)
    print(f"  - Confirmed Issues: {counts.get('Confirmed', 0)}", file=sys.stderr)
    print(f"  - False Positives: {counts.get('False Positive', 0)}", file=sys.stderr)
    print(f"  - Needs Review: {counts.get('Needs Review', 0)}", file=sys.stderr)
    print(f"[AI Triage] Overall confidence: {overall_conf}", file=sys.stderr)

    # Minimal executive summary tailored to what we actually observed in the triaged sample.
    narrative_parts: List[str] = []
    narrative_parts.append(
        "This Phase 2 triage pass reviews a subset of findings to separate likely true issues from policy/heuristic noise (especially in vendored/minified assets)."
    )

    # Derive which high-priority categories were actually seen in the triaged sample.
    has_debugger = any(
        (item.get('finding_key') or {}).get('id') == 'spo-001-debug-code'
        for item in triaged_items
    )
    has_http_timeout = any(
        (item.get('finding_key') or {}).get('id') == 'http-no-timeout'
        for item in triaged_items
    )
    has_rest_pagination = any(
        (item.get('finding_key') or {}).get('id') == 'rest-no-pagination'
        for item in triaged_items
    )
    has_superglobals = any(
        (item.get('finding_key') or {}).get('id') in ('spo-002-superglobals', 'unsanitized-superglobal-read')
        for item in triaged_items
    )

    key_items = []
    if has_debugger:
        key_items.append("shipped `debugger;` statements in JS assets")
    if has_http_timeout:
        key_items.append("remote HTTP requests without explicit timeouts")
    if has_rest_pagination:
        key_items.append("REST endpoints missing explicit pagination/limits")
    if has_superglobals:
        key_items.append("direct or unsanitized superglobal access")

    if key_items:
        if len(key_items) == 1:
            key_summary = key_items[0]
        else:
            key_summary = ", ".join(key_items[:-1]) + f" and {key_items[-1]}"
        narrative_parts.append(
            f"Key confirmed or high-signal items in the reviewed set include {key_summary}."
        )
    else:
        narrative_parts.append(
            "In this sampled set, no debugger statements, missing HTTP timeouts, REST pagination, or superglobal patterns were confirmed; most findings remain heuristic or require case-by-case review."
        )

    narrative_parts.append(
        "A large portion of findings often come from bundled/minified JavaScript or third-party libraries; these are difficult to validate from pattern matching alone and are therefore marked as Needs Review unless a clear mitigation is visible (e.g., regex escaping before `new RegExp()`)."
    )

    recommendations: List[str] = []

    if has_debugger:
        recommendations.append(
            'Remove/strip `debugger;` statements from shipped JS assets (or upgrade/patch the vendored library that contains them).'
        )
    if has_http_timeout:
        recommendations.append(
            'Add explicit `timeout` arguments to `wp_remote_get/wp_remote_post/wp_remote_request` calls where missing.'
        )
    if has_rest_pagination:
        recommendations.append(
            'For REST endpoints, confirm which routes return potentially large collections; add `per_page`/limit constraints there (action/single-item routes may not need pagination).'
        )
    if has_superglobals:
        recommendations.append(
            'For superglobal reads, ensure values are validated/sanitized before use and that nonce/capability checks exist on the request path.'
        )

    if not recommendations:
        recommendations.append(
            'Review the flagged findings in context and decide which ones to fix versus baseline, focusing first on CRITICAL-impact performance and security patterns.'
        )

    data['ai_triage'] = {
        'performed': True,
        'status': 'complete',
        'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        'version': '1.1',
        'scope': {
            'max_findings_reviewed': args.max_findings,
            'findings_reviewed': reviewed,
        },
        'summary': {
            'findings_reviewed': reviewed,  # Duplicated for convenience/back-compat
            'confirmed_issues': counts.get('Confirmed', 0),
            'false_positives': counts.get('False Positive', 0),
            'needs_review': counts.get('Needs Review', 0),
            'confidence_level': overall_conf,
        },
        'narrative': '\n\n'.join(narrative_parts),
        'recommendations': recommendations,
        'triaged_findings': triaged_items,
    }

    print(f"[AI Triage] Writing updated JSON to: {args.json_path}", file=sys.stderr)
    args.json_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

    # Verify write was successful
    file_size = args.json_path.stat().st_size
    print(f"[AI Triage] ✅ Successfully wrote {file_size:,} bytes", file=sys.stderr)
    print(f"[AI Triage] Triage data injected with {len(triaged_items)} triaged findings", file=sys.stderr)

    # Post-write verification: re-open and assert ai_triage exists
    print(f"[AI Triage] Verifying write integrity...", file=sys.stderr)
    try:
        verification_data = json.loads(args.json_path.read_text(encoding='utf-8'))

        # Check that ai_triage key exists
        if 'ai_triage' not in verification_data:
            print(f"[AI Triage] ❌ VERIFICATION FAILED: 'ai_triage' key not found in written JSON", file=sys.stderr)
            return 1

        # Check that ai_triage.performed is True
        if not verification_data.get('ai_triage', {}).get('performed'):
            print(f"[AI Triage] ❌ VERIFICATION FAILED: 'ai_triage.performed' is not True", file=sys.stderr)
            return 1

        # Check that triaged_findings count matches
        written_count = len(verification_data.get('ai_triage', {}).get('triaged_findings', []))
        if written_count != len(triaged_items):
            print(f"[AI Triage] ❌ VERIFICATION FAILED: Expected {len(triaged_items)} triaged findings, found {written_count}", file=sys.stderr)
            return 1

        # Check that summary exists and has expected keys
        summary = verification_data.get('ai_triage', {}).get('summary', {})
        required_keys = ['findings_reviewed', 'confirmed_issues', 'false_positives', 'needs_review', 'confidence_level']
        missing_keys = [k for k in required_keys if k not in summary]
        if missing_keys:
            print(f"[AI Triage] ❌ VERIFICATION FAILED: Missing summary keys: {missing_keys}", file=sys.stderr)
            return 1

        print(f"[AI Triage] ✅ Verification passed: ai_triage data is intact", file=sys.stderr)
        print(f"[AI Triage] ✅ Confirmed {written_count} triaged findings persisted", file=sys.stderr)

    except json.JSONDecodeError as e:
        print(f"[AI Triage] ❌ VERIFICATION FAILED: Written JSON is invalid: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"[AI Triage] ❌ VERIFICATION FAILED: Unexpected error: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
