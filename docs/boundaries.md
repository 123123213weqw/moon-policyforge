# Version 0.1.0 boundaries

A custom bounded expression language. No arbitrary code execution, loops, user functions or external I/O. Runtime types are checked; static type inference is not included. All matching rule outputs are evaluated even in first mode, and first selects the highest-priority match; equal priority uses rule ID order. Unique produces conflict and null decision on multiple matches. Facts are caller supplied. Traces can include fact values, so redact sensitive facts before storing reports.
