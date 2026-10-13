///|
/// Plain-language rule explanations.
///
/// The explain_rules operation renders each rule condition as an
/// English sentence derived from the compiled tree — comparisons read
/// naturally ("<path> must be at least <value>"), conjunctions join
/// with "and", disjunctions with "or", negations with "not", and
/// builtin calls expand to their intent (exists -> "<path> is
/// present"). Deterministic from the tree, no facts involved; a
/// reviewer can hand the output to a non-technical stakeholder.

///|
fn phrase(expr : Expression) -> String {
  match expr {
    Literal(value) => Value::stringify(value)
    Variable(path) => path
    Unary("!", operand) => "not (" + phrase(operand) + ")"
    Unary("-", operand) => "negative " + phrase(operand)
    Unary(op, operand) => op + " applied to (" + phrase(operand) + ")"
    Binary(op, left, right) => {
      let left_text = phrase(left)
      let right_text = phrase(right)
      match op {
        "&&" => "(" + left_text + ") and (" + right_text + ")"
        "||" => "(" + left_text + ") or (" + right_text + ")"
        ">" => left_text + " must be greater than " + right_text
        ">=" => left_text + " must be at least " + right_text
        "<" => left_text + " must be less than " + right_text
        "<=" => left_text + " must be at most " + right_text
        "==" => left_text + " must equal " + right_text
        "!=" => left_text + " must not equal " + right_text
        "+" => left_text + " plus " + right_text
        "-" => left_text + " minus " + right_text
        "*" => left_text + " times " + right_text
        "/" => left_text + " divided by " + right_text
        "in" => left_text + " is listed in " + right_text
        _ => left_text + " " + op + " " + right_text
      }
    }
    Call(name, args) =>
      match (name, args) {
        ("exists", [Variable(path)]) => path + " is present"
        ("len", [arg]) => "the size of (" + phrase(arg) + ")"
        ("contains", [Variable(path), item]) =>
          path + " contains " + phrase(item)
        ("lower", [arg]) => "the lowercase form of (" + phrase(arg) + ")"
        ("upper", [arg]) => "the uppercase form of (" + phrase(arg) + ")"
        ("abs", [arg]) => "the absolute value of (" + phrase(arg) + ")"
        ("floor", [arg]) => phrase(arg) + " rounded down"
        ("ceil", [arg]) => phrase(arg) + " rounded up"
        ("round", [arg]) => phrase(arg) + " rounded"
        (_, _) => name + " over its arguments"
      }
  }
}

///|
fn explain_rules_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let explanations : Array[Value] = []
  let mut index = 0
  for item in rules {
    let id = str(get(item, "id"))
    let condition = compile(str(get(item, "when")))
    let sentence = phrase(condition)
    // Capitalize the first alphabetic character (the sentence may
    // start with punctuation such as a grouping parenthesis).
    let chars = sentence.to_array()
    let mut cut = 0
    let mut upper_prefix = ""
    while cut < chars.length() {
      let piece = chars[cut].to_string()
      let upper_piece = piece.to_upper()
      if piece == upper_piece {
        // not a lowercase letter: keep scanning
        upper_prefix += piece
        cut += 1
      } else {
        upper_prefix += upper_piece
        cut += 1
        break
      }
    }
    let capitalized = upper_prefix + sentence.substring(start=cut).to_string()
    explanations.push(
      record([
        ("id", String(id)),
        ("canonical", String(condition.render())),
        ("explanation", String(capitalized + ".")),
      ]),
    )
    index += 1
  }
  ignore(index)
  record([
    ("explanations", Array(explanations)),
    (
      "rule_count",
      Number(explanations.length().to_double()),
    ),
  ])
}
