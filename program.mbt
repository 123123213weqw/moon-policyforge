///|
/// Precompiled rule programs.
///
/// The compile_rules operation validates and canonicalizes a rule set
/// once, returning an opaque program list whose conditions and compute
/// expressions are canonical renderings. The run_program operation then
/// executes that program over fact batches without re-deriving anything:
/// parsing already happened at compile time, canonical conditions parse
/// to identical trees, and structural identity is re-verified so a
/// tampered program is rejected with a coded error.

///|
fn compile_rules_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let program : Array[Value] = []
  let conditions : Map[String, Bool] = Map([])
  let mut index = 0
  for item in rules {
    let id = str(get(item, "id"))
    let priority = optional_num(get(item, "priority"), 0.0)
    if priority.is_nan() || priority.is_inf() {
      raise input_error("E3004", "priority for rule " + id + " must be finite")
    }
    let condition = compile(str(get(item, "when")))
    let canonical_condition = condition.render()
    ignore(compile(canonical_condition))
    let output = get(item, "output")
    let compute_value : Value = match get(item, "compute") {
      Null => Null
      String(source) => {
        let expr = compile(source)
        let canonical = expr.render()
        ignore(compile(canonical))
        String(canonical)
      }
      _ => raise input_error("E4007", "compute must be a string")
    }
    if conditions.contains(canonical_condition) {
      program.push(
        record([
          ("id", String(id)),
          ("priority", Number(priority)),
          ("condition", String(canonical_condition)),
          ("compute", compute_value),
          ("output", output),
          ("duplicate_condition", Bool(true)),
        ]),
      )
    } else {
      conditions[canonical_condition] = true
      program.push(
        record([
          ("id", String(id)),
          ("priority", Number(priority)),
          ("condition", String(canonical_condition)),
          ("compute", compute_value),
          ("output", output),
          ("duplicate_condition", Bool(false)),
        ]),
      )
    }
    index += 1
  }
  ignore(index)
  let mut duplicates = 0
  for entry in program {
    if get(entry, "duplicate_condition") is Bool(true) {
      duplicates += 1
    }
  }
  record([
    ("program", Array(program)),
    ("rule_count", Number(rules.length().to_double())),
    ("duplicate_conditions", Number(duplicates.to_double())),
  ])
}

///|
fn program_rule(item : Value) -> Rule raise {
  let id = str(get(item, "id"))
  let priority = optional_num(get(item, "priority"), 0.0)
  let condition_source = str(get(item, "condition"))
  let condition = compile(condition_source)
  if condition.render() != condition_source {
    raise input_error(
      "E3003",
      "program condition for " + id + " is not canonical",
    )
  }
  let computed : Expression? = match get(item, "compute") {
    Null => None
    String(source) => {
      let expr = compile(source)
      if expr.render() != source {
        raise input_error(
          "E3003",
          "program compute for " + id + " is not canonical",
        )
      }
      Some(expr)
    }
    _ => raise input_error("E4007", "compute must be a string")
  }
  { id, priority, condition, output: get(item, "output"), computed, }
}

///|
fn run_program_request(request : Value) -> Value raise {
  let program = arr(get(request, "program"))
  let ids : Map[String, Bool] = Map([])
  let rules : Array[Rule] = []
  for item in program {
    let rule = program_rule(item)
    if ids.contains(rule.id) {
      raise input_error("E4001", "duplicate rule ID: " + rule.id)
    }
    ids[rule.id] = true
    rules.push(rule)
  }
  rules.sort_by(fn(a, b) {
    let cmp = b.priority.compare(a.priority)
    if cmp == 0 {
      stable_string_compare(a.id, b.id)
    } else {
      cmp
    }
  })
  let mode = optional_str(get(request, "mode"), "first")
  if !["first", "all", "unique"].contains(mode) {
    raise input_error("E3006", "unknown decision mode")
  }
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  if budget <= 0 || budget > 1000000 {
    raise input_error("E3007", "budget out of range")
  }
  let results : Array[Value] = []
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  for i = 0; i < facts.length(); i = i + 1 {
    results.push(
      record([
        ("index", Number(i.to_double())),
        (
          "result",
          decide(rules, facts[i], mode, get(request, "default"), budget),
        ),
      ]),
    ) catch {
      error =>
        results.push(
          record([
            ("index", Number(i.to_double())),
            ("error", String(error.to_string())),
          ]),
        )
    }
  }
  record([
    ("results", Array(results)),
    ("rule_count", Number(rules.length().to_double())),
  ])
}
