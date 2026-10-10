"""Differential fuzzing of the expression core.

Generates seeded random numeric expressions, evaluates each with an
independent recursive-descent oracle written in plain Python, and
compares against the real CLI in a single JSONL streaming call. Error
classes must match by E-code (E2008 division by zero, E2007 non-finite
results); values must match exactly after JSON parsing.
"""

import json
import math
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

random.seed(20261005)
FACTORS = [0, 1, 2, 3, 7, -1, -4, 10, 250, 999]
THRESHOLDS = [0, 2, 5, 10]
VARS = ["a", "b", "c"]


class EvalError(Exception):
    def __init__(self, code):
        self.code = code


def gen(depth):
    if depth <= 0 or random.random() < 0.25:
        if random.random() < 0.55:
            return ("num", random.choice(FACTORS))
        return ("var", random.choice(VARS))
    kind = random.random()
    if kind < 0.16:
        return ("neg", gen(depth - 1))
    if kind < 0.42:
        return ("bin", random.choice(["+", "-", "*", "/"]), gen(depth - 1), gen(depth - 1))
    if kind < 0.58:
        return ("cmp", random.choice(["<", "<=", ">", ">=", "==", "!="]), gen(depth - 1), gen(depth - 1))
    if kind < 0.72:
        return ("and", gen(depth - 1), gen(depth - 1))
    if kind < 0.80:
        return ("or", gen(depth - 1), gen(depth - 1))
    if kind < 0.86:
        return ("not", gen(depth - 1))
    if kind < 0.93:
        return ("count_matches", random.choice(VARS), random.choice([">", ">=", "<", "<=", "==", "!="]), random.choice(THRESHOLDS))
    return (random.choice(["any_match", "all_match"]), random.choice(VARS))


def render(node):
    kind = node[0]
    if kind == "num":
        return str(node[1])
    if kind == "var":
        return node[1]
    if kind == "neg":
        return "-" + wrap(node[1], 7)
    if kind == "bin":
        op = node[1]
        return wrap(node[2], PRECEDENCE[op]) + " " + op + " " + wrap(node[3], PRECEDENCE[op] + 1)
    if kind == "cmp":
        op = node[1]
        level = PRECEDENCE[op]
        return wrap(node[2], level) + " " + op + " " + wrap(node[3], level + 1)
    if kind == "and":
        return wrap(node[1], 2) + " && " + wrap(node[2], 3)
    if kind == "or":
        return wrap(node[1], 1) + " || " + wrap(node[2], 2)
    if kind == "not":
        return "!" + wrap(node[1], 8)
    if kind == "count_matches":
        return f"count_matches({node[1]}, \"{node[2]}\", {node[3]})"
    if kind in ("any_match", "all_match"):
        return f"{node[0]}({node[1]})"
    raise AssertionError(kind)


PRECEDENCE = {"+": 5, "-": 5, "*": 6, "/": 6, "==": 3, "!=": 3, "<": 4, "<=": 4, ">": 4, ">=": 4}


def wrap(node, minimum):
    text = render(node)
    return "(" + text + ")" if needs_parens(node, minimum) else text


def needs_parens(node, minimum):
    # Mirrors the engine: parenthesize when the child binds more loosely
    # than the position requires; unary not always binds tightest.
    kind = node[0]
    if kind in ("num", "var", "not"):
        return False
    if kind == "neg":
        return 7 < minimum
    if kind in ("bin", "cmp"):
        return PRECEDENCE[node[1]] < minimum
    if kind == "and":
        return 2 < minimum
    if kind == "or":
        return 1 < minimum
    return True


def boolean(value):
    if not isinstance(value, bool):
        raise EvalError("E2002")
    return value


