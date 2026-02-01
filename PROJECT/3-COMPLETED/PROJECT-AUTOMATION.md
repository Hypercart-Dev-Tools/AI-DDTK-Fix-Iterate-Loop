# Project Automation: Phase 2 AI Triage Integration

**Created**: 2026-01-07
**Status**: Not Started
**Priority**: High
**Target Version**: v1.1.0
**Scope**: Human-initiated POC validation (v1.1) → Semi-automated publishing (v1.2) → Full server automation (v2.0+)

---

## 📋 Implementation Checklist (v1.1 POC)

- [ ] **Phase 1: JSON Schema Updates**
  - [ ] Add `ai_triage` placeholder object to JSON schema
  - [ ] Define structure: `status`, `findings_reviewed`, `verdicts`, `timestamp`
  - [ ] Document in PATTERN-LIBRARY.md

- [ ] **Phase 2: HTML Template Updates**
  - [ ] Add Phase 2 placeholder section to report-template.html
  - [ ] Create `#ai-triage` injection point with `data-ai-inject="triage"`
  - [ ] Style placeholder state (pending/complete/error)
  - [ ] Add disclaimer box styling

- [ ] **Phase 3: AI Agent Instructions**
  - [ ] Update `_AI_INSTRUCTIONS.md` with Phase 2 workflow
  - [ ] Document JSON injection method (Python script)
  - [ ] Document HTML re-generation after JSON update
  - [ ] Add disclaimer text template

- [ ] **Phase 4: Enhance json-to-html.py**
  - [ ] Add `ai_triage` section rendering to existing script
  - [ ] Handle missing `ai_triage` gracefully (show placeholder)
  - [ ] Preserve AI triage data during conversion
  - [ ] No new files created (modify existing only)

- [ ] **Phase 5: Local Dev Workflow Testing**
  - [ ] Manual test: AI agent injects triage into JSON
  - [ ] Manual test: json-to-html.py renders Phase 2 section
  - [ ] Verify both local HTML and server-ready JSON work
  - [ ] Document manual workflow steps

---

## 🎯 Overview

**Goal (v1.1 POC)**: Enable human-initiated AI-assisted false positive detection as a 2nd pass after static analysis, with results stored in JSON and rendered in HTML for local dev validation.

**Long-term Vision (v2.0+)**: Fully automated server-side scanning of WP.org plugin updates with circuit breakers, throttling, and semi-automated publishing to WP site.

**Current Scope**: Human-initiated testing only. No automation yet.

**Architecture (v1.1)**:
```
Static Scan → JSON (Phase 1 data + AI placeholder)
                ↓
        [HUMAN INITIATES]
                ↓
        Local Dev AI Agent (manual trigger)
                ↓
        JSON (Phase 1 + Phase 2 AI triage)
                ↓
        json-to-html.py (enhanced)
                ↓
        Final HTML Report (with both phases)
                ↓
        [HUMAN REVIEWS & VALIDATES]
```

**Future Architecture (v2.0+)**:
```
WP.org Plugin Updates (monitored)
        ↓
    [AUTOMATED]
        ↓
Server-side scan + AI triage
        ↓
Circuit breakers & throttling
        ↓
Semi-automated publish to WP site
```

---

## 📐 JSON Schema: `ai_triage` Object

```json
{
  "ai_triage": {
    "status": "pending",
    "performed": false,
    "timestamp": null,
    "version": "1.0",
    "disclaimer": "This AI-assisted analysis is provided for informational purposes only...",
    "summary": {
      "findings_reviewed": 0,
      "confirmed_issues": 0,
      "false_positives": 0,
      "needs_review": 0,
      "confidence_level": "N/A"
    },
    "verdicts": [],
    "recommendations": [],
    "notes": "Not performed yet"
  }
}
```

**Verdict Object Structure**:
```json
{
  "finding_id": "hcc-008-unsafe-regexp",
  "file": "repeater.js",
  "line": 126,
  "verdict": "confirmed",
  "reason": "User property in RegExp without escaping",
  "confidence": "high",
  "recommendation": "Add regex escaping for property names"
}
```

---

## 🎨 HTML Template: Phase 2 Placeholder

```html
<!-- Phase 2: AI-Assisted Triage (Placeholder) -->
<section id="ai-triage" class="ai-triage-section" data-ai-inject="triage">
  <h2>Phase 2 (TL;DR) - Automated AI False Positive Scan</h2>
  
  <div class="ai-triage-disclaimer">
    <strong>⚠️ Disclaimer:</strong> This AI-assisted analysis is provided for 
    informational purposes only and represents probabilistic pattern matching, 
    not definitive security assessment. Developers must perform manual code 
    review to verify all findings. We make no guarantees about accuracy or 
    completeness. When in doubt, treat flagged code as requiring human review.
  </div>
  
  <div class="ai-triage-content" data-status="pending">
    <p class="status-message">⏳ Not performed yet</p>
    <p class="help-text">
      Run the AI triage command to analyze findings and identify likely false positives.
    </p>
  </div>
</section>
```

