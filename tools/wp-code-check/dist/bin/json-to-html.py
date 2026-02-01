#!/usr/bin/env python3
"""
json-to-html.py - Convert WP Code Check JSON logs to HTML reports

Usage: ./json-to-html.py <input.json> <output.html>
Example: ./json-to-html.py dist/logs/2026-01-05-032317-UTC.json dist/reports/report.html

This standalone script converts JSON scan logs to beautiful HTML reports.
It's optimized for performance and reliability.

Requirements:
  - Python 3.6+
  - No external dependencies (uses only stdlib)

Exit codes:
  0 - Success
  1 - Missing arguments or file not found
  2 - JSON parsing error
  3 - Template file not found
"""

import json
import os
import sys
import subprocess
from pathlib import Path

# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_usage():
    """Print usage information"""
    print(f"""{Colors.BLUE}WP Code Check - JSON to HTML Converter{Colors.NC}

{Colors.GREEN}Usage:{Colors.NC}
  {sys.argv[0]} <input.json> <output.html>

{Colors.GREEN}Arguments:{Colors.NC}
  input.json   - Path to JSON scan log file
  output.html  - Path to output HTML report file

{Colors.GREEN}Example:{Colors.NC}
  {sys.argv[0]} dist/logs/2026-01-05-032317-UTC.json dist/reports/report.html

{Colors.GREEN}Description:{Colors.NC}
  Converts WP Code Check JSON scan logs into beautiful, interactive HTML reports.
  Fast and reliable Python implementation.
""")

