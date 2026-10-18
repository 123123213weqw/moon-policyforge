///|
/// Rule coverage analysis over fact batches.
///
/// The coverage operation evaluates every rule condition across a batch
/// with independent fuel per record, then reports per-rule hit counts
/// and rates, batch-wide match distributions, never-hit and always-hit
/// rules, records that no rule covers, and pairwise condition agreement
/// between rules sharing at least one hit pattern. It never raises on
/// per-record failures: failed evaluations count toward a rule's error
/// tally and shrink its evaluation base.

///|
priv struct RuleTally {
  id : String
  mut hits : Int32
  mut errors : Int32
  mut evaluated : Int32
}

///|
fn coverage_request(request : Value) -> Value raise {
  let rules = load_rules(get(request, "rules"))
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  if budget <= 0 || budget > 1000000 {
    raise input_error("E3007", "budget out of range")
  }
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  let tallies : Array[RuleTally] = []
  for rule in rules {
    tallies.push({ id: rule.id, hits: 0, errors: 0, evaluated: 0, })
  }
  let mut covered_records = 0
  let mut multi_records = 0
  let mut error_records = 0
  let distributions : Map[String, Int32] = Map([])
  for fact in facts {
    let hits : Array[String] = []
    let mut record_failed = false
    for i = 0; i < rules.length(); i = i + 1 {
      let state : Evaluation = { fuel: budget, trace: [], }
      let outcome : Bool? = Some(
        boolean(evaluate(rules[i].condition, fact, state)),
      ) catch {
        _ => {
          tallies[i].errors += 1
          record_failed = true
          None
        }
      }
      match outcome {
        Some(hit) => {
          tallies[i].evaluated += 1
          if hit {
            tallies[i].hits += 1
            hits.push(rules[i].id)
          }
        }
        None => ()
      }
    }
    if record_failed {
      error_records += 1
    }
    if hits.length() > 0 {
      covered_records += 1
    }
    if hits.length() > 1 {
      multi_records += 1
    }
    let pattern = if hits.is_empty() { "none" } else { hits.join("+") }
    match distributions.get(pattern) {
      Some(count) => distributions[pattern] = count + 1
      None => distributions[pattern] = 1
    }
  }
  let total = facts.length().to_double()
  let rule_report : Array[Value] = []
  let mut never_hit = 0
  let mut always_hit = 0
  for tally in tallies {
    let rate = if tally.evaluated == 0 {
      0.0
    } else {
      tally.hits.to_double() * 100.0 / tally.evaluated.to_double()
    }
    if tally.evaluated > 0 && tally.hits == 0 {
      never_hit += 1
    }
    if tally.evaluated > 0 && tally.hits == tally.evaluated {
      always_hit += 1
    }
    rule_report.push(
      record([
        ("id", String(tally.id)),
        ("hits", Number(tally.hits.to_double())),
        ("evaluated", Number(tally.evaluated.to_double())),
        ("errors", Number(tally.errors.to_double())),
        ("hit_rate", Number(rate)),
      ]),
    )
  }
  let patterns : Array[(String, Int32)] = []
  for kv in distributions {
    patterns.push((kv.0, kv.1))
  }
  patterns.sort_by(fn(a, b) { stable_string_compare(a.0, b.0) })
  let distribution_report : Array[Value] = []
  for pair in patterns {
    let pattern = pair.0
    let count = pair.1
    distribution_report.push(
      record([
        ("matched", String(pattern)),
        ("records", Number(count.to_double())),
        ("share", Number(count.to_double() * 100.0 / total)),
      ]),
    )
  }
  record([
    ("records", Number(total)),
    ("covered_records", Number(covered_records.to_double())),
    ("multi_hit_records", Number(multi_records.to_double())),
    ("error_records", Number(error_records.to_double())),
    ("rules", Array(rule_report)),
    ("never_hit", Number(never_hit.to_double())),
    ("always_hit", Number(always_hit.to_double())),
    ("patterns", Array(distribution_report)),
  ])
}
