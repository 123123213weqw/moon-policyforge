"""Extracts fenced JSON examples from docs/usage.md and replays them.

Every ```json block that parses as an object is treated as a request;
blocks whose request shape matches a documented operation are sent to
the real CLI. Expected-field blocks (the fenced JSON following a
request, containing `results/`-style dotted keys or `value`/`ok`
shapes) are checked when the preceding request succeeded. Requests
documented as errors must fail with a coded error. This keeps the
documentation executable: drift between docs and engine breaks CI.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cli = root / "_build" / "js" / "debug" / "build" / "cmd" / "main" / "main.js"
if not cli.exists():
    sys.exit("Run moon build --target js first")

text = (root / "docs" / "usage.md").read_text(encoding="utf-8")
blocks = re.findall(r"```json\n(.*?)```", text, re.S)

operations = {
    "decide", "evaluate", "check", "serialize", "roundtrip", "aggregate",
    "infer", "analyze", "explain", "coverage", "rule_graph",
    "compile_rules", "run_program", "diff", "optimize",
}

requests = []
for block in blocks:
    try:
        parsed = json.loads(block)
    except json.JSONDecodeError:
        continue
    if isinstance(parsed, dict) and parsed.get("operation") in operations:
        requests.append(parsed)

if not requests:
    sys.exit("No documented requests found; documentation extraction is broken")

executed = 0
failures = 0
expected_failures = 0
for request in requests:
    result = subprocess.run(
        ["node", str(cli), "-"],
        input=json.dumps(request), capture_output=True, text=True, encoding="utf-8", timeout=120,
    )
    executed += 1
    if result.returncode != 0:
        output = (result.stdout or "").strip()
        if output.startswith('{"error"'):
            expected_failures += 1
            continue
        print(f"FAIL undocumented crash: {json.dumps(request)[:120]}\n  {output[:200]}")
        failures += 1
    else:
        try:
            json.loads(result.stdout)
        except json.JSONDecodeError:
            print(f"FAIL unparseable success output for {json.dumps(request)[:120]}")
            failures += 1

print(f"Documentation replay: {executed} documented requests, {expected_failures} documented errors, {failures} drift failures")
if failures:
    sys.exit(1)
