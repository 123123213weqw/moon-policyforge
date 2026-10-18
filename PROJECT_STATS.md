# Project statistics

Snapshot at 1.0.0. `python -B scripts/stats.py` regenerates the category table from the repository tree; see docs/scripts.md for how the numbers are exercised.

| Scope | Count |
| --- | --- |
| MoonBit implementation files | 36 |
| MoonBit implementation lines (excluding tests) | 5233 (4541 effective) |
| White-box tests (engine_wbtest.mbt) | 206 tests, 3432 lines |
| CLI fixtures (tests/cases.json) | 101 |
| Operations dispatched through `run` | 36 |
| Host scripts, oracles and tooling | 14 files, 1353 lines |
| Independent oracles | 3 (arithmetic, expression fuzz, decide fuzz) |
| Differential fuzz volume per run | 620 cases (500 expressions + 120 rule sets) |
| Scale validation | 100,000 facts against a plain-Python oracle |
| Verification ladder stages | 9 (quick mode: 6) |
| Backend targets tested | 4 (js, wasm, wasm-gc, native) |
| Documentation files | 14 |
| Example scenarios | 5 (three domains, streaming pipeline, browser demo) |

All counts are reproducible: `scripts/stats.py` for line categories, `grep -c '^test ' engine_wbtest.mbt` for white-box tests, `python3 -c "import json;print(len(json.load(open('tests/cases.json'))))"` for fixtures, and the ladder itself for the behavioral guarantees behind them.
