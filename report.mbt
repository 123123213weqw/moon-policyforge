///|
/// Human-readable decision reports.
///
/// The explain operation runs the normal decide pipeline over one record
/// and renders the structured result as deterministic text: one PASS or
/// FAIL line per evaluated rule with its canonical condition, the chosen
/// outputs, the final decision, conflict accounting and step counts.

///|
fn render_scalar_short(value : Value) -> String {
  match value {
    String(_) | Number(_) | Bool(_) | Null => value.stringify()
    other => {
      let text = other.stringify()
      if text.length() > 40 {
        text.substring(start=0, end=37).to_string() + "..."
      } else {
        text
      }
    }
  }
}

///|
fn explain_lines(result : Value, mode : String) -> Array[String] raise {
  let lines : Array[String] = []
  lines.push("mode: " + mode)
  lines.push(
    "decision: " + render_scalar_short(get(result, "decision")),
  )
  lines.push("conflict: " + get(result, "conflict").stringify())
  let conflict_ids = get(result, "conflict_ids")
  match conflict_ids {
    Array(items) =>
      if !items.is_empty() {
        lines.push("conflicting rules: " + items.map(fn(v) {
          match v {
            String(s) => s
            _ => ""
          }
        }).join(", "))
      }
    _ => ()
  }
  lines.push("")
  lines.push("evaluated rules:")
  match get(result, "evaluated") {
    Array(entries) =>
      for entry in entries {
        let id = match get(entry, "id") {
          String(name) => name
          _ => "?"
        }
        let matched = get(entry, "matched")
        let mark = match matched {
          Bool(true) => "[PASS]"
          _ => "[FAIL]"
        }
        lines.push("  " + mark + " " + id)
        match get(entry, "trace") {
          Array(trace) =>
            if !trace.is_empty() {
              let parts : Array[String] = []
              for step in trace {
                parts.push(render_scalar_short(step))
              }
              lines.push("        trace: " + parts.join(" | "))
            }
          _ => ()
        }
      }
    _ => ()
  }
  match get(result, "matched") {
    Array(matched) =>
      if !matched.is_empty() {
        lines.push("")
        lines.push("matched outputs:")
        for entry in matched {
          let id = match get(entry, "id") {
            String(name) => name
            _ => "?"
          }
          let priority = get(entry, "priority").stringify()
          lines.push(
            "  " +
            id +
            " (priority " +
            priority +
            ") -> " +
            render_scalar_short(get(entry, "value")),
          )
        }
      }
    _ => ()
  }
  lines.push("")
  lines.push("steps: " + get(result, "steps").stringify())
  lines
}

///|
fn explain_request(request : Value) -> Value raise {
  let mode = optional_str(get(request, "mode"), "first")
  if !["first", "all", "unique"].contains(mode) {
    raise input_error("E3006", "unknown decision mode")
  }
  let rules = load_rules(get(request, "rules"))
  let facts = match get(request, "facts") {
    Array(items) =>
      if items.length() != 1 {
        raise input_error("E3010", "explain needs exactly one fact record")
      } else {
        items[0]
      }
    other => other
  }
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  if budget <= 0 || budget > 1000000 {
    raise input_error("E3007", "budget out of range")
  }
  let result = decide(rules, facts, mode, get(request, "default"), budget)
  let lines = explain_lines(result, mode)
  record([
    ("text", String(lines.join("\n"))),
    ("line_count", Number(lines.length().to_double())),
    ("result", result),
  ])
}
