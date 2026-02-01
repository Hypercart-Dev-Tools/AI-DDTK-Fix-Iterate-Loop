#!/usr/bin/env python3
"""
Merge multiple JSON scan results into a single consolidated report.
Usage: python3 merge-json-scans.py <file1.json> <file2.json> ... > merged.json
"""

import json
import sys
from pathlib import Path
from datetime import datetime

def merge_scans(*json_files):
    """Merge multiple scan JSON files into one consolidated report."""
    
    if not json_files:
        print("Error: No JSON files provided", file=sys.stderr)
        sys.exit(1)
    
    # Load all JSON files
    scans = []
    for filepath in json_files:
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
                scans.append(data)
        except Exception as e:
            print(f"Warning: Failed to load {filepath}: {e}", file=sys.stderr)
            continue
    
    if not scans:
        print("Error: No valid JSON files loaded", file=sys.stderr)
        sys.exit(1)
    
    # Use the first scan as the base
    merged = scans[0].copy()
    
    # Update metadata
    merged['timestamp'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    merged['paths_scanned'] = "Multiple directories (merged scan)"
    
    # Merge findings
    all_findings = []
    for scan in scans:
        all_findings.extend(scan.get('findings', []))
    merged['findings'] = all_findings
    
    # Merge checks (deduplicate by name, sum counts)
    checks_map = {}
    for scan in scans:
        for check in scan.get('checks', []):
            name = check['name']
            if name not in checks_map:
                checks_map[name] = check.copy()
            else:
                # Merge status (failed if any failed)
                if check['status'] == 'failed':
                    checks_map[name]['status'] = 'failed'
                # Sum findings count
                checks_map[name]['findings_count'] += check.get('findings_count', 0)
    
    merged['checks'] = list(checks_map.values())
    
    # Merge magic string violations
    all_violations = []
    for scan in scans:
        all_violations.extend(scan.get('magic_string_violations', []))
    merged['magic_string_violations'] = all_violations
    
    # Update summary
    total_errors = sum(scan['summary']['total_errors'] for scan in scans)
    total_warnings = sum(scan['summary']['total_warnings'] for scan in scans)
    total_files = sum(scan['summary'].get('files_analyzed', 0) for scan in scans)
    total_loc = sum(scan['summary'].get('lines_of_code', 0) for scan in scans)
    total_violations = sum(scan['summary'].get('magic_string_violations', 0) for scan in scans)
    
    merged['summary'] = {
        'total_errors': total_errors,
        'total_warnings': total_warnings,
        'magic_string_violations': total_violations,
        'files_analyzed': total_files,
        'lines_of_code': total_loc,
        'baselined': sum(scan['summary'].get('baselined', 0) for scan in scans),
        'stale_baseline': sum(scan['summary'].get('stale_baseline', 0) for scan in scans),
        'exit_code': 1 if total_errors > 0 else 0
    }
    
    # Update project info
    merged['project']['files_analyzed'] = total_files
    merged['project']['lines_of_code'] = total_loc
    
    # Merge fixture validation (use best result)
    best_validation = max(scans, key=lambda s: s.get('fixture_validation', {}).get('passed', 0))
    merged['fixture_validation'] = best_validation.get('fixture_validation', merged.get('fixture_validation', {}))
    
    return merged

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 merge-json-scans.py <file1.json> <file2.json> ...", file=sys.stderr)
        sys.exit(1)
    
    json_files = sys.argv[1:]
    merged_data = merge_scans(*json_files)
    
    # Output merged JSON
    print(json.dumps(merged_data, indent=2))

