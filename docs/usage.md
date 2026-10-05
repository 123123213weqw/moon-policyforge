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
