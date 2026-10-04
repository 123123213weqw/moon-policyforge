///|
/// Canonical rendering and structural metrics for compiled expressions.
///
/// The renderer reproduces an expression as a canonical string: minimal
/// parentheses derived from operator precedence, single spaces around binary
/// operators, and JSON-quoted literals. Re-compiling a rendered expression
/// yields an equivalent tree, which enables round-trip guarantees.

///|
fn Expression::precedence_of(self : Expression) -> Int {
  match self {
    Literal(_) | Variable(_) | Call(_, _) => 100
    Unary(_, _) => 7
    Binary(op, _, _) => precedence(op)
  }
}

///|
fn render_scalar(value : Value) -> String {
  match value {
    Null => "null"
    Bool(true) => "true"
    Bool(false) => "false"
    Number(n) => Json::number(n).stringify()
    String(s) => Json::string(s).stringify()
    other => other.stringify()
  }
}

///|
fn Expression::render_prec(self : Expression, minimum : Int) -> String {
  let text = self.render()
  if self.precedence_of() < minimum {
    "(" + text + ")"
  } else {
    text
  }
}

///|
fn Expression::render(self : Expression) -> String {
  match self {
    Literal(value) => render_scalar(value)
    Variable(path) => path
    Unary(op, operand) =>
      if op == "-" {
        "-" + operand.render_prec(7)
      } else {
        op + operand.render_prec(8)
      }
    Binary(op, left, right) => {
      let level = precedence(op)
      left.render_prec(level) + " " + op + " " + right.render_prec(level + 1)
    }
    Call(name, args) => {
      let parts : Array[String] = []
      for arg in args {
        parts.push(arg.render())
      }
      name + "(" + parts.join(", ") + ")"
    }
  }
}

///|
/// Structural metrics: total node count and maximum nesting depth.
fn Expression::metrics(self : Expression) -> (Int, Int) {
  match self {
    Literal(_) | Variable(_) => (1, 1)
    Unary(_, operand) => {
      let (nodes, depth) = operand.metrics()
      (nodes + 1, depth + 1)
    }
    Binary(_, left, right) => {
      let (ln, ld) = left.metrics()
      let (rn, rd) = right.metrics()
      let deeper = if ld > rd { ld } else { rd }
      (ln + rn + 1, deeper + 1)
    }
    Call(_, args) => {
      let mut nodes = 1
      let mut depth = 0
      for arg in args {
        let (n, d) = arg.metrics()
        nodes = nodes + n
        if d > depth {
          depth = d
        }
      }
      (nodes, depth + 1)
    }
  }
}

///|
/// Full leaf-to-root description of an expression tree for diagnostics.
fn Expression::describe(self : Expression, lines : Array[String]) -> Unit {
  let prefix = lines.length().to_string()
  match self {
    Literal(value) => lines.push(prefix + " literal " + render_scalar(value))
    Variable(path) => lines.push(prefix + " variable " + path)
    Unary(op, operand) => {
      lines.push(prefix + " unary " + op)
      operand.describe(lines)
    }
    Binary(op, left, right) => {
      lines.push(prefix + " binary " + op)
      left.describe(lines)
      right.describe(lines)
    }
    Call(name, args) => {
      lines.push(prefix + " call " + name + "/" + args.length().to_string())
      for arg in args {
        arg.describe(lines)
      }
    }
  }
}

///|
fn serialize_request(request : Value) -> Value raise {
  let expr = compile(str(get(request, "expression")))
  let (nodes, depth) = expr.metrics()
  let lines : Array[String] = []
  expr.describe(lines)
  let tree : Array[Value] = lines.map(fn(line) { String(line) })
  record([
    ("canonical", String(expr.render())),
    ("nodes", Number(nodes.to_double())),
    ("depth", Number(depth.to_double())),
    ("tree", Array(tree)),
  ])
}

///|
/// Re-compiles a canonical rendering and verifies behavioral equivalence
/// against the original expression over the supplied sample facts.
fn roundtrip_request(request : Value) -> Value raise {
  let source = str(get(request, "expression"))
  let facts = get(request, "facts")
  let budget = optional_num(get(request, "budget"), 10000.0).to_int()
  if budget <= 0 || budget > 1000000 {
    raise InputError("budget out of range")
  }
  let original = compile(source)
  let rendered = original.render()
  let reparsed = compile(rendered)
  let state_a : Evaluation = { fuel: budget, trace: [], }
  let state_b : Evaluation = { fuel: budget, trace: [], }
  let first = evaluate(original, facts, state_a)
  let second = evaluate(reparsed, facts, state_b)
  let same = first == second
  let (nodes, depth) = original.metrics()
  record([
    ("equivalent", Bool(same)),
    ("value", first),
    ("canonical", String(rendered)),
    ("nodes", Number(nodes.to_double())),
    ("depth", Number(depth.to_double())),
  ])
}
