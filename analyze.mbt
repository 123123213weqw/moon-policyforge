///|
/// Static rule-set analysis.
///
/// The analyze operation compiles every rule and reports, without any
/// facts: the fact paths each rule depends on (condition plus compute),
/// condition complexity metrics, canonical condition forms, and a list
/// of findings — duplicate conditions that shadow each other under the
/// priority order, constant-true conditions, and equal-priority ties on
/// identical conditions.

///|
fn collect_paths(expr : Expression, paths : Map[String, Bool]) -> Unit {
  match expr {
    Literal(_) => ()
    Variable(path) => paths[path] = true
    Unary(_, operand) => collect_paths(operand, paths)
    Binary(_, left, right) => {
      collect_paths(left, paths)
      collect_paths(right, paths)
    }
    Call(_, args) =>
      for arg in args {
        collect_paths(arg, paths)
      }
  }
}

///|
fn sorted_paths(paths : Map[String, Bool]) -> Array[String] {
  let names : Array[String] = []
  for path, _ in paths {
    names.push(path)
  }
  names.sort_by(fn(a, b) { stable_string_compare(a, b) })
  names
}

///|
fn analyze_rules(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let report : Array[Value] = []
  let findings : Array[Value] = []
  let conditions : Map[String, Array[Value]] = Map([])
  let mut index = 0
  for item in rules {
    let id = match get(item, "id") {
      String(name) => name
      _ =>
        raise input_error(
          "E4006",
          "rule at index " + index.to_string() + " needs an ID",
        )
    }
    let condition = compile(str(get(item, "when")))
    let paths : Map[String, Bool] = Map([])
    collect_paths(condition, paths)
    match get(item, "compute") {
      Null => ()
      String(source) => collect_paths(compile(source), paths)
      _ => raise input_error("E4007", "compute must be a string")
    }
    let dependency_list = sorted_paths(paths)
    let dependencies = strings(dependency_list)
    let (nodes, depth) = condition.metrics()
    let canonical = condition.render()
    let priority = optional_num(get(item, "priority"), 0.0)
    let flags : Array[Value] = []
    if canonical == "true" {
      flags.push(String("tautology"))
      findings.push(
        record([
          ("rule", String(id)),
          ("kind", String("tautology")),
          ("detail", String("condition is constant true")),
        ]),
      )
    }
    match conditions.get(canonical) {
      Some(existing) => {
        let mut other_id = ""
        let mut other_priority = 0.0
        match existing[0] {
          Object(fields) => {
            other_id = match fields.get("id") {
              Some(String(name)) => name
              _ => ""
            }
            other_priority = match fields.get("priority") {
              Some(Number(value)) => value
              _ => 0.0
            }
          }
          _ => ()
        }
        let relation = if priority > other_priority {
          "shadows " + other_id
        } else if priority < other_priority {
          "shadowed by " + other_id
        } else {
          "ties with " + other_id + " at equal priority"
        }
        flags.push(String("duplicate_condition"))
        findings.push(
          record([
            ("rule", String(id)),
            ("kind", String("duplicate_condition")),
            ("detail", String(relation)),
          ]),
        )
        if priority == other_priority {
          findings.push(
            record([
              ("rule", String(id)),
              ("kind", String("priority_tie")),
              (
                "detail",
                String("decides by rule ID order: " + other_id + " vs " + id),
              ),
            ]),
          )
        }
        existing.push(
          record([("id", String(id)), ("priority", Number(priority))]),
        )
      }
      None =>
        conditions[canonical] = [
          record([("id", String(id)), ("priority", Number(priority))]),
        ]
    }
    report.push(
      record([
        ("id", String(id)),
        ("priority", Number(priority)),
        ("dependencies", dependencies),
        ("canonical", String(canonical)),
        ("nodes", Number(nodes.to_double())),
        ("depth", Number(depth.to_double())),
        ("flags", Array(flags)),
      ]),
    )
    index += 1
  }
  record([
    ("rules", Array(report)),
    ("findings", Array(findings)),
    ("finding_count", Number(findings.length().to_double())),
  ])
}
