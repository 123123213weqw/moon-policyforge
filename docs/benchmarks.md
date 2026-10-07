# Benchmarks

Single-process CLI runs (`node scripts/bench.mjs`), 20,000 records per scenario over a three-rule priority table, Node.js 20 on Linux x86_64 (Supermicro SYS-4029GP-TRT, Xeon Scalable). Numbers are reproducible but hardware-dependent; they characterize the engine, not a service.

| Scenario | Records | Wall | Throughput |
| --- | --- | --- | --- |
| decide first | 20,000 | 2.29s | 8,719 records/s |
| decide all | 20,000 | 2.57s | 7,778 records/s |
| decide unique | 20,000 | 2.82s | 7,099 records/s |
| aggregate (3 metrics) | 20,000 | 0.30s | 66,064 records/s |
| evaluate expressions | 2,000 | 0.30s | 6,665 records/s |

Notes:

- `unique` is slowest because every matching rule's output is evaluated and conflicts are tracked per record.
- `aggregate` groups without building per-record evaluation reports, so it is roughly an order of magnitude faster than `decide`.
- The scale run in `scripts/scale_check.py` settles 100,000 facts in about 12 seconds end to end, consistent with the `decide first` throughput above.

These are synthetic workloads; they are not production adoption evidence.
