///|
pub(all) enum Expression {
  Literal(Value)
  Variable(String)
  Unary(String, Expression)
  Binary(String, Expression, Expression)
  Call(String, Array[Expression])
}

///|
struct Parser {
  tokens : Array[String]
  mut position : Int
}

///|
fn identifier_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '.'
}

///|
fn tokenize(source : String) -> Array[String] raise InputError {
  if source.length() > 65536 {
    raise InputError("expression too long")
  }
  let chars = source.to_array()
  let result : Array[String] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ' ' || c == '\n' || c == '\t' || c == '\r' {
      i += 1
      continue
    }
    if c == '"' {
      let mut value = "\""
      i += 1
      let mut closed = false
      let mut escaped = false
      while i < chars.length() {
        let next = chars[i]
        value += next.to_string()
        i += 1
        if !escaped && next == '"' {
          closed = true
          break
        }
        if next == '\\' && !escaped {
          escaped = true
        } else {
          escaped = false
        }
      }
      if !closed {
        raise InputError("unterminated string")
      }
      result.push(value)
    } else if identifier_char(c) {
      let mut token = ""
      while i < chars.length() && identifier_char(chars[i]) {
        token += chars[i].to_string()
        i += 1
      }
      result.push(token)
    } else {
      let mut token = c.to_string()
      i += 1
      if i < chars.length() {
        let pair = token + chars[i].to_string()
        if ["==", "!=", ">=", "<=", "&&", "||"].contains(pair) {
          token = pair
          i += 1
        }
      }
      if ![
          "(", ")", ",", "!", "-", "+", "*", "/", "==", "!=", ">", "<", ">=", "<=",
          "&&", "||",
        ].contains(token) {
        raise InputError("unexpected token: " + token)
      }
      result.push(token)
    }
  }
  result
}

///|
fn Parser::peek(self : Parser) -> String {
  if self.position >= self.tokens.length() {
    ""
  } else {
    self.tokens[self.position]
  }
}

///|
fn Parser::take(self : Parser) -> String raise InputError {
  if self.position >= self.tokens.length() {
    raise InputError("unexpected end of expression")
  }
  let token = self.tokens[self.position]
  self.position += 1
  token
}

///|
fn precedence(op : String) -> Int {
  match op {
    "||" => 1
    "&&" => 2
    "==" | "!=" => 3
    ">" | "<" | ">=" | "<=" | "in" => 4
    "+" | "-" => 5
    "*" | "/" => 6
    _ => 0
  }
}

///|
fn Parser::expression(
  self : Parser,
  minimum : Int,
  depth : Int,
) -> Expression raise {
  if depth > 128 {
    raise InputError("expression nesting limit")
  }
  let token = self.take()
  let mut left = if token == "!" || token == "-" {
    Unary(token, self.expression(7, depth + 1))
  } else if token == "(" {
    let expr = self.expression(1, depth + 1)
    if self.take() != ")" {
      raise InputError("expected closing parenthesis")
    }
    expr
  } else if token.has_prefix("\"") ||
    token == "true" ||
    token == "false" ||
    token == "null" ||
    (token[0] >= 48 && token[0] <= 57) {
    Literal(parse_value(token))
  } else {
    if token == "" || token == ")" || token == "," || precedence(token) != 0 {
      raise InputError("expected value")
    }
    if self.peek() == "(" {
      ignore(self.take())
      let args : Array[Expression] = []
      if self.peek() != ")" {
        while true {
          args.push(self.expression(1, depth + 1))
          if self.peek() != "," {
            break
          }
          ignore(self.take())
        }
      }
      if self.take() != ")" {
        raise InputError("expected closing parenthesis")
      }
      if !["exists", "len", "contains", "lower", "abs"].contains(token) {
        raise InputError("unknown function: " + token)
      }
      Call(token, args)
    } else {
      Variable(token)
    }
  }
  while precedence(self.peek()) >= minimum && precedence(self.peek()) != 0 {
    let op = self.take()
    left = Binary(op, left, self.expression(precedence(op) + 1, depth + 1))
  }
  left
}

