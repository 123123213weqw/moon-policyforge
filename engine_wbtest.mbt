///|
fn test_at(value : Value, parts : Array[String]) -> Value raise {
  let mut current = value
  for part in parts {
    current = match current {
      Object(fields) =>
        match fields.get(part) {
          Some(v) => v
          None => raise InputError("test key missing: " + part)
        }
      Array(items) => items[num(parse_value(part)).to_int()]
      _ => raise InputError("invalid test traversal")
    }
  }
  current
}

///|
test "arithmetic precedence" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"1 + 2 * 3 == 7 && true\",\"facts\":{}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "short circuit" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"false && (1 / 0 > 1)\",\"facts\":{}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("false"))
}

///|
test "missing exists" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"exists(user.age)\",\"facts\":{}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("false"))
}

///|
test "priority first" {
  let result = run(
    parse_value(
      "{\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{\"age\":20}}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"adult\""),
  )
}

///|
test "unique conflict" {
  let result = run(
    parse_value(
      "{\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{\"age\":20},\"mode\":\"unique\"}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "conflict"]),
    parse_value("true"),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("null"),
  )
}

///|
test "all matches" {
  let result = run(
    parse_value(
      "{\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{\"age\":20},\"mode\":\"all\"}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("[\"adult\",\"other\"]"),
  )
}

///|
test "division zero" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"1 / 0\",\"facts\":{}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "strict boolean" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"1 && true\",\"facts\":{}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "duplicate rules" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"}],\"facts\":{}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
