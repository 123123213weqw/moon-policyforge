# Operation reference

Every operation is a JSON request passed to `execute`, the CLI file argument, or a JSONL line. Successful requests print one JSON result; failures exit nonzero with `{"error": "<E-code> <message>"}`. See [errors.md](errors.md) for the code taxonomy and [usage.md](usage.md) for executable fixtures.

## decide

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `operation` | string | `"decide"` | optional; implied |
| `rules` | array | required | each: `id` (string, unique), `when` (expression string), `priority` (finite number, default 0), `output` (any value) or `compute` (expression string) |
| `facts` | object or array | required | a single record or a batch; arrays produce one result per record |
| `mode` | string | `"first"` | `first`, `all` or `unique` |
| `budget` | number | 10000 | evaluation fuel per record, 1..1,000,000 |
| `default` | any | null | decision when no rule matches |

Result: `{"results": [{"index", "result" | "error"}...], "rule_count"}`. Each `result` carries `decision`, `conflict`, `conflict_ids`, `matched` (id/priority/value), `evaluated` (id/matched/trace) and `steps`. All matching rules are evaluated even in `first` mode; `first` selects the highest priority with rule ID tie-break; `unique` reports `conflict` with null `decision` and the conflicting IDs.

## evaluate

| Field | Type | Default |
| --- | --- | --- |
| `expression` | string | required |
| `facts` | object | `{}` |
| `budget` | number | 10000 |

Result: `{"value": <semantic value>}`.

## check

Validates expressions or rule sets without facts. Optional `schema` maps dotted fact paths to `boolean | number | string | null | array | object`.

- With `expression`: result `{"ok", "type", "errors"}` — `type` is the inferred JSON type or `"unknown"`.
- With `rules`: result `{"ok", "rules": [{"id", "valid", "condition_type", "errors"}]}` — covers duplicate IDs, missing or non-boolean conditions, non-finite priorities, uncompilable compute, and rules with neither output nor compute.

The checker mirrors runtime semantics exactly; unknown fact paths defer to runtime.

## serialize

`{"expression"}` → `{"canonical", "nodes", "depth", "tree"}`. Canonical rendering with minimal parentheses; `tree` lists every node leaf-to-root.

## roundtrip

`{"expression", "facts", "budget"?}` → `{"equivalent", "value", "canonical", "nodes", "depth"}`. Re-compiles the canonical rendering and asserts behavioral equality over the facts.

## aggregate

| Field | Type | Notes |
| --- | --- | --- |
| `facts` | array | records to group |
| `key` | expression string | group key per record |
| `metrics` | array | `{name, op, expression?}`; ops `count`, `sum`, `avg`, `min`, `max`; numeric ops require an expression |
| `budget` | number | 10000 |

Result: `{"groups": [{"key", "count", "metrics", "metric_errors"}...], "group_count", "records", "record_errors"}`. Groups sort in semantic order (null, false, true, numbers ascending, strings character-wise, arrays/objects by canonical form). Failed records are skipped and counted; the batch never aborts.

## infer

`{"facts"}` → `{"schema", "mixed", "scanned"}`. Derives a dotted-path schema; arrays type as `array` without element inspection; paths with conflicting types move to `mixed` with their type lists. Output plugs directly into `check`'s `schema`.

## analyze

`{"rules"}` → `{"rules": [{"id", "priority", "dependencies", "canonical", "nodes", "depth", "flags"}], "findings", "finding_count"}`. Static rule-set analysis without facts: dependencies are character-wise sorted fact paths across condition and compute; findings include `tautology`, `duplicate_condition` with shadow direction, and `priority_tie`.

## explain

Renders one record's decision as deterministic text. Same fields as `decide`, but `facts` must be exactly one record (E3010 otherwise). Result: `{"text", "line_count", "result"}` — `text` is a multi-line report with a mode/decision/conflict header, `[PASS]`/`[FAIL]` lines with traces, matched outputs and step counts.

## decision_table / decide_table

`{"table": {"columns": [...], "rows": [{"<column>": "<op> <literal>" | literal, ..., "outcome": ...}]}}` compiles a business-authored table to rules: each row becomes the conjunction of its cell predicates with descending priorities (table order decides), string cells parse their operator prefix or fall back to quoted equality, outcomes become rule IDs with duplicate rejection. `decide_table` adds `facts` (and optional mode/budget/default) and runs the compiled table, returning the rules alongside the decide report.

## bundle_validate / bundle_resolve

`{"versions": [{"version", "rules", "deprecates"?}...]}` compiles every version and reports `head`, the `chain`, per-step programs and aggregate counts; duplicate versions, empty rule sets and unknown deprecation targets are rejected. `bundle_resolve` adds `current` and returns `pending_steps` in application order with `pending_rule_count` and an `up_to_date` flag.

## quantifiers

`count_matches(array, operator, threshold)` scores numeric elements (`<`, `<=`, `>`, `>=`, `==`, `!=`); `any_match(array)` / `all_match(array)` reduce boolean arrays (empty arrays: false / true). Element coercion failures raise E3004; non-array arguments raise E2006.

## pick

`{"facts", "paths": [dotted...]}` projects the record onto the paths (numeric segments index arrays); picked values nest, missing or out-of-range paths are reported under `missing` in character order, duplicates are rejected.

## ast

`{"expression"}` converts source to a JSON tree (`literal`, `variable`, `unary`, `binary`, `call` nodes) with its canonical rendering; `{"ast": tree}` compiles a tree back, rejecting unknown kinds, operators and functions with coded errors and re-compiling the canonical rendering for round-trip safety.

## validate

`{"schema", "required"?, "facts"}` checks fact records against the check operation's schema. Typed paths are type-checked when present; `required` paths must exist; absent unrequired paths are optional. Result: `{"results": [{"index", "ok", "errors": [{"path", "expected", "found"}]}], "records", "error_records", "error_count"}`. The batch never aborts.

## conflicts

`{"rules"}` classifies every rule pair over the conjunction-of-ranges fragment: `disjoint` (provably non-overlapping numeric ranges, strictness exact), `equivalent`, `a_subsumes_b` / `b_subsumes_a` (the looser condition subsumes the tighter one — every match of the tighter is a match of the looser), and `unanalyzed` for conditions outside the sound fragment (disjunctions, string comparisons, non-conjunct shapes). Result: `{"pairs", "pair_count", "summary"}`.

## stats

`{"rules"}` describes a rule set from compiled trees: `rule_count`, `compute_count` with `compute_rules` IDs, `min_priority`/`max_priority`, `condition_nodes`, `avg_nodes`, `max_depth`, the union of fact-path dependencies with per-path rule counts, and the builtin `functions` exercised. No facts are evaluated.

## diff

`{"old": rules, "new": rules}` → `{"added", "removed", "changed"}`. Rule-ID set comparison by full-rule structural equality; ID lists are sorted.

## JSONL streaming

Any request may also be delivered as newline-delimited JSON through a `.jsonl` file path: one compact result per line, per-line error objects, nonzero exit when any line failed. `-` (stdin) always stays single-request.
