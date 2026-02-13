# AGENTS.md - LLM Development Guidelines

This document provides architectural guidance for AI assistants working on this codebase.

## Navigation & Layout System

### ✅ Current Pattern (v0.1.6+)

All pages should use a **unified layout system** located in `src/components/layouts/`:

```
src/components/layouts/
├── UnifiedSidebar.tsx   ← Single sidebar for all user states
├── UnifiedLayout.tsx    ← Layout wrapper (sidebar + content area)
└── index.ts             ← Exports
```

**Usage:**
```tsx
import { UnifiedLayout } from ‘@/components/layouts’;

const MyPage = () => {
  return (
    <UnifiedLayout>
      {/* Page content */}
    </UnifiedLayout>
  );
};
```

### Navigation States

`UnifiedSidebar` automatically renders appropriate nav items based on auth state:

| State | Nav Items |
|———|—————|
| **Logged out** | Home, Status, Changelog, Terms (`/tos`), Sign-up, Sign-in |
| **Logged in (non-admin)** | Dashboard, Monitors, Profile, Status, Changelog, Terms (`/tos`), Sign out |
| **Logged in (admin)** | Dashboard, Monitors, Profile, Admin, Status, Changelog, Terms (`/tos`), Sign out |

### Footer Component

The `Footer.tsx` component (`src/components/Footer.tsx`) renders CMS content from `app_config.footer_html`. It is **embedded inside `UnifiedSidebar.tsx`**, not used standalone in pages.

### ❌ Deprecated Patterns

Do NOT use these patterns:
- `PublicNavbar.tsx` - **DELETED** - was separate nav for public pages
- Standalone `<Footer />` in page components - Footer is now embedded in sidebar
- Custom layout wrappers per page - Use `UnifiedLayout` instead

—

## CMS Content Pattern

Content managed via Admin CMS is stored in the `app_config` table:

| Key | Description | Component |
|——|——————|—————|
| `tos_html` | Terms of Service HTML | `TosPage.tsx` |
| `footer_html` | Footer HTML content | `Footer.tsx` |

**Reading CMS content:**
```tsx
const { data } = await supabase
  .from(‘app_config’)
  .select(‘value’)
  .eq(‘key’, ‘tos_html’)
  .single();

// Parse JSON string value
const html = JSON.parse(data.value);
```

**Writing CMS content (Admin only):**
```tsx
await supabase
  .from(‘app_config’)
  .upsert({ key: ‘footer_html’, value: JSON.stringify(htmlContent) });
```

—

## Theme System (Future-Ready)

The layout system is designed for future theme/branding injection:

### Extension Points

1. **`UnifiedSidebar.tsx`** - Look for `// Future:` comments
   - Logo/branding injection
   - Product name from theme context
   - Color scheme from CSS custom properties

2. **`UnifiedLayout.tsx`** - Layout variant switching
   - `sidebar-left` (current WPCanary)
   - `topnav` (future products)

### Planned Structure
```
src/components/layouts/
├── UnifiedSidebar.tsx      ← Current
├── UnifiedLayout.tsx       ← Current
├── TopNavLayout.tsx        ← Future: horizontal nav variant
├── MobileDrawer.tsx        ← Future: shared mobile drawer
└── LayoutPicker.tsx        ← Future: reads branding.layout, picks layout
```

—

## State Management

### Auth Store (`src/stores/auth-store.ts`)
- Use `useAuthStore()` for auth state
- `isAdmin()` method for admin checks
- `signOut()` for logout

### Events Store (`src/stores/events-store.ts`)
- Bounded to `MAX_EVENTS = 500`
- Use for dashboard event feed

—

## Key Principles

1. **DRY** - Don’t duplicate navigation, layout, or CMS patterns
2. **Single Source of Truth** - Auth state from `useAuthStore()`, not prop drilling
3. **Unified Layout** - All pages use `UnifiedLayout`, no custom wrappers
4. **CMS via app_config** - Admin-editable content stored as JSON in `app_config` table
5. **Future-Ready** - Check `// Future:` comments before adding theme/branding logic
6. **Small Diffs Only** - Refactor 1 file/pattern per prompt; avoid large sweeping changes
7. **Ask When Unclear** - If uncertain, ask: “Which AGENTS.md pattern applies here?”

—

## Verification Commands

Run these before committing changes:

```bash
# Type checking
bun run typecheck        # or: tsc —noEmit

# Linting
bun run lint             # eslint

# Test affected pages
bun run test             # vitest

# Check Supabase schema drift
supabase db diff
```

—

## Supabase RLS Policies

The `app_config` table uses these RLS policies:

```sql
— Public can read all config
CREATE POLICY “Public read app_config” ON app_config
  FOR SELECT USING (true);

— Only authenticated admins can write
CREATE POLICY “Admin write app_config” ON app_config
  FOR ALL USING (
    auth.role() = ‘authenticated’
    AND is_admin(auth.uid())
  );
```

**Important:** Always verify RLS policies exist before adding new `app_config` keys.

—

## File Locations

| Purpose | Location |
|————|—————|
| Layout components | `src/components/layouts/` |
| Page components | `src/pages/` |
| UI primitives | `src/components/ui/` |
| Stores (Zustand) | `src/stores/` |
| Supabase client | `src/integrations/supabase/` |
| Edge functions | `supabase/functions/` |

—

## Before Making Changes

1. Check this file for established patterns
2. Use `codebase-retrieval` to find existing implementations
3. Follow the unified layout system - do NOT create new layout wrappers
4. Update CHANGELOG.md with version bump after changes
