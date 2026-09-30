# Implemented architecture

## Core

An expression lexer and precedence parser; numeric/string/boolean literals; dotted fact paths; arithmetic and comparisons; strict boolean short circuit; exists/len/contains/lower/abs; finite arithmetic; evaluation budgets shared by decide and evaluate; rule priority; first/all/unique decisions; conflict flags with conflicting rule IDs; per-record errors; condition traces; rule-set diff.

## Static checker

An opt-in `check` operation validates expressions and rule sets without facts. An optional schema maps dotted fact paths to JSON type names. Inference mirrors runtime semantics exactly: it reports only what the evaluator would reject and leaves unknown fact paths as `unknown`, so schema-less checks still catch structural errors without claiming full type inference. Rule checks cover duplicate IDs, missing conditions, non-boolean conditions, non-finite priorities, uncompilable compute expressions, and rules with neither output nor compute.

## Boundaries

A custom bounded expression language. No arbitrary code execution, loops, user functions or external I/O. Runtime types are always checked at evaluation. A full static type inference is not included; the opt-in `check` operation reports what an optional caller-supplied schema proves, and unknown fact paths defer to runtime. All matching rule outputs are evaluated even in first mode, and first selects the highest-priority match; equal priority uses rule ID order. Unique produces conflict and null decision on multiple matches, with the conflicting rule IDs reported in `conflict_ids`. Facts are caller supplied. Traces can include fact values, so redact sensitive facts before storing reports.

## Integration

The core accepts semantic values and returns deterministic JSON-shaped reports. Host adapters handle files, network or processes; they invoke the compiled MoonBit engine. The CLI package declares `supported_targets = "js"`; other backends test the portable core.

## Validation evidence

Fixture cases are hand-checked assertions. Independent reference checks and integration scripts are runnable from a clean checkout. A scale script re-decides 100,000 deterministic facts with a plain-Python oracle and asserts per-index agreement, hit-rule attribution through the explanation chain, and a deterministic hit distribution. Three complete scenario fixtures (discount, admission, data quality) demonstrate the proposal use cases end to end. CI executes four core backends and host checks. Historical proposal targets are not release results.
