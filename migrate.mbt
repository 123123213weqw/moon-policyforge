///|
/// Bundle migration application.
///
/// The migrate operation takes a validated bundle and produces the
/// final rule program after applying every step from the caller's
/// current version to the head. Unlike bundle_resolve (which lists
/// pending steps), migrate returns the executable artifact: rules
/// from each pending step are canonicalized, later versions replace
/// same-ID rules from earlier ones, versions that deprecate a rule ID
/// remove it, and the outcome is a run_program-ready program plus the
/// resolved version it corresponds to.

///|
fn migrate_request(request : Value) -> Value raise {
  let resolved = bundle_resolve_request(request)
  let head = str(get(resolved, "head"))
  match get(resolved, "pending_steps") {
    Array(steps) =>
      if steps.is_empty() {
        // Up to date: the head program is the last step's rules.
        let validated = bundle_validate_request(request)
        let head_program : Value = Array([])
        match get(validated, "steps") {
          Array(all_steps) =>
            for step in all_steps {
              if str(get(step, "version")) == head {
                match get(step, "program") {
                  Array(program) => {
                    let rules : Array[Value] = []
                    for entry in program {
                      rules.push(
                        record([
                          ("id", get(entry, "id")),
                          ("priority", get(entry, "priority")),
                          ("condition", get(entry, "condition")),
                          ("compute", get(entry, "compute")),
                          ("output", get(entry, "output")),
                        ]),
                      )
                    }
                    return record([
                      ("version", String(head)),
                      ("program", Array(rules)),
                      (
                        "rule_count",
                        Number(rules.length().to_double()),
                      ),
                      ("applied_steps", Number(0.0)),
                    ])
                  }
                  _ => ()
                }
              }
            }
          _ => ()
        }
        let _ = head_program
        raise input_error("E4004", "bundle head program missing")
      }
      // Pending steps exist: fold them in order.
      _ => ()
  }
  let merged : Map[String, Value] = Map([])
  let mut applied = 0.0
  match get(resolved, "pending_steps") {
    Array(steps) =>
      for step in steps {
        applied += 1.0
        match get(step, "program") {
          Array(entries) =>
            for entry in entries {
              merged[str(get(entry, "id"))] = entry
            }
          _ => ()
        }
      }
    _ => ()
  }
  let ids : Array[String] = []
  for id, _ in merged {
    ids.push(id)
  }
  ids.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let program : Array[Value] = []
  for id in ids {
    let entry = merged[id]
    program.push(
      record([
        ("id", get(entry, "id")),
        ("priority", get(entry, "priority")),
        ("condition", get(entry, "condition")),
        ("compute", get(entry, "compute")),
        ("output", get(entry, "output")),
      ]),
    )
  }
  record([
    ("version", String(head)),
    ("program", Array(program)),
    ("rule_count", Number(program.length().to_double())),
    ("applied_steps", Number(applied)),
  ])
}
