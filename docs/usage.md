# Request and result guide

Every example below is an executable fixture. Assertions cover the listed result fields; additional output fields are documented by the API and other fixtures. Error cases intentionally reject the request.

## arithmetic precedence

```json
{
  "operation": "evaluate",
  "expression": "1 + 2 * 3 == 7 && true",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": true
}
```

## short circuit

```json
{
  "operation": "evaluate",
  "expression": "false && (1 / 0 > 1)",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": false
}
```

## missing exists

```json
{
  "operation": "evaluate",
  "expression": "exists(user.age)",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": false
}
```

## priority first

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  }
}
```

Expected result fields:

```json
{
  "results/0/result/decision": "adult"
}
```

## unique conflict

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  },
  "mode": "unique"
}
```

Expected result fields:

```json
{
  "results/0/result/conflict": true,
  "results/0/result/decision": null
}
```

## all matches

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  },
  "mode": "all"
}
```

Expected result fields:

```json
{
  "results/0/result/decision": [
    "adult",
    "other"
  ]
}
```

## division zero

```json
{
  "operation": "evaluate",
  "expression": "1 / 0",
  "facts": {}
}
```

Expected: nonzero exit with an input error.

## strict boolean

```json
{
  "operation": "evaluate",
  "expression": "1 && true",
  "facts": {}
}
```

Expected: nonzero exit with an input error.

## duplicate rules

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    }
  ],
  "facts": {}
}
```

Expected: nonzero exit with an input error.

## in operator

```json
{
  "operation": "evaluate",
  "expression": "\"g\" in tags",
  "facts": {
    "tags": ["g", "s"]
  }
}
```

Expected result fields:

```json
{
  "value": true
}
```

The right operand must be an array fact; array literals are not part of the expression language.

## string concat

```json
{
  "operation": "evaluate",
  "expression": "\"a\" + \"b\"",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": "ab"
}
```

`+` concatenates only when both operands are strings; otherwise both sides must be numbers.

## nonfinite result

```json
{
  "operation": "evaluate",
  "expression": "1e308 * 10",
  "facts": {}
}
```

Expected: nonzero exit with an input error. Arithmetic results must stay finite.

## unknown function

```json
{
  "operation": "evaluate",
  "expression": "foo(1)",
  "facts": {}
}
```

Expected: nonzero exit with an input error.

## unknown operation

```json
{
  "operation": "wat"
}
```

Expected: nonzero exit with an input error.

## unknown decision mode

```json
{
  "rules": [
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {},
  "mode": "sometimes"
}
```

Expected: nonzero exit with an input error. Valid modes are `first`, `all` and `unique`.

## budget out of range

```json
{
  "rules": [
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {},
  "budget": 0
}
```

Expected: nonzero exit with an input error. The budget must be between 1 and 1,000,000 and applies to `decide` and to `evaluate`.

## evaluate budget parameter

```json
{
  "operation": "evaluate",
  "expression": "1 + 1",
  "facts": {},
  "budget": 100
}
```

Expected result fields:

```json
{
  "value": 2
}
```

## evaluate budget exceeded

```json
{
  "operation": "evaluate",
  "expression": "1+1+1+1+1+1+1+1+1+1+1+1+1+1",
  "facts": {},
  "budget": 10
}
```

Expected: nonzero exit with an input error.

## missing fact per-record error

```json
{
  "rules": [
    {
      "id": "r",
      "when": "amount > 5",
      "output": "hit"
    }
  ],
  "facts": [
    {
      "amount": 10
    },
    {}
  ]
}
```

Expected result fields:

```json
{
  "results/0/result/decision": "hit",
  "results/1/index": 1
}
```

Record 1 carries an `error` field instead of `result`; batch evaluation continues.

