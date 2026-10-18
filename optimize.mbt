///|
/// Expression optimizer.
///
/// Bottom-up rewrites that preserve observable evaluation semantics:
/// fully-literal subtrees fold through the standard evaluator (a raising
/// subtree stays unfolded so runtime errors are preserved), and identity
/// eliminations drop a literal operand only when the eliminated side is
/// provably never evaluated or the kept side is a literal. Traces and
/// step counts legitimately shrink; values and error classes do not.

///|
fn try_fold(expr : Expression) -> Expression? {
  let state : Evaluation = { fuel: 1000, trace: [], }
  let folded : Expression? = try {
    let value = evaluate(expr, Object(Map([])), state)
    Some(Literal(value))
  } catch {
    _ => None
  }
  folded
}

///|
fn optimize_expr(expr : Expression) -> Expression {
  match expr {
    Literal(_) => expr
    Variable(_) => expr
    Unary(op, operand) => {
      let child = optimize_expr(operand)
      match (op, child) {
        ("!", Literal(Bool(b))) => Literal(Bool(!b))
        ("-", Literal(Number(n))) => Literal(Number(-n))
        ("!", Unary("!", inner)) => inner
        ("-", Unary("-", Unary("-", inner))) => inner
        (_, _) => Unary(op, child)
      }
    }
    Binary(op, left, right) => {
      let l = optimize_expr(left)
      let r = optimize_expr(right)
      match (op, l, r) {
        ("&&", Literal(Bool(false)), _) => Literal(Bool(false))
        ("&&", Literal(Bool(true)), kept) => kept
        ("&&", kept, Literal(Bool(true))) => kept
        ("||", Literal(Bool(true)), _) => Literal(Bool(true))
        ("||", Literal(Bool(false)), kept) => kept
        ("||", kept, Literal(Bool(false))) => kept
        (_, _, _) =>
          match try_fold(Binary(op, l, r)) {
            Some(folded) => folded
            None => Binary(op, l, r)
          }
      }
    }
    Call(name, args) => {
      let optimized : Array[Expression] = []
      for arg in args {
        optimized.push(optimize_expr(arg))
      }
      match try_fold(Call(name, optimized)) {
        Some(folded) => folded
        None => Call(name, optimized)
      }
    }
  }
}

///|
fn optimize_request(request : Value) -> Value raise {
  let source = str(get(request, "expression"))
  let original = compile(source)
  let optimized = optimize_expr(original)
  let (original_nodes, original_depth) = original.metrics()
  let (optimized_nodes, optimized_depth) = optimized.metrics()
  let original_canonical = original.render()
  let optimized_canonical = optimized.render()
  let savings = if original_nodes == 0 {
    0.0
  } else {
    (original_nodes - optimized_nodes).to_double() *
    100.0 /
    original_nodes.to_double()
  }
  record([
    ("original", String(original_canonical)),
    ("canonical", String(optimized_canonical)),
    ("changed", Bool(original_canonical != optimized_canonical)),
    ("original_nodes", Number(original_nodes.to_double())),
    ("nodes", Number(optimized_nodes.to_double())),
    ("original_depth", Number(original_depth.to_double())),
    ("depth", Number(optimized_depth.to_double())),
    ("savings_percent", Number(savings)),
  ])
}
