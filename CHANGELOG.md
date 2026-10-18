# Changelog

## Unreleased

### Fixed

- Sorted identifier lists and canonical keys follow UTF-16 code unit order again on the 2026-10 toolchain, whose default string comparison orders by length first.

### Added

- `scripts/stats.py` regenerates the source-statistics table (`PROJECT_STATS.md` refreshed to 1.0.0 numbers: 206 white-box tests, 101 CLI fixtures, 36 dispatched operations).
- `scripts/consume.sh` verifies the published package from a fresh module by registry version; a `package` CI job runs it on demand.

### Changed

- The package builds with `moon check --deny-warn` on the 2026-10 toolchain: deprecated string and integer APIs replaced, effect-inferred closures rewritten as arrow functions, ambiguous `{}` map literals made explicit, internal types marked `priv`, the reserved word `member` renamed, dead code and unused accumulators removed, and trait promotions for `InputError` follow the moonbitlang/core policy (`extends.mbt`). `InputError` prints its bare message (`E3002 expected array`) instead of the `InputError(...)` wrapper.
- CI checks warnings as errors on all four backends, plus formatting and interface freshness.
All notable changes are documented per release. The format follows Keep a Changelog; versions are the published package versions.

## 0.8.0

### Added

- `merge`: rule-set combination by ID with canonical-signature equality and first/last/report conflict strategies; every merged rule carries its origin set.
- `matrix`: all three decision modes side by side per record with agreement flags, the mode-selection review tool.
- `audit`: compliance-grade decision records — facts echo, matched-rule evidence, conflict and step accounting under mode, deterministic rule-set digest and budget metadata.
- Smoke pass extended to 36 checks.

## 0.7.0

### Added

- `template`: parameterized rule sets with `{{name}}` placeholders — JSON literal expansion in expressions and compute, bare-text in IDs, with missing/unused parameter reporting.
- `score`: condition complexity grades 0-100 from compiled-tree evidence against configurable soft limits, with ranks and explicit reasons.
- `explain_rules`: plain-language sentences for every condition, derived from the compiled tree, with the canonical form alongside.
- Smoke pass extended to 33 checks.

## 0.6.1

### Added

- `snapshot` / `compare`: decision regression snapshots with FNV-1a fingerprints over decision, matched IDs and conflict flag; compare reports added, removed and changed records with before/after digests.
- `plan_waves`: deployment wave scheduling from the dependency graph, with per-wave member rules and coupling paths.

### Fixed

- `snapshot` now routes through the batch decide path so array facts work as documented.

## 0.6.0

### Added

- `validate`: fact records checked against engine schemas, with required-path enforcement, per-record error paths and batch-level summaries.
- `conflicts`: sound semantic relation classification over the conjunction-of-ranges fragment — disjoint with exact strictness, equivalence, and subsumption in standard naming; conditions outside the fragment are marked unanalyzed.
- `stats`: engine self-description from compiled trees (compute census, priority range, node/depth aggregates, per-path dependency counts, builtin function census).
- Smoke pass extended to 28 checks; API reference and boundaries updated.

## 0.5.0

### Added

- `lint`: one-call governance gate composing static analysis, schema type checking and bundle integrity; all sections always run, findings carry their source.
- `fmt`: canonical rule-set formatting with per-ID change flags and `changed_only` selection; formatted rules compile to identical trees.
- `export_schema`: JSON Schema draft 2020-12 documents from engine schemas, with inference fallback.
- `migrate`: applies pending bundle steps into a run_program-ready final program with same-ID replacement and deterministic ordering.

## 0.4.0

### Added

- `count_matches`, `any_match`, `all_match`: array quantifiers with static signatures and per-element fuel.
- `pick`: fact projection onto explicit dotted paths with array indexing and missing-path accounting.
- `ast`: expression AST as JSON in both directions, with coded rejection of unknown kinds, operators and functions.
- `bundle_validate` / `bundle_resolve`: policy bundle manifests, version chains, deprecation checks and pending-migration resolution.
- `decision_table` / `decide_table`: business tables (operator-prefixed range cells, quoted string equality) compile to engine rules; one-call deciding over facts.
- Smoke pass (21 checks) and the verification ladder orchestrator; differential fuzzing extended to quantifiers.

## 0.3.0

### Added

- `optimize`: constant folding and identity eliminations with the raising-subtree preservation guarantee; `evaluate` accepts an optimize flag.
- `compile_rules` / `run_program`: compile-once run-many with tamper rejection.
- `coverage`: per-rule hit tallies, never/always-hit detection, matched-pattern distribution.
- `rule_graph`: fact-sharing dependency graph with union-find components and hub ranking.
- `explain`: single-record deterministic text decision reports.
- Coded error taxonomy E1xxx–E4xxx across every raise site; JSONL streaming through `.jsonl` paths; the tutorial; decide and expression differential oracles; scale validation and benchmarks.

### Fixed

- Equal-priority rule tie-break now uses character-wise rule ID order (the toolchain's String::compare orders by length first).
- JSONL streaming exit code counts execution failures, not only unparseable lines.

## 0.2.0

### Added

- `check`: opt-in schema-based static validation of expressions and rule sets.
- `conflict_ids` attribution for unique-mode conflicts; `evaluate` budget parameter.
- Three complete scenario fixtures (discount, admission, data quality); 100k-fact scale validation; CI integration of the scale check.

## 0.1.0

### Added

- Initial implementation: expression lexer and precedence parser, budgets, strict booleans, finite arithmetic, rule priority, first/all/unique decisions, condition traces, rule-set diff, JSON CLI, four-backend tests, host adapters and fixture-based verification.
