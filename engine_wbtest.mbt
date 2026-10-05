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


///|
test "replace function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"replace(code, \\\"-\\\", \\\"_\\\") == \\\"A_B\\\"\",\"facts\":{\"code\":\"A-B\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "replace requires three strings" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"replace(code, \\\"-\\\", 1)\",\"facts\":{\"code\":\"A-B\"}}",
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
test "substring function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"substring(code, 1, 3)\",\"facts\":{\"code\":\"ABCDE\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("\"BC\""))
}

///|
test "substring out of bounds" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"substring(code, 4, 9)\",\"facts\":{\"code\":\"AB\"}}",
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
test "floor and ceil" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"floor(price) == 3 && ceil(price) == 4\",\"facts\":{\"price\":3.2}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "floor requires number" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"floor(name)\",\"facts\":{\"name\":\"x\"}}",
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
test "round function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"round(score) == 3\",\"facts\":{\"score\":2.6}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "round requires number" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"round(name)\",\"facts\":{\"name\":\"x\"}}",
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
test "min and max" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"min(a, b) == 2 && max(a, b) == 5\",\"facts\":{\"a\":5,\"b\":2}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "max requires numbers" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"max(a, b)\",\"facts\":{\"a\":1,\"b\":\"x\"}}",
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
test "sum array" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"sum(prices) == 6\",\"facts\":{\"prices\":[1.5,2.5,2]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "sum requires numeric elements" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"sum(prices)\",\"facts\":{\"prices\":[1,\"x\"]}}",
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
test "concat array" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"concat(parts) == \\\"abc\\\"\",\"facts\":{\"parts\":[\"a\",\"b\",\"c\"]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "concat requires string elements" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"concat(parts)\",\"facts\":{\"parts\":[\"a\",1]}}",
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
test "serialize canonical form and metrics" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"  1+2*3  \"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"1 + 2 * 3\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("5"))
  assert_eq(test_at(result, ["depth"]), parse_value("3"))
}

///|
test "serialize preserves explicit grouping" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"(1 + 2) * 3\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"(1 + 2) * 3\""))
}

///|
test "serialize drops redundant parentheses" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"(a) + (b * c)\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"a + b * c\""))
}

///|
test "serialize logical precedence" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"a || b && c || !d\"}",
    ),
  )
  assert_eq(
    test_at(result, ["canonical"]),
    parse_value("\"a || b && c || !d\""),
  )
  let grouped = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"(a || b) && c\"}",
    ),
  )
  assert_eq(
    test_at(grouped, ["canonical"]),
    parse_value("\"(a || b) && c\""),
  )
}

///|
test "serialize string and null literals" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"name == \\\"a b\\\" && extra != null\"}",
    ),
  )
  assert_eq(
    test_at(result, ["canonical"]),
    parse_value("\"name == \\\"a b\\\" && extra != null\""),
  )
}

///|
test "serialize calls and unary chain" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"len(name) >= 3 && lower(tag) == \\\"x\\\" && -n < 0\"}",
    ),
  )
  assert_eq(
    test_at(result, ["canonical"]),
    parse_value("\"len(name) >= 3 && lower(tag) == \\\"x\\\" && -n < 0\""),
  )
}

///|
test "serialize tree description" {
  let result = run(
    parse_value(
      "{\"operation\":\"serialize\",\"expression\":\"a + b * 2\"}",
    ),
  )
  match test_at(result, ["tree"]) {
    Array(lines) => assert_eq(lines.length(), 5)
    _ => assert_true(false)
  }
}