**CSS Styling**:
```css
.ai-triage-section {
  background: #f0f4ff;
  border-left: 4px solid #4a90e2;
  padding: 20px;
  margin: 30px 0;
  border-radius: 4px;
}

.ai-triage-disclaimer {
  background: #fff3cd;
  border: 1px solid #ffc107;
  padding: 12px;
  border-radius: 4px;
  margin-bottom: 15px;
  font-size: 0.9em;
}

.ai-triage-content[data-status="pending"] {
  color: #666;
  font-style: italic;
}

.ai-triage-content[data-status="complete"] {
  color: #155724;
}

.ai-triage-content[data-status="error"] {
  color: #721c24;
  background: #f8d7da;
  padding: 10px;
  border-radius: 4px;
}
```

---

## 🤖 AI Agent Workflow (Local Dev)

**Step 1: Detect Report**
```bash
# After scan completes, AI agent checks for new JSON
latest_json=$(ls -t dist/logs/*.json | head -1)
echo "New report: $latest_json"
```

**Step 2: Perform Triage**
```bash
# AI agent reads JSON, analyzes findings
# Generates verdicts and recommendations
# Updates JSON ai_triage section
```

**Step 3: Update JSON**
```bash
# AI agent injects Phase 2 data into JSON
# Sets: status="complete", performed=true, timestamp, verdicts[], etc.
```

**Step 4: Re-generate HTML**
```bash
# Re-run JSON → HTML converter with updated JSON
python3 dist/bin/json-to-html.py "$latest_json" "dist/reports/$(basename $latest_json .json).html"
```

---

## 📝 AI Instructions Update

Add to `_AI_INSTRUCTIONS.md`:

```markdown
## Phase 2: AI-Assisted Triage (Manual, v1.1 POC)

After HTML report is generated, you can perform a 2nd pass AI triage:

### When to Use
- User explicitly asks: "Run AI triage on this report"
- User wants to validate false positives before publishing
- Part of POC validation workflow (not yet automated)

### Workflow Steps

1. **Read the JSON log** to understand findings
   \`\`\`bash
   cat dist/logs/TIMESTAMP.json | jq '.findings[] | {id, severity, file, line}'
   \`\`\`

2. **Analyze each critical finding** for false positives
   - Check for phpcs:ignore comments
   - Verify nonce/capability checks
   - Look for adjacent sanitization
   - Identify string literal matches vs actual superglobal access

3. **Update the JSON** with verdicts and recommendations
   - Use Python to safely inject ai_triage data
   - Preserve all existing Phase 1 data
   - Set timestamp to current UTC time

4. **Re-generate HTML** to include AI triage section
   - Run enhanced json-to-html.py
   - Verify Phase 2 section renders correctly

### JSON Injection Method

Use Python to safely update JSON:
\`\`\`python
import json
from datetime import datetime

# Read existing JSON
with open('dist/logs/TIMESTAMP.json', 'r') as f:
    data = json.load(f)

# Inject ai_triage data
data['ai_triage'] = {
    'status': 'complete',
    'performed': True,
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'version': '1.0',
    'summary': {
        'findings_reviewed': 10,
        'confirmed_issues': 2,
        'false_positives': 7,
        'needs_review': 1,
        'confidence_level': 'high'
    },
    'verdicts': [
        {
            'finding_id': 'hcc-008-unsafe-regexp',
            'file': 'repeater.js',
            'line': 126,
            'verdict': 'confirmed',
            'reason': 'User property in RegExp without escaping',
            'confidence': 'high',
            'recommendation': 'Add regex escaping for property names'
        },
        # ... more verdicts
    ],
    'recommendations': [
        'Priority 1: Fix unsafe RegExp in repeater.js',
        'Priority 2: Review minified JS source'
    ]
}

# Write updated JSON
with open('dist/logs/TIMESTAMP.json', 'w') as f:
    json.dump(data, f, indent=2)
\`\`\`

### Re-generate HTML

After updating JSON:
\`\`\`bash
python3 dist/bin/json-to-html.py dist/logs/TIMESTAMP.json dist/reports/TIMESTAMP.html
\`\`\`

### Verify Results

Open the HTML report and verify:
- Phase 2 section appears (not placeholder)
- Disclaimer is visible
- Verdicts table renders correctly
- All findings are accounted for

### Future (v1.2+)
This workflow will be semi-automated. For now, it's manual.
```

