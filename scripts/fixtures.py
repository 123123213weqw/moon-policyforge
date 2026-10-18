"""Generate MoonBit white-box tests from tests/cases.json so the CLI
fixtures also run on wasm, wasm-gc and native, not only through Node.

    python -B scripts/fixtures.py          # rewrite fixtures_wbtest.mbt
    python -B scripts/fixtures.py --check  # fail when the file is out of date

docs/usage.md is partly curated and is deliberately not regenerated.
"""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cases = json.loads((root / 'tests/cases.json').read_text(encoding='utf-8'))

def mbt_string(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def path_parts(key):
    if key.startswith('origins/'):
        return ['origins', key[len('origins/'):]]
    return key.split('/')


def render_tests():
    out = ['// Generated from tests/cases.json by scripts/fixtures.py; do not edit.', '']
    if 'fn fails(' not in (root / 'engine_wbtest.mbt').read_text(encoding='utf-8'):
        out += ['///|', 'fn fails(request : String) -> Bool {',
                '  try {', '    ignore(run(parse_value(request)))', '    false',
                '  } catch {', '    _ => true', '  }', '}', '']
    for case in cases:
        request = mbt_string(json.dumps(case['request'], separators=(',', ':'), ensure_ascii=False))
        out += ['///|', f'test {mbt_string(case["name"])} {{']
        if case.get('error'):
            out.append(f'  assert_true(fails({request}))')
        else:
            out.append(f'  let result = run(parse_value({request}))')
            for key, expected in case['expected'].items():
                parts = ', '.join(mbt_string(p) for p in path_parts(key))
                value = mbt_string(json.dumps(expected, separators=(',', ':'), ensure_ascii=False))
                out.append(f'  assert_eq(test_at(result, [{parts}]), parse_value({value}))')
        out += ['}', '']
    return '\n'.join(out)


def write_outputs():
    (root / 'fixtures_wbtest.mbt').write_text(render_tests() + '\n', encoding='utf-8')
    # The formatter wraps the generated tests; keep its layout authoritative.
    subprocess.run(['moon', 'fmt'], cwd=root, capture_output=True)


def main():
    outputs = [root / 'fixtures_wbtest.mbt']
    saved = {p: p.read_text(encoding='utf-8') if p.exists() else None for p in outputs}
    write_outputs()
    if '--check' in sys.argv:
        stale = [str(p.relative_to(root)) for p in outputs if saved[p] != p.read_text(encoding='utf-8')]
        for p, text in saved.items():
            if text is not None:
                p.write_text(text, encoding='utf-8')
        if stale:
            print('Generated files are out of date:', ', '.join(stale), '- run python -B scripts/fixtures.py')
            return 1
        print('Fixture-derived files are up to date:', len(cases), 'cases')
        return 0
    print('Wrote', ', '.join(str(p.relative_to(root)) for p in outputs), 'from', len(cases), 'cases')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
