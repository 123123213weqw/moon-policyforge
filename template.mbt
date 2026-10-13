///|
/// Rule-set templates.
///
/// The template operation renders a parameterized rule set into a
/// concrete one: expressions may reference `{{name}}` placeholders and
/// string cells may embed them, every placeholder is substituted from
/// the params map before compilation, and the result compiles through
/// the standard pipeline so a template error is a compile error with
/// position. Unknown placeholders and unused params are reported —
/// templates must be closed over their parameters to be reusable.

///|
fn split_all(text : String, separator : String) -> Array[String] {
  let parts : Array[String] = []
  for view in text.split(separator) {
    parts.push(view.to_string())
  }
  parts
}

///|
fn expand_template(
  text : String,
  params : Map[String, Value],
  json_values : Bool,
) -> (String, Array[String], Array[String]) {
  // Placeholder scanning via segment splits (no char-by-char walking):
  // text between "{{" and "}}" names a parameter; values render as JSON.
  let used : Map[String, Bool] = Map([])
  let missing : Array[String] = []
  let mut out = ""
  let mut rest = text
  let mut loops = 0
  while loops < 1000 {
    loops += 1
    let parts = split_all(rest, "{{")
    if parts.length() < 2 {
      out += rest
      break
    }
    out += parts[0]
    let tail = parts[1]
    let tail_parts = split_all(tail, "}}")
    if tail_parts.length() < 2 {
      // unterminated placeholder: keep literally along with the rest
      out += "{{" + tail
      break
    }
    let key = tail_parts[0].trim().to_string()
    match params.get(key) {
      Some(value) => {
        // Expressions need JSON literals (strings quoted); plain text
        // fields like IDs take the bare string form.
        if json_values {
          out += Value::stringify(value)
        } else {
          out += match value {
            String(s) => s
            other => Value::stringify(other)
          }
        }
        used[key] = true
      }
      None => {
        missing.push(key)
        out += "{{" + key + "}}"
      }
    }
    // Re-join any further "{{" occurrences split apart above so the
    // next loop iteration sees them intact.
    let mut remainder = tail_parts[1]
    for k = 2; k < parts.length(); k = k + 1 {
      remainder += "{{" + parts[k]
    }
    rest = remainder
  }
  let missing_set : Map[String, Bool] = Map([])
  for name in missing {
    missing_set[name] = true
  }
  let missing_dedup : Array[String] = []
  for name, _ in missing_set {
    missing_dedup.push(name)
  }
  let used_list : Array[String] = []
  for name, _ in used {
    used_list.push(name)
  }
  used_list.sort_by(fn(a, b) { stable_string_compare(a, b) })
  missing_dedup.sort_by(fn(a, b) { stable_string_compare(a, b) })
  (out, used_list, missing_dedup)
}

///|
fn template_request(request : Value) -> Value raise {
  let params : Map[String, Value] = Map([])
  match get(request, "params") {
    Null => ()
    Object(fields) =>
      for key, value in fields {
        params[key] = value
      }
    _ => raise input_error("E3009", "params must be an object")
  }
  let rules = arr(get(request, "rules"))
  let rendered : Array[Value] = []
  let all_used : Map[String, Bool] = Map([])
  let all_missing : Map[String, Bool] = Map([])
  let mut index = 0
  for item in rules {
    let id = str(get(item, "id"))
    let id_expanded = expand_template(id, params, false)
    let expanded_id = id_expanded.0
    for name in id_expanded.1 {
      all_used[name] = true
    }
    for name in id_expanded.2 {
      all_missing[name] = true
    }
    let source = str(get(item, "when"))
    let expanded = expand_template(source, params, true)
    let expanded_when = expanded.0
    for name in expanded.1 {
      all_used[name] = true
    }
    for name in expanded.2 {
      all_missing[name] = true
    }
    let rule : Map[String, Value] = Map([])
    rule["id"] = String(expanded_id)
    rule["when"] = String(expanded_when)
    match get(item, "priority") {
      Null => rule["priority"] = Number(0.0)
      other => rule["priority"] = other
    }
    match get(item, "output") {
      Null => ()
      output => rule["output"] = output
    }
    match get(item, "compute") {
      Null => ()
      String(compute_source) => {
        let expanded_compute = expand_template(compute_source, params, true)
        rule["compute"] = String(expanded_compute.0)
        for name in expanded_compute.1 {
          all_used[name] = true
        }
        for name in expanded_compute.2 {
          all_missing[name] = true
        }
      }
      _ => raise input_error("E4007", "compute must be a string")
    }
    ignore(index)
    index += 1
    rendered.push(Object(rule))
  }
  let missing_names : Array[String] = []
  for name, _ in all_missing {
    missing_names.push(name)
  }
  missing_names.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let unused_names : Array[String] = []
  for name, _ in params {
    if !all_used.contains(name) {
      unused_names.push(name)
    }
  }
  unused_names.sort_by(fn(a, b) { stable_string_compare(a, b) })
  record([
    ("rules", Array(rendered)),
    ("rule_count", Number(rules.length().to_double())),
    ("missing_params", strings(missing_names)),
    ("unused_params", strings(unused_names)),
    ("ok", Bool(missing_names.is_empty())),
  ])
}
