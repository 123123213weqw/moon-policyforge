///|
/// Group-wise aggregation over fact batches.
///
/// The aggregate operation compiles one key expression and one expression
/// per metric, evaluates them per record, and folds the results into
/// deterministic groups sorted by canonical key. Count needs no expression;
/// sum, avg, min and max require numeric values and reject non-finite
/// intermediate results through the standard evaluator.

///|
struct MetricSpec {
  name : String
  op : String
  expr : Expression?
}

///|
struct GroupAcc {
  key_value : Value
  key_canonical : String
  mut count : Int
  sums : Map[String, Double]
  mins : Map[String, Double]
  maxs : Map[String, Double]
  mut metric_errors : Int
}

///|
fn parse_metrics(source : Value) -> Array[MetricSpec] raise {
  let specs : Array[MetricSpec] = []
  let names : Map[String, Bool] = Map([])
  for item in arr(source) {
    let name = str(get(item, "name"))
    if names.contains(name) {
      raise InputError("duplicate metric name: " + name)
    }
    names[name] = true
    let op = str(get(item, "op"))
    let expr : Expression? = if get(item, "expression") is Null {
      if op != "count" {
        raise InputError("metric " + name + " needs an expression")
      }
      None
    } else {
      if op == "count" {
        raise InputError("count metric takes no expression")
      }
      Some(compile(str(get(item, "expression"))))
    }
    if !["count", "sum", "avg", "min", "max"].contains(op) {
      raise InputError("unknown metric op: " + op)
    }
    specs.push({ name, op, expr })
  }
  specs
}

///|
fn GroupAcc::record_number(
  self : GroupAcc,
  spec : MetricSpec,
  value : Double,
) -> Unit {
  if self.sums.contains(spec.name) {
    self.sums[spec.name] = self.sums[spec.name] + value
  } else {
    self.sums[spec.name] = value
  }
  match self.mins.get(spec.name) {
    None => self.mins[spec.name] = value
    Some(current) => if value < current {
      self.mins[spec.name] = value
    }
  }
  match self.maxs.get(spec.name) {
    None => self.maxs[spec.name] = value
    Some(current) => if value > current {
      self.maxs[spec.name] = value
    }
  }
}

///|
fn GroupAcc::metric_values(
  self : GroupAcc,
  specs : Array[MetricSpec],
) -> Array[Value] {
  let values : Array[Value] = []
  for spec in specs {
    let value : Value = if spec.op == "count" {
      Number(self.count.to_double())
    } else if !self.sums.contains(spec.name) {
      Null
    } else if spec.op == "avg" {
      Number(self.sums[spec.name] / self.count.to_double())
    } else if spec.op == "sum" {
      Number(self.sums[spec.name])
    } else if spec.op == "min" {
      Number(self.mins[spec.name])
    } else {
      Number(self.maxs[spec.name])
    }
    values.push(String(spec.name))
    values.push(value)
  }
  values
}

///|
fn type_rank(value : Value) -> Int {
  match value {
    Null => 0
    Bool(_) => 1
    Number(_) => 2
    String(_) => 3
    Array(_) => 4
    Object(_) => 5
  }
}

///|
/// Character-wise lexicographic order. The core string compare is not
/// byte-lexicographic on this toolchain, so group ordering uses this
/// explicit comparator to stay deterministic and conventional.
fn stable_string_compare(a : String, b : String) -> Int {
  let ac = a.to_array()
  let bc = b.to_array()
  let shared = if ac.length() < bc.length() {
    ac.length()
  } else {
    bc.length()
  }
  for i in 0..<shared {
    if ac[i] < bc[i] {
      return -1
    }
    if ac[i] > bc[i] {
      return 1
    }
  }
  ac.length() - bc.length()
}

///|
/// Total order over semantic values: null, then false, true, numbers in
/// numeric order, strings in character order, then arrays and objects by
/// their canonical JSON form.
fn stable_value_compare(a : Value, b : Value) -> Int {
  let ra = type_rank(a)
  let rb = type_rank(b)
  if ra != rb {
    return ra - rb
  }
  match (a, b) {
    (Bool(x), Bool(y)) =>
      match (x, y) {
        (false, true) => -1
        (true, false) => 1
        (_, _) => 0
      }
    (Number(x), Number(y)) => x.compare(y)
    (String(x), String(y)) => stable_string_compare(x, y)
    (_, _) => stable_string_compare(canonical(a), canonical(b))
  }
}

///|
fn aggregate_request(request : Value) -> Value raise {
  let key_expr = compile(str(get(request, "key")))
  let specs = parse_metrics(get(request, "metrics"))
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  if budget <= 0 || budget > 1000000 {
    raise InputError("budget out of range")
  }
  let groups : Map[String, GroupAcc] = Map([])
  let order : Array[String] = []
  let mut record_errors = 0
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  for fact in facts {
    let state : Evaluation = { fuel: budget, trace: [], }
    let key_value = try {
      evaluate(key_expr, fact, state)
    } catch {
      error => {
        record_errors += 1
        continue
      }
    }
    let key_canonical = canonical(key_value)
    let group = match groups.get(key_canonical) {
      Some(existing) => existing
      None => {
        let fresh : GroupAcc = {
          key_value,
          key_canonical,
          count: 0,
          sums: Map([]),
          mins: Map([]),
          maxs: Map([]),
          metric_errors: 0,
        }
        groups[key_canonical] = fresh
        order.push(key_canonical)
        fresh
      }
    }
    group.count += 1
    for spec in specs {
      match spec.expr {
        None => ()
        Some(expr) =>
          try {
            let value = evaluate(expr, fact, state)
            group.record_number(spec, num(value))
          } catch {
            error => {
              group.metric_errors += 1
              record_errors += 1
            }
          }
      }
    }
  }
  order.sort()
  let accs : Array[GroupAcc] = []
  for canonical_key in order {
    accs.push(groups[canonical_key])
  }
  accs.sort_by(fn(a, b) { stable_value_compare(a.key_value, b.key_value) })
  let report : Array[Value] = []
  for group in accs {
    let flat = group.metric_values(specs)
    let metric_map : Map[String, Value] = Map([])
    let mut i = 0
    while i < flat.length() {
      metric_map[match flat[i] {
        String(name) => name
        _ => ""
      }] = flat[i + 1]
      i += 2
    }
    report.push(
      record([
        ("key", group.key_value),
        ("count", Number(group.count.to_double())),
        ("metrics", Object(metric_map)),
        ("metric_errors", Number(group.metric_errors.to_double())),
      ]),
    )
  }
  record([
    ("groups", Array(report)),
    ("group_count", Number(order.length().to_double())),
    ("records", Number(facts.length().to_double())),
    ("record_errors", Number(record_errors.to_double())),
  ])
}
