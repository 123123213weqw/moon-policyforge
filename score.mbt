///|
/// Condition complexity scoring.
///
/// The score operation grades every rule condition for maintainability
/// using compiled-tree evidence: node count and depth against soft
/// limits, distinct fact-path count, boolean-branch density, and
/// builtin-call usage. Each rule receives a 0-100 score (higher is
/// simpler) plus a rank (simple / moderate / complex) and the reasons
/// that lowered it. The scoring is deterministic and documented — no
/// facts are evaluated, no hidden ML.

///|
fn score_condition(
  id : String,
  condition : Expression,
  soft_nodes : Int32,
  soft_depth : Int32,
) -> Value {
  let (nodes, depth) = condition.metrics()
  let paths : Map[String, Bool] = Map([])
  collect_paths(condition, paths)
  let calls : Map[String, Bool] = Map([])
  collect_calls(condition, calls)
  let distinct_paths = paths.keys().collect().length()
  let mut score = 100
  let reasons : Array[Value] = []
  let mut branch_count = 0
  fn count_bools(expr : Expression) -> Unit {
    match expr {
      Binary("&&", left, right) => {
        branch_count += 1
        count_bools(left)
        count_bools(right)
      }
      Binary("||", left, right) => {
        branch_count += 1
        count_bools(left)
        count_bools(right)
      }
      Binary(_, left, right) => {
        count_bools(left)
        count_bools(right)
      }
      Unary(_, operand) => count_bools(operand)
      Call(_, args) =>
        for arg in args {
          count_bools(arg)
        }
      _ => ()
    }
  }
  count_bools(condition)
  if nodes > soft_nodes {
    let over = nodes - soft_nodes
    let penalty = if over * 2 > 40 { 40 } else { over * 2 }
    score -= penalty
    reasons.push(
      String(
        "wide: " +
        nodes.to_string() +
        " nodes over limit " +
        soft_nodes.to_string(),
      ),
    )
  }
  if depth > soft_depth {
    let over = depth - soft_depth
    let penalty = if over * 5 > 30 { 30 } else { over * 5 }
    score -= penalty
    reasons.push(
      String(
        "deep: " +
        depth.to_string() +
        " levels over limit " +
        soft_depth.to_string(),
      ),
    )
  }
  if distinct_paths > 4 {
    let penalty = if (distinct_paths - 4) * 5 > 20 {
      20
    } else {
      (distinct_paths - 4) * 5
    }
    score -= penalty
    reasons.push(
      String(
        "wide-facts: " + distinct_paths.to_string() + " distinct fact paths",
      ),
    )
  }
  if branch_count > 3 {
    let penalty = if (branch_count - 3) * 4 > 16 {
      16
    } else {
      (branch_count - 3) * 4
    }
    score -= penalty
    reasons.push(
      String("branchy: " + branch_count.to_string() + " boolean operators"),
    )
  }
  if calls.keys().collect().length() > 2 {
    score -= 5
    reasons.push(String("call-heavy: more than two builtin functions"))
  }
  if score < 0 {
    score = 0
  }
  let rank = if score >= 80 {
    "simple"
  } else if score >= 55 {
    "moderate"
  } else {
    "complex"
  }
  record([
    ("id", String(id)),
    ("score", Number(score.to_double())),
    ("rank", String(rank)),
    ("nodes", Number(nodes.to_double())),
    ("depth", Number(depth.to_double())),
    ("distinct_paths", Number(distinct_paths.to_double())),
    ("boolean_ops", Number(branch_count.to_double())),
    ("functions", strings(calls.keys().collect())),
    ("reasons", Array(reasons)),
  ])
}

///|
fn score_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let soft_nodes = optional_num(get(request, "soft_nodes"), 12.0).to_int()
  let soft_depth = optional_num(get(request, "soft_depth"), 4.0).to_int()
  if soft_nodes <= 0 || soft_depth <= 0 {
    raise input_error("E3007", "soft limits must be positive")
  }
  let scored : Array[Value] = []
  let mut simple = 0
  let mut moderate = 0
  let mut complex = 0
  let mut total = 0.0
  for item in rules {
    let id = str(get(item, "id"))
    let condition = compile(str(get(item, "when")))
    let entry = score_condition(id, condition, soft_nodes, soft_depth)
    match get(entry, "rank") {
      String(rank) =>
        match rank {
          "simple" => simple += 1
          "moderate" => moderate += 1
          _ => complex += 1
        }
      _ => ()
    }
    total += match get(entry, "score") {
      Number(value) => value
      _ => 0.0
    }
    scored.push(entry)
  }
  let average = if rules.length() == 0 {
    0.0
  } else {
    total / rules.length().to_double()
  }
  record([
    ("rules", Array(scored)),
    ("rule_count", Number(rules.length().to_double())),
    ("average_score", Number(average)),
    ("simple", Number(simple.to_double())),
    ("moderate", Number(moderate.to_double())),
    ("complex", Number(complex.to_double())),
  ])
}
