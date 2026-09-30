"""Scale validation: 100k facts through the real CLI vs an independent oracle.

The oracle re-implements the decision table in plain Python. The script
asserts per-index agreement, hit-rule attribution through the explanation
chain, positive step accounting, and prints a deterministic hit distribution.
"""

import json
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cli = root / "_build" / "js" / "debug" / "build" / "cmd" / "main" / "main.js"
if not cli.exists():
    sys.exit("Run moon build --target js first")

COUNT = 100_000
TIERS = ["bronze", "silver", "gold"]

RULES = [
    {
        "id": "high_value",
        "priority": 2,
        "when": "amount >= 800",
        "compute": "amount * 0.02",
    },
    {
        "id": "gold_tier",
        "priority": 1,
        "when": 'tier == "gold"',
        "output": "gold_5pct",
    },
    {
        "id": "standard",
        "priority": 0,
        "when": "true",
        "output": "none",
    },
]


def fact(i):
    return {"index": i, "amount": (i * 37) % 1000, "tier": TIERS[i % 3]}


def oracle(record):
    if record["amount"] >= 800:
        return "high_value", record["amount"] * 0.02
    if record["tier"] == "gold":
        return "gold_tier", "gold_5pct"
    return "standard", "none"


def main():
    records = [fact(i) for i in range(COUNT)]
    request = {
        "operation": "decide",
        "rules": RULES,
        "mode": "first",
        "facts": records,
    }
    payload = json.dumps(request)
    if len(payload.encode()) > 16 * 1024 * 1024:
        sys.exit("request exceeds the 16 MiB CLI limit")
    started = time.time()
    result = subprocess.run(
        ["node", str(cli), "-"],
        input=payload,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=300,
    )
    wall = time.time() - started
    if result.returncode:
        sys.exit(result.stdout or result.stderr)
    output = json.loads(result.stdout)
    results = output["results"]
    assert output["rule_count"] == len(RULES)
    assert len(results) == COUNT, f"expected {COUNT} results, got {len(results)}"

    distribution = {}
    for i, entry in enumerate(results):
        assert entry["index"] == i
        if "error" in entry:
            sys.exit(f"unexpected per-record error at {i}: {entry['error']}")
        detail = entry["result"]
        rule_id, value = oracle(records[i])
        assert detail["decision"] == value, f"decision mismatch at {i}"
        assert detail["conflict"] is False
        assert detail["conflict_ids"] == []
        assert detail["steps"] > 0
        matched = detail["matched"]
        assert len(matched) >= 1
        assert matched[0]["id"] == rule_id, f"hit rule mismatch at {i}"
        evaluated = detail["evaluated"]
        assert len(evaluated) == len(RULES)
        assert evaluated[-1]["id"] == "standard"
        assert evaluated[-1]["matched"] is True
        distribution[rule_id] = distribution.get(rule_id, 0) + 1

    print(f"Scale validation passed: {COUNT} facts, {wall:.1f}s wall time")
    for rule_id in sorted(distribution):
        share = 100.0 * distribution[rule_id] / COUNT
        print(f"  {rule_id}: {distribution[rule_id]} ({share:.1f}%)")


main()
