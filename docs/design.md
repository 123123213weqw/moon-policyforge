# Implemented architecture

## Core

An expression lexer and precedence parser; numeric/string/boolean literals; dotted fact paths; arithmetic and comparisons; strict boolean short circuit; exists/len/contains/lower/abs; finite arithmetic; evaluation budgets; rule priority; first/all/unique decisions; conflict flags; per-record errors; condition traces; rule-set diff.

## Boundaries

A custom bounded expression language. No arbitrary code execution, loops, user functions or external I/O. Runtime types are checked; static type inference is not included. All matching rule outputs are evaluated even in first mode, and first selects the highest-priority match; equal priority uses rule ID order. Unique produces conflict and null decision on multiple matches. Facts are caller supplied. Traces can include fact values, so redact sensitive facts before storing reports.

## Integration

The core accepts semantic values and returns deterministic JSON-shaped reports. Host adapters handle files, network or processes; they invoke the compiled MoonBit engine. The CLI package declares `supported_targets = "js"`; other backends test the portable core.

## Validation evidence

Fixture cases are hand-checked assertions. Independent reference checks and integration scripts are runnable from a clean checkout. CI executes four core backends and host checks. Historical proposal targets are not release results.
