///|
struct Rule {
  id : String
  priority : Double
  condition : Expression
  output : Value
  computed : Expression?
}

///|
fn load_rules(source : Value) -> Array[Rule] raise {
  let ids : Map[String, Bool] = {}
  let rules : Array[Rule] = []
  for item in arr(source) {
    let id = str(get(item, "id"))
    if ids.contains(id) {
      raise InputError("duplicate rule ID: " + id)
    }
    ids[id] = true
    rules.push({
      id,
      priority: optional_num(get(item, "priority"), 0.0),
      condition: compile(str(get(item, "when"))),
      output: get(item, "output"),
      computed: if get(item, "compute") == Null {
        None
      } else {
        Some(compile(str(get(item, "compute"))))
      },
    })
  }
  rules.sort_by(fn(a, b) {
    let cmp = b.priority.compare(a.priority)
    if cmp == 0 {
      a.id.compare(b.id)
    } else {
      cmp
    }
  })
  rules
}

///|
fn decide(
  rules : Array[Rule],
  facts : Value,
  mode : String,
  fallback : Value,
  budget : Int,
) -> Value raise {
  ignore(obj(facts))
  let matched : Array[Value] = []
  let evaluated : Array[Value] = []
  let state : Evaluation = { fuel: budget, trace: [], }
  for rule in rules {
    let start = state.trace.length()
    let hits = boolean(evaluate(rule.condition, facts, state))
    let trace : Array[Value] = []
    for i = start; i < state.trace.length(); i = i + 1 {
      trace.push(state.trace[i])
    }
    evaluated.push(
      record([
        ("id", String(rule.id)),
        ("matched", Bool(hits)),
        ("trace", Array(trace)),
      ]),
    )
    if hits {
      let output = match rule.computed {
        Some(expr) => evaluate(expr, facts, state)
        None => rule.output
      }
      matched.push(
        record([
          ("id", String(rule.id)),
          ("priority", Number(rule.priority)),
          ("value", output),
        ]),
      )
    }
  }
  let conflict = mode == "unique" && matched.length() > 1
  let decision = if matched.is_empty() {
    fallback
  } else if conflict {
    Null
  } else if mode == "all" {
    Array(matched.map(fn(item) { get(item, "value") }))
  } else {
    get(matched[0], "value")
  }
  record([
    ("decision", decision),
    ("conflict", Bool(conflict)),
    ("matched", Array(matched)),
    ("evaluated", Array(evaluated)),
    ("steps", Number((budget - state.fuel).to_double())),
  ])
}

///|
pub fn run(request : Value) -> Value raise {
  let operation = optional_str(get(request, "operation"), "decide")
  if operation == "evaluate" {
    return record([
      (
        "value",
        evaluate_expression(
          str(get(request, "expression")),
          get(request, "facts"),
        ),
      ),
    ])
  }
  if operation == "diff" {
    let old_rules : Map[String, Value] = {}
    let new_rules : Map[String, Value] = {}
    for r in arr(get(request, "old")) {
      old_rules[str(get(r, "id"))] = r
    }
    for r in arr(get(request, "new")) {
      new_rules[str(get(r, "id"))] = r
    }
    let added : Array[String] = []
    let removed : Array[String] = []
    let changed : Array[String] = []
    for id, r in new_rules {
      match old_rules.get(id) {
        None => added.push(id)
        Some(old) => if old != r { changed.push(id) }
      }
    }
    for id, _ in old_rules {
      if !new_rules.contains(id) {
        removed.push(id)
      }
    }
    added.sort()
    removed.sort()
    changed.sort()
    return record([
      ("added", strings(added)),
      ("removed", strings(removed)),
      ("changed", strings(changed)),
    ])
  }
  if operation != "decide" {
    raise InputError("unknown operation")
  }
  let rules = load_rules(get(request, "rules"))
  let mode = optional_str(get(request, "mode"), "first")
  if !["first", "all", "unique"].contains(mode) {
    raise InputError("unknown decision mode")
  }
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  if budget <= 0 || budget > 1000000 {
    raise InputError("budget out of range")
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
