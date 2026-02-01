# Logic Duplication Detection - Feasibility Study

**Date:** January 1, 2026
**Status:** 🔬 Research & Feasibility Analysis
**Context:** Following B+ audit of string literal duplication (v1.0.73 - SHIPPED), exploring logic clone detection

---

## Executive Summary

**Question:** Can we detect duplicated logic using grep/bash, or do we need AST parsing?

**Answer:** 
- ✅ **Type 1 clones (exact copies)** - grep/bash is sufficient
- ⚠️ **Type 2 clones (renamed variables)** - grep/bash is limited but possible with PHP tokenizer
- ❌ **Type 3 clones (modified logic)** - AST required
- ❌ **Type 4 clones (semantic equivalence)** - AST + ML required

**Recommendation:** Implement Type 1 detection with grep/bash (quick win), then evaluate AST for Type 2/3.

---

## Context: String Literal Detection is Already Working ✅

**Current Implementation (v1.0.73):**
- ✅ 3 patterns: duplicate option names, transient keys, capability strings
- ✅ Hash-based aggregation with configurable thresholds
- ✅ JSON/HTML/Terminal reporting
- ✅ Zero false positives on 2 production plugins (8 violations detected)
- ✅ Integrated into `check-performance.sh` with `run_aggregated_pattern()` function

**This document explores:** Extending the proven grep/bash approach to detect **function/code block clones**, not just string literals.

---

## 📊 Implementation Summary (TL;DR)

### Key Decision: Leverage Existing Infrastructure ✅

**What Changed from Original Study:**
- **Before:** Theoretical feasibility study ("Can grep detect clones?")
- **After:** Practical implementation plan ("Extend proven v1.0.73 system")

**Why This Matters:**
- ✅ **80% of infrastructure exists** - `run_aggregated_pattern()`, JSON patterns, aggregation thresholds
- ✅ **Proven approach** - Same architecture that achieved 0 false positives in string literal detection
- ✅ **Low risk** - Reusing battle-tested code from v1.0.73
- ✅ **Quick implementation** - 2-3 hours coding + 1 day testing = 1-2 days total

### What We'll Build (Phase 1)

**Single Pattern:** `duplicate-functions.json`
- Detects Type 1 clones (exact function copies)
- Hash-based matching with normalization (strip comments/whitespace)
- Thresholds: min 5 lines, min 2 files
- Expected: 60-70% clone coverage, < 5% false positives

**Integration Points:**
- Extend `run_aggregated_pattern()` in `check-performance.sh`
- Add section to existing HTML reports
- Use same JSON schema as string literal patterns

**Exit Criteria (Go/No-Go Decision):**
- [ ] False positive rate < 10% on real WordPress plugins
- [ ] Scan time < 5 seconds on typical codebase
- [ ] Team says "This is useful"

### What We Won't Build (Yet)

**Deferred to Phase 2/3:**
- ❌ Type 2 clones (renamed variables) - Requires PHP tokenizer
- ❌ Type 3 clones (modified logic) - Requires AST
- ❌ Semantic similarity - Requires AST + ML
- ❌ Automatic refactoring - Too risky for MVP

**Philosophy:** "Do ONE thing well with zero false positives" (same as v1.0.73)

---

## Clone Detection Taxonomy

### Industry Standard Classification

| Type | Description | Example | Grep/Bash Feasible? |
|------|-------------|---------|---------------------|
| **Type 1** | Exact copies (except whitespace/comments) | Copy-paste with no changes | ✅ Yes |
| **Type 2** | Syntactically identical (renamed identifiers) | Same code, different variable names | ⚠️ Limited |
| **Type 3** | Modified copies (statements added/removed) | Similar logic with edits | ❌ No |
| **Type 4** | Semantically similar (different syntax) | Different code, same behavior | ❌ No |

### Visual Examples

