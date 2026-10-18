///|
/// Schema inference over fact samples.
///
/// The infer operation walks fact records and derives a dotted-path to
/// type-name mapping usable by the check operation's optional schema.
/// Paths observed with more than one type are reported separately as
/// `mixed` instead of a single type, so downstream checks never receive
/// an ambiguous schema entry.

///|
fn walk_schema(
  value : Value,
  prefix : String,
  observed : Map[String, Map[String, Bool]],
) -> Unit {
  match value {
    Object(fields) =>
      for key, item in fields {
        let path = if prefix == "" { key } else { prefix + "." + key }
        match item {
          Object(_) => {
            note_schema_type(observed, path, "object")
            walk_schema(item, path, observed)
          }
          Array(_) => note_schema_type(observed, path, "array")
          _ => note_schema_type(observed, path, type_name(item))
        }
      }
    _ => ()
  }
}

///|
fn note_schema_type(
  observed : Map[String, Map[String, Bool]],
  path : String,
  kind : String,
) -> Unit {
  match observed.get(path) {
    Some(kinds) => kinds[kind] = true
    None => {
      let kinds : Map[String, Bool] = Map([])
      kinds[kind] = true
      observed[path] = kinds
    }
  }
}

///|
fn infer_request(request : Value) -> Value raise {
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  let observed : Map[String, Map[String, Bool]] = Map([])
  for fact in facts {
    walk_schema(fact, "", observed)
  }
  let paths : Array[String] = []
  for path, _ in observed {
    paths.push(path)
  }
  paths.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let schema : Map[String, Value] = Map([])
  let mixed : Array[Value] = []
  for path in paths {
    let kinds = observed[path]
    let names : Array[String] = []
    for kind, _ in kinds {
      names.push(kind)
    }
    names.sort_by(fn(a, b) { stable_string_compare(a, b) })
    if names.length() == 1 {
      schema[path] = String(names[0])
    } else {
      mixed.push(record([("path", String(path)), ("types", strings(names))]))
    }
  }
  record([
    ("schema", Object(schema)),
    ("mixed", Array(mixed)),
    ("scanned", Number(facts.length().to_double())),
  ])
}
