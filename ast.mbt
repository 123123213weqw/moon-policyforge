///|
/// Expression AST as JSON.
///
/// The ast operation converts between expression source and an explicit
/// JSON tree: `{"kind": "binary", "op": "+", "left": ..., "right": ...}`
/// with literal leaves carrying their value and call nodes carrying
/// their argument list. The `parse` direction accepts such a tree and
/// compiles it back to an expression, rejecting unknown kinds and
/// malformed nodes with coded errors. This is the stable interchange
/// format for external tooling: nothing else in the API exposes tree
/// structure as data.

///|
fn Expression::to_ast(self : Expression) -> Value {
  match self {
    Literal(value) =>
      record([("kind", String("literal")), ("value", value)])
    Variable(path) =>
      record([("kind", String("variable")), ("path", String(path))])
    Unary(op, operand) =>
      record([
        ("kind", String("unary")),
        ("op", String(op)),
        ("operand", operand.to_ast()),
      ])
    Binary(op, left, right) =>
      record([
        ("kind", String("binary")),
        ("op", String(op)),
        ("left", left.to_ast()),
        ("right", right.to_ast()),
      ])
    Call(name, args) =>
      record([
        ("kind", String("call")),
        ("name", String(name)),
        ("args", Array(args.map(fn(arg) { arg.to_ast() }))),
      ])
  }
}

///|
fn Expression::from_ast(value : Value) -> Expression raise {
  let kind = str(get(value, "kind"))
  match kind {
    "literal" => {
      let literal = get(value, "value")
      if literal is Null {
        raise input_error("E3001", "literal node needs a value")
      }
      Literal(literal)
    }
    "variable" => Variable(str(get(value, "path")))
    "unary" => {
      let op = str(get(value, "op"))
      if op != "!" && op != "-" {
        raise input_error("E2004", "unsupported unary operator: " + op)
      }
      Unary(op, Expression::from_ast(get(value, "operand")))
    }
    "binary" => {
      let op = str(get(value, "op"))
      if precedence(op) == 0 {
        raise input_error("E2005", "unknown operator: " + op)
      }
      Binary(
        op,
        Expression::from_ast(get(value, "left")),
        Expression::from_ast(get(value, "right")),
      )
    }
    "call" => {
      let name = str(get(value, "name"))
      let allowed = [
        "exists", "len", "contains", "lower", "upper", "trim",
        "starts_with", "ends_with", "replace", "substring", "abs",
        "floor", "ceil", "round", "min", "max", "sum", "concat",
        "count_matches", "any_match", "all_match",
      ]
      if !allowed.contains(name) {
        raise input_error("E1008", "unknown function: " + name)
      }
      let args : Array[Expression] = []
      for item in arr(get(value, "args")) {
        args.push(Expression::from_ast(item))
      }
      Call(name, args)
    }
    other => raise input_error("E3009", "unknown node kind: " + other)
  }
}

///|
fn ast_request(request : Value) -> Value raise {
  match get(request, "expression") {
    Null => ()
    source => {
      let expr = compile(str(source))
      return record([("ast", expr.to_ast()), ("canonical", String(expr.render()))])
    }
  }
  let tree = get(request, "ast")
  if tree is Null {
    raise input_error("E3001", "ast operation needs expression or ast")
  }
  let expr = Expression::from_ast(tree)
  let rendered = expr.render()
  ignore(compile(rendered))
  let (nodes, depth) = expr.metrics()
  record([
    ("canonical", String(rendered)),
    ("nodes", Number(nodes.to_double())),
    ("depth", Number(depth.to_double())),
  ])
}