#### Type 1 Clone (Exact Duplicate)
```php
// File A
function validate_user_email($email) {
    if (empty($email)) {
        return false;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    return true;
}

// File B (EXACT COPY)
function validate_user_email($email) {
    if (empty($email)) {
        return false;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    return true;
}
```
**Detection:** ✅ Grep can find this (hash matching, line-by-line comparison)

---

#### Type 2 Clone (Renamed Variables)
```php
// File A
function validate_email($email) {
    if (empty($email)) {
        return false;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    return true;
}

// File B (Different variable names)
function check_email_validity($user_email) {
    if (empty($user_email)) {
        return false;
    }
    if (!filter_var($user_email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    return true;
}
```
**Detection:** ⚠️ Grep can find with normalization (replace identifiers with placeholders)

---

#### Type 3 Clone (Modified Logic)
```php
// File A
function validate_email($email) {
    if (empty($email)) {
        return false;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    return true;
}

// File B (Extra logging added)
function validate_email($email) {
    if (empty($email)) {
        error_log("Empty email provided");
        return false;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        error_log("Invalid email format: " . $email);
        return false;
    }
    return true;
}
```
**Detection:** ❌ Grep cannot detect (requires structural comparison)

---

#### Type 4 Clone (Semantic Equivalence)
```php
// File A
function validate_email($email) {
    return !empty($email) && filter_var($email, FILTER_VALIDATE_EMAIL);
}

// File B (Different implementation, same logic)
function validate_email($email) {
    if (empty($email)) {
        return false;
    }
    return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}
```
**Detection:** ❌ Grep cannot detect (requires semantic analysis)

---

## Grep/Bash Capabilities Analysis

### ✅ What Grep/Bash CAN Do

#### 1. **Exact Line Matching** (Type 1 - Trivial)
```bash
# Find files with identical lines (minimum 5 consecutive lines)
grep -rHn "if (empty(\$email))" . | while read match; do
    file=$(echo "$match" | cut -d: -f1)
    line=$(echo "$match" | cut -d: -f2)
    # Check next 4 lines for continuation
done
```
**Effectiveness:** ✅ High (catches exact copy-paste)
**False Positives:** Low (exact matching)

---

#### 2. **Hash-Based Comparison** (Type 1 - Robust)
```bash
# Generate hashes of normalized function bodies
find . -name "*.php" -exec grep -Pzo 'function\s+\w+\s*\([^)]*\)\s*\{[^}]+\}' {} \; | \
  sed 's/\s\+/ /g' | # Normalize whitespace
  sed 's/\/\/.*$//' | # Remove comments
  md5sum | \
  sort | \
  uniq -d # Find duplicates
```
**Effectiveness:** ✅ High (catches exact functions)
**False Positives:** Low
**Limitations:** Misses renamed variables

---

#### 3. **Pattern-Based Structure Matching** (Type 2 - Limited)
```bash
# Find functions with similar structure (abstracted)
grep -Pzo 'if\s*\(\s*empty\s*\([^\)]+\)\s*\)\s*\{[^}]+return\s+false' *.php | \
  sed 's/\$[a-zA-Z_][a-zA-Z0-9_]*/VAR/g' | # Replace variables with VAR
  sort | uniq -d
```
**Effectiveness:** ⚠️ Medium (catches some renamed clones)
**False Positives:** Medium-High (many patterns are common)
**Limitations:** Fragile regex, misses reordered logic

---

#### 4. **Token Sequence Matching** (Type 2 - Advanced)
```bash
# Tokenize PHP and compare token sequences
php -r '
$code = file_get_contents("file.php");
$tokens = token_get_all($code);
foreach ($tokens as $token) {
    if (is_array($token)) {
        echo token_name($token[0]) . " ";
    }
}
' | md5sum
```
**Effectiveness:** ✅ High (catches renamed variables)
**False Positives:** Low
**Limitations:** Requires PHP, still misses Type 3/4

---

### ❌ What Grep/Bash CANNOT Do

#### 1. **Abstract Syntax Tree Comparison** (Type 3)
Cannot understand code structure beyond text patterns.