def evaluate(node, facts):
    kind = node[0]
    if kind == "count_matches":
        raw = facts[node[1]]
        if not isinstance(raw, list):
            raise EvalError("E2006")
        threshold = float(node[3])
        op = node[2]
        ops = {">": lambda v: v > threshold, ">=": lambda v: v >= threshold, "<": lambda v: v < threshold, "<=": lambda v: v <= threshold, "==": lambda v: v == threshold, "!=": lambda v: v != threshold}
        total = 0
        for item in raw:
            # The engine coerces elements through num(), so non-numeric
            # elements raise the arithmetic-operand code E3004.
            if isinstance(item, bool) or not isinstance(item, (int, float)):
                raise EvalError("E3004")
            total += 1 if ops[op](float(item)) else 0
        return float(total)
    if kind in ("any_match", "all_match"):
        raw = facts[node[1]]
        if not isinstance(raw, list):
            raise EvalError("E2006")
        flags = []
        for item in raw:
            if not isinstance(item, bool):
                raise EvalError("E2002")
            flags.append(item)
        return any(flags) if kind == "any_match" else all(flags)
    if kind == "num":
        return float(node[1])
    if kind == "var":
        return facts[node[1]]
    if kind == "neg":
        return -number(evaluate(node[1], facts))
    if kind == "bin":
        op = node[1]
        # The engine fully evaluates both subtrees before numeric
        # coercion, so an error inside the right subtree wins over a
        # type error on the left.
        raw_left = evaluate(node[2], facts)
        raw_right = evaluate(node[3], facts)
        # Mirrors the engine exactly: the denominator is validated (and
        # zero-checked) before the numerator's type, so `true / 0`
        # reports division by zero rather than a type error.
        right = number(raw_right)
        if op == "/" and right == 0.0:
            raise EvalError("E2008")
        left = number(raw_left)
        value = left + right if op == "+" else left - right if op == "-" else left * right if op == "*" else left / right
        if math.isinf(value) or math.isnan(value):
            raise EvalError("E2007")
        return value
    if kind == "cmp":
        op = node[1]
        left = evaluate(node[2], facts)
        right = evaluate(node[3], facts)
        if op in ("<", "<=", ">", ">="):
            numeric = lambda v: isinstance(v, float) and not isinstance(v, bool)
            if not (numeric(left) and numeric(right)):
                raise EvalError("E2003")
            return {"<": left < right, "<=": left <= right, ">": left > right, ">=": left >= right}[op]
        return strict_equals(left, right) if op == "==" else not strict_equals(left, right)
    if kind == "and":
        return boolean(evaluate(node[1], facts)) and boolean(evaluate(node[2], facts))
    if kind == "or":
        return boolean(evaluate(node[1], facts)) or boolean(evaluate(node[2], facts))
    if kind == "not":
        return not boolean(evaluate(node[1], facts))
    raise AssertionError(kind)


def boolean_of(value):
    if not isinstance(value, bool):
        raise EvalError("E2002")
    return value


def strict_equals(left, right):
    left_bool = isinstance(left, bool)
    right_bool = isinstance(right, bool)
    if left_bool or right_bool:
        return left_bool and right_bool and left == right
    if isinstance(left, float) and isinstance(right, float):
        return left == right
    return False


def number(value):
    # Mirrors the engine's num(): arithmetic operands raise the request
    # helper code E3004, not the logical-operand code E2002.
    if isinstance(value, bool) or not isinstance(value, float):
        raise EvalError("E3004")
    return value


def main():
    cases = []
    for _ in range(500):
        facts = {}
        for name in VARS:
            if random.random() < 0.35:
                facts[name] = [float(random.choice(FACTORS)) for _ in range(random.randint(0, 4))]
            elif random.random() < 0.55:
                facts[name] = [random.random() < 0.5 for _ in range(random.randint(0, 4))]
            else:
                facts[name] = float(random.choice(FACTORS))
        node = gen(random.randint(2, 6))
        cases.append((render(node), facts, node))
    payload = "".join(
        json.dumps({"operation": "evaluate", "expression": text, "facts": facts}) + "\n"
        for text, facts, _ in cases
    )
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
    assert len(lines) == len(cases), f"expected {len(cases)} result lines, got {len(lines)}"
    agreement = 0
    for (text, facts, node), line in zip(cases, lines):
        output = json.loads(line)
        try:
            expected = evaluate(node, dict(facts))
        except EvalError as err:
            assert "error" in output, f"{text}: oracle raised {err.code}, CLI returned {output}"
            assert err.code in output["error"], (
                f"{text}: expected {err.code}, got {output['error']}\nAST: {node!r}"
            )
            agreement += 1
            continue
        assert "value" in output, f"{text}: oracle computed {expected}, CLI returned {output}"
        actual = output["value"]
        assert actual == expected, f"{text}: expected {expected}, got {actual}\nAST: {node!r}"
        agreement += 1
    print(f"Differential fuzz passed: {agreement}/500 expressions agree on values and error codes")


main()
