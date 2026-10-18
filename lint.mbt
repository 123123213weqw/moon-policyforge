///|
/// One-call governance report.
///
/// The lint operation composes the existing static analyses into a
/// single pass a reviewer can gate on: schema type-checking (via the
/// check operation's rule path), static analysis findings
/// (tautologies, duplicate conditions, priority ties), and bundle
/// manifest integrity when versions are supplied. Every check runs
/// even if earlier ones report problems — the point is a complete
/// finding list, not fail-fast. The overall `ok` is false only when at
/// least one finding exists; unknown fact paths defer to runtime
/// exactly as check does, so lint never invents errors.

///|
fn lint_request(request : Value) -> Value raise {
  let findings : Array[Value] = []
  let sections : Array[Value] = []

  // Section 1: static rule analysis (dependencies, tautologies,
  // duplicates, ties). Raises only on malformed requests, not on
  // findings, so malformed rules fail the whole lint request.
  let analyzed = analyze_rules(request)
  sections.push(
    record([
      ("section", String("analysis")),
      ("finding_count", get(analyzed, "finding_count")),
    ]),
  )
  match get(analyzed, "findings") {
    Array(items) =>
      for item in items {
        findings.push(
          record([
            ("source", String("analysis")),
            ("rule", get(item, "rule")),
            ("kind", get(item, "kind")),
            ("detail", get(item, "detail")),
          ]),
        )
      }
    _ => ()
  }

  // Section 2: type checking against the optional schema. Reuses the
  // check operation verbatim so lint and check can never disagree;
  // unknown fact paths defer to runtime as in check.
  let checked = check_request(request)
  let check_section : Array[Value] = []
  match get(checked, "rules") {
    Array(rules) =>
      for rule in rules {
        if get(rule, "valid") is Bool(false) {
          match get(rule, "errors") {
            Array(errors) =>
              for err in errors {
                check_section.push(
                  record([("rule", get(rule, "id")), ("detail", err)]),
                )
              }
            _ => ()
          }
        }
      }
    _ => ()
  }
  sections.push(
    record([
      ("section", String("types")),
      ("finding_count", Number(check_section.length().to_double())),
    ]),
  )
  for item in check_section {
    findings.push(
      record([
        ("source", String("types")),
        ("rule", get(item, "rule")),
        ("kind", String("type_error")),
        ("detail", get(item, "detail")),
      ]),
    )
  }

  // Section 3: bundle integrity, only when a manifest is supplied.
  match get(request, "versions") {
    Null =>
      sections.push(
        record([("section", String("bundle")), ("finding_count", Number(0.0))]),
      )
    _ => {
      let bundle_bad : Array[Value] = []
      let bundle_ok : Bool = try {
        ignore(bundle_validate_request(request))
        true
      } catch {
        error => {
          bundle_bad.push(
            record([("rule", String("")), ("detail", String(error.to_string()))]),
          )
          false
        }
      }
      sections.push(
        record([
          ("section", String("bundle")),
          ("finding_count", Number(bundle_bad.length().to_double())),
        ]),
      )
      for item in bundle_bad {
        findings.push(
          record([
            ("source", String("bundle")),
            ("rule", get(item, "rule")),
            ("kind", String("bundle_error")),
            ("detail", get(item, "detail")),
          ]),
        )
      }
      let _ = bundle_ok
    }
  }

  let count = findings.length()
  let by_source : Map[String, Int32] = Map([])
  for item in findings {
    let source = match get(item, "source") {
      String(name) => name
      _ => "?"
    }
    match by_source.get(source) {
      Some(n) => by_source[source] = n + 1
      None => by_source[source] = 1
    }
  }
  let summary : Array[Value] = []
  for source in ["analysis", "types", "bundle"] {
    summary.push(
      record([
        ("source", String(source)),
        (
          "findings",
          Number(
            (match by_source.get(source) {
              Some(n) => n
              None => 0
            }).to_double(),
          ),
        ),
      ]),
    )
  }
  record([
    ("ok", Bool(count == 0)),
    ("finding_count", Number(count.to_double())),
    ("summary", Array(summary)),
    ("sections", Array(sections)),
    ("findings", Array(findings)),
  ])
}