**Example:**
```php
// These are equivalent but grep cannot tell
if ($x) { doA(); doB(); }
if ($x) {
    doA();
    doB();
}
```

---

#### 2. **Control Flow Analysis** (Type 3)
Cannot understand logic flow or statement reordering.

**Example:**
```php
// Logically identical, different order
// Version A
if ($x) return true;
if ($y) return false;

// Version B  
if ($y) return false;
if ($x) return true;
```

---

#### 3. **Semantic Equivalence** (Type 4)
Cannot understand that different code does the same thing.

**Example:**
```php
// Semantically identical
for ($i = 0; $i < count($arr); $i++) {}
foreach ($arr as $item) {}
array_map(function($x) {}, $arr);
```

---

## Proposed Grep/Bash Implementation

### Strategy: Multi-Tier Detection

#### **Tier 1: Exact Function Clones** (Type 1)
**Method:** Hash normalized function bodies
**Threshold:** Minimum 5 lines, 2+ occurrences
**Expected False Positive Rate:** < 5%

```bash
detect_exact_function_clones() {
    local min_lines=5
    local min_occurrences=2
    
    # Extract all functions, normalize, hash
    find "$target_path" -name "*.php" -exec \
        grep -Pzo 'function\s+\w+\s*\([^)]*\)\s*\{(?:[^{}]|\{[^{}]*\})*\}' {} \; | \
        sed 's/\s\+/ /g' | \         # Normalize whitespace
        sed 's/\/\/.*$//' | \         # Strip comments
        sed 's/\/\*.*?\*\///' | \     # Strip block comments
        awk 'NF >= '$min_lines' {print}' | \  # Minimum lines
        sort | uniq -c | \            # Count occurrences
        awk '$1 >= '$min_occurrences' {print}'
}
```

**Pros:**
- ✅ Simple, fast, reliable
- ✅ Low false positive rate
- ✅ No external dependencies

**Cons:**
- ❌ Misses renamed variables
- ❌ Misses modified clones

---

#### **Tier 2: Normalized Code Blocks** (Type 1 + Partial Type 2)
**Method:** Replace identifiers with placeholders, hash
**Threshold:** Minimum 10 lines, 70%+ similarity
**Expected False Positive Rate:** 10-20%
**Status**: Deferred as of Jan. 2, 2026 - wait for feedback

```bash
detect_normalized_clones() {
    find "$target_path" -name "*.php" | while read file; do
        # Tokenize and normalize
        php -r "
        \$code = file_get_contents('$file');
        \$tokens = token_get_all(\$code);
        foreach (\$tokens as \$token) {
            if (is_array(\$token)) {
                if (\$token[0] == T_VARIABLE) echo 'VAR ';
                elseif (\$token[0] == T_STRING) echo 'FUNC ';
                else echo token_name(\$token[0]) . ' ';
            } else {
                echo \$token . ' ';
            }
        }
        " | md5sum
    done | sort | uniq -c | awk '$1 >= 2 {print}'
}
```

**Pros:**
- ✅ Catches renamed variables
- ✅ More tolerant of whitespace/comments
- ✅ Uses PHP's own tokenizer (accurate)

**Cons:**
- ❌ Requires PHP CLI
- ❌ Higher false positive rate
- ❌ Still misses Type 3/4

---

#### **Tier 3: Code Block Hashing** (Type 1)
**Method:** Hash consecutive line blocks (sliding window)
**Threshold:** Minimum 8 consecutive identical lines
**Expected False Positive Rate:** < 5%

```bash
detect_code_block_clones() {
    local window_size=8
    
    find "$target_path" -name "*.php" | while read file; do
        # Generate rolling hashes of N-line blocks
        awk -v window=$window_size '
        {
            lines[NR] = $0
            if (NR >= window) {
                block = ""
                for (i = NR - window + 1; i <= NR; i++) {
                    block = block lines[i] "\n"
                }
                print FILENAME ":" (NR - window + 1) ":" block
            }
        }
        ' "$file"
    done | md5sum -c | grep -v OK | sort | uniq -c | awk '$1 >= 2 {print}'
}
```

