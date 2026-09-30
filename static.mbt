///|
/// Optional static checker for expressions and rule sets.
///
/// The checker mirrors runtime semantics exactly: it only reports what the
/// evaluator would reject. Fact paths absent from an optional caller-supplied
/// schema are "unknown" and defer to runtime, so a schema-less check still
/// catches structural errors (unknown functions, malformed rules) without
/// claiming full type inference.
priv struct CheckState {
  schema : Map[String, String]
  errors : Array[String]
}

///|
fn type_name(value : Value) -> String {
  match value {
    Null => "null"
    Bool(_) => "boolean"
    Number(_) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
let known_types : Array[String] = [
  "boolean", "number", "string", "null", "array", "object",
]

///|
fn CheckState::fail(self : CheckState, message : String) -> Unit {
  self.errors.push(message)
}

///|
fn CheckState::require(
  self : CheckState,
  actual : String,
  expected : String,
  context : String,
) -> Bool {
  if actual == "unknown" || actual == expected {
    true
  } else {
    self.fail(
      context +
      " expects " +
      expected +
      " but inferred " +
      actual,
    )
    false
  }
}

///|
fn CheckState::infer(self : CheckState, expr : Expression) -> String {
  match expr {
    Literal(value) => type_name(value)
    Variable(path) =>
      match self.schema.get(path) {
        Some(kind) => kind
        None => "unknown"
      }
    Unary(op, operand) => {
      let inner = self.infer(operand)
      match op {
        "!" => {
          ignore(self.require(inner, "boolean", "operator !"))
          "boolean"
        }
        "-" => {
          ignore(self.require(inner, "number", "unary -"))
          "number"
        }
        _ => {
          self.fail("unsupported unary operator: " + op)
          "unknown"
        }
      }
    }
    Binary(op, left, right) => {
      let lt = self.infer(left)
      let rt = self.infer(right)
      match op {
        "&&" | "||" => {
          ignore(self.require(lt, "boolean", "logical operand"))
          ignore(self.require(rt, "boolean", "logical operand"))
          "boolean"
        }
        "==" | "!=" => "boolean"
        ">" | "<" | ">=" | "<=" => {
          if lt == "unknown" || rt == "unknown" {
            "boolean"
          } else if lt == rt && (lt == "number" || lt == "string") {
            "boolean"
          } else {
            self.fail(
              "comparison expects two numbers or two strings but inferred " +
              lt +
              " and " +
              rt,
            )
            "unknown"
          }
        }
        "in" => {
          ignore(self.require(rt, "array", "right operand of in"))
          "boolean"
        }
        "+" => {
          if lt == "string" {
            if self.require(rt, "string", "string concatenation") {
              "string"
            } else {
              "unknown"
            }
          } else if lt == "number" {
            if self.require(rt, "number", "arithmetic +") {
              "number"
            } else {
              "unknown"
            }
          } else if lt == "unknown" {
            "unknown"
          } else {
            self.fail("operator + expects number or string but inferred " + lt)
            "unknown"
          }
        }
        "-" | "*" | "/" => {
          ignore(self.require(lt, "number", "arithmetic " + op))
          ignore(self.require(rt, "number", "arithmetic " + op))
          "number"
        }
        _ => {
          self.fail("unknown operator: " + op)
          "unknown"
        }
      }
    }
    Call(name, args) => {
      let kinds = args.map(fn(arg) { self.infer(arg) })
      match (name, args.length()) {
        ("exists", 1) =>
          if args[0] is Variable(_) {
            "boolean"
          } else {
            self.fail("exists requires a fact path argument")
            "unknown"
          }
        ("len", 1) => {
          let kind = kinds[0]
          if kind == "unknown" ||
            kind == "string" ||
            kind == "array" ||
            kind == "object" {
            "number"
          } else {
            self.fail("len expects string, array or object but inferred " + kind)
            "unknown"
          }
        }
        ("contains", 2) => {
          let kind = kinds[0]
          if kind == "unknown" {
            "boolean"
          } else if kind == "string" {
            if self.require(kinds[1], "string", "contains on a string") {
              "boolean"
            } else {
              "unknown"
            }
          } else if kind == "array" {
            "boolean"
          } else {
            self.fail(
              "contains expects string or array but inferred " + kind,
            )
            "unknown"
          }
        }
        ("lower", 1) => {
          ignore(self.require(kinds[0], "string", "lower"))
          "string"
        }
        ("upper", 1) => {
          ignore(self.require(kinds[0], "string", "upper"))
          "string"
        }
        ("trim", 1) => {
          ignore(self.require(kinds[0], "string", "trim"))
          "string"
        }
        ("starts_with", 2) => {
          ignore(self.require(kinds[0], "string", "starts_with"))
          ignore(self.require(kinds[1], "string", "starts_with"))
          "boolean"
        }
        ("ends_with", 2) => {
          ignore(self.require(kinds[0], "string", "ends_with"))
          ignore(self.require(kinds[1], "string", "ends_with"))
          "boolean"
        }
        ("abs", 1) => {
          ignore(self.require(kinds[0], "number", "abs"))
          "number"
        }
        (_, _) => {
          self.fail("unknown function or wrong arity: " + name)
          "unknown"
        }
      }
    }
  }
}

///|
fn compile_checked(
  state : CheckState,
  source : String,
  role : String,
) -> Expression? {
  let parsed : Expression? = try {
    Some(compile(source))
  } catch {
    error => {
      state.fail(role + " does not compile: " + error.to_string())
      None
    }
  }
  parsed
}

///|
fn check_request(request : Value) -> Value raise {
  let schema : Map[String, String] = Map([])
  match get(request, "schema") {
    Null => ()
    Object(fields) =>
      for key, value in fields {
        let kind = str(value)
        if !known_types.contains(kind) {
          raise InputError("unknown schema type for " + key + ": " + kind)
        }
        schema[key] = kind
      }
    _ => raise InputError("schema must be an object")
  }
  match get(request, "expression") {
    Null => ()
    source => {
      let state : CheckState = { schema, errors: [] }
      let inferred = match compile_checked(state, str(source), "expression") {
        Some(expr) => state.infer(expr)
        None => "unknown"
      }
      return record([
        ("ok", Bool(state.errors.is_empty())),
        ("type", String(inferred)),
        ("errors", strings(state.errors)),
      ])
    }
  }
  let report : Array[Value] = []
  let ids : Map[String, Bool] = Map([])
  let mut ok = true
  for item in arr(get(request, "rules")) {
    let errors : Array[String] = []
    let state : CheckState = { schema, errors, }
    let id = match get(item, "id") {
      String(name) => name
      _ => {
        state.fail("missing or invalid rule ID")
        ""
      }
    }
    if id != "" {
      if ids.contains(id) {
        state.fail("duplicate rule ID: " + id)
      }
      ids[id] = true
    }
    match get(item, "priority") {
      Null => ()
      Number(n) =>
        if n.is_nan() || n.is_inf() {
          state.fail("priority must be a finite number")
        }
      _ => state.fail("priority must be a number")
    }
    let mut condition_type = "unknown"
    match get(item, "when") {
      Null => state.fail("missing condition")
      String(source) =>
        match compile_checked(state, source, "condition") {
          Some(expr) => {
            condition_type = state.infer(expr)
            if condition_type != "boolean" && condition_type != "unknown" {
              state.fail(
                "condition must be boolean but inferred " + condition_type,
              )
            }
          }
          None => ()
        }
      _ => state.fail("condition must be a string")
    }
    match get(item, "compute") {
      Null =>
        if get(item, "output") is Null {
          state.fail("rule needs an output value or a compute expression")
        }
      String(source) => {
        ignore(compile_checked(state, source, "compute"))
      }
      _ => state.fail("compute must be a string")
    }
    if errors.is_empty() {
      ok = ok && true
    } else {
      ok = false
    }
    report.push(
      record([
        ("id", String(id)),
        ("valid", Bool(errors.is_empty())),
        ("condition_type", String(condition_type)),
        ("errors", strings(errors)),
      ]),
    )
  }
  record([("ok", Bool(ok)), ("rules", Array(report))])
}
