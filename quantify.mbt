///|
/// Counting and quantifier helpers for array facts.
///
/// count(xs, path-free predicate placeholder) is deliberately NOT
/// expressible in a path-based language, so the engine provides
/// structured equivalents instead: count_matches scores an array
/// against threshold operators applied to its numeric elements, and
/// any_match / all_match reduce boolean arrays. These are fold-shaped
/// builtins: bounded by array length, charged fuel per element, and
/// type-checked statically as (array, number) -> number and
/// (array) -> boolean respectively.

///|
fn count_matches(items : Array[Value], threshold : Double, op : String) -> Value raise {
  let operators = ["<", "<=", ">", ">=", "==", "!="]
  if !operators.contains(op) {
    raise input_error("E4005", "unknown count_matches operator: " + op)
  }
  let mut hits = 0
  for item in items {
    let value = num(item)
    let hit = match op {
      "<" => value < threshold
      "<=" => value <= threshold
      ">" => value > threshold
      ">=" => value >= threshold
      "==" => value == threshold
      "!=" => value != threshold
      _ => false
    }
    if hit {
      hits += 1
    }
  }
  Number(hits.to_double())
}

///|
fn any_match(items : Array[Value]) -> Value raise {
  let mut found = false
  for item in items {
    if boolean(item) {
      found = true
    }
  }
  Bool(found)
}

///|
fn all_match(items : Array[Value]) -> Value raise {
  let mut all = true
  for item in items {
    if !boolean(item) {
      all = false
    }
  }
  Bool(all)
}

///|
fn count_matches_expr(args : Array[Expression], facts : Value, state : Evaluation) -> Value raise {
  if args.length() != 3 {
    raise input_error("E2006", "count_matches takes (array, operator, threshold)")
  }
  let evaluated = args.map(fn(arg) { evaluate(arg, facts, state) })
  match (evaluated[0], evaluated[1], evaluated[2]) {
    (Array(items), String(op), Number(threshold)) =>
      count_matches(items, threshold, op)
    (_, _, _) =>
      raise input_error(
        "E2006",
        "count_matches needs (array, string, number)",
      )
  }
}

///|
fn boolean_array(items : Array[Value], who : String) -> Array[Value] raise {
  for item in items {
    ignore(boolean(item))
  }
  let _ = who
  items
}
