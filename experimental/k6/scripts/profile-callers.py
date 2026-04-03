#!/usr/bin/env python3
"""Print upstream call sites for one or more symbols in an Xdebug cachegrind file.

Works with either plain-text or gzipped cachegrind output.

Examples:
  python3 profile-callers.py /var/tmp/cachegrind.out.1234.gz 'WC_Coupon->__construct'
  python3 profile-callers.py ./cachegrind.out --symbols-file ./symbols.txt --max-sites 20
"""

from __future__ import annotations

import argparse
import gzip
import re
from pathlib import Path

DEFAULT_SYMBOLS = [
    'WC_SC_URL_Coupon->apply_coupon_from_session',
    'WC_SC_URL_Coupon->apply_coupon_from_url',
    'WC_Coupon->__construct',
    'get_posts',
    'WP_Query->get_posts',
    'WP_Query->query',
    'WC_SC_Coupon_Actions->get_coupon_actions',
    'WC_SC_Coupon_Actions->modify_cart_item_in_session',
    'WC_SC_Coupon_Actions->modify_cart_item_data',
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', type=Path, help='Path to a cachegrind file (.out or .gz).')
    parser.add_argument('symbols', nargs='*', help='One or more function symbols to inspect.')
    parser.add_argument('--symbols-file', type=Path, help='Optional newline-delimited symbol list.')
    parser.add_argument('--max-sites', type=int, default=50, help='Maximum call sites to print per symbol.')
    parser.add_argument('--context', type=int, default=6, help='Context lines to show before each call site.')
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


def build_indices(lines: list[str]) -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    fn_names: dict[str, str] = {}
    fl_names: dict[str, str] = {}
    for line in lines:
        fn_match = re.match(r'^fn=\((\d+)\) (.*)$', line)
        if fn_match:
            fn_names[fn_match.group(1)] = fn_match.group(2)
        fl_match = re.match(r'^fl=\((\d+)\) (.*)$', line)
        if fl_match:
            fl_names[fl_match.group(1)] = fl_match.group(2)
    return fn_names, fl_names, {name: idx for idx, name in fn_names.items()}


def decode_reference(raw: str, fn_names: dict[str, str], fl_names: dict[str, str]) -> str:
    fn_match = re.match(r'^cfn=\((\d+)\)$', raw)
    if fn_match:
        return f'{raw} => {fn_names.get(fn_match.group(1), fn_match.group(1))}'
    fl_match = re.match(r'^cfl=\((\d+)\)$', raw)
    if fl_match:
        return f'{raw} => {fl_names.get(fl_match.group(1), fl_match.group(1))}'
    return raw


def print_call_sites(
    lines: list[str],
    symbol: str,
    fn_names: dict[str, str],
    fl_names: dict[str, str],
    symbol_to_id: dict[str, str],
    *,
    max_sites: int,
    context: int,
) -> None:
    target_id = symbol_to_id.get(symbol)
    print(f'## {symbol}')
    print('target_id =', target_id)

    current_fn = None
    current_fl = None
    count = 0

    for index, line in enumerate(lines):
        file_id_match = re.match(r'^fl=\((\d+)\)$', line)
        if file_id_match:
            current_fl = file_id_match.group(1)
        elif line.startswith('fl='):
            current_fl = line[3:]

        fn_id_match = re.match(r'^fn=\((\d+)\)$', line)
        if fn_id_match:
            current_fn = fn_id_match.group(1)
        elif line.startswith('fn=') and not re.match(r'^fn=\((\d+)\) ', line):
            current_fn = line[3:]

        is_target = line == f'cfn=({target_id})' or line == f'cfn={symbol}'
        if not is_target:
            continue

        count += 1
        print(f'-- call site {count} at line {index + 1}')
        print('caller_fn:', fn_names.get(current_fn, current_fn))
        print('caller_fl:', fl_names.get(current_fl, current_fl))

        start = max(0, index - context)
        end = min(len(lines), index + context + 2)
        for context_index in range(start, end):
            print(f'{context_index + 1}: {decode_reference(lines[context_index], fn_names, fl_names)}')
        print()

        if count >= max_sites:
            break

    if count == 0:
        print('NOT FOUND')
    print('total call sites =', count)
    print()


def main() -> None:
    args = parse_args()
    lines = read_lines(args.profile)
    fn_names, fl_names, symbol_to_id = build_indices(lines)
    for symbol in load_symbols(args):
        print_call_sites(
            lines,
            symbol,
            fn_names,
            fl_names,
            symbol_to_id,
            max_sites=args.max_sites,
            context=args.context,
        )


if __name__ == '__main__':
    main()

