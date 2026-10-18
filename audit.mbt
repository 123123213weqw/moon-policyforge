///|
/// Decision audit records.
///
/// The audit operation produces the compliance-grade record for a
/// decide batch: per record the input echo (facts), the resolved
/// decision with its matched-rule evidence, engine metadata (mode,
/// rule-set digest, budget), and wall-clock-free ordering that is
/// stable across runs. Snapshots fingerprint outcomes for diffing;
/// audit preserves the full reasoning trail for reviewers who must
/// reconstruct why any single decision happened.

///|
fn audit_request(request : Value) -> Value raise {
  let mode = optional_str(get(request, "mode"), "first")
  let rules = arr(get(request, "rules"))
  let rule_digest_text = digest(canonical(get(request, "rules")))
  let budget = optional_num(get(request, "budget"), 10000.0)
  let decided = run(
    record([
      ("operation", String("decide")),
      ("rules", get(request, "rules")),
      ("facts", get(request, "facts")),
      ("mode", String(mode)),
      ("default", get(request, "default")),
      ("budget", Number(budget)),
    ]),
  )
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  let entries : Array[Value] = []
  match get(decided, "results") {
    Array(results) =>
      for result in results {
        let index = num(get(result, "index")).to_int()
        let outcome = get(result, "result")
        let matched : Array[Value] = []
        match get(outcome, "matched") {
          Array(items) =>
            for item in items {
              matched.push(item)
            }
          _ => ()
        }
        entries.push(
          record([
            ("index", Number(index.to_double())),
            ("facts", facts[index]),
            ("decision", get(outcome, "decision")),
            ("matched", Array(matched)),
            ("conflict", get(outcome, "conflict")),
            ("steps", get(outcome, "steps")),
          ]),
        )
      }
    _ => ()
  }
  record([
    ("engine", String("moon-policyforge")),
    ("mode", String(mode)),
    ("rule_digest", String(rule_digest_text)),
    ("rule_count", Number(rules.length().to_double())),
    ("budget", Number(budget)),
    ("record_count", Number(facts.length().to_double())),
    ("entries", Array(entries)),
  ])
}
