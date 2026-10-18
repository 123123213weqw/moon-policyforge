///|
/// Rule-set merging.
///
/// The merge operation combines multiple rule sets into one: rules
/// are matched by ID across sets, and every ID keeps a single entry
/// in the merged output. Non-conflicting duplicates collapse; when
/// two sets define the same ID differently the strategy decides —
/// `first` keeps the earlier set's version and `last` keeps the
/// later's, while `report` marks the ID as conflicted and keeps the
/// earliest. The output records each rule's origin so reviews can
/// trace provenance.

///|
fn rule_signature(item : Value) -> String raise {
  // A stable comparable form of a rule: canonical condition, compute,
  // priority and output through canonical serialization.
  let signature : Map[String, Value] = Map([])
  signature["when"] = String(compile(str(get(item, "when"))).render())
  match get(item, "priority") {
    Null => signature["priority"] = Number(0.0)
    other => signature["priority"] = other
  }
  match get(item, "compute") {
    Null => ()
    String(source) => signature["compute"] = String(compile(source).render())
    _ => signature["compute"] = get(item, "compute")
  }
  signature["output"] = get(item, "output")
  canonical(Object(signature))
}

///|
fn merge_request(request : Value) -> Value raise {
  let strategy = optional_str(get(request, "strategy"), "first")
  if strategy != "first" && strategy != "last" && strategy != "report" {
    raise input_error("E3005", "strategy must be first, last or report")
  }
  let sets = match get(request, "sets") {
    Array(items) => items
    _ => raise input_error("E3002", "merge needs a sets array")
  }
  if sets.is_empty() {
    raise input_error("E3002", "merge needs at least one rule set")
  }
  let by_id : Map[String, Value] = Map([])
  let origin : Map[String, String] = Map([])
  let conflicts : Map[String, Bool] = Map([])
  let mut set_index = 0
  for set in sets {
    let set_name = match get(set, "name") {
      String(name) => name
      _ => "set" + set_index.to_string()
    }
    for item in arr(get(set, "rules")) {
      let id = str(get(item, "id"))
      match by_id.get(id) {
        None => {
          by_id[id] = item
          origin[id] = set_name
        }
        Some(existing) => {
          let same = rule_signature(existing) == rule_signature(item)
          if !same {
            match strategy {
              "last" => {
                by_id[id] = item
                origin[id] = set_name
                conflicts[id] = true
              }
              "report" => conflicts[id] = true
              _ => conflicts[id] = true
            }
          }
        }
      }
    }
    set_index += 1
  }
  let ids : Array[String] = []
  for id, _ in by_id {
    ids.push(id)
  }
  ids.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let merged : Array[Value] = []
  let conflicted_ids : Array[String] = []
  for id in ids {
    let item = by_id[id]
    merged.push(
      record([
        ("id", String(id)),
        ("origin", String(origin.get(id).unwrap_or("?"))),
        ("rule", item),
      ]),
    )
    if conflicts.contains(id) {
      conflicted_ids.push(id)
    }
  }
  conflicted_ids.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let sources : Array[Value] = []
  let mut set_idx2 = 0
  for set in sets {
    let set_name = match get(set, "name") {
      String(name) => name
      _ => "set" + set_idx2.to_string()
    }
    let count = arr(get(set, "rules")).length()
    sources.push(
      record([("name", String(set_name)), ("rules", Number(count.to_double()))]),
    )
    set_idx2 += 1
  }
  record([
    ("rules", Array(merged)),
    ("rule_count", Number(merged.length().to_double())),
    ("conflict_count", Number(conflicted_ids.length().to_double())),
    ("conflicted_ids", strings(conflicted_ids)),
    ("sources", Array(sources)),
    ("strategy", String(strategy)),
  ])
}
