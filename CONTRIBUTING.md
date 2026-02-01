# Contributing to WP Code Check

Thank you for your interest in contributing to **WP Code Check**! We welcome contributions from the WordPress community.

---

## 🚀 How to Contribute

### Reporting Bugs

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear title describing the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Your environment (OS, bash version, WordPress version)
   - Sample code that triggers the issue (if applicable)

### Suggesting Features

1. **Check existing feature requests** to avoid duplicates
2. **Create a new issue** with:
   - Clear description of the feature
   - Use case / problem it solves
   - Example usage (if applicable)

### Submitting Pull Requests

1. **Sign the Contributor License Agreement (CLA)** - See [CLA Requirements](#-contributor-license-agreement-cla) below
2. **Fork the repository**
3. **Create a feature branch** (`git checkout -b feature/my-new-check`)
4. **Make your changes**
5. **Add tests** (see `dist/tests/fixtures/` for examples)
6. **Run the test suite** (`dist/tests/run-fixture-tests.sh`)
7. **Update documentation** (README.md, CHANGELOG.md)
8. **Commit with clear messages** (see commit guidelines below)
9. **Push to your fork** and submit a pull request

---

## 📝 Development Guidelines

### Adding New Performance Checks

**⚠️ IMPORTANT:** All new rules MUST be defined as JSON patterns in `dist/patterns/`. Inline rules in `check-performance.sh` are legacy and will be removed.

**JSON Rule Structure:**

Create a new JSON file in `dist/patterns/` (or add to an existing category file):

```json
{
  "id": "unbounded-posts-per-page",
  "version": "1.0.0",
  "enabled": true,
  "category": "performance",
  "severity": "CRITICAL",
  "title": "Unbounded posts_per_page",
  "description": "Detects WordPress queries that disable pagination and can crash large sites.",
  "rationale": "Unbounded queries can fetch all posts at once, leading to timeouts and memory exhaustion.",

  "detection": {
    "type": "simple",
    "file_patterns": ["*.php"],
    "grep": {
      "include": [
        "-E posts_per_page[[:space:]]*=>[[:space:]]*-1"
      ],
      "override_include": "--include=*.php"
    }
  },

  "remediation": {
    "summary": "Add pagination or a reasonable LIMIT to queries to avoid loading all records at once.",
    "examples": [
      {
        "bad": "WP_Query(['posts_per_page' => -1])",
        "good": "WP_Query(['posts_per_page' => 50, 'paged' => $paged])",
        "note": "Use paged queries and reasonable limits for production sites."
      }
    ]
  }
}
```

**Detection Types:**

- `"simple"` – Basic grep pattern matching (most common)
- `"aggregated"` – DRY/clone detection with grouping and thresholds
- `"contextual"` – Context-aware rules (requires custom validator)
- `"scripted"` – Complex rules requiring custom validator scripts

**File Organization:**

- `dist/patterns/core/*.json` – Core performance/security rules
- `dist/patterns/dry/*.json` – DRY/duplication detection rules
- `dist/patterns/headless/*.json` – Headless WordPress patterns
- `dist/patterns/js/*.json` – JavaScript-specific patterns
- `dist/patterns/nodejs/*.json` – Node.js-specific patterns

**Legacy Inline Format (DO NOT USE):**

```bash
# ❌ DEPRECATED - Do not add new rules this way
run_check "ERROR" "CRITICAL" \
  "Unbounded posts_per_page" "unbounded-posts-per-page" \
  "-E posts_per_page[[:space:]]*=>[[:space:]]*-1"
```

See `PROJECT/2-WORKING/PATTERN-MIGRATION-TO-JSON.md` for the migration plan.

### Test Fixtures

Every new check **must** have test fixtures:

1. **Add antipattern** to `dist/tests/fixtures/antipatterns.php`
2. **Add safe pattern** to `dist/tests/fixtures/clean-code.php`
3. **Update expected counts** in `dist/tests/run-fixture-tests.sh`

### Code Style

- **Bash**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Comments**: Explain *why*, not *what*
- **Functions**: One responsibility per function
- **Variables**: Use descriptive names (`FINDING_COUNT` not `fc`)

### Updating the Cache-Primed Hooks Dictionary

The **cache-primed hooks dictionary** (`WP_CACHE_PRIMED_HOOKS`) is located in `dist/bin/ai-triage.py`. This dictionary maps WordPress hooks to object types and is critical for reducing false positives in N+1 detection.

#### Steps to Update:
1. **Identify New Hooks**:
   - Look for WordPress hooks that pre-cache metadata for objects (e.g., `user`, `post`, `comment`).
2. **Add to the Dictionary**:
   - Open `dist/bin/ai-triage.py` and add the new hook to the `WP_CACHE_PRIMED_HOOKS` dictionary.
3. **Test Your Changes**:
   - Run the test suite to ensure no regressions.
   - Add new test cases if necessary.
4. **Submit a Pull Request**:
   - Include a clear description of the added hooks and their purpose.

#### Example:
```python
WP_CACHE_PRIMED_HOOKS = {
    'show_user_profile': 'user',
    'edit_user_profile': 'user',
    'add_meta_boxes': 'post',
    # Add new hooks here
}
```

---

## 🧪 Testing

### Run All Tests

```bash
cd dist/tests
./run-fixture-tests.sh
```

### Test Individual Checks

```bash
cd dist/bin
./check-performance.sh --paths ../tests/fixtures/antipatterns.php
```

Expected output:
- **Errors**: 6+ (depending on active checks)
- **Warnings**: 4+

### End-to-End Template Testing

Use the keyword **"Run template [name] end to end"** to execute a complete scan and AI triage workflow with minimal human intervention.

**What this does:**
1. Loads the template configuration from `TEMPLATES/[name].txt`
2. Executes the full performance scan (`check-performance.sh`)
3. Generates JSON log with all findings
4. Runs AI-assisted triage on the findings
5. Converts JSON to HTML report with triage data embedded
6. Opens the final report in your browser

**Example:**
```bash
# User request: "Run template gravityforms end to end"
# AI will execute:
./dist/bin/run gravityforms --format json
python3 dist/bin/ai-triage.py dist/logs/[latest].json
python3 dist/bin/json-to-html.py dist/logs/[latest].json dist/reports/[output].html
```

**Benefits:**
- ✅ Complete workflow in one command
- ✅ AI triage automatically classifies findings
- ✅ HTML report includes triage classifications and confidence levels
- ✅ No manual JSON/HTML conversion needed
- ✅ Ideal for testing new checks or validating fixes

**Template Requirements:**
- Template file must exist in `TEMPLATES/[name].txt`
- Must contain `PROJECT_PATH` pointing to a valid WordPress plugin/theme directory
- Optional: `FORMAT=json` to enable JSON output (required for triage)

---

## 📋 Commit Message Guidelines

Use conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `test`: Adding/updating tests
- `refactor`: Code restructuring (no behavior change)
- `perf`: Performance improvement
- `chore`: Maintenance tasks

**Examples:**
```
feat(checks): add detection for unbounded get_users()

Detects get_users() calls without 'number' parameter which can
fetch ALL users and crash sites with large user bases.

Closes #42
```

```
fix(html): display full path instead of "." in report header

When scanning with --paths ., the HTML report now shows the
resolved absolute path instead of just a dot.
```

---

## 🔒 Security

**Do NOT commit:**
- API keys, tokens, or credentials
- User-generated logs or reports
- Proprietary plugin/theme code
- Personal information

If you discover a security vulnerability, please email **security@hypercart.com** instead of opening a public issue.

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the **Apache License 2.0**, the same license as the project.

See [LICENSE](LICENSE) for full terms.

---

## 📝 Contributor License Agreement (CLA)

### Why We Require a CLA

WP Code Check is dual-licensed under Apache 2.0 (open source) and commercial licenses. The CLA ensures:

1. **Legal clarity** - You confirm you have the right to contribute
2. **Dual licensing** - Your contributions can be included in both open source and commercial versions
3. **Patent protection** - Explicit patent grants protect all users
4. **Community protection** - Prevents legal issues that could harm the project

### How to Sign the CLA

**For Individual Contributors:**

1. Read the [Individual Contributor License Agreement (CLA.md)](CLA.md)
2. On your first pull request, add a comment: **"I have read and agree to the CLA"**
3. Alternatively, email a signed copy to `cla@hypercart.com`

**For Corporate Contributors:**

If you're contributing on behalf of your employer:

1. Your employer must sign the [Corporate CLA (CLA-CORPORATE.md)](CLA-CORPORATE.md)
2. You must also sign the Individual CLA
3. Contact `cla@hypercart.com` to submit the Corporate CLA

### Key Points

- ✅ **You retain copyright** to your contributions
- ✅ **You can use your code elsewhere** - No restrictions on your own use
- ✅ **Open source stays open** - Apache 2.0 version always available
- ✅ **One-time process** - Sign once, contribute forever
- ✅ **Standard practice** - Based on Apache Software Foundation's CLA

**Questions about the CLA?** Email `cla@hypercart.com`

---

## 🙏 Recognition

Contributors will be recognized in:
- GitHub contributors page
- CHANGELOG.md (for significant contributions)
- Project README (for major features)

---

## ❓ Questions?

- **Documentation**: See [README.md](README.md) and [dist/README.md](dist/README.md)
- **Issues**: [GitHub Issues](https://github.com/YOUR_ORG/wp-code-check/issues)
- **Email**: support@hypercart.com

---

**Thank you for helping make WordPress faster and more secure!** 🚀