---

## 🖥️ Enhanced json-to-html.py Script

**File**: `dist/bin/json-to-html.py` (existing, enhanced)

**Changes**:
- Add `ai_triage` section rendering to existing template injection
- Detect `ai_triage.performed === true` and render verdicts
- Handle missing `ai_triage` gracefully (show placeholder)
- Preserve all data for archival and server deployment

**Key Features**:
- Renders verdicts table if `ai_triage.performed === true`
- Shows disclaimer prominently in Phase 2 section
- Maintains backward compatibility (old JSON without `ai_triage` still works)
- No new files created (single source of truth for conversion logic)

**Scope (v1.1)**:
- Local dev: AI agent manually triggers re-generation after JSON update
- Server (future): Same script used for server-side conversion

---

## 🔄 Workflow Examples

### v1.1 POC: Local Dev (Human-Initiated)
```bash
# Step 1: Developer runs scan
./run gravityforms --format json
# → Generates: dist/logs/2026-01-07-163420-UTC.json
# → Generates: dist/reports/2026-01-07-163420-UTC.html (Phase 2 shows placeholder)

# Step 2: Developer manually triggers AI triage (via VS Code agent)
# → AI agent reads JSON
# → AI agent analyzes findings
# → AI agent updates JSON with ai_triage data
# → JSON now has: status="complete", performed=true, verdicts[], etc.

# Step 3: Developer manually re-generates HTML
python3 dist/bin/json-to-html.py dist/logs/2026-01-07-163420-UTC.json dist/reports/2026-01-07-163420-UTC.html
# → HTML now includes Phase 2 section with AI verdicts

# Step 4: Developer reviews report
open dist/reports/2026-01-07-163420-UTC.html
# → Validates AI triage accuracy
# → Confirms false positives identified
# → Prepares for publishing
```

### v1.2+ Future: Semi-Automated Publishing
```bash
# After validation, developer publishes to WP site
# (Manual step, not yet automated)
```

### v2.0+ Future: Server Deployment (Fully Automated)
```bash
# Server receives JSON from WP.org monitoring
# Server runs enhanced json-to-html.py
python3 dist/bin/json-to-html.py input.json output.html

# If JSON has ai_triage data → renders Phase 2 section
# If not → shows placeholder
# Publishes to WP site automatically (with circuit breakers)
```

---

## 🎯 Success Criteria (v1.1 POC)

- ✅ JSON schema includes `ai_triage` placeholder
- ✅ HTML template has Phase 2 section with placeholder
- ✅ AI agent can manually inject triage data into JSON
- ✅ Enhanced json-to-html.py renders Phase 2 section
- ✅ Local dev workflow tested and documented
- ✅ Disclaimer is prominent and clear
- ✅ Backward compatible (old JSON without ai_triage still works)
- ✅ No new files created (only existing files modified)

---

## 📋 Phased Rollout Plan

### v1.1 (Current POC)
- **Scope**: Human-initiated AI triage validation
- **Trigger**: Developer manually runs AI agent
- **Publishing**: Manual (not automated)
- **Target**: Validate AI triage accuracy before scaling

### v1.2 (Future Enhancement)
- **Scope**: Semi-automated publishing workflow
- **Trigger**: Developer approves triage, publishes to WP site
- **Publishing**: Semi-automated (developer initiates)
- **Target**: Streamline local dev → WP site workflow

### v2.0+ (Long-term Vision)
- **Scope**: Fully automated WP.org monitoring and testing
- **Trigger**: Automatic detection of plugin updates
- **Publishing**: Automated with circuit breakers & throttling
- **Target**: Continuous scanning of WP.org ecosystem

---

## ⚠️ Known Limitations & Future Improvements

**v1.1 Limitations**:
- AI triage is human-initiated (not automatic)
- No circuit breakers or throttling (not needed for POC)
- No WP.org monitoring (manual plugin selection)
- No automated publishing (manual step)
- AI analyzes top 10-15 critical findings only (can be extended)

**Future Improvements**:
- Automatic detection of new plugin versions on WP.org
- Circuit breakers to prevent runaway scans
- Throttling to respect WP.org API limits
- Semi-automated publishing to WP site
- ML model training on Gravity Forms codebase for better accuracy
- Confidence scoring per finding
- Bidirectional linking between AI verdicts and findings

---

## 📚 Related Files to Modify

- `dist/TEMPLATES/_AI_INSTRUCTIONS.md` - Add Phase 2 workflow section
- `dist/bin/templates/report-template.html` - Add Phase 2 placeholder section
- `dist/bin/json-to-html.py` - Enhance to render ai_triage section
- `PATTERN-LIBRARY.json` - Document ai_triage schema (optional)

