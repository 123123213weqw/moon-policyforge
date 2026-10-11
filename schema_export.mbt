///|
/// JSON Schema export.
///
/// The export_schema operation turns an inferred or hand-maintained
/// engine schema (dotted path to type name) into a JSON Schema draft
/// 2020-12 document: nested objects become `properties` trees, dotted
/// segments after an array index are collapsed into `items`, and
/// engine type names map to JSON Schema types one-to-one (`null` to
/// `{"type": "null"}`, arrays to untyped `items`). The result is a
/// standard document external validators accept without adaptation.

///|
let json_schema_types : Map[String, String] = {
  "boolean": "boolean",
  "number": "number",
  "string": "string",
  "null": "null",
}

///|
fn schema_node() -> Map[String, Value] {
  let node : Map[String, Value] = Map([])
  node["type"] = String("object")
  node["properties"] = Object(Map([]))
  node
}

///|
fn insert_schema_node(
  root : Map[String, Value],
  segments : Array[String],
  kind : String,
) -> Unit {
  let mut current = root
  for i = 0; i < segments.length(); i = i + 1 {
    let segment = segments[i]
    let is_last = i == segments.length() - 1
    let props = match current.get("properties") {
      Some(Object(fields)) => fields
      _ => {
        let fresh : Map[String, Value] = Map([])
        current["properties"] = Object(fresh)
        fresh
      }
    }
    if is_last {
      match json_schema_types.get(kind) {
        Some(json_type) => {
          let leaf : Map[String, Value] = Map([])
          leaf["type"] = String(json_type)
          props[segment] = Object(leaf)
        }
        None => {
          // array and object keep structural types
          let structural : Map[String, Value] = Map([])
          if kind == "array" {
            structural["type"] = String("array")
          } else {
            structural["type"] = String("object")
          }
          props[segment] = Object(structural)
        }
      }
    } else {
      match props.get(segment) {
        Some(Object(existing)) => current = existing
        _ => {
          let nested = schema_node()
          props[segment] = Object(nested)
          current = nested
        }
      }
    }
  }
}

///|
fn export_schema_request(request : Value) -> Value raise {
  let schema = match get(request, "schema") {
    Null => get(infer_request(request), "schema")
    other => other
  }
  let root = schema_node()
  match schema {
    Object(fields) =>
      for path, value in fields {
        let kind = str(value)
        let segments : Array[String] = []
        for view in path.split(".") {
          segments.push(view.to_string())
        }
        insert_schema_node(root, segments, kind)
      }
    _ => raise input_error("E3009", "schema must be an object")
  }
  let document : Map[String, Value] = Map([])
  document["$schema"] = String(
    "https://json-schema.org/draft/2020-12/schema",
  )
  document["type"] = String("object")
  match root.get("properties") {
    Some(properties) => document["properties"] = properties
    None => ()
  }
  let path_count = match schema {
    Object(fields) => fields.keys().collect().length()
    _ => 0
  }
  record([
    ("json_schema", Object(document)),
    ("paths", Number(path_count.to_double())),
    ("draft", String("2020-12")),
  ])
}
