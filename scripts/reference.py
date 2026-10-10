"""Independent Python standard library oracles; deterministic synthetic data.

Usage: python3 -B scripts/reference.py [--count N]

Runs N (default 40) random precedence expressions through the real CLI
and asserts each result against Python's own arithmetic evaluator.
"""

import argparse
import csv, datetime, hashlib, heapq, io, json, math, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261005)
def run(request):
    result = subprocess.run(['node',str(root/'_build/js/debug/build/cmd/main/main.js'),'-'],
        input=json.dumps(request),capture_output=True,text=True,encoding='utf-8',timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--count', type=int, default=40, help='number of expressions')
    args = parser.parse_args()
    for i in range(args.count):
        a,b,c = [random.randint(-100,100) for _ in range(3)]
        expression = f'({a}) + ({b}) * ({c})'
        assert run({'operation':'evaluate','expression':expression,'facts':{}})['value'] == a+b*c
    print(f'Independent arithmetic oracle: {args.count} precedence and negative-number expressions passed')


main()