def main():
    # Check arguments
    if len(sys.argv) != 3:
        print(f"{Colors.RED}Error: Missing required arguments{Colors.NC}", file=sys.stderr)
        print("", file=sys.stderr)
        print_usage()
        sys.exit(1)
    
    input_json = sys.argv[1]
    output_html = sys.argv[2]
    
    # Validate input file exists
    if not os.path.isfile(input_json):
        print(f"{Colors.RED}Error: Input file not found: {input_json}{Colors.NC}", file=sys.stderr)
        sys.exit(1)
    
    # Get script directory for template
    script_dir = Path(__file__).parent
    template_file = script_dir / "templates" / "report-template.html"
    
    # Check if template exists
    if not template_file.exists():
        print(f"{Colors.RED}Error: HTML template not found at {template_file}{Colors.NC}", file=sys.stderr)
        sys.exit(3)
    
    print(f"{Colors.BLUE}Converting JSON to HTML...{Colors.NC}")
    print(f"  Input:  {Colors.GREEN}{input_json}{Colors.NC}")
    print(f"  Output: {Colors.GREEN}{output_html}{Colors.NC}")
    
    # Read and parse JSON
    try:
        with open(input_json, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}Error: Invalid JSON in input file: {e}{Colors.NC}", file=sys.stderr)
        sys.exit(2)
    
    # Extract metadata
    version = data.get('version', 'Unknown')
    timestamp = data.get('timestamp', 'Unknown')
    paths = data.get('paths_scanned', '.')
    
    summary = data.get('summary', {})
    total_errors = summary.get('total_errors', 0)
    total_warnings = summary.get('total_warnings', 0)
    baselined = summary.get('baselined', 0)
    stale_baseline = summary.get('stale_baseline', 0)
    exit_code = summary.get('exit_code', 0)
    
    strict_mode = str(data.get('strict_mode', False)).lower()
    
    findings = data.get('findings', [])
    findings_count = len(findings)
    
    magic_violations = data.get('magic_string_violations', [])
    dry_violations_count = len(magic_violations)
    clone_detection_ran = summary.get('clone_detection_ran', False)

    # Count magic strings vs function clones
    magic_string_count = sum(1 for v in magic_violations if v.get('type') == 'magic_string')
    function_clone_count = sum(1 for v in magic_violations if v.get('type') == 'function_clone')

    checks = data.get('checks', [])
    
    # Extract fixture validation info
    fixture_validation = data.get('fixture_validation', {})
    fixture_status = fixture_validation.get('status', 'not_run')
    fixture_passed = fixture_validation.get('passed', 0)
    fixture_failed = fixture_validation.get('failed', 0)

    # Set fixture status for HTML
    if fixture_status == 'passed':
        fixture_status_class = 'passed'
        fixture_status_text = f'✓ Detection Verified ({fixture_passed} fixtures)'
    elif fixture_status == 'failed':
        fixture_status_class = 'failed'
        fixture_status_text = f'⚠ Detection Warning ({fixture_failed}/{fixture_passed} failed)'
    else:
        fixture_status_class = 'skipped'
        fixture_status_text = '○ Fixtures Skipped'

    # Extract AI triage info (Phase 2)
    ai_triage = data.get('ai_triage', {})
    ai_triage_performed = ai_triage.get('performed', False)
    ai_triage_timestamp = ai_triage.get('timestamp', '')
    ai_triage_summary = ai_triage.get('summary', {})
    ai_triage_recommendations = ai_triage.get('recommendations', [])
    
    # Extract project information
    project = data.get('project', {})
    project_type = project.get('type', 'unknown')
    project_name = project.get('name', '')
    project_version = project.get('version', '')
    project_author = project.get('author', '')
    files_analyzed = project.get('files_analyzed', 0)
    lines_of_code = project.get('lines_of_code', 0)
    
    print(f"{Colors.BLUE}Processing project information...{Colors.NC}")
    
    # Build project info HTML
    project_info_html = ""
    if project_name and project_name != "Unknown":
        type_display = {
            'plugin': 'WordPress Plugin',
            'theme': 'WordPress Theme',
            'fixture': 'Fixture Test',
            'unknown': 'Unknown'
        }.get(project_type, project_type)
        
        project_info_html = f"<div style='font-size: 1.1em; font-weight: 600; margin-bottom: 5px;'>PROJECT INFORMATION</div>"
        project_info_html += f"<div>Name: {project_name}</div>"
        if project_version:
            project_info_html += f"<div>Version: {project_version}</div>"
        project_info_html += f"<div>Type: {type_display}</div>"
        if project_author:
            project_info_html += f"<div>Author: {project_author}</div>"
        if files_analyzed:
            try:
                formatted_files = f"{int(files_analyzed):,}"
            except (TypeError, ValueError):
                formatted_files = files_analyzed
            project_info_html += f"<div>Files Analyzed: {formatted_files} PHP files</div>"
        if lines_of_code:
            project_info_html += f"<div>Lines Reviewed: {lines_of_code:,} lines of code</div>"
    
    # Create clickable links for scanned paths
    abs_path = os.path.abspath(paths) if not os.path.isabs(paths) else paths
    paths_link = f'<a href="file://{abs_path}" class="ide-link" data-file="{abs_path}" style="color: #667eea;">{paths}</a>'

    # Create clickable link for JSON log file
    json_log_link = ""
    if os.path.isfile(input_json):
        abs_json_path = os.path.abspath(input_json)
        log_link = f'<a href="file://{abs_json_path}" class="ide-link" data-file="{abs_json_path}" style="color: #667eea;">{input_json}</a>'
        json_log_link = f'<div style="margin-top: 8px;">JSON Log: {log_link} <button class="copy-btn" onclick="copyLogPath()" title="Copy JSON log path to clipboard">📋 Copy Path</button></div>'

    # Determine status
    status_class = "pass"
    status_message = "✓ All critical checks passed!"
    if exit_code != 0:
        status_class = "fail"
        if total_errors > 0:
            status_message = f"✗ Check failed with {total_errors} error type(s)"
        elif strict_mode == "true" and total_warnings > 0:
            status_message = f"✗ Check failed in strict mode with {total_warnings} warning type(s)"

    print(f"{Colors.BLUE}Processing findings ({findings_count} total)...{Colors.NC}")

    # Generate findings HTML
    findings_html = ""
    if findings_count > 0:
        findings_parts = []
        for finding in findings:
            file_path = finding.get('file', '')
            line = finding.get('line', '')
            message = finding.get('message', finding.get('id', ''))
            code = finding.get('code', '')
            impact = finding.get('impact', 'MEDIUM').lower()

            # Build absolute file path
            if file_path:
                if os.path.isabs(file_path):
                    abs_file = file_path
                else:
                    # Convert relative path to absolute based on current working directory
                    abs_file = os.path.abspath(file_path)
            else:
                abs_file = file_path

            # HTML escape code
            code_escaped = code.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

            finding_html = f'''<div class="finding {impact}">
      <div class="finding-header">
        <div class="finding-title">{message}</div>
        <span class="badge {impact}">{impact.upper()}</span>
      </div>
      <div class="finding-details">
        <div class="file-path"><a href="file://{abs_file}" class="ide-link" data-file="{abs_file}" data-line="{line}" style="color: #667eea; text-decoration: none;" title="Click to open in IDE">{file_path}</a>:{line}</div>
        <div class="code-snippet">{code_escaped}</div>
      </div>
    </div>'''
            findings_parts.append(finding_html)

        findings_html = '\n'.join(findings_parts)
    else:
        findings_html = "<p style='text-align: center; color: #6c757d; padding: 20px;'>No findings detected. Great job! 🎉</p>"

    print(f"{Colors.BLUE}Processing checks...{Colors.NC}")

    # Generate checks HTML
    checks_parts = []
    for check in checks:
        check_name = check.get('name', '')
        check_status = check.get('status', 'unknown')
        check_impact = check.get('impact', 'MEDIUM').lower()
        check_findings_count = check.get('findings_count', 0)

        status_class_check = 'low' if check_status == 'passed' else check_impact

        check_html = f'''<div class="finding {status_class_check}">
      <div class="finding-header">
        <div class="finding-title">{check_name}</div>
        <span class="badge {status_class_check}">{check_status.upper()}</span>
      </div>
      <div class="finding-details">Findings: {check_findings_count}</div>
    </div>'''
        checks_parts.append(check_html)

    checks_html = '\n'.join(checks_parts)

    print(f"{Colors.BLUE}Processing AI triage data...{Colors.NC}")

    # Generate AI Triage HTML
    # Default placeholder if not performed
    ai_triage_html = '''<div class="ai-triage-content" data-status="pending">
        <p class="status-message">⏳ Not performed yet</p>
        <p class="help-text">
          Run the AI triage command to analyze findings and identify likely false positives.
        </p>
      </div>'''

    if ai_triage_performed:
        # Build summary stats
        # Note: findings_reviewed is duplicated in both summary and scope for convenience
        # Try summary first (new location), fall back to scope (old location) for back-compat
        findings_reviewed = ai_triage_summary.get('findings_reviewed')
        if findings_reviewed is None:
            ai_triage_scope = ai_triage.get('scope', {})
            findings_reviewed = ai_triage_scope.get('findings_reviewed', 0)
        confirmed_issues = ai_triage_summary.get('confirmed_issues', 0)
        false_positives = ai_triage_summary.get('false_positives', 0)
        needs_review = ai_triage_summary.get('needs_review', 0)
        confidence_level = ai_triage_summary.get('confidence_level', 'N/A')

        # Build summary stats HTML
        summary_stats = f'''
        <div class="ai-triage-summary">
          <div class="ai-triage-stat">
            <div class="label">Reviewed</div>
            <div class="value">{findings_reviewed}</div>
          </div>
          <div class="ai-triage-stat">
            <div class="label">Confirmed</div>
            <div class="value" style="color: #28a745;">{confirmed_issues}</div>
          </div>
          <div class="ai-triage-stat">
            <div class="label">False Positives</div>
            <div class="value" style="color: #6c757d;">{false_positives}</div>
          </div>
          <div class="ai-triage-stat">
            <div class="label">Needs Review</div>
            <div class="value" style="color: #ffc107;">{needs_review}</div>
          </div>
          <div class="ai-triage-stat">
            <div class="label">Confidence</div>
            <div class="value">{confidence_level}</div>
          </div>
        </div>'''

        # Build overall summary narrative (3-5 paragraphs)
        summary_narrative = f'''<div style="margin-top: 20px; line-height: 1.6; color: #333;">'''

        # Paragraph 1: Overview
        summary_narrative += f'''<p><strong>Overview:</strong> AI analysis reviewed {findings_reviewed} findings with {confidence_level} confidence. '''
        if confirmed_issues > 0:
            summary_narrative += f'''Of these, <span style="color: #28a745; font-weight: bold;">{confirmed_issues} issues were confirmed</span> as genuine security or performance concerns requiring developer attention. '''
        summary_narrative += f'''</p>'''

        # Paragraph 2: False positives
        if false_positives > 0:
            fp_percent = int((false_positives / findings_reviewed * 100)) if findings_reviewed > 0 else 0
            summary_narrative += f'''<p><strong>False Positives:</strong> <span style="color: #6c757d;">{false_positives} findings ({fp_percent}%)</span> were identified as false positives—code that appears flagged but has proper safeguards (nonce verification, sanitization, capability checks, etc.). These can be safely ignored or added to a baseline file to reduce noise in future scans.</p>'''

        # Paragraph 3: Needs review
        if needs_review > 0:
            summary_narrative += f'''<p><strong>Needs Manual Review:</strong> <span style="color: #ffc107;">{needs_review} findings</span> require human judgment to classify. These are ambiguous cases where context matters—review the detailed findings section below to make a final determination.</p>'''

        # Paragraph 4: Recommendations
        if ai_triage_recommendations:
            summary_narrative += f'''<p><strong>Recommendations:</strong></p><ul style="margin: 10px 0 0 20px;">'''
            for rec in ai_triage_recommendations:
                summary_narrative += f'''<li style="margin-bottom: 8px;">{rec}</li>'''
            summary_narrative += f'''</ul>'''

        # Paragraph 5: Next steps
        summary_narrative += f'''<p><strong>Next Steps:</strong> Review the confirmed issues in the Findings section below. For false positives, consider updating your baseline file or adding phpcs:ignore comments with justification. For items needing review, consult with your security team.</p>'''

        summary_narrative += f'''</div>'''

        # Combine all AI triage content
        ai_triage_html = f'''<div class="ai-triage-content" data-status="complete">
        <div style="margin-bottom: 15px; color: #155724;">
          <strong>✓ AI Triage Completed</strong> - {ai_triage_timestamp}
        </div>
        {summary_stats}
        {summary_narrative}
      </div>'''

    print(f"{Colors.BLUE}Processing DRY violations ({dry_violations_count} total)...{Colors.NC}")

    # Generate Magic Strings HTML (separate from Function Clones)
    magic_strings_html = ""
    magic_string_violations = [v for v in magic_violations if v.get('type') == 'magic_string']
    if len(magic_string_violations) > 0:
        magic_parts = []
        for violation in magic_string_violations:
            dup_string = violation.get('duplicated_string', '')
            pattern = violation.get('pattern', '')
            file_count = violation.get('file_count', 0)
            total_count = violation.get('total_count', 0)
            locations = violation.get('locations', [])

            locations_html = []
            for loc in locations:
                loc_file = loc.get('file', '')
                loc_line = loc.get('line', '')
                locations_html.append(f'<li style="font-family: monospace; font-size: 0.9em;">{loc_file}:{loc_line}</li>')

            locations_list = ''.join(locations_html)

            magic_html = f'''<div class="finding medium">
      <div class="finding-header">
        <div class="finding-title">🔤 {dup_string}</div>
        <span class="badge medium">MEDIUM</span>
      </div>
      <div class="finding-details">
        <div style="margin-bottom: 10px;">
          <strong>Pattern:</strong> {pattern}<br>
          <strong>Duplicated String:</strong> <code>{dup_string}</code><br>
          <strong>Files:</strong> {file_count} files | <strong>Total Occurrences:</strong> {total_count}
        </div>
        <div style="margin-top: 10px;">
          <strong>Locations:</strong>
          <ul style="margin: 5px 0 0 20px; padding: 0;">
            {locations_list}
          </ul>
        </div>
      </div>
    </div>'''
            magic_parts.append(magic_html)

        magic_strings_html = '\n'.join(magic_parts)
    else:
        magic_strings_html = "<p style='text-align: center; color: #6c757d; padding: 20px;'>No magic strings detected. Great job! 🎉</p>"

    # Generate Function Clones HTML (separate from Magic Strings)
    function_clones_html = ""
    if clone_detection_ran:
        function_clone_violations = [v for v in magic_violations if v.get('type') == 'function_clone']
        if len(function_clone_violations) > 0:
            clone_parts = []
            for violation in function_clone_violations:
                dup_string = violation.get('duplicated_string', '')
                pattern = violation.get('pattern', '')
                file_count = violation.get('file_count', 0)
                total_count = violation.get('total_count', 0)
                locations = violation.get('locations', [])

                locations_html = []
                for loc in locations:
                    loc_file = loc.get('file', '')
                    loc_line = loc.get('line', '')
                    locations_html.append(f'<li style="font-family: monospace; font-size: 0.9em;">{loc_file}:{loc_line}</li>')

                locations_list = ''.join(locations_html)

                clone_html = f'''<div class="finding medium">
      <div class="finding-header">
        <div class="finding-title">🔄 {dup_string}</div>
        <span class="badge medium">MEDIUM</span>
      </div>
      <div class="finding-details">
        <div style="margin-bottom: 10px;">
          <strong>Pattern:</strong> {pattern}<br>
          <strong>Duplicated Function:</strong> <code>{dup_string}</code><br>
          <strong>Files:</strong> {file_count} files | <strong>Total Occurrences:</strong> {total_count}
        </div>
        <div style="margin-top: 10px;">
          <strong>Locations:</strong>
          <ul style="margin: 5px 0 0 20px; padding: 0;">
            {locations_list}
          </ul>
        </div>
      </div>
    </div>'''
                clone_parts.append(clone_html)

            function_clones_html = '\n'.join(clone_parts)
        else:
            function_clones_html = "<p style='text-align: center; color: #6c757d; padding: 20px;'>No duplicate functions detected. Great job! 🎉</p>"
    else:
        function_clones_html = "<p style='text-align: center; color: #6c757d; padding: 20px;'>⏭️ Skipped (use <code>--enable-clone-detection</code> to run)</p>"

    print(f"{Colors.BLUE}Generating HTML report...{Colors.NC}")

    # Read template
    with open(template_file, 'r') as f:
        html_content = f.read()

    # Escape paths for JavaScript
    js_abs_path = abs_path.replace('\\', '\\\\').replace("'", "\\'").replace('"', '\\"')
    js_log_path = os.path.abspath(input_json).replace('\\', '\\\\').replace("'", "\\'").replace('"', '\\"') if os.path.isfile(input_json) else ""

    # Replace all placeholders
    replacements = {
        '{{PROJECT_INFO}}': project_info_html,
        '{{VERSION}}': version,
        '{{TIMESTAMP}}': timestamp,
        '{{PATHS_SCANNED}}': paths_link,
        '{{JSON_LOG_LINK}}': json_log_link,
        '{{JS_FOLDER_PATH}}': js_abs_path,
        '{{JS_LOG_PATH}}': js_log_path,
        '{{TOTAL_ERRORS}}': str(total_errors),
        '{{TOTAL_WARNINGS}}': str(total_warnings),
        '{{MAGIC_STRING_VIOLATIONS_COUNT}}': str(dry_violations_count),
        '{{MAGIC_STRING_COUNT}}': str(magic_string_count),
        '{{FUNCTION_CLONE_COUNT}}': str(function_clone_count),
        '{{BASELINED}}': str(baselined),
        '{{STALE_BASELINE}}': str(stale_baseline),
        '{{EXIT_CODE}}': str(exit_code),
        '{{STRICT_MODE}}': strict_mode,
        '{{STATUS_CLASS}}': status_class,
        '{{STATUS_MESSAGE}}': status_message,
        '{{FINDINGS_COUNT}}': str(findings_count),
        '{{FINDINGS_HTML}}': findings_html,
        '{{MAGIC_STRINGS_HTML}}': magic_strings_html,
        '{{FUNCTION_CLONES_HTML}}': function_clones_html,
        '{{CHECKS_HTML}}': checks_html,
        '{{FIXTURE_STATUS_CLASS}}': fixture_status_class,
        '{{FIXTURE_STATUS_TEXT}}': fixture_status_text,
        '{{AI_TRIAGE_HTML}}': ai_triage_html,
    }

    for placeholder, value in replacements.items():
        html_content = html_content.replace(placeholder, value)

    # Create output directory if it doesn't exist
    output_dir = os.path.dirname(output_html)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # Write HTML file
    with open(output_html, 'w') as f:
        f.write(html_content)

    # Get file size
    file_size = os.path.getsize(output_html)
    size_kb = file_size / 1024

    # Success message
    print()
    print(f"{Colors.GREEN}✓ HTML report generated successfully!{Colors.NC}")
    print(f"  {Colors.BLUE}Report:{Colors.NC} {output_html}")
    print(f"  {Colors.BLUE}Size:{Colors.NC} {size_kb:.1f}K")
    print()

    # Auto-open in browser if available
    try:
        if sys.platform == 'darwin':  # macOS
            print(f"{Colors.YELLOW}Opening report in browser...{Colors.NC}")
            subprocess.run(['open', output_html], check=False, capture_output=True)
        elif sys.platform.startswith('linux'):  # Linux
            print(f"{Colors.YELLOW}Opening report in browser...{Colors.NC}")
            subprocess.run(['xdg-open', output_html], check=False, capture_output=True)
    except Exception:
        pass  # Silently fail if browser opening doesn't work

    sys.exit(0)

if __name__ == '__main__':
    main()

