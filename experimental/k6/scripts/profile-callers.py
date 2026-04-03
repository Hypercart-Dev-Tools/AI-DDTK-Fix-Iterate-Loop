import gzip
import re
import sys
from pathlib import Path

profile = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/var/tmp/cachegrind.out.6983.gz')
lines = gzip.open(profile, 'rt', errors='replace').read().splitlines()

fn_names = {}
fl_names = {}
for line in lines:
    m = re.match(r'^fn=\((\d+)\) (.*)$', line)
    if m:
        fn_names[m.group(1)] = m.group(2)
    m = re.match(r'^fl=\((\d+)\) (.*)$', line)
    if m:
        fl_names[m.group(1)] = m.group(2)

symbol_to_id = {v: k for k, v in fn_names.items()}

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

def print_call_sites(symbol: str, max_sites: int = 50):
    target_id = symbol_to_id.get(symbol)
    print(f'## {symbol}')
    print('target_id =', target_id)
    if not target_id:
        print('NOT FOUND')
        print()
        return

    current_fn = None
    current_fl = None
    count = 0
    for i, line in enumerate(lines):
        m = re.match(r'^fl=\((\d+)\)', line)
        if m:
            current_fl = m.group(1)
        m = re.match(r'^fn=\((\d+)\)', line)
        if m:
            current_fn = m.group(1)
        if line == f'cfn=({target_id})':
            count += 1
            caller_name = fn_names.get(current_fn, current_fn)
            caller_file = fl_names.get(current_fl, current_fl)
            print(f'-- call site {count} at line {i+1}')
            print('caller_fn:', caller_name)
            print('caller_fl:', caller_file)
            start = max(0, i - 6)
            end = min(len(lines), i + 8)
            for j in range(start, end):
                raw = lines[j]
                out = raw
                m = re.match(r'^cfn=\((\d+)\)$', raw)
                if m:
                    out += ' => ' + fn_names.get(m.group(1), m.group(1))
                m = re.match(r'^cfl=\((\d+)\)$', raw)
                if m:
                    out += ' => ' + fl_names.get(m.group(1), m.group(1))
                print(f'{j+1}: {out}')
            print()
            if count >= max_sites:
                break
    print('total call sites =', count)
    print()

symbols = sys.argv[2:] if len(sys.argv) > 2 else DEFAULT_SYMBOLS

for symbol in symbols:
    print_call_sites(symbol)

