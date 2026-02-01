# PHP JSON-to-HTML Converter Guide

**Quick Answer:** YES — The JSON file contains **100% of the data** needed to generate HTML in PHP. It's a 1:1 mapping.

---

## Key Points

✅ **Complete Data** — JSON has everything; nothing is lost  
✅ **Stable Structure** — Same keys/values across all versions  
✅ **Optional Fields** — Phase 2 (ai_triage) is optional; gracefully handle missing data  
✅ **Safe Defaults** — Use `??` operator for optional fields  

---

## Minimal PHP Example

```php
<?php
// Load JSON
$json = json_decode(file_get_contents('scan.json'), true);

// Extract with safe defaults
$version = $json['version'] ?? 'Unknown';
$timestamp = $json['timestamp'] ?? '';
$findings = $json['findings'] ?? [];
$checks = $json['checks'] ?? [];
$ai_triage = $json['ai_triage'] ?? [];

// Render findings
foreach ($findings as $finding) {
    echo sprintf(
        "<div class='finding %s'>\n",
        strtolower($finding['impact'] ?? 'medium')
    );
    echo sprintf("  <strong>%s</strong><br>\n", $finding['message']);
    echo sprintf("  %s:%d<br>\n", $finding['file'], $finding['line']);
    echo sprintf("  <code>%s</code>\n", htmlspecialchars($finding['code']));
    echo "</div>\n";
}

// Render Phase 2 (if performed)
if ($ai_triage['performed'] ?? false) {
    $reviewed = $ai_triage['scope']['findings_reviewed'] ?? 0;
    $confirmed = $ai_triage['summary']['confirmed_issues'] ?? 0;
    $false_pos = $ai_triage['summary']['false_positives'] ?? 0;
    $needs_review = $ai_triage['summary']['needs_review'] ?? 0;
    
    echo "<div class='phase2-summary'>\n";
    echo "  <p>Reviewed: $reviewed | Confirmed: $confirmed | ";
    echo "False Positives: $false_pos | Needs Review: $needs_review</p>\n";
    echo "</div>\n";
}
?>
```

---

## Data Structure Reference

### Top-Level Keys
```
version              string    Script version
timestamp            string    ISO 8601 UTC timestamp
paths_scanned        string    Scanned directory path
strict_mode          boolean   Strict mode enabled
project              object    Project metadata
summary              object    Scan summary stats
findings             array     All findings
checks               array     All checks
magic_string_violations array  DRY violations
fixture_validation   object    Fixture test results
ai_triage            object    Phase 2 triage data (optional)
```

### findings[] Structure
```
id                   string    Pattern ID
severity             string    error/warning
impact               string    CRITICAL/HIGH/MEDIUM/LOW
file                 string    File path
line                 integer   Line number
message              string    Human-readable message
code                 string    Code snippet
context              array     Context lines (optional)
```

### checks[] Structure
```
name                 string    Check name
impact               string    CRITICAL/HIGH/MEDIUM/LOW
status               string    passed/failed
findings_count       integer   Number of findings
```

### ai_triage Structure (Optional)
```
performed            boolean   Triage was performed
timestamp            string    ISO 8601 timestamp
status               string    complete/pending/error
version              string    Triage tool version
scope                object    {findings_reviewed: int, max_findings_reviewed: int}
summary              object    {confirmed_issues, false_positives, needs_review, confidence_level}
narrative            string    3-5 paragraph summary
recommendations      array     Actionable recommendations
triaged_findings     array     Individual verdict details
```

---

## Safe Conversion Checklist

- [ ] Use `json_decode($json, true)` to get associative array
- [ ] Use `??` operator for optional fields (ai_triage, context, etc.)
- [ ] HTML-escape all user-facing strings with `htmlspecialchars()`
- [ ] Convert file paths to absolute paths if needed
- [ ] Handle missing ai_triage gracefully (show placeholder)
- [ ] Preserve all finding data (don't filter/truncate)
- [ ] Test with both old JSON (no ai_triage) and new JSON (with ai_triage)

---

## Testing Your Converter

```bash
# Get a sample JSON file
ls -t dist/logs/*.json | head -1

# Validate JSON structure
jq . dist/logs/LATEST.json > /dev/null

# Test your PHP converter
php your-converter.php dist/logs/LATEST.json > report.html

# Verify output
open report.html
```

---

## Common Pitfalls

❌ **Don't** assume ai_triage exists — use `??` operator  
❌ **Don't** truncate findings — preserve all data  
❌ **Don't** forget to HTML-escape code snippets  
❌ **Don't** hardcode field names — use safe accessors  

✅ **Do** validate JSON before processing  
✅ **Do** handle missing optional fields gracefully  
✅ **Do** preserve all finding context  
✅ **Do** test with multiple JSON versions  

---

## Questions?

See `dist/JSON-TO-HTML-MAPPING.md` for complete field reference.

