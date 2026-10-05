"""Independent Python standard library oracles; deterministic synthetic data."""
import csv, datetime, hashlib, heapq, io, json, math, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261005)
def run(request):
    result = subprocess.run(['node',str(root/'_build/js/debug/build/cmd/main/main.js'),'-'],
        input=json.dumps(request),capture_output=True,text=True,encoding='utf-8',timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for i in range(40):
    a,b,c = [random.randint(-100,100) for _ in range(3)]
    expression = f'({a}) + ({b}) * ({c})'
    assert run({'operation':'evaluate','expression':expression,'facts':{}})['value'] == a+b*c
print('Independent arithmetic oracle: 40 precedence and negative-number expressions passed')
