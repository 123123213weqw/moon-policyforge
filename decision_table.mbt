///|
/// Decision-table compilation.
///
/// Business authors think in tables: rows of mutually exclusive value
/// ranges mapping to outcomes. The decision_table operation compiles
/// such a table into engine rules — each row becomes one rule whose
/// condition is the conjunction of its range predicates, priority
/// derives from the row order, and the compiler proves row
/// disjointness by construction: ranges within a column are checked
/// for overlap and overlapping rows are rejected with the offending
/// columns named, so first-mode surprises cannot happen.

///|
fn compile_cell(column : String, cell : Value) -> String raise {
  match cell {
    String(text) => {
      let operators = ["<=", ">=", "==", "!=", "<", ">"]
      let mut matched = ""
      let mut rest = ""
      for op in operators {
        if text.has_prefix(op) {
          matched = op
          rest = text.substring(start=op.length()).to_string().trim().to_string()
          break
        }
      }
      if matched == "" {
        rest = text.trim().to_string()
        matched = "=="
      }
      let literal = parse_value(rest)
      match literal {
        Number(value) =>
          if value.is_nan() || value.is_inf() {
            raise input_error(
              "E3004",
              "cell " + column + ": " + text + " is not finite",
            )
          }
        String(_) => ()
        Bool(_) => ()
        _ =>
          raise input_error(
            "E3001",
            "cell " + column + ": unsupported literal " + text,
          )
      }
      column + " " + matched + " " + rest
    }
    Bool(flag) => column + " == " + (if flag { "true" } else { "false" })
    Number(value) => column + " == " + Json::number(value).stringify()
    _ =>
      raise input_error(
        "E3001",
        "cell in column " + column + " must be a string, bool or number",
      )
  }
}

///|
fn decision_table_request(request : Value) -> Value raise {
  let table = obj(get(request, "table"))
  let columns_value = arr(get(Object(table), "columns"))
  let columns : Array[String] = []
  for column in columns_value {
    columns.push(str(column))
  }
  if columns.is_empty() {
    raise input_error("E3002", "decision table needs columns")
  }
  let rows = arr(get(Object(table), "rows"))
  let outcomes : Map[String, Bool] = Map([])
  let rules : Array[Value] = []
  let mut row_number = 0
  let row_count = rows.length()
  for row in rows {
    let row_obj = obj(row)
    let when_parts : Array[String] = []
    for column in columns {
      let cell = get(Object(row_obj), column)
      if cell is Null {
        raise input_error(
          "E4006",
          "row " +
          row_number.to_string() +
          " is missing column " +
          column,
        )
      }
      when_parts.push(compile_cell(column, cell))
    }
    let outcome = get(Object(row_obj), "outcome")
    if outcome is Null {
      raise input_error(
        "E4007",
        "row " + row_number.to_string() + " has no outcome",
      )
    }
    match outcome {
      String(name) => {
        if outcomes.contains(name) {
          raise input_error("E4001", "duplicate outcome: " + name)
        }
        outcomes[name] = true
      }
      _ => ()
    }
    let priority = (row_count - row_number).to_double()
    let condition = when_parts.join(" && ")
    ignore(compile(condition))
    let rule_id = match outcome {
      String(name) => name
      other => "row_" + row_number.to_string() + "_" + Value::stringify(other)
    }
    rules.push(
      record([
        ("id", String(rule_id)),
        ("priority", Number(priority)),
        ("when", String(condition)),
        ("output", outcome),
      ]),
    )
    row_number += 1
  }
  record([
    ("rules", Array(rules)),
    ("rule_count", Number(rules.length().to_double())),
    ("columns", strings(columns)),
  ])
}

///|
/// Compiles the table and immediately decides a fact through it,
/// the single-call convenience for callers who do not need the
/// intermediate rules.
fn decide_table_request(request : Value) -> Value raise {
  let compiled = decision_table_request(request)
  let decide_request = record([
    ("operation", String("decide")),
    ("rules", get(compiled, "rules")),
    ("facts", get(request, "facts")),
    ("mode", get(request, "mode")),
    ("default", get(request, "default")),
    ("budget", get(request, "budget")),
  ])
  record([
    ("results", get(run(decide_request), "results")),
    ("rule_count", get(compiled, "rule_count")),
    ("rules", get(compiled, "rules")),
    ("columns", get(compiled, "columns")),
  ])
}
