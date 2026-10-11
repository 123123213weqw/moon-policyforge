# Repository structure

| Path | Role |
| --- | --- |
| `value.mbt` | Semantic `Value` enum, JSON conversion, `execute` boundary. |
| `input.mbt` | Request accessors, coercion helpers, the `input_error` code factory. |
| `expression.mbt` | Lexer, precedence parser, evaluator core with budgets and traces. |
| `static.mbt` | Opt-in schema-based checker mirroring runtime semantics. |
| `decision.mbt` | Rule loading, decide pipeline, operation dispatch, diff. |
| `format.mbt` | Canonical rendering, structural metrics, serialize/roundtrip. |
| `optimize.mbt` | Semantics-preserving rewrites; optimize operation and evaluate flag. |
| `aggregate.mbt` | Group-wise aggregation with semantic ordering. |
| `infer.mbt` | Schema inference over fact samples. |
| `analyze.mbt` | Static rule analysis: dependencies, tautologies, shadowing, ties. |
| `coverage.mbt` | Batch rule coverage tallies and pattern distribution. |
| `graph.mbt` | Fact-sharing dependency graph with union-find components. |
| `report.mbt` | Single-record text decision reports (explain). |
| `program.mbt` | Compile-once rule programs with tamper rejection. |
| `bundle.mbt` | Versioned policy bundles and migration resolution. |
| `quantify.mbt` | Array quantifiers: count_matches, any_match, all_match. |
| `extract.mbt` | Fact projection (pick) with missing-path accounting. |
| `ast.mbt` | Expression AST as JSON interchange. |
| `decision_table.mbt` | Business table compilation and one-call deciding. |
| `cmd/main/` | The JS host: file/stdin/.jsonl input, exit-code protocol. |
| `tests/cases.json` | The 77 CLI fixtures, mirrored as white-box tests. |
| `engine_wbtest.mbt` | 137 white-box tests over the public `run` boundary. |
| `scripts/` | Verification ladder, oracles, fuzzers, benchmarks; see docs/scripts.md. |
| `examples/` | Three scenario fixtures, the streaming pipeline, the browser demo. |
| `docs/` | Tutorial, API reference, errors, boundaries, design, benchmarks, structure. |

Module layering: everything above `decision.mbt` depends only on `expression.mbt` (trees and evaluation), `input.mbt` (accessors and codes), `format.mbt` (rendering/metrics) and `value.mbt` (values). `decision.mbt` is the only module that dispatches operations, so adding one is a new file plus a dispatch arm — no cross-module rewrites. Test code sits in `engine_wbtest.mbt` and drives the same `run` boundary as production callers.