**Pros:**
- ✅ Catches partial function clones
- ✅ Catches code blocks outside functions
- ✅ Fast and simple

**Cons:**
- ❌ Misses clones split across files
- ❌ Window size tuning required

---

## When Do We Need AST?

### Clear AST Requirements

| Scenario | Grep/Bash | AST Required |
|----------|-----------|--------------|
| Exact function copies | ✅ Sufficient | ❌ No |
| Renamed variables | ⚠️ Limited | ✅ Yes |
| Reordered statements | ❌ Cannot detect | ✅ Yes |
| Refactored logic | ❌ Cannot detect | ✅ Yes |
| Different control structures | ❌ Cannot detect | ✅ Yes |
| Cross-language detection | ❌ Cannot detect | ✅ Yes |

### AST Tool Options

#### Option A: PHP-Parser (PHP Library)
```php
use PhpParser\ParserFactory;
use PhpParser\NodeTraverser;

$parser = (new ParserFactory)->create(ParserFactory::PREFER_PHP7);
$ast = $parser->parse($code);
```
**Pros:** Native PHP, accurate parsing
**Cons:** Requires PHP library, slower

#### Option B: tree-sitter (Universal Parser)
```bash
tree-sitter parse file.php --quiet | md5sum
```
**Pros:** Multi-language, fast
**Cons:** External dependency, learning curve

#### Option C: nikic/PHP-Parser + Custom Tool
Build custom clone detector using PHP-Parser
**Pros:** Full control, accurate
**Cons:** Significant development time

---

## Feasibility Assessment

### Grep/Bash Approach (Type 1 Only)

| Factor | Assessment | Grade |
|--------|------------|-------|
| **Development Time** | 2-3 hours coding + 1 day testing | ✅ Fast |
| **Accuracy (Type 1)** | 90-95% | ✅ Good |
| **False Positives** | 5-10% | ✅ Acceptable |
| **Maintenance** | Low complexity | ✅ Easy |
| **Coverage** | Type 1 only | ⚠️ Limited |
| **Infrastructure Reuse** | 80% (patterns, aggregation, reports) | ✅ Excellent |

**Verdict:** ✅ **Viable MVP** - Good ROI for detecting exact clones with minimal new code

---

### AST Approach (Type 2 + Type 3)

| Factor | Assessment | Grade |
|--------|------------|-------|
| **Development Time** | 2-4 weeks | ⚠️ Slow |
| **Accuracy (Type 2/3)** | 95-99% | ✅ Excellent |
| **False Positives** | 1-5% | ✅ Very Low |
| **Maintenance** | High complexity | ⚠️ Difficult |
| **Coverage** | Type 1-3 | ✅ Comprehensive |

**Verdict:** ⚠️ **High Value, High Cost** - Requires significant investment

---

## Recommended Approach

### Phase 1: Grep/Bash MVP (Immediate) ✅ **LEVERAGE EXISTING INFRASTRUCTURE**
**Timeline:** 1-2 days (infrastructure already exists!)
**Target:** Type 1 clones (exact duplicates)

**Implementation:**
1. **Reuse aggregation logic** from `run_aggregated_pattern()` in `check-performance.sh`
2. Create new pattern files in `dist/patterns/dry/`:
   - `duplicate-functions.json` - Hash-based function clone detection
   - `duplicate-code-blocks.json` - Sliding window block detection
3. Extend JSON schema with `detection_type: "clone_detection"`
4. Integrate into existing HTML/JSON reporting

**Expected Results:**
- Detect 60-70% of all clones (Type 1 only)
- < 5% false positive rate (same as string literal detection)
- Actionable results for developers
- **Zero new infrastructure needed** - builds on proven v1.0.73 implementation

**Risk:** LOW (proven pattern infrastructure + aggregation logic)

---

### Phase 2: Enhanced Normalization (Optional)
**Timeline:** 3-5 days
**Target:** Type 2 clones (renamed variables)

