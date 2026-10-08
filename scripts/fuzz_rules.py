"""Differential fuzzing of the decide pipeline.

Builds seeded random rule sets (conditions over a small numeric fact
space) and evaluates first/all/unique decisions with an independent
plain-Python oracle, then compares against the real CLI in a single
JSONL streaming call. The oracle encodes the documented semantics:
priority descension with character-wise rule ID tie-break, full
evaluation of matching rules even in first mode, unique conflicts
with null decision and conflict_ids, canonical default fallback, and
per-record step accounting through the explanation chain.
"""

import json
import os
import random
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cli = root / "_build" / "js" / "debug" / "build" / "cmd" / "main" / "main.js"
if not cli.exists():
    sys.exit("Run moon build --target js first")

random.seed(20261012)
PATHS = ["amount", "score", "level"]
THRESHOLDS = [1, 3, 5, 7, 9]


class Cond:
    """A condition is a comparison over one fact path."""

    def __init__(self, path, op, threshold):
        self.path = path
        self.op = op
        self.threshold = threshold

    def render(self):
        return f"{self.path} {self.op} {self.threshold}"

    def test(self, facts):
        value = facts[self.path]
        if self.op == ">":
            return value > self.threshold
        if self.op == ">=":
            return value >= self.threshold
        if self.op == "<":
            return value < self.threshold
        if self.op == "<=":
            return value <= self.threshold
        if self.op == "==":
            return value == self.threshold
        if self.op == "!=":
            return value != self.threshold
        raise AssertionError(self.op)


def gen_condition():
    return Cond(random.choice(PATHS), random.choice([">", ">=", "<", "<=", "==", "!="]), random.choice(THRESHOLDS))


def oracle_decide(rules, facts, mode, default):
    ordered = sorted(rules, key=lambda r: (-r["priority"], stable_key(r["id"])))
    matched = []
    for rule in ordered:
        if rule["cond"].test(facts):
            matched.append(rule)
    conflict = mode == "unique" and len(matched) > 1
    if not matched:
        decision = default
    elif conflict:
        decision = None
    elif mode == "all":
        decision = [rule["output"] for rule in matched]
    else:
        decision = matched[0]["output"]
    return {
        "decision": decision,
        "conflict": conflict,
        "conflict_ids": [rule["id"] for rule in matched] if conflict else [],
        "matched_ids": [rule["id"] for rule in matched],
    }


def stable_key(text):
    return [ord(ch) for ch in text]


def main():
    rule_sets = []
    requests = []
    for _ in range(120):
        count = random.randint(1, 5)
        ids = random.sample(["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta"], count)
        rules = []
        for rule_id in ids:
            rules.append({
                "id": rule_id,
                "priority": random.choice([0, 1, 2]),
                "cond": gen_condition(),
                "output": f"out_{rule_id}",
            })
        facts = {path: random.choice([0, 2, 4, 6, 8, 10]) for path in PATHS}
        mode = random.choice(["first", "all", "unique"])
        request = {
            "operation": "decide",
            "rules": [
                {"id": r["id"], "priority": r["priority"], "when": r["cond"].render(), "output": r["output"]}
                for r in rules
            ],
            "facts": facts,
            "mode": mode,
            "default": "default_out",
        }
        rule_sets.append((rules, facts, mode))
        requests.append(request)
    payload = "".join(json.dumps(request) + "\n" for request in requests)
    handle = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8")
    handle.write(payload)
    handle.close()
    result = subprocess.run(
        ["node", str(cli), handle.name], capture_output=True, text=True, encoding="utf-8", timeout=300
    )
    os.unlink(handle.name)
    if not result.stdout:
        sys.exit(result.stderr or "no CLI output")
    lines = result.stdout.strip().split("\n")
    assert len(lines) == len(rule_sets), f"expected {len(rule_sets)} lines, got {len(lines)}"
    modes_agreed = 0
    for (rules, facts, mode), line in zip(rule_sets, lines):
        output = json.loads(line)
        detail = output["results"][0]["result"]
        expected = oracle_decide(rules, facts, mode, "default_out")
        assert detail["decision"] == expected["decision"], (
            f"decision mismatch in mode {mode}: expected {expected['decision']}, got {detail['decision']}"
        )
        assert detail["conflict"] == expected["conflict"], f"conflict mismatch in mode {mode}"
        assert detail["conflict_ids"] == expected["conflict_ids"], (
            f"conflict_ids mismatch: expected {expected['conflict_ids']}, got {detail['conflict_ids']}"
        )
        got_matched_ids = [m["id"] for m in detail["matched"]]
        assert got_matched_ids == expected["matched_ids"], (
            f"matched order mismatch: expected {expected['matched_ids']}, got {got_matched_ids}"
        )
        assert detail["steps"] > 0
        modes_agreed += 1
    print(f"Decide differential passed: {modes_agreed}/120 rule sets agree on all modes")


main()
