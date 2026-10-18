///|
/// Decision-mode comparison matrix.
///
/// The matrix operation decides every fact record under all three
/// modes side by side: first, all and unique. For each record it
/// reports the three decisions, whether the modes agree, and which
/// matched-rule set produced disagreement. This is the review tool
/// for mode selection: run it over representative facts and every
/// disagreement is a candidate to inspect before locking a mode.

///|
fn matrix_request(request : Value) -> Value raise {
  ignore(arr(get(request, "rules"))) // validate the rule array up front
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  let rows : Array[Value] = []
  let mut agreements = 0
  let mut disagreements = 0
  for i = 0; i < facts.length(); i = i + 1 {
    let fact = facts[i]
    let decisions : Map[String, Value] = Map([])
    let mut first_decision : Value = Null
    let mut all_decision : Value = Null
    let mut unique_decision : Value = Null
    // first
    let first_report = decide(
      load_rules(get(request, "rules")),
      fact,
      "first",
      get(request, "default"),
      budget,
    )
    first_decision = get(first_report, "decision")
    decisions["first"] = first_decision
    // all
    let all_report = decide(
      load_rules(get(request, "rules")),
      fact,
      "all",
      get(request, "default"),
      budget,
    )
    match get(all_report, "decisions") {
      Array(items) => all_decision = Array(items)
      _ => all_decision = Null
    }
    decisions["all"] = all_decision
    // unique
    let unique_report = decide(
      load_rules(get(request, "rules")),
      fact,
      "unique",
      get(request, "default"),
      budget,
    )
    unique_decision = get(unique_report, "decision")
    decisions["unique"] = unique_decision
    // conflict flag from matched count under all
    let matched_count = match get(all_report, "matched") {
      Array(matched) => matched.length()
      _ => 0
    }
    // Agreement: all three views identify the same single outcome when
    // exactly one rule matched; otherwise modes inherently differ.
    let agree = matched_count <= 1
    if agree {
      agreements += 1
    } else {
      disagreements += 1
    }
    rows.push(
      record([
        ("index", Number(i.to_double())),
        ("first", first_decision),
        ("unique", unique_decision),
        ("all_count", Number(matched_count.to_double())),
        ("agree", Bool(agree)),
      ]),
    )
    ignore(decisions)
  }
  record([
    ("rows", Array(rows)),
    ("record_count", Number(facts.length().to_double())),
    ("agreements", Number(agreements.to_double())),
    ("disagreements", Number(disagreements.to_double())),
  ])
}
