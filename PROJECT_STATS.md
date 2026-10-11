# Project statistics

Snapshot at 0.4.0 (generated from the repository tree; see docs/scripts.md for how the numbers are exercised).

| Scope | Count |
| --- | --- |
| MoonBit implementation files | 19 |
| MoonBit implementation lines (excluding tests) | 4,181 |
| White-box tests (engine_wbtest.mbt) | 137 tests, 1,364 lines |
| CLI fixtures (tests/cases.json) | 77 |
| Operations dispatched through `run` | 17 |
| Error codes in the taxonomy | 37 sites, 35 documented codes |
| Independent oracles | 3 (arithmetic, expression fuzz, decide fuzz) |
| Differential fuzz volume per run | 620 cases (500 expressions + 120 rule sets) |
| Scale validation | 100,000 facts against a plain-Python oracle |
| Verification ladder stages | 9 (quick mode: 6) |
| Backend targets tested | 4 (js, wasm, wasm-gc, native) |
| Documentation files | 9 |
| Example scenarios | 5 (three domains, streaming pipeline, browser demo) |

All counts are reproducible: `wc -l` over the tree for sizes, `grep -c '^test ' engine_wbtest.mbt` for white-box tests, `python3 -c "import json;print(len(json.load(open('tests/cases.json'))))"` for fixtures, and the ladder itself for the behavioral guarantees behind them.
