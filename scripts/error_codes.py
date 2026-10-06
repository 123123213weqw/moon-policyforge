"""Asserts that every documented E-code appears for its failure case."""

import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cli = root / "_build" / "js" / "debug" / "build" / "cmd" / "main" / "main.js"
if not cli.exists():
    sys.exit("Run moon build --target js first")

CASES = [
    ("E1001", "expression too long", {"operation": "evaluate", "expression": "1" * 70000, "facts": {}}),
    ("E1002", "unterminated string", {"operation": "evaluate", "expression": '"abc', "facts": {}}),
    ("E1003", "unexpected token", {"operation": "evaluate", "expression": "1 @ 2", "facts": {}}),
    ("E1005", "closing parenthesis", {"operation": "evaluate", "expression": "(1 + 2 3", "facts": {}}),
    ("E1006", "expected value", {"operation": "evaluate", "expression": "&& true", "facts": {}}),
    ("E1007", "nesting limit", {"operation": "evaluate", "expression": "-" * 200 + "1", "facts": {}}),
    ("E1008", "unknown function", {"operation": "evaluate", "expression": "foo(1)", "facts": {}}),
    ("E1009", "trailing", {"operation": "evaluate", "expression": "1 2", "facts": {}}),
    ("E2001", "missing fact", {"operation": "evaluate", "expression": "ghost", "facts": {}}),
    ("E2002", "logical operand", {"operation": "evaluate", "expression": "1 && true", "facts": {}}),
    ("E2003", "comparison", {"operation": "evaluate", "expression": "1 > \"x\"", "facts": {}}),
    ("E2006", "invalid function argument", {"operation": "evaluate", "expression": "len(1)", "facts": {}}),
    ("E2007", "nonfinite", {"operation": "evaluate", "expression": "1e308 * 10", "facts": {}}),
    ("E2008", "division by zero", {"operation": "evaluate", "expression": "1 / 0", "facts": {}}),
    ("E2009", "budget", {"operation": "evaluate", "expression": "1+1+1+1+1+1+1+1+1+1+1+1+1+1", "facts": {}, "budget": 10}),
    ("E3005", "unknown operation", {"operation": "wat"}),
    ("E3006", "unknown decision mode", {"rules": [{"id": "r", "when": "true", "output": 1}], "facts": {}, "mode": "sometimes"}),
    ("E3007", "budget out of range", {"rules": [{"id": "r", "when": "true", "output": 1}], "facts": {}, "budget": 0}),
    ("E3009", "schema", {"operation": "check", "expression": "1", "schema": [1]}),
    ("E4001", "duplicate rule ID", {"rules": [{"id": "r", "when": "true", "output": 1}, {"id": "r", "when": "true", "output": 2}], "facts": {}}),
    ("E4003", "needs an expression", {"operation": "aggregate", "facts": [], "key": "1", "metrics": [{"name": "a", "op": "sum"}]}),
    ("E4005", "unknown metric op", {"operation": "aggregate", "facts": [], "key": "1", "metrics": [{"name": "a", "op": "median", "expression": "1"}]}),
    ("E4007", "compute must be a string", {"operation": "analyze", "rules": [{"id": "r", "when": "true", "compute": 5}]}),
]

failures = 0
for code, hint, request in CASES:
    result = subprocess.run(
        ["node", str(cli), "-"],
        input=json.dumps(request), capture_output=True, text=True, encoding="utf-8", timeout=60,
    )
    output = (result.stdout or "") + (result.stderr or "")
    if result.returncode == 0 or code not in output:
        print(f"FAIL {code} ({hint}): exit={result.returncode} output={output[:120]}")
        failures += 1
    else:
        print(f"ok   {code} {hint}")

if failures:
    sys.exit(f"{failures} error-code cases failed")
print(f"Error-code taxonomy passed: {len(CASES)} cases")