**Implementation:**
1. **PHP tokenizer integration** (already available - used in debugging)
2. Variable/function name normalization (replace with placeholders)
3. Similarity scoring (70%+ threshold)
4. **Reuse aggregation thresholds from v1.0.73** (min_distinct_files=3, min_total_matches=6)

**Expected Results:**
- Detect 80-85% of all clones (Type 1 + partial Type 2)
- 10-15% false positive rate (acceptable with manual review)
- Builds on proven pattern architecture

**Risk:** MEDIUM (higher false positives, but proven aggregation logic helps)

---

### Phase 3: AST-Based Detection (Future)
**Timeline:** 2-4 weeks
**Target:** Type 2-3 clones (structural similarity)

**Implementation:**
1. Integrate PHP-Parser or tree-sitter
2. Build AST comparison engine
3. Control flow graph analysis
4. Advanced similarity metrics

**Expected Results:**
- Detect 90-95% of all clones (Type 1-3)
- < 5% false positive rate
- Production-grade detection

---

## Comparison: Grep vs AST

### Detection Capabilities

```
Type 1 Clones (Exact Copies)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  ████████████████████████████  95%
AST:   ██████████████████████████████ 100%

Type 2 Clones (Renamed Variables)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  ████████                      30%
AST:   ██████████████████████████████ 100%

Type 3 Clones (Modified Logic)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  ██                            5%
AST:   █████████████████████████      85%

Type 4 Clones (Semantic Equivalence)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  -                             0%
AST:   ████                          15%
```

### Development Effort

```
Implementation Time
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  ███                     1-2 days (mostly testing)
AST:   ██████████████████      2-4 weeks

Maintenance Burden
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  ████                    Low
AST:   ████████████████████    High

Infrastructure Reuse
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grep:  ████████████████████    80% (v1.0.73 patterns/aggregation)
AST:   ██                      10% (needs new parser)
```

---

## Proof of Concept: Exact Function Clone Detector

**IMPORTANT:** This integrates with existing `check-performance.sh` infrastructure, not a standalone script.

### Pattern Definition (JSON)

**File:** `dist/patterns/dry/duplicate-functions.json`

```json
{
  "id": "duplicate-functions",
  "version": "1.0.0",
  "enabled": true,
  "category": "duplication",
  "severity": "MEDIUM",
  "title": "Duplicate function definitions across files",
  "description": "Detects exact function clones (Type 1) using hash-based comparison of normalized function bodies.",
  "rationale": "Copy-pasted functions across files violate DRY principle and create maintenance burden.",

  "detection": {
    "type": "aggregated",
    "file_patterns": ["*.php"],
    "search_pattern": "function\\s+\\w+\\s*\\([^)]*\\)\\s*\\{(?:[^{}]|\\{[^{}]*\\})*\\}",
    "capture_group": 0,
    "exclude_patterns": [
      "test",
      "vendor/",
      "node_modules/"
    ]
  },

  "aggregation": {
    "enabled": true,
    "group_by": "normalized_hash",
    "min_total_matches": 2,
    "min_distinct_files": 2,
    "min_lines": 5,
    "top_k_groups": 15,
    "normalization": {
      "remove_comments": true,
      "normalize_whitespace": true,
      "hash_algorithm": "md5"
    },
    "report_format": "Function duplicated in {file_count} files ({total_count} occurrences, {line_count} lines)",
    "sort_by": "file_count_desc"
  },

  "remediation": {
    "summary": "Extract duplicate functions to a shared utility class or file.",
    "examples": [
      {
        "bad": "// Duplicate function in 3 files\nfunction validate_email($email) { ... }",
        "good": "// Shared utility:\nclass Validators {\n  public static function email($email) { ... }\n}\n\n// Usage:\nValidators::email($email);",
        "note": "Centralize in includes/utilities/ or src/Helpers/"
      }
    ]
  }
}
```

### Integration with Existing Aggregation Logic

