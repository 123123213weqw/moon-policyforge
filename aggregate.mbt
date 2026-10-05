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
  let report : Array[Value] = []
  for canonical_key in order {
    let group = groups[canonical_key]
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
