# Scripted Validators

This directory contains validator scripts for complex pattern detection that cannot be expressed as simple grep patterns.

## Overview

Scripted validators enable **post-processing logic** for pattern matches, allowing:
- Context-aware validation (reading surrounding lines)
- Comment suppression detection (phpcs:ignore, etc.)
- Parameter counting and validation
- Heuristic analysis (loop detection, etc.)
- Custom business logic

## Validator Interface

### Input (via command-line arguments)

Validators receive the following arguments:

```bash
validator-script.sh <file> <line_number> <matched_code> [context_lines]
```

**Arguments:**
1. `$1` - **file**: Full path to the file containing the match
2. `$2` - **line_number**: Line number where the pattern matched
3. `$3` - **matched_code**: The actual line of code that matched
4. `$4` - **context_lines** (optional): Number of context lines to read (default: 10)

### Output (via exit code)

Validators must exit with one of these codes:

- **Exit 0**: Confirmed issue - this is a real violation
- **Exit 1**: False positive - suppress this finding
- **Exit 2**: Needs manual review - flag for human inspection (treated as warning)

### Standard Error

Validators should write diagnostic messages to stderr for debugging:

```bash
echo "[DEBUG] Checking for phpcs:ignore comment" >&2
```

## JSON Pattern Schema

To use a scripted validator, set `detection.type` to `"scripted"` and specify the validator script:

```json
{
  "id": "example-pattern",
  "detection": {
    "type": "scripted",
    "search_pattern": "some_function\\(",
    "file_patterns": ["*.php"],
    "validator_script": "validators/example-validator.sh",
    "context_lines": 15
  }
}
```

**Fields:**
- `type`: Must be `"scripted"`
- `search_pattern`: Initial grep pattern to find candidates
- `file_patterns`: File extensions to search
- `validator_script`: Path to validator script (relative to repo root)
- `context_lines`: Number of lines to pass to validator (optional, default: 10)

## Validator Template

See `validator-template.sh` for a complete example with error handling and best practices.

## Existing Validators

- `phpcs-ignore-check.sh` - Detects phpcs:ignore suppression comments
- `parameter-count-check.sh` - Validates function parameter counts
- `loop-context-check.sh` - Detects code patterns inside loops

## Development Guidelines

1. **Keep validators focused** - One validator per validation concern
2. **Handle edge cases** - Check for empty input, invalid line numbers, missing files
3. **Use defensive coding** - Validate all inputs before processing
4. **Write to stderr for debugging** - Use `[DEBUG]` prefix for diagnostic messages
5. **Test in isolation** - Validators should work standalone without the main script
6. **Document assumptions** - Explain what the validator checks and why

## Testing Validators

Test validators manually before integrating:

```bash
# Test with a real file
./dist/validators/phpcs-ignore-check.sh \
  "path/to/file.php" \
  42 \
  "current_time('timestamp')" \
  10

# Check exit code
echo $?  # Should be 0 (issue), 1 (false positive), or 2 (needs review)
```

## Performance Considerations

- Validators are called **once per match**, so keep them fast
- Avoid expensive operations (network calls, large file reads)
- Cache file reads when possible (read once, check multiple conditions)
- Use `sed -n` for targeted line extraction instead of reading entire files

## Security Considerations

- **Never execute code from matched patterns** - treat all input as untrusted
- **Validate file paths** - ensure files exist and are readable
- **Sanitize line numbers** - check for numeric values before using in sed/awk
- **Avoid shell injection** - quote all variables, use `[[ ]]` for comparisons