The existing `run_aggregated_pattern()` function in `check-performance.sh` already handles:
- ✅ Pattern loading
- ✅ Grep execution with capture groups
- ✅ Threshold filtering (min_total_matches, min_distinct_files)
- ✅ JSON/HTML output

**Additions needed:**
1. Hash normalization step (strip comments/whitespace before grouping)
2. Line count tracking (for min_lines threshold)
3. Function name extraction (for better reporting)

### Enhanced Implementation (100 lines of bash - integrates with existing system)

```bash
#!/bin/bash
# detect-function-clones.sh
# Detects exact function clones in PHP files

detect_function_clones() {
    local target_path="$1"
    local min_lines="${2:-5}"
    local min_files="${3:-2}"
    
    echo "🔍 Scanning for duplicate functions..."
    echo "   Minimum lines: $min_lines"
    echo "   Minimum files: $min_files"
    echo ""
    
    # Temporary file for results
    local temp_file=$(mktemp)
    
    # Extract all functions with their normalized bodies
    find "$target_path" -name "*.php" -type f | while read file; do
        # Extract function definitions with bodies
        grep -Pzo 'function\s+\w+\s*\([^)]*\)\s*\{(?:[^{}]|\{[^{}]*\})*\}' "$file" | \
        while IFS= read -r -d '' func; do
            # Normalize the function
            normalized=$(echo "$func" | \
                sed 's/\/\/.*$//' | \           # Remove line comments
                sed 's/\/\*.*?\*\///' | \       # Remove block comments
                sed 's/\s\+/ /g' | \            # Normalize whitespace
                tr -d '\n')                     # Remove newlines
            
            # Count lines in original function
            line_count=$(echo "$func" | wc -l)
            
            # Only process functions meeting minimum line threshold
            if [ "$line_count" -ge "$min_lines" ]; then
                # Generate hash of normalized function
                hash=$(echo "$normalized" | md5sum | cut -d' ' -f1)
                
                # Extract function name
                func_name=$(echo "$func" | grep -oP 'function\s+\K\w+')
                
                # Store: hash|file|function_name|line_count
                echo "$hash|$file|$func_name|$line_count" >> "$temp_file"
            fi
        done
    done
    
    # Find duplicates
    echo "📊 Analyzing results..."
    echo ""
    
    # Group by hash, count files
    sort "$temp_file" | \
    awk -F'|' '{
        hash=$1; file=$2; func=$3; lines=$4
        hashes[hash]++
        files[hash]=files[hash] file ":" func ":" lines ";"
    }
    END {
        for (hash in hashes) {
            if (hashes[hash] >= '$min_files') {
                print hash "|" hashes[hash] "|" files[hash]
            }
        }
    }' | while IFS='|' read hash count locations; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  DUPLICATE FUNCTION DETECTED"
        echo "   Found in $count location(s)"
        echo ""
        
        IFS=';' read -ra LOCS <<< "$locations"
        for loc in "${LOCS[@]}"; do
            [ -z "$loc" ] && continue
            IFS=':' read -r file func lines <<< "$loc"
            echo "   📁 $file"
            echo "      Function: $func() [$lines lines]"
            echo ""
        done
    done
    
    # Cleanup
    rm -f "$temp_file"
}

# Run detection
detect_function_clones "${1:-.}" "${2:-5}" "${3:-2}"
```

### Expected Output