///|
pub fn compile(source : String) -> Expression raise {
  let parser : Parser = { tokens: tokenize(source), position: 0, }
  let expr = parser.expression(1, 0)
  if parser.peek() != "" {
    raise InputError("trailing expression token")
  }
  expr
}

///|
fn lookup(facts : Value, path : String) -> Value? {
  let mut value = facts
  for part in path.split(".") {
    match value {
      Object(fields) =>
        match fields.get(part.to_string()) {
          Some(v) => value = v
          None => return None
        }
      _ => return None
    }
  }
  Some(value)
}

///|
struct Evaluation {
  mut fuel : Int
  trace : Array[Value]
}

///|
fn boolean(value : Value) -> Bool raise InputError {
  match value {
    Bool(b) => b
    _ => raise InputError("logical operand is not boolean")
  }
}

///|
fn order(a : Value, b : Value) -> Int raise InputError {
  match (a, b) {
    (Number(x), Number(y)) => x.compare(y)
    (String(x), String(y)) => x.compare(y)
    _ => raise InputError("incompatible comparison operands")
  }
}

///|
fn evaluate(
  expr : Expression,
  facts : Value,
  state : Evaluation,
) -> Value raise {
  state.fuel -= 1
  if state.fuel < 0 {
    raise InputError("evaluation budget exceeded")
  }
  let value = match expr {
    Literal(v) => v
    Variable(path) =>
      match lookup(facts, path) {
        Some(v) => v
        None => raise InputError("missing fact: " + path)
      }
    Unary("!", operand) => Bool(!boolean(evaluate(operand, facts, state)))
    Unary("-", operand) => Number(-num(evaluate(operand, facts, state)))
    Unary(_, _) => raise InputError("unsupported unary operator")
    Binary(op, a, b) => {
      let left = evaluate(a, facts, state)
      if op == "&&" && !boolean(left) {
        Bool(false)
      } else if op == "||" && boolean(left) {
        Bool(true)
      } else {
        let right = evaluate(b, facts, state)
        match op {
          "&&" | "||" => Bool(boolean(right))
          "==" => Bool(left == right)
          "!=" => Bool(left != right)
          ">" => Bool(order(left, right) > 0)
          "<" => Bool(order(left, right) < 0)
          ">=" => Bool(order(left, right) >= 0)
          "<=" => Bool(order(left, right) <= 0)
          "in" => Bool(arr(right).contains(left))
          "+" =>
            if left is String(s) {
              String(s + str(right))
            } else {
              Number(num(left) + num(right))
            }
          "-" => Number(num(left) - num(right))
          "*" => Number(num(left) * num(right))
          "/" => {
            let denominator = num(right)
            if denominator == 0.0 {
              raise InputError("division by zero")
            }
            Number(num(left) / denominator)
          }
          _ => raise InputError("unknown operator")
        }
      }
    }
    Call("exists", [Variable(path)]) => Bool(lookup(facts, path) is Some(_))
    Call(name, args) => {
      let values = args.map(fn(arg) { evaluate(arg, facts, state) })
      match (name, values) {
        ("len", [String(s)]) => Number(s.char_length().to_double())
        ("len", [Array(a)]) => Number(a.length().to_double())
        ("len", [Object(o)]) => Number(o.length().to_double())
        ("contains", [String(s), String(part)]) => Bool(s.contains(part))
        ("contains", [Array(a), v]) => Bool(a.contains(v))
        ("lower", [String(s)]) => String(s.to_lower())
        ("abs", [Number(n)]) => Number(n.abs())
        _ => raise InputError("invalid function argument(s): " + name)
      }
    }
  }
  if value is Number(n) && (n.is_inf() || n.is_nan()) {
    raise InputError("nonfinite result")
  }
  state.trace.push(value)
  value
}

///|
pub fn evaluate_expression(
  source : String,
  facts : Value,
  budget? : Int = 10000,
) -> Value raise {
  evaluate(compile(source), facts, { fuel: budget, trace: [], })
}
