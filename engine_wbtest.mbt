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

///|
test "in operator" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"\\\"g\\\" in tags\",\"facts\":{\"tags\":[\"g\",\"s\"]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
  let miss = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"\\\"x\\\" in tags\",\"facts\":{\"tags\":[\"g\",\"s\"]}}",
    ),
  )
  assert_eq(test_at(miss, ["value"]), parse_value("false"))
}

///|
test "string concat" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"\\\"a\\\" + \\\"b\\\" == \\\"ab\\\"\",\"facts\":{}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "nonfinite result rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"1e308 * 10\",\"facts\":{}}",
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
test "unknown function rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"foo(1)\",\"facts\":{}}",
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
test "unknown operation rejected" {
  let failed = try {
    ignore(run(parse_value("{\"operation\":\"wat\"}")))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "unknown decision mode rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":{},\"mode\":\"sometimes\"}",
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
test "budget out of range rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":{},\"budget\":0}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let failed_high = try {
    ignore(
      run(
        parse_value(
          "{\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":{},\"budget\":1000001}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed_high)
}

///|
test "evaluate budget parameter" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"1 + 1\",\"facts\":{},\"budget\":100}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("2"))
  let exhausted = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"1+1+1+1+1+1+1+1+1+1+1+1+1+1\",\"facts\":{},\"budget\":10}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(exhausted)
}

///|
test "missing fact becomes per-record error" {
  let result = run(
    parse_value(
      "{\"rules\":[{\"id\":\"r\",\"when\":\"amount > 5\",\"output\":\"hit\"}],\"facts\":[{\"amount\":10},{}]}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"hit\""),
  )
  match test_at(result, ["results", "1"]) {
    Object(fields) => assert_true(fields.contains("error"))
    _ => assert_true(false)
  }
}

///|
test "conflict ids reported" {
  let result = run(
    parse_value(
      "{\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{\"age\":20},\"mode\":\"unique\"}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "conflict_ids"]),
    parse_value("[\"adult\",\"fallback\"]"),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("null"),
  )
}

///|
test "check valid expression" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"amount > 5 && name == \\\"x\\\"\",\"schema\":{\"amount\":\"number\",\"name\":\"string\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(test_at(result, ["type"]), parse_value("\"boolean\""))
}

///|
test "check expression type error" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"amount > \\\"x\\\"\",\"schema\":{\"amount\":\"number\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
}

///|
test "check expression compile error" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"amount >\",\"schema\":{\"amount\":\"number\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
}

///|
test "check valid rules" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"}],\"schema\":{\"age\":\"number\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(
    test_at(result, ["rules", "0", "condition_type"]),
    parse_value("\"boolean\""),
  )
}

///|
test "check rules issues" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"rules\":[{\"id\":\"a\",\"when\":\"age >= 18\",\"output\":\"x\"},{\"id\":\"a\",\"when\":\"true\",\"output\":\"y\"},{\"id\":\"b\",\"when\":\"count\",\"output\":\"z\"}],\"schema\":{\"age\":\"number\",\"count\":\"string\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(
    test_at(result, ["rules", "1", "valid"]),
    parse_value("false"),
  )
  assert_eq(
    test_at(result, ["rules", "2", "valid"]),
    parse_value("false"),
  )
}

///|
test "check rule without output rejected" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"rules\":[{\"id\":\"a\",\"when\":\"true\"}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
}

///|
test "check exists and len types" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"exists(user.age) && len(items) > 0\",\"schema\":{\"user.age\":\"number\",\"items\":\"array\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(test_at(result, ["type"]), parse_value("\"boolean\""))
}

///|
test "check string concat type mismatch" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"\\\"a\\\" + 1\",\"schema\":{}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
}



///|
test "upper function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"upper(name) == \\\"BOB\\\"\",\"facts\":{\"name\":\"Bob\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "upper requires string" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"upper(age)\",\"facts\":{\"age\":3}}",
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
test "trim function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"trim(code) == \\\"AB\\\"\",\"facts\":{\"code\":\" AB \"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "trim requires string" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"trim(flag)\",\"facts\":{\"flag\":true}}",
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
test "starts_with and ends_with" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"starts_with(code, \\\"PRE\\\") && ends_with(code, \\\"SUF\\\")\",\"facts\":{\"code\":\"PRE-SUF\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
  let negative = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"ends_with(code, \\\"PRE\\\")\",\"facts\":{\"code\":\"PRE-SUF\"}}",
    ),
  )
  assert_eq(test_at(negative, ["value"]), parse_value("false"))
}

///|
test "starts_with requires string arguments" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"starts_with(code, 1)\",\"facts\":{\"code\":\"PRE\"}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
