///|
/// Fact validation against an engine schema.
///
/// The validate operation checks real fact records against the same
/// dotted-path schema the check operation uses for rules: each typed
/// path present in a record must carry the declared type, and paths
/// listed under `required` must exist. Absent unrequired paths are
/// fine — check defers them to runtime, and validate treats them as
/// optional. Errors carry the path, the expected type and the found
/// type (or `missing`), per record, with the batch never aborting.

///|
fn validate_record(
  fact : Value,
  schema : Map[String, String],
  required : Map[String, Bool],
) -> Array[Value] {
  let errors : Array[Value] = []
  let paths : Array[String] = []
  for path, _ in schema {
    paths.push(path)
  }
  for path, _ in required {
    if !schema.contains(path) {
      paths.push(path)
    }
  }
  paths.sort_by(fn(a, b) { stable_string_compare(a, b) })
  for path in paths {
    let found = pick_at(fact, split_path(path))
    match found {
      None =>
        if required.contains(path) {
          errors.push(
            record([
              ("path", String(path)),
              ("expected", String(schema.get(path).unwrap_or("value"))),
              ("found", String("missing")),
              ("error", String("missing required path")),
            ]),
          )
        }
      Some(value) =>
        match schema.get(path) {
          Some(expected) =>
            if type_name(value) != expected {
              errors.push(
                record([
                  ("path", String(path)),
                  ("expected", String(expected)),
                  ("found", String(type_name(value))),
                  ("error", String("type mismatch")),
                ]),
              )
            }
          None => ()
        }
    }
  }
  errors
}

///|
fn validate_request(request : Value) -> Value raise {
  let schema : Map[String, String] = Map([])
  match get(request, "schema") {
    Null => ()
    Object(fields) =>
      for key, value in fields {
        let kind = str(value)
        if !known_types.contains(kind) {
          raise input_error("E3008", "unknown schema type for " + key + ": " + kind)
        }
        schema[key] = kind
      }
    _ => raise input_error("E3009", "schema must be an object")
  }
  let required : Map[String, Bool] = Map([])
  match get(request, "required") {
    Null => ()
    listed =>
      for item in arr(listed) {
        let path = str(item)
        required[path] = true
      }
  }
  let facts = match get(request, "facts") {
    Array(items) => items
    other => [other]
  }
  let results : Array[Value] = []
  let mut error_records = 0
  let mut error_count = 0
  for i = 0; i < facts.length(); i = i + 1 {
    let errors = validate_record(facts[i], schema, required)
    let ok = errors.is_empty()
    if !ok {
      error_records += 1
      error_count += errors.length()
    }
    results.push(
      record([
        ("index", Number(i.to_double())),
        ("ok", Bool(ok)),
        ("errors", Array(errors)),
      ]),
    )
  }
  record([
    ("results", Array(results)),
    ("records", Number(facts.length().to_double())),
    ("error_records", Number(error_records.to_double())),
    ("error_count", Number(error_count.to_double())),
  ])
}
