///|
/// Engine self-description.
///
/// The stats operation summarizes a rule set the way a maintainer
/// would ask about it: rule counts with and without compute, priority
/// range, aggregated condition size (nodes and depth), the union of
/// fact-path dependencies with per-path usage counts, and the
/// functions the rule set exercises. It never evaluates conditions
/// against facts; everything is derived from the compiled trees.

///|
fn collect_calls(expr : Expression, names : Map[String, Bool]) -> Unit {
  match expr {
    Literal(_) | Variable(_) => ()
    Unary(_, operand) => collect_calls(operand, names)
    Binary(_, left, right) => {
      collect_calls(left, names)
      collect_calls(right, names)
    }
    Call(name, args) => {
      names[name] = true
      for arg in args {
        collect_calls(arg, names)
      }
    }
  }
}

///|
fn note_rule_paths(
  path_count : Map[String, Int],
  paths : Map[String, Bool],
) -> Unit {
  for path, _ in paths {
    match path_count.get(path) {
      Some(n) => path_count[path] = n + 1
      None => path_count[path] = 1
    }
  }
}

///|
fn stats_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let with_compute : Array[Value] = []
  let priorities : Array[Double] = []
  let mut total_nodes = 0
  let mut total_depth = 0
  let mut max_depth = 0
  let path_count : Map[String, Int] = Map([])
  let fn_count : Map[String, Int] = Map([])
  let mut conditions = 0
  let mut computes = 0
  for item in rules {
    let condition = compile(str(get(item, "when")))
    conditions += 1
    let (nodes, depth) = condition.metrics()
    total_nodes += nodes
    total_depth += depth
    if depth > max_depth {
      max_depth = depth
    }
    let paths : Map[String, Bool] = Map([])
    collect_paths(condition, paths)
    let calls : Map[String, Bool] = Map([])
    collect_calls(condition, calls)
    match get(item, "compute") {
      Null => ()
      String(source) => {
        computes += 1
        let compute = compile(source)
        let (cn, cd) = compute.metrics()
        total_nodes += cn
        total_depth += cd
        if cd > max_depth {
          max_depth = cd
        }
        collect_paths(compute, paths)
        collect_calls(compute, calls)
        with_compute.push(String(str(get(item, "id"))))
      }
      _ => raise input_error("E4007", "compute must be a string")
    }
    // A path counts once per rule that uses it, wherever it appears.
    note_rule_paths(path_count, paths)
    for name, _ in calls {
      match fn_count.get(name) {
        Some(n) => fn_count[name] = n + 1
        None => fn_count[name] = 1
      }
    }
    let priority = optional_num(get(item, "priority"), 0.0)
    priorities.push(priority)
  }
  priorities.sort_by(fn(a, b) { a.compare(b) })
  let min_priority = match priorities.get(0) {
    Some(value) => value
    None => 0.0
  }
  let max_priority = match priorities.get(priorities.length() - 1) {
    Some(value) => value
    None => 0.0
  }
  let names : Array[String] = []
  for path, _ in path_count {
    names.push(path)
  }
  names.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let path_report : Array[Value] = []
  for path in names {
    path_report.push(
      record([
        ("path", String(path)),
        (
          "rules",
          Number((match path_count.get(path) {
            Some(n) => n
            None => 0
          }).to_double()),
        ),
      ]),
    )
  }
  let fn_names : Array[String] = []
  for name, _ in fn_count {
    fn_names.push(name)
  }
  fn_names.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let avg_nodes = if rules.length() == 0 {
    0.0
  } else {
    total_nodes.to_double() / rules.length().to_double()
  }
  record([
    ("rule_count", Number(rules.length().to_double())),
    ("compute_count", Number(computes.to_double())),
    ("compute_rules", Array(with_compute)),
    ("min_priority", Number(min_priority)),
    ("max_priority", Number(max_priority)),
    ("condition_nodes", Number(total_nodes.to_double())),
    ("avg_nodes", Number(avg_nodes)),
    ("max_depth", Number(max_depth.to_double())),
    ("condition_paths", Number(names.length().to_double())),
    ("paths", Array(path_report)),
    ("functions", strings(fn_names)),
  ])
}
