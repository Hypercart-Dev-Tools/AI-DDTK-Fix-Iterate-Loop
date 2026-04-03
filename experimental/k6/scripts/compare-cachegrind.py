#!/usr/bin/env python3
"""Compare selected symbols between two Xdebug cachegrind files.

Works with either plain-text or gzipped cachegrind output.

Examples:
  python3 compare-cachegrind.py before.gz after.gz 'WC_Coupon->__construct'
  python3 compare-cachegrind.py before.out after.out --symbols-file ./symbols.txt
"""

from __future__ import annotations

import argparse
import gzip
import re
from pathlib import Path

DEFAULT_SYMBOLS = [
    'WC_SC_Coupon_Actions->coupon_action',
    'WC_SC_Coupon_Actions->get_coupon_actions',
    'WC_Coupon->__construct',
    'wc_get_coupon_id_by_code',
    'WC_Data_Store->get_ids_by_code',
    'WC_Coupon_Data_Store_CPT->get_ids_by_code',
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path, help='Baseline cachegrind file.')
    parser.add_argument('after', type=Path, help='Comparison cachegrind file.')
    parser.add_argument('symbols', nargs='*', help='Symbols to compare. Defaults to common Woo/WP hotspots.')
    parser.add_argument('--symbols-file', type=Path, help='Optional newline-delimited symbol list.')
    return parser.parse_args()


def read_lines(path: Path) -> list[str]:
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt', errors='replace') as handle:
        return handle.read().splitlines()


def load_symbols(args: argparse.Namespace) -> list[str]:
    symbols = list(args.symbols)
    if args.symbols_file:
        symbols.extend(
            line.strip() for line in args.symbols_file.read_text().splitlines() if line.strip() and not line.startswith('#')
        )
    return symbols or DEFAULT_SYMBOLS


def summarize(path: Path) -> dict[str, dict[str, int]]:
    fn_names: dict[str, str] = {}
    summary: dict[str, dict[str, int]] = {}
    current_fn = None

    for line in read_lines(path):
        fn_with_id = re.match(r'^fn=\((\d+)\) (.*)$', line)
        if fn_with_id:
            fn_names[fn_with_id.group(1)] = fn_with_id.group(2)
            current_fn = fn_with_id.group(2)
            summary.setdefault(current_fn, {'self_cost': 0, 'lines': 0, 'called': 0})
            continue

        if line.startswith('fn=') and not re.match(r'^fn=\((\d+)\) ', line):
            current_fn = line[3:]
            summary.setdefault(current_fn, {'self_cost': 0, 'lines': 0, 'called': 0})
            continue

        cfn_with_id = re.match(r'^cfn=\((\d+)\)$', line)
        if cfn_with_id and current_fn:
            called = fn_names.get(cfn_with_id.group(1), cfn_with_id.group(1))
            summary.setdefault(called, {'self_cost': 0, 'lines': 0, 'called': 0})
            summary[called]['called'] += 1
            continue

        if line.startswith('cfn=') and current_fn:
            called = line[4:]
            summary.setdefault(called, {'self_cost': 0, 'lines': 0, 'called': 0})
            summary[called]['called'] += 1
            continue

        if current_fn and re.match(r'^[0-9]+ [0-9]+(?: [0-9]+)*$', line):
            parts = [int(piece) for piece in line.split()]
            summary[current_fn]['self_cost'] += parts[1]
            summary[current_fn]['lines'] += 1

    return summary


def percent_change(before: int, after: int) -> str:
    if before == 0:
        return 'n/a'
    return f'{((after - before) / before) * 100:.1f}%'


def print_section(label: str, path: Path, summary: dict[str, dict[str, int]], symbols: list[str]) -> None:
    print(f'## {label}: {path}')
    for symbol in symbols:
        data = summary.get(symbol, {'self_cost': 0, 'lines': 0, 'called': 0})
        print(f"{symbol}\tself_cost={data['self_cost']}\tlines={data['lines']}\tcalled={data['called']}")
    print()


def main() -> None:
    args = parse_args()
    symbols = load_symbols(args)
    before_summary = summarize(args.before)
    after_summary = summarize(args.after)

    print_section('before', args.before, before_summary, symbols)
    print_section('after', args.after, after_summary, symbols)
    print('## delta')
    for symbol in symbols:
        before = before_summary.get(symbol, {'self_cost': 0, 'lines': 0, 'called': 0})
        after = after_summary.get(symbol, {'self_cost': 0, 'lines': 0, 'called': 0})
        print(
            f"{symbol}\tself_cost_delta={after['self_cost'] - before['self_cost']}"
            f"\tself_cost_pct={percent_change(before['self_cost'], after['self_cost'])}"
            f"\tcalled_delta={after['called'] - before['called']}"
        )


if __name__ == '__main__':
    main()