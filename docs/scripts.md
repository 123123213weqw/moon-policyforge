# Scripts reference

Every validation script is runnable from a clean checkout after `moon build --target js`. `node scripts/verify.mjs` runs the whole ladder with fail-fast propagation; CI executes exactly this ladder in the integration job.

| Script | What it proves |
| --- | --- |
| `check.mjs` | The 77 JSON fixtures in `tests/cases.json` decide identically through the real Node CLI. |
| `jsonl_check.mjs` | `.jsonl` streaming isolates failures per line, skips blanks, stays compact, and exits nonzero; stdin stays single-request. |
| `smoke.mjs` | A 21-check executable walk over all seventeen operations, the compile-run loop, quantifiers, pick, AST interchange and coded errors. |
| `reference.py` | An independent arithmetic oracle: 40 precedence and negative-number expressions against Python's own evaluator. |
| `check_docs.py` | Documentation replay: every fenced request in docs/usage.md runs against the CLI; documented errors must fail with a coded error object, everything else must parse. Drift between docs and engine breaks the build. |
| `error_codes.py` | The 23 documented E-codes each appear for their failure class with a nonzero exit. |
| `scale_check.py` | 100,000 deterministic facts through the CLI agree with a plain-Python oracle per index, including hit-rule attribution through the explanation chain; prints the deterministic hit distribution. |
| `fuzz_diff.py` | 500 seeded random expressions (arithmetic, comparisons, logic, quantifiers over array facts) agree with an independent Python evaluator on values and error-code classes, including evaluation-order edges such as denominator-before-numerator validation. |
| `fuzz_rules.py` | 120 seeded random rule sets decide identically in first, all and unique modes against an oracle encoding priority descension, character-wise ID tie-break, conflict attribution and default fallback; each set also flows through compile_rules to prove program transparency. |
| `bench.mjs` | Throughput benchmarks for decide modes, aggregate and compound-expression evaluation; recorded numbers live in docs/benchmarks.md. |

Oracle discipline: every differential script writes its expectations in plain Python from the documented semantics, never by importing engine code, so an engine regression cannot teach the oracle the wrong answer.

## Reproducing a release check

A release is green when, from a clean checkout:

```sh
moon update
moon test --target js && moon test --target wasm && moon test --target wasm-gc && moon test --target native
moon build --target js
node scripts/verify.mjs
```

The four backend runs guard the portable core; the ladder guards behavior through the real CLI. Both together are what CI runs on every push.