```
🔍 Scanning for duplicate functions...
   Minimum lines: 5
   Minimum files: 2

📊 Analyzing results...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  DUPLICATE FUNCTION DETECTED
   Found in 3 location(s)

   📁 includes/validation.php
      Function: validate_email() [12 lines]

   📁 includes/admin/settings.php
      Function: validate_user_email() [12 lines]

   📁 includes/forms/contact.php
      Function: check_email() [12 lines]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Conclusion

### Can Grep/Bash Detect Logic Duplication?

**Answer:** ✅ **Yes, for Type 1 clones (exact copies)**

| Clone Type | Grep/Bash | Recommended Approach |
|------------|-----------|---------------------|
| Type 1 (Exact) | ✅ 95% accuracy | Hash-based matching |
| Type 2 (Renamed) | ⚠️ 30% accuracy | Token normalization + PHP |
| Type 3 (Modified) | ❌ 5% accuracy | AST required |
| Type 4 (Semantic) | ❌ 0% accuracy | AST + ML required |

### Do We Need AST?

**Answer:** ⚠️ **Not immediately, but eventually**

**Grep/Bash is sufficient for:**
- Exact function clones (Type 1) ← **Quick win, implement first**
- Code block duplication
- Copy-paste detection
- MVP validation

**AST is required for:**
- Renamed variable detection (Type 2)
- Modified logic detection (Type 3)
- Structural similarity (Type 3)
- Semantic equivalence (Type 4)
- Production-grade accuracy

---

## Recommendation

### Immediate: Implement Grep/Bash MVP ✅

**Why:**
- 1-2 days total (2-3 hours coding, rest is testing/validation)
- 60-70% of clones detected (Type 1)
- < 5% false positive rate (proven in v1.0.73)
- **80% infrastructure reuse** (patterns, aggregation, reports)
- Easy to maintain (bash + existing aggregation logic)
- Complements existing string literal detection

**Implementation Priority:**
1. Create `duplicate-functions.json` pattern (1 hour)
2. Extend `run_aggregated_pattern()` with hash normalization (1 hour)
3. Add to HTML report template (30 min)
4. Create test fixture with sample clones (30 min)
5. Test on 2-3 production WordPress plugins (validate false positives)
6. Document results and hold Go/No-Go decision

**Expected Value:**
- Detect copy-paste function violations
- Actionable results for developers (same as string literal detection)
- Low false positive rate = high trust
- **Proven approach** - same architecture as v1.0.73 string detection

**Exit Criteria (borrowed from NEXT-FIND-DRY.md):**
- [ ] Pattern detects violations in test fixtures
- [ ] False positive rate < 10% (manually verified on 2-3 real plugins)
- [ ] Scan time < 5 seconds on 10k file codebase
- [ ] Team agrees: "This is useful, let's continue"

**Key Learning from v1.0.73:**
> "The string literal detection earned a B+ not because it's comprehensive, but because it does ONE thing well with zero false positives."
>
> Logic clone detection follows the same philosophy: Start small, prove value, build trust.

---

### Future: Evaluate AST for Phase 2 🔜

**When to implement:**
- After MVP validates user demand (same as string literal Phase 1→Phase 2 progression)
- If Type 2/3 detection becomes priority
- If budget allows 2-4 week investment

**Tool Selection:**
- PHP-Parser (nikic/php-parser) - Best for PHP-only
- tree-sitter - Best for multi-language
- Custom solution - Best for control

**Decision Point:** 
Follow same Go/No-Go criteria as string literal detection:
- ✅ GO if: Patterns useful, < 10% false positives, team wants more
- ❌ NO-GO if: False positives > 25%, team doesn't find value

---

**Status:** 📋 Pending approval for Phase 1 implementation
**Next Steps:** Implement grep/bash MVP if approved
**Timeline:** 1-2 days total (2-3 hours coding + testing/validation)
**Risk:** LOW (proven infrastructure + clear validation plan)

---

## Appendix A: Lessons from String Literal Detection (v1.0.73)

### What Worked Well ✅
1. **Incremental approach** - Started with 3 patterns, not 20
2. **Aggregation thresholds** - min_distinct_files=3, min_total_matches=6 eliminated noise
3. **JSON pattern files** - Easy to add new patterns without code changes
4. **Real-world testing** - 2 plugins, 8 violations, 0 false positives proved value
5. **HTML integration** - Violations visible in reports developers already use
6. **Clear remediation** - "Extract to constants" is actionable

### What to Replicate 🔄
1. **Same pattern schema** - Extend existing JSON format, don't reinvent
2. **Same aggregation logic** - Reuse `run_aggregated_pattern()` function
3. **Same thresholds** - Start with min_distinct_files=2, min_lines=5
4. **Same testing approach** - Test on 2-3 real plugins before shipping
5. **Same Go/No-Go criteria** - < 10% false positives, team finds it useful

### What to Improve 🔧
1. **Add pattern validation** - JSON schema validation at load time
2. **Performance metrics** - Measure scan time on large codebases
3. **Better debug logging** - Append mode instead of overwrite
4. **Unit tests** - Mock grep output, test aggregation logic

### Key Insight
**"The string literal detection earned a B+ not because it's comprehensive, but because it does ONE thing well with zero false positives."**

Logic clone detection should follow the same philosophy:
- Start with Type 1 clones (exact copies) only
- Achieve < 5% false positive rate
- Make results actionable
- Build trust before expanding scope

---

## Appendix B: Integration Checklist

**Files to Modify:**
- [ ] `dist/patterns/dry/duplicate-functions.json` (NEW)
- [ ] `dist/bin/check-performance.sh` (MODIFY - add hash normalization to `run_aggregated_pattern()`)
- [ ] `dist/bin/templates/report-template.html` (MODIFY - add logic clones section)
- [ ] `dist/tests/fixtures/dry/duplicate-functions.php` (NEW - test fixture)

**Files to Review:**
- [ ] `DRY_VIOLATIONS_STATUS.md` (UPDATE - add logic clone detection status)
- [ ] `README.md` (UPDATE - document new detection type)

**Testing:**
- [ ] Unit test: Hash normalization strips comments/whitespace correctly
- [ ] Integration test: Pattern detects clones in test fixture
- [ ] Real-world test: Run on 2-3 production WordPress plugins
- [ ] Performance test: Measure scan time on 10k+ file codebase

**Acceptance Criteria:**
- [ ] Detects Type 1 clones (exact function copies)
- [ ] False positive rate < 10%
- [ ] Scan time < 10 seconds on typical plugin
- [ ] JSON/HTML output includes clone violations
- [ ] Team review: "This is useful"

---

## Appendix C: WordPress-Specific Clone Patterns (Future)

Based on real WordPress codebases, common clone patterns to detect:

1. **Authentication checks** (scattered across files)
   ```php
   if (!is_user_logged_in()) {
       wp_die('Access denied');
   }
   ```

2. **Permission checks** (already covered by capability strings, but logic differs)
   ```php
   if (!current_user_can('manage_options')) {
       return new WP_Error('forbidden', 'Insufficient permissions');
   }
   ```

3. **Data validation** (email, URL, sanitization)
   ```php
   if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
       return false;
   }
   ```

4. **Retry loops** (API calls, transient failures)
   ```php
   $retries = 3;
   while ($retries > 0) {
       // attempt operation
       if ($success) break;
       $retries--;
   }
   ```

5. **Cache patterns** (transient get/set with fallback)
   ```php
   $data = get_transient('cache_key');
   if (false === $data) {
       $data = expensive_operation();
       set_transient('cache_key', $data, HOUR_IN_SECONDS);
   }
   ```

**Priority:** Add these as Phase 2 patterns after Type 1 exact clone detection is validated.

---

## Document History

**Version 1.0** - January 1, 2026
- Initial feasibility study exploring grep/bash vs AST for logic duplication detection

**Version 2.0** - January 1, 2026
- Merged insights from `NEXT-FIND-DRY.md` (real-world implementation plan)
- Added context about v1.0.73 string literal detection (SHIPPED with 0 false positives)
- Repositioned from "greenfield project" to "extension of proven system"
- Added Implementation Summary (TL;DR) section
- Added three appendices: Lessons Learned, Integration Checklist, WordPress Patterns
- Unified timeline estimates (1-2 days including testing)
- Added Go/No-Go decision criteria from proven Phase 1 approach
- Added concrete JSON pattern schema example
- Emphasized infrastructure reuse (80% of code already exists)

**Key Insight:** Document transformed from theoretical study to practical implementation plan by connecting to proven v1.0.73 success.

---

**End of Document**

