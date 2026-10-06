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

## diff

`{"old": rules, "new": rules}` → `{"added", "removed", "changed"}`. Rule-ID set comparison by full-rule structural equality; ID lists are sorted.

## JSONL streaming

Any request may also be delivered as newline-delimited JSON through a `.jsonl` file path: one compact result per line, per-line error objects, nonzero exit when any line failed. `-` (stdin) always stays single-request.
