///|
/// Fact projection and extraction.
///
/// The pick operation projects a fact record onto an explicit list of
/// dotted paths, producing a nested object containing only those paths.
/// Missing paths are reported separately instead of being silently
/// dropped, and array indexing uses the standard `path.0` numeric
/// segment convention shared with the test traversal helper.

///|
fn pick_at(value : Value, parts : Array[String]) -> Value? {
  let mut current = value
  for part in parts {
    match current {
      Object(fields) =>
        match fields.get(part) {
          Some(next) => current = next
          None => return None
        }
      Array(items) => {
        let index = num(parse_value(part)).to_int() catch { _ => return None }
        if index < 0 || index >= items.length() {
          return None
        }
        current = items[index]
      }
      _ => return None
    }
  }
  Some(current)
}

///|
fn insert_at(
  target : Map[String, Value],
  parts : Array[String],
  value : Value,
) -> Unit {
  if parts.is_empty() {
    return
  }
  if parts.length() == 1 {
    target[parts[0]] = value
    return
  }
  let rest : Array[String] = []
  for i = 1; i < parts.length(); i = i + 1 {
    rest.push(parts[i])
  }
  match target.get(parts[0]) {
    Some(Object(existing)) => insert_at(existing, rest, value)
    _ => {
      let nested : Map[String, Value] = Map([])
      insert_at(nested, rest, value)
      target[parts[0]] = Object(nested)
    }
  }
}

///|
fn split_path(path : String) -> Array[String] {
  let parts : Array[String] = []
  for view in path.split(".") {
    parts.push(view.to_owned())
  }
  parts
}

///|
fn pick_request(request : Value) -> Value raise {
  let fact = get(request, "facts")
  let paths : Array[String] = []
  for item in arr(get(request, "paths")) {
    paths.push(str(item))
  }
  let unique : Map[String, Bool] = Map([])
  let picked : Map[String, Value] = Map([])
  let missing : Array[String] = []
  let order : Array[String] = []
  for path in paths {
    if unique.contains(path) {
      raise input_error("E4002", "duplicate path: " + path)
    }
    unique[path] = true
    order.push(path)
  }
  order.sort_by(fn(a, b) { stable_string_compare(a, b) })
  for path in order {
    let segments = split_path(path)
    match pick_at(fact, segments) {
      Some(value) => insert_at(picked, segments, value)
      None => missing.push(path)
    }
  }
  missing.sort_by(fn(a, b) { stable_string_compare(a, b) })
  record([
    ("picked", Object(picked)),
    ("missing", strings(missing)),
    ("requested", Number(paths.length().to_double())),
  ])
}