## conflict ids

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  },
  "mode": "unique"
}
```

Expected result fields:

```json
{
  "results/0/result/conflict": true,
  "results/0/result/decision": null,
  "results/0/result/conflict_ids": ["adult", "fallback"]
}
```

## check valid expression

```json
{
  "operation": "check",
  "expression": "amount > 5",
  "schema": {
    "amount": "number"
  }
}
```

Expected result fields:

```json
{
  "ok": true,
  "type": "boolean"
}
```

## check expression type error

```json
{
  "operation": "check",
  "expression": "amount > \"x\"",
  "schema": {
    "amount": "number"
  }
}
```

Expected result fields:

```json
{
  "ok": false
}
```

The checker reports only what the evaluator would reject; unknown fact paths defer to runtime.

## check rules duplicate id

```json
{
  "operation": "check",
  "rules": [
    {
      "id": "a",
      "when": "true",
      "output": "x"
    },
    {
      "id": "a",
      "when": "true",
      "output": "y"
    }
  ]
}
```

Expected result fields:

```json
{
  "ok": false,
  "rules/1/valid": false
}
```

## check valid rules

```json
{
  "operation": "check",
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    }
  ],
  "schema": {
    "age": "number"
  }
}
```

Expected result fields:

```json
{
  "ok": true,
  "rules/0/condition_type": "boolean"
}
```

## Complete scenarios

Three fixtures under `examples/` demonstrate the proposal use cases end to end. Run them with the CLI and inspect `decision`, `conflict`, `matched` and `evaluated` per record.

### discount-scenario.json (first mode)

Tiered order discount: `vip_large_order` (gold and total >= 500, 15%), `gold_member` (10%), `first_order_bonus` (fixed 20), `no_discount`. Priorities make the best applicable discount win; `compute` derives the amount from cart facts.

Expected: `decision` is `102` (680 cart total at 15%) with `conflict` false.

### admission-scenario.json (unique mode)

Mutually exclusive allow/deny/missing-info rules over device facts, including `exists(device.rooted) && device.rooted` and `!exists(device.api_level)`. The `unique` mode flags any accidental overlap as `conflict` with the offending rules in `conflict_ids`.

Expected: `decision` is `"allow"`, `conflict` false, `conflict_ids` empty.

### dataquality-scenario.json (all mode)

Quality triage over a batch: `auto_pass`, `manual_review` (0.80–0.95), `reject` (< 0.80) and `quarantine` (completeness < 0.5). The `all` mode returns every applicable label per record; ties break by rule ID order.

Expected decisions: `["auto_pass"]`, `["manual_review"]`, `["reject", "quarantine"]`.

## upper

```json
{
  "operation": "evaluate",
  "expression": "upper(name)",
  "facts": {
    "name": "Bob"
  }
}
```

Expected result fields:

```json
{
  "value": "BOB"
}
```

`upper` requires a string argument and returns the uppercase form.

## trim

```json
{
  "operation": "evaluate",
  "expression": "trim(code)",
  "facts": {
    "code": "  AB  "
  }
}
```

Expected result fields:

```json
{
  "value": "AB"
}
```

`trim` removes leading and trailing whitespace from a string.

## starts_with and ends_with

```json
{
  "operation": "evaluate",
  "expression": "starts_with(code, \"PRE\") && ends_with(code, \"SUF\")",
  "facts": {
    "code": "PRE-SUF"
  }
}
```

Expected result fields:

```json
{
  "value": true
}
```

Both predicates require two string arguments.

## replace

```json
{
  "operation": "evaluate",
  "expression": "replace(code, \"-\", \"_\")",
  "facts": {
    "code": "A-B"
  }
}
```

Expected result fields:

```json
{
  "value": "A_B"
}
```

`replace` substitutes every occurrence of the second argument with the third and requires three string arguments.

## substring

```json
{
  "operation": "evaluate",
  "expression": "substring(code, 1, 3)",
  "facts": {
    "code": "ABCDE"
  }
}
```

Expected result fields:

```json
{
  "value": "BC"
}
```

`substring` takes a string, an inclusive start index and an exclusive end index. Indices outside the string, or a start after the end, are input errors.

## floor and ceil

```json
{
  "operation": "evaluate",
  "expression": "floor(price)",
  "facts": {
    "price": 3.2
  }
}
```

Expected result fields:

```json
{
  "value": 3
}
```

`floor` rounds down, `ceil` rounds up; both require a number.

## round

```json
{
  "operation": "evaluate",
  "expression": "round(score)",
  "facts": {
    "score": 2.6
  }
}
```

Expected result fields:

```json
{
  "value": 3
}
```

`round` rounds to the nearest integer and requires a number.

## min and max

```json
{
  "operation": "evaluate",
  "expression": "min(a, b) + max(a, b)",
  "facts": {
    "a": 5,
    "b": 2
  }
}
```

Expected result fields:

```json
{
  "value": 7
}
```

`min` and `max` take two numbers.

## sum

```json
{
  "operation": "evaluate",
  "expression": "sum(prices)",
  "facts": {
    "prices": [1.5, 2.5, 2]
  }
}
```

Expected result fields:

```json
{
  "value": 6
}
```

`sum` takes an array of numbers; any other element type is an input error.

## serialize

```json
{
  "operation": "serialize",
  "expression": "  1+2*3  "
}
```

Expected result fields:

```json
{
  "canonical": "1 + 2 * 3",
  "nodes": 5,
  "depth": 3
}
```

`serialize` compiles an expression and returns its canonical rendering (minimal parentheses, single spaces), structural metrics and a `tree` description listing every node. Array and object literals are not part of the language and render as JSON.

## roundtrip

```json
{
  "operation": "roundtrip",
  "expression": "(price - discount) * quantity >= 100",
  "facts": {
    "price": 50,
    "discount": 10,
    "quantity": 3
  }
}
```

Expected result fields:

```json
{
  "equivalent": true,
  "value": true
}
```

`roundtrip` re-compiles the canonical rendering and evaluates both trees over the supplied facts, asserting identical results. It accepts an optional `budget`.

## aggregate

```json
{
  "operation": "aggregate",
  "facts": [
    { "tier": "g", "amount": 10 },
    { "tier": "s", "amount": 1 },
    { "tier": "g", "amount": 20 }
  ],
  "key": "tier",
  "metrics": [
    { "name": "n", "op": "count" },
    { "name": "total", "op": "sum", "expression": "amount" },
    { "name": "avg", "op": "avg", "expression": "amount" }
  ]
}
```

Expected result fields:

```json
{
  "group_count": 2,
  "groups/0/metrics/total": 30
}
```

`aggregate` groups facts by a key expression and computes count/sum/avg/min/max metrics per group. Groups sort in semantic order: null, false, true, numbers ascending, strings character-wise, then arrays and objects by canonical form. Records whose key or metric expressions fail are skipped and counted in `record_errors`; group-level failures appear in `metric_errors`. Duplicate metric names, unknown ops, a `count` with an expression, and out-of-range budgets are request errors.

## infer

```json
{
  "operation": "infer",
  "facts": [
    { "user": { "age": 30, "name": "bob" }, "active": true, "tags": ["a"] }
  ]
}
```

Expected result fields:

```json
{
  "schema/user.age": "number",
  "schema/user.name": "string",
  "schema/active": "boolean",
  "schema/tags": "array"
}
```

`infer` derives a dotted-path schema from fact samples. Nested objects recurse; arrays are typed `array` without element inspection; paths seen with more than one type are excluded from `schema` and reported under `mixed` with their type lists. The output is directly usable as the `schema` argument of `check`.

## analyze

```json
{
  "operation": "analyze",
  "rules": [
    { "id": "fallback", "when": "true", "output": "x" },
    { "id": "a", "priority": 1, "when": "amount > 10", "output": 1 },
    { "id": "b", "priority": 9, "when": "amount > 10", "output": 2 }
  ]
}
```

Expected result fields:

```json
{
  "finding_count": 2,
  "findings/0/kind": "tautology",
  "findings/1/kind": "duplicate_condition"
}
```

`analyze` compiles every rule without facts and reports per-rule fact-path dependencies (condition plus compute, character-wise sorted), canonical condition forms, node/depth metrics, and findings: `tautology` for constant-true conditions, `duplicate_condition` with shadow direction (`shadows X` / `shadowed by X`), and `priority_tie` for equal priorities on identical conditions where rule ID order decides. Missing rule IDs and non-string compute are request errors.

## explain

```json
{
  "operation": "explain",
  "rules": [
    { "id": "adult", "priority": 2, "when": "age >= 18", "output": "adult" },
    { "id": "minor", "when": "age < 18", "output": "minor" }
  ],
  "facts": { "age": 20 }
}
```

Expected result fields:

```json
{
  "line_count": 12
}
```

`explain` renders one record's decision as deterministic multi-line text: a mode/decision/conflict header, a `[PASS]` or `[FAIL]` line per evaluated rule with truncated trace values, matched outputs with priorities, and step counts. The structured `result` is included alongside. Fact arrays must contain exactly one record; mode and budget are validated as in `decide`.

## JSONL streaming

When the input path ends with `.jsonl`, the CLI processes newline-delimited requests: each non-empty line is one request, each line prints one compact JSON result, request failures become per-line `{"error": ...}` objects without stopping the stream, and the process exits nonzero if any line failed. Blank lines are skipped. Streaming is selected only by the file path suffix; `-` (stdin) always stays in single-request mode.

```sh
node _build/js/debug/build/cmd/main/main.js requests.jsonl
```

Successful lines print compact results, failing lines print error objects, and the exit code is 1 when anything failed. Run `node scripts/jsonl_check.mjs` for the executable end-to-end cases.

## optimize

```json
{
  "operation": "optimize",
  "expression": "1 + 2 * 3 == 7 && true"
}
```

Expected result fields:

```json
{
  "canonical": "true",
  "nodes": 1,
  "changed": true
}
```

`optimize` rewrites an expression with semantics-preserving rewrites: fully-literal subtrees fold through the standard evaluator (a subtree that would raise at runtime stays unfolded so error classes are preserved), literal `true`/`false` operands of `&&` and `||` are eliminated when the eliminated side is provably never evaluated, and double negations collapse. The result reports canonical forms, node and depth metrics before and after, and the savings percentage.

## evaluate with optimize

Adding `"optimize": true` to an `evaluate` request evaluates the reduced tree: identical values and error classes, fewer recorded steps. Requests without the flag keep full-fidelity step accounting.

## compile_rules / run_program

```json
{
  "operation": "compile_rules",
  "rules": [
    { "id": "adult", "priority": 2, "when": "age>=18", "output": "adult" }
  ]
}
```

Expected result fields:

```json
{
  "program/0/condition": "age >= 18",
  "program/0/duplicate_condition": false
}
```

`compile_rules` validates a rule set once and returns a canonical program: every condition and compute expression is rendered to canonical form (so `"age>=18"` becomes `"age >= 18"`), duplicate conditions are flagged, and non-finite priorities are rejected. `run_program` executes that program over fact batches with the same `mode`/`budget`/`default` semantics as `decide`; it re-verifies structural identity of every entry and rejects tampered or non-canonical programs, duplicate IDs, unknown modes and out-of-range budgets. This enables compile-once, run-many workflows through JSONL streaming.

## coverage

```json
{
  "operation": "coverage",
  "rules": [
    { "id": "adult", "when": "age >= 18" },
    { "id": "senior", "when": "age >= 65" }
  ],
  "facts": [
    { "age": 70 },
    { "age": 30 },
    { "age": 10 }
  ]
}
```

Expected result fields:

```json
{
  "covered_records": 2,
  "multi_hit_records": 1,
  "rules/0/hits": 2
}
```

`coverage` evaluates every rule condition across the batch with independent fuel per record and reports per-rule hits, evaluated counts, errors and hit rates; batch-level covered, multi-hit and error record counts; never-hit and always-hit rule counts; and the full matched-rule pattern distribution sorted character-wise with shares. Per-record failures count toward the failing rule's error tally and shrink its evaluation base without aborting the batch.

## count_matches

```json
{
  "operation": "evaluate",
  "expression": "count_matches(scores, \">\", 5)",
  "facts": {
    "scores": [3, 7, 9, 5]
  }
}
```

Expected result fields:

```json
{
  "value": 2
}
```

`count_matches` takes an array of numbers, one of `<` `<=` `>` `>=` `==` `!=`, and a threshold; unknown operators and non-numeric elements are input errors.

## any_match and all_match

```json
{
  "operation": "evaluate",
  "expression": "any_match(flags) && !all_match(flags)",
  "facts": {
    "flags": [false, true, false]
  }
}
```

Expected result fields:

```json
{
  "value": true
}
```

Both reduce boolean arrays; non-boolean elements are input errors. `all_match` on an empty array is vacuously true.

## pick

```json
{
  "operation": "pick",
  "facts": {
    "user": { "age": 30, "name": "bob" },
    "tags": ["x", "y"]
  },
  "paths": ["user.age", "tags.1", "user.email"]
}
```

Expected result fields:

```json
{
  "picked/user/age": 30,
  "picked/tags/1": "y",
  "missing": ["user.email"]
}
```

`pick` projects a fact record onto an explicit path list, producing a nested object with only the requested paths; numeric segments index arrays. Missing or out-of-range paths are listed under `missing` in character order instead of being silently dropped; duplicate paths are rejected.

## ast

```json
{
  "operation": "ast",
  "expression": "1 + len(items)"
}
```

Expected result fields:

```json
{
  "ast/kind": "binary",
  "ast/op": "+",
  "canonical": "1 + len(items)"
}
```

`ast` converts expression source to an explicit JSON tree — `literal`, `variable`, `unary`, `binary` and `call` nodes — or accepts such a tree under `"ast"` and compiles it back. Parse-direction requests validate kinds, operators and the function allow-list with coded errors and re-compile the canonical rendering to guarantee round-trip safety, so external tooling can manipulate rules as data safely.

## bundle_validate / bundle_resolve

```json
{
  "operation": "bundle_validate",
  "versions": [
    { "version": "1.0.0", "rules": [ { "id": "base", "when": "true", "output": 1 } ] },
    { "version": "1.1.0", "deprecates": ["1.0.0"], "rules": [ { "id": "base", "when": "x > 1", "output": 2 } ] }
  ]
}
```

Expected result fields:

```json
{
  "head": "1.1.0",
  "chain/0": "1.0.0 -> 1.1.0"
}
```

A bundle is a named, versioned rule set with an ordered migration chain. `bundle_validate` compiles every version's program, rejects duplicate versions, empty rule sets and unknown deprecation targets, and reports the head plus the version chain. `bundle_resolve` adds a `current` version and returns the pending steps in application order with `pending_rule_count`, flags `up_to_date` callers, and rejects current versions the bundle does not contain.

## decision_table / decide_table

```json
{
  "operation": "decide_table",
  "table": {
    "columns": ["amount"],
    "rows": [
      { "amount": ">= 100", "outcome": "high" },
      { "amount": "> 0", "outcome": "low" }
    ]
  },
  "facts": [{ "amount": 150 }, { "amount": 0 }]
}
```

Expected result fields:

```json
{
  "results/0/result/decision": "high"
}
```

A decision table is business-authored: columns name fact paths, rows carry operator-prefixed cells (`>= 100`, `< 5`, `== "gold"`, bare words become quoted equality) and an outcome. `decision_table` compiles it to rules — row conjunctions with descending priorities so table order decides, duplicate outcomes rejected, missing cells rejected — and `decide_table` runs the compiled table over facts in one call, returning the rules for inspection.
