///|
fn followup_once(definition : Value, facts : Value) -> Value raise {
  let input = obj(definition).copy()
  if optional_str(get(definition, "operation"), "decide") != "decide" {
    raise input_error("E3002", "replay_versions accepts decide definitions")
  }
  input["facts"] = facts
  arr(get(run(Object(input)), "results"))[0]
}

///|
fn followup_ids(outcome : Value) -> Value raise {
  let matched = get(get(outcome, "result"), "matched")
  if matched == Null {
    return Array([])
  }
  let ids = arr(matched).map(item => str(get(item, "id")))
  ids.sort_by(stable_string_compare)
  strings(ids)
}

///|
fn replay_versions_request(request : Value) -> Value raise {
  let cases = arr(get(request, "cases"))
  if cases.length() > 10000 {
    raise input_error("E3007", "too many replay cases")
  }
  let seen : Map[String, Bool] = Map([])
  let output : Array[Value] = []
  let mut changed = 0
  for case in cases {
    let id = str(get(case, "id"))
    if id == "" || seen.contains(id) {
      raise input_error("E4001", "duplicate or empty replay identity")
    }
    seen[id] = true
    let facts = get(case, "facts")
    ignore(obj(facts))
    let before = followup_once(get(request, "old"), facts)
    let after = followup_once(get(request, "new"), facts)
    let a = get(before, "result")
    let b = get(after, "result")
    let decision = get(a, "decision") != get(b, "decision")
    let conflict = get(a, "conflict") != get(b, "conflict")
    let error = get(before, "error") != get(after, "error")
    let matched = followup_ids(before) != followup_ids(after)
    if decision || conflict || error || matched {
      changed += 1
    }
    output.push(
      record([
        ("id", String(id)),
        ("before", before),
        ("after", after),
        ("decision_changed", Bool(decision)),
        ("conflict_changed", Bool(conflict)),
        ("error_changed", Bool(error)),
        ("matched_changed", Bool(matched)),
      ]),
    )
  }
  record([
    ("cases", Array(output)),
    ("sample_count", Number(cases.length().to_double())),
    ("changed_count", Number(changed.to_double())),
    ("equivalent_on_samples", Bool(changed == 0)),
    ("global_equivalence_proven", Bool(false)),
    ("ok", Bool(changed == 0)),
  ])
}