///|
test "roundtrip equivalence over facts" {
  let result = run(
    parse_value(
      "{\"operation\":\"roundtrip\",\"expression\":\"(price - discount) * quantity >= 100 && tier == \\\"gold\\\"\",\"facts\":{\"price\":50,\"discount\":10,\"quantity\":3,\"tier\":\"gold\"}}",
    ),
  )
  assert_eq(test_at(result, ["equivalent"]), parse_value("true"))
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "roundtrip evaluates same as original" {
  let result = run(
    parse_value(
      "{\"operation\":\"roundtrip\",\"expression\":\"sum(items) / count > avg_floor\",\"facts\":{\"items\":[2,4,6],\"count\":3,\"avg_floor\":3.9}}",
    ),
  )
  assert_eq(test_at(result, ["equivalent"]), parse_value("true"))
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "roundtrip rejects bad budget" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"roundtrip\",\"expression\":\"1\",\"facts\":{},\"budget\":-3}",
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
test "aggregate sum avg min max by tier" {
  let result = run(
    parse_value(
      "{\"operation\":\"aggregate\",\"facts\":[{\"tier\":\"g\",\"amount\":10},{\"tier\":\"s\",\"amount\":1},{\"tier\":\"g\",\"amount\":20},{\"tier\":\"s\",\"amount\":3}],\"key\":\"tier\",\"metrics\":[{\"name\":\"n\",\"op\":\"count\"},{\"name\":\"total\",\"op\":\"sum\",\"expression\":\"amount\"},{\"name\":\"avg\",\"op\":\"avg\",\"expression\":\"amount\"},{\"name\":\"lo\",\"op\":\"min\",\"expression\":\"amount\"},{\"name\":\"hi\",\"op\":\"max\",\"expression\":\"amount\"}]}",
    ),
  )
  assert_eq(test_at(result, ["group_count"]), parse_value("2"))
  assert_eq(
    test_at(result, ["groups", "0", "key"]),
    parse_value("\"g\""),
  )
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "total"]),
    parse_value("30"),
  )
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "avg"]),
    parse_value("15"),
  )
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "hi"]),
    parse_value("20"),
  )
  assert_eq(
    test_at(result, ["groups", "1", "metrics", "lo"]),
    parse_value("1"),
  )
  assert_eq(test_at(result, ["records"]), parse_value("4"))
}

///|
test "aggregate numeric keys sorted canonically" {
  let result = run(
    parse_value(
      "{\"operation\":\"aggregate\",\"facts\":[{\"band\":20},{\"band\":3},{\"band\":20}],\"key\":\"band\",\"metrics\":[{\"name\":\"n\",\"op\":\"count\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["groups", "0", "key"]),
    parse_value("3"),
  )
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "n"]),
    parse_value("1"),
  )
  assert_eq(
    test_at(result, ["groups", "1", "metrics", "n"]),
    parse_value("2"),
  )
}

///|
test "aggregate computed key expression" {
  let result = run(
    parse_value(
      "{\"operation\":\"aggregate\",\"facts\":[{\"amount\":50},{\"amount\":500},{\"amount\":900}],\"key\":\"amount >= 500\",\"metrics\":[{\"name\":\"n\",\"op\":\"count\"}]}",
    ),
  )
  assert_eq(test_at(result, ["group_count"]), parse_value("2"))
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "n"]),
    parse_value("1"),
  )
  assert_eq(
    test_at(result, ["groups", "1", "metrics", "n"]),
    parse_value("2"),
  )
}

///|
test "aggregate tolerates per-record errors" {
  let result = run(
    parse_value(
      "{\"operation\":\"aggregate\",\"facts\":[{\"amount\":5},{}, {\"amount\":7}],\"key\":\"exists(amount)\",\"metrics\":[{\"name\":\"total\",\"op\":\"sum\",\"expression\":\"amount\"}]}",
    ),
  )
  assert_eq(test_at(result, ["record_errors"]), parse_value("1"))
  assert_eq(test_at(result, ["group_count"]), parse_value("2"))
  assert_eq(test_at(result, ["groups", "0", "key"]), parse_value("false"))
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "total"]),
    parse_value("null"),
  )
  assert_eq(test_at(result, ["groups", "1", "key"]), parse_value("true"))
  assert_eq(
    test_at(result, ["groups", "1", "metrics", "total"]),
    parse_value("12"),
  )
}

///|
test "aggregate duplicate metric rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"aggregate\",\"facts\":[],\"key\":\"1\",\"metrics\":[{\"name\":\"a\",\"op\":\"count\"},{\"name\":\"a\",\"op\":\"count\"}]}",
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
test "aggregate unknown op rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"aggregate\",\"facts\":[],\"key\":\"1\",\"metrics\":[{\"name\":\"a\",\"op\":\"median\",\"expression\":\"1\"}]}",
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
test "aggregate count with expression rejected" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"aggregate\",\"facts\":[],\"key\":\"1\",\"metrics\":[{\"name\":\"a\",\"op\":\"count\",\"expression\":\"1\"}]}",
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
test "aggregate budget validated" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"aggregate\",\"facts\":[],\"key\":\"1\",\"metrics\":[],\"budget\":99999999}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
