# Moon PolicyForge

[![CI](https://github.com/123123213weqw/moon-policyforge/actions/workflows/ci.yml/badge.svg)](https://github.com/123123213weqw/moon-policyforge/actions/workflows/ci.yml)

Explainable rule decisions, implemented in MoonBit with a JSON CLI and reusable library API. Thirty-two operations, four backends, 206 white-box tests, 96 CLI fixtures, two differential fuzz oracles and a 100k-fact scale check — all wired into one verification ladder (`node scripts/verify.mjs`).

- Repository: [https://github.com/123123213weqw/moon-policyforge](https://github.com/123123213weqw/moon-policyforge)
- Package: `123123213weqw/moon_policyforge@0.8.0`
- License: Apache-2.0
- Release scope: **0.8.0**. The broader competition proposal in `docs/proposal.md` is a reference design, not a claim that every planned capability is implemented.

## Implemented

An expression lexer and precedence parser; numeric/string/boolean literals; dotted fact paths; arithmetic and comparisons; strict boolean short circuit; exists/len/contains/lower/abs; finite arithmetic; evaluation budgets (shared by decide and evaluate); rule priority; first/all/unique decisions; conflict flags with conflicting rule IDs; per-record errors; condition traces; rule-set diff with conflict attribution; an opt-in schema-based static checker; array quantifiers (count_matches, any_match, all_match); fact projection (pick); expression AST as JSON interchange; policy bundle manifests with migration resolution and application; one-call governance lint; canonical rule-set formatting; JSON Schema draft 2020-12 export; fact validation with required paths; semantic condition conflict detection (disjointness and subsumption over range fragments); engine self-description via stats; an optimizer with semantics-preserving rewrites; precompiled rule programs; coverage analysis; dependency graphs; an explain text renderer; a coded error taxonomy (E1xxx-E4xxx); JSONL streaming; canonical expression serialization with structural metrics and round-trip verification; group-wise aggregation; schema inference; static rule-set analysis (dependencies, tautologies, shadowing, ties); single-record text decision reports; a coded error taxonomy (E1xxx-E4xxx); JSONL streaming through the CLI; three complete scenario fixtures; a 100k-fact scale validation, a 500-expression differential fuzz oracle and recorded throughput benchmarks.

## Build and run

Use MoonBit and Node.js 24. The core library supports JS, wasm, wasm-gc and native; the filesystem/HTTP/process CLI is JS only.

```sh
moon update
moon build --target js
moon run cmd/main --target js -- examples/discount-scenario.json
node _build/js/debug/build/cmd/main/main.js examples/admission-scenario.json
```

Pass `-` to read a UTF-8 JSON request from stdin. A single request must be at most 16 MiB. Successful requests print one JSON result; invalid requests exit nonzero. The host runner is a separate process and does not edit the input request file.

## Library use

```sh
moon add 123123213weqw/moon_policyforge@0.8.0
```

In the consumer's `moon.pkg`:

```moonbit
import {
  "123123213weqw/moon_policyforge" @engine,
  "moonbitlang/core/json",
}
```

```moonbit
fn example(request : Json) -> Json raise {
  @engine.execute(request)
}
```

`execute(Json) -> Json raise` is the standard JSON boundary. `from_json`, `Value::to_json`, and `run(Value) -> Value raise` provide a typed semantic value interface. Object ordering is not significant; numeric values use finite Double. Public domain functions are listed in `pkg.generated.mbti`.

## Static checking

The `check` operation validates an expression or a rule set without evaluating it against facts:

```sh
echo '{"operation":"check","expression":"amount > \"x\"","schema":{"amount":"number"}}' | \
  node _build/js/debug/build/cmd/main/main.js -
```

The optional `schema` maps dotted fact paths to one of `boolean`, `number`, `string`, `null`, `array`, `object`. The checker mirrors runtime semantics exactly and only reports what the evaluator would reject; fact paths absent from the schema are `unknown` and defer to runtime, so a schema-less check still catches structural errors. Rule checks cover duplicate IDs, missing conditions, non-boolean conditions, non-finite priorities, uncompilable `compute` expressions, and rules with neither `output` nor `compute`.

## Tests

```sh
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon test --target native  # requires a C compiler
moon build --target js
node scripts/check.mjs
node scripts/verify.mjs  # everything below in one fail-fast ladder
python -B scripts/reference.py
python -B scripts/scale_check.py
python -B scripts/error_codes.py
python -B scripts/fuzz_diff.py
python -B scripts/fuzz_rules.py
python -B scripts/check_docs.py
node scripts/jsonl_check.mjs
node scripts/smoke.mjs
node scripts/bench.mjs
```

There are 96 checked fixture cases in `tests/cases.json`, executed both in MoonBit white-box tests and through the actual Node CLI. Independent reference checks use Python's standard library or separately written algorithms; `scripts/scale_check.py` re-decides 100,000 deterministic facts with a plain-Python oracle and asserts per-index agreement, hit-rule attribution through the explanation chain, and a deterministic hit distribution. Fixtures are synthetic and are not presented as production adoption evidence. New to the project? Start with the [tutorial](docs/tutorial.md). The module map lives in [docs/structure.md](docs/structure.md). Releases are summarized in the [changelog](CHANGELOG.md); validation scripts are catalogued in [docs/scripts.md](docs/scripts.md). Then see the [operation reference](docs/api.md), the [error taxonomy](docs/errors.md), [benchmarks](docs/benchmarks.md), [input and output examples](docs/usage.md) and [current boundaries](docs/boundaries.md).

## Current boundaries

A custom bounded expression language. No arbitrary code execution, loops, user functions or external I/O. Runtime types are always checked at evaluation. A full static type inference is not included; the opt-in `check` operation reports what an optional caller-supplied schema proves, and unknown fact paths defer to runtime. Every input error carries a stable E-code prefix (see docs/errors.md). All matching rule outputs are evaluated even in first mode, and first selects the highest-priority match; equal priority uses rule ID order. Unique produces conflict and null decision on multiple matches, with the conflicting IDs in `conflict_ids`. Facts are caller supplied. Traces can include fact values, so redact sensitive facts before storing reports.

See [source and dependency attribution](THIRD_PARTY.md). This release does not establish competition eligibility or organizer acceptance.
