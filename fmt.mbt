///|
/// Canonical rule-set formatting.
///
/// The fmt operation rewrites every rule to its canonical textual
/// form: conditions through the expression renderer (minimal
/// parentheses, single spaces), IDs and outcomes untouched, optional
/// fields normalized to a stable key order. `changed` flags rules
/// whose source differed from canonical form, so CI can fail on
/// unformatted rule sets exactly like a code formatter — and `apply`
/// returns the formatted rules as a ready-to-use rule set that
/// compiles to identical trees.

///|
fn fmt_rules_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let formatted : Array[Value] = []
  let changed_ids : Array[String] = []
  let mut index = 0
  let mut changed_count = 0
  for item in rules {
    let id = str(get(item, "id"))
    let condition = compile(str(get(item, "when")))
    let canonical = condition.render()
    let source = str(get(item, "when"))
    let rule : Map[String, Value] = Map([])
    rule["id"] = String(id)
    rule["when"] = String(canonical)
    match get(item, "priority") {
      Null => rule["priority"] = Number(0.0)
      other => rule["priority"] = other
    }
    match get(item, "output") {
      Null => ()
      output => rule["output"] = output
    }
    match get(item, "compute") {
      Null => ()
      String(source) => {
        let compute = compile(source)
        let canonical_compute = compute.render()
        rule["compute"] = String(canonical_compute)
        if canonical_compute != source {
          changed_count += 1
          changed_ids.push(id)
        }
      }
      _ => raise input_error("E4007", "compute must be a string")
    }
    if canonical != source {
      changed_count += 1
      changed_ids.push(id)
    }
    ignore(index)
    index += 1
    formatted.push(Object(rule))
  }
  changed_ids.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let changed_flagged = match get(request, "changed_only") {
    Bool(true) => {
      let selected : Array[Value] = []
      let wanted : Map[String, Bool] = Map([])
      for id in changed_ids {
        wanted[id] = true
      }
      for rule in formatted {
        if wanted.contains(str(get(rule, "id"))) {
          selected.push(rule)
        }
      }
      Array(selected)
    }
    _ => Array(formatted)
  }
  record([
    ("rules", changed_flagged),
    ("rule_count", Number(rules.length().to_double())),
    ("changed_count", Number(changed_count.to_double())),
    ("changed_ids", strings(changed_ids)),
  ])
}
