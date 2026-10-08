# Tutorial: from first decision to governed rule sets

This walkthrough builds a small discount policy end to end: a first decision, explanation-driven review, static governance, and a compile-once run-many production loop. Every command is executable from a clean checkout after `moon build --target js`.

## 1. A first decision

Save this request as `order.json`:

```json
{
  "operation": "decide",
  "mode": "first",
  "rules": [
    { "id": "vip", "priority": 2, "when": "tier == \"gold\" && total >= 500", "compute": "total * 0.15" },
    { "id": "member", "priority": 1, "when": "tier == \"gold\"", "compute": "total * 0.10" },
    { "id": "none", "priority": 0, "when": "true", "output": 0 }
  ],
  "facts": { "tier": "gold", "total": 680 }
}
```

Run it:

```sh
node _build/js/debug/build/cmd/main/main.js order.json
```

The decision is `102` — the `vip` rule outranks `member` because priorities descend, and `compute` derived the discount from the cart total. Rules whose `when` is true but lower priority still appear in `matched` and `evaluated`: first mode always evaluates every matching rule, it only picks the winner by priority (ties break by rule ID in character order).

## 2. Explaining the decision

Change `"operation"` to `"explain"` and keep everything else. The result is a deterministic text report:

```
mode: first
decision: 102
conflict: false
...
evaluated rules:
  [PASS] vip
        trace: "gold" | 680 | "gold" | 500 | true
  [PASS] member
  [PASS] none
...
```

Each `[PASS]` line carries the condition trace — the intermediate values the evaluator produced. That is the review artifact for business sign-off. Remember that traces contain fact values, so redact sensitive facts before storing reports.

## 3. Governing the rule set

Three static operations review the rules themselves, without facts:

- `check` — schema-based type validation. Pass an optional `schema` mapping dotted paths to types; the checker reports exactly what the evaluator would reject and defers unknown paths to runtime.
- `analyze` — dependencies, complexity, tautologies, duplicate conditions with shadow direction, and equal-priority ties on identical conditions.
- `rule_graph` — the fact-sharing graph. Rules in one connected component are update-order coupled: if you ever change facts between rule waves, one component may observe another's inputs.

```sh
echo '{"operation":"analyze","rules":[...]}' | node _build/js/debug/build/cmd/main/main.js -
```

A clean governance pass shows `finding_count: 0`. Each finding carries a kind and a human detail; see docs/api.md for the full contract.

## 4. Measuring real coverage

Before promoting a rule set, measure what it does on realistic traffic:

```sh
echo '{"operation":"coverage","rules":[...],"facts":[{...batch...}]}' | node _build/js/debug/build/cmd/main/main.js -
```

The report tallies per-rule hits and hit rates, records no rule covered, and the matched-pattern distribution. Two smells to act on:

- A rule with `hit_rate` 0 across a large batch is a candidate for deletion.
- Patterns matching many rules at once are conflict candidates; if you need exclusivity, switch the mode to `unique` and watch `conflict` / `conflict_ids`.

## 5. Compile once, run many

Rule sets change rarely; facts arrive constantly. `compile_rules` validates and canonicalizes the set once:

```json
{ "operation": "compile_rules", "rules": [ ... ] }
```

The response `program` carries canonical conditions (`"age>=18"` became `"age >= 18"`) and flags duplicate conditions at compile time. Ship that program with your deployment; at runtime, `run_program` executes it over batches with full `decide` semantics — and rejects any program whose entries were tampered with, so a corrupted artifact fails loudly instead of silently reinterpreting.

Stream a production hour as newline-delimited JSON through a `.jsonl` file path: one result line per request, per-line error objects, nonzero exit when anything failed.

## 6. Performance envelope

Budgets bound every evaluation: `budget` (default 10,000, maximum 1,000,000) counts evaluator steps per record. A runaway condition fails with `E2009 evaluation budget exceeded` instead of hanging the batch. Recorded throughput on server hardware: roughly 8,000 decide records per second per process, 66,000 aggregate records per second; the scale script settles 100,000 facts in about 12 seconds against an independent oracle (docs/benchmarks.md).

## 7. Where to go next

- docs/api.md — the full operation reference.
- docs/errors.md — the E-code taxonomy for programmatic failure handling.
- docs/usage.md — every fixture documented with expected fields.
- docs/design.md — architecture and validation evidence.
- scripts/ — differential fuzzing, scale validation, benchmarks: the same checks CI runs.
