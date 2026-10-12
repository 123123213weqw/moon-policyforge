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


///|
test "infer nested schema types" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"user\":{\"age\":30,\"name\":\"bob\"},\"active\":true,\"tags\":[\"a\"],\"score\":1.5}]}",
    ),
  )
  assert_eq(
    test_at(result, ["schema", "user.age"]),
    parse_value("\"number\""),
  )
  assert_eq(
    test_at(result, ["schema", "user.name"]),
    parse_value("\"string\""),
  )
  assert_eq(
    test_at(result, ["schema", "active"]),
    parse_value("\"boolean\""),
  )
  assert_eq(
    test_at(result, ["schema", "tags"]),
    parse_value("\"array\""),
  )
  assert_eq(test_at(result, ["mixed"]), parse_value("[]"))
  assert_eq(test_at(result, ["scanned"]), parse_value("1"))
}

///|
test "infer reports mixed types separately" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"value\":1},{\"value\":\"x\"},{\"value\":true}]}",
    ),
  )
  match test_at(result, ["schema"]) {
    Object(fields) => assert_true(!fields.contains("value"))
    _ => assert_true(false)
  }
  match test_at(result, ["mixed"]) {
    Array(items) => {
      assert_eq(items.length(), 1)
      match items[0] {
        Object(fields) =>
          match fields.get("types") {
            Some(Array(types)) => assert_eq(types.length(), 3)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "infer paths sorted deterministically" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"z\":1,\"a\":{\"y\":2,\"b\":3}}]}",
    ),
  )
  match test_at(result, ["schema"]) {
    Object(fields) => {
      let keys : Array[String] = []
      for key, _ in fields {
        keys.push(key)
      }
      assert_eq(keys.length(), 4)
      assert_eq(keys[0], "a")
      assert_eq(keys[1], "a.b")
      assert_eq(keys[2], "a.y")
      assert_eq(keys[3], "z")
    }
    _ => assert_true(false)
  }
}

///|
test "infer null and nested arrays" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"extra\":null,\"matrix\":[[1],[2]]}]}",
    ),
  )
  assert_eq(
    test_at(result, ["schema", "extra"]),
    parse_value("\"null\""),
  )
  assert_eq(
    test_at(result, ["schema", "matrix"]),
    parse_value("\"array\""),
  )
}

///|
test "infer union of paths across records" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"a\":1},{\"b\":2},{\"a\":3,\"b\":4}]}",
    ),
  )
  assert_eq(
    test_at(result, ["schema", "a"]),
    parse_value("\"number\""),
  )
  assert_eq(
    test_at(result, ["schema", "b"]),
    parse_value("\"number\""),
  )
  assert_eq(test_at(result, ["scanned"]), parse_value("3"))
}

///|
test "inferred schema feeds check" {
  let inferred = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"amount\":50,\"tier\":\"gold\"}]}",
    ),
  )
  let schema = test_at(inferred, ["schema"])
  let result = run(
    record([
      ("operation", String("check")),
      ("expression", String("amount > 10 && tier == \"gold\"")),
      ("schema", schema),
    ]),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(test_at(result, ["type"]), parse_value("\"boolean\""))
}


///|
test "analyze extracts dependencies and metrics" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"r\",\"priority\":5,\"when\":\"user.age >= 18 && len(tags) > 0\",\"compute\":\"total * 2\"}]}",
    ),
  )
  match test_at(result, ["rules", "0", "dependencies"]) {
    Array(items) => {
      assert_eq(items.length(), 3)
      assert_eq(items[0], parse_value("\"tags\""))
      assert_eq(items[2], parse_value("\"user.age\""))
    }
    _ => assert_true(false)
  }
  assert_eq(
    test_at(result, ["rules", "0", "canonical"]),
    parse_value("\"user.age >= 18 && len(tags) > 0\""),
  )
  assert_eq(test_at(result, ["rules", "0", "depth"]), parse_value("4"))
  assert_eq(test_at(result, ["finding_count"]), parse_value("0"))
}

///|
test "analyze flags tautology" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"x\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["rules", "0", "flags", "0"]),
    parse_value("\"tautology\""),
  )
  assert_eq(
    test_at(result, ["findings", "0", "kind"]),
    parse_value("\"tautology\""),
  )
  assert_eq(test_at(result, ["finding_count"]), parse_value("1"))
}

///|
test "analyze detects shadow direction" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"base\",\"priority\":1,\"when\":\"amount > 10\",\"output\":1},{\"id\":\"copy\",\"priority\":9,\"when\":\"amount > 10\",\"output\":2}]}",
    ),
  )
  assert_eq(test_at(result, ["finding_count"]), parse_value("1"))
  assert_eq(
    test_at(result, ["findings", "0", "kind"]),
    parse_value("\"duplicate_condition\""),
  )
  match test_at(result, ["findings", "0", "detail"]) {
    String(detail) => assert_eq(detail, "shadows base")
    _ => assert_true(false)
  }
}

///|
test "analyze flags equal-priority tie" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"alpha\",\"priority\":2,\"when\":\"x > 0\",\"output\":1},{\"id\":\"beta\",\"priority\":2,\"when\":\"x > 0\",\"output\":2}]}",
    ),
  )
  assert_eq(test_at(result, ["finding_count"]), parse_value("2"))
  match test_at(result, ["findings", "1", "kind"]) {
    String(kind) => assert_eq(kind, "priority_tie")
    _ => assert_true(false)
  }
}

///|
test "analyze reports canonical normalization differences" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"a\",\"when\":\"x  >  0\",\"output\":1},{\"id\":\"b\",\"when\":\"x > 0\",\"output\":2}]}",
    ),
  )
  assert_eq(
    test_at(result, ["rules", "0", "canonical"]),
    parse_value("\"x > 0\""),
  )
  assert_eq(test_at(result, ["finding_count"]), parse_value("2"))
  assert_eq(
    test_at(result, ["findings", "0", "kind"]),
    parse_value("\"duplicate_condition\""),
  )
  assert_eq(
    test_at(result, ["findings", "1", "kind"]),
    parse_value("\"priority_tie\""),
  )
}

///|
test "analyze rejects missing rule id" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"analyze\",\"rules\":[{\"when\":\"true\",\"output\":1}]}",
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
test "analyze rejects non-string compute" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"compute\":5}]}",
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
fn explain_sample() -> Value raise {
  run(
    parse_value(
      "{\"operation\":\"explain\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"},{\"id\":\"minor\",\"when\":\"age < 18\",\"output\":\"minor\"}],\"facts\":{\"age\":20}}",
    ),
  )
}

///|
test "explain renders pass fail lines" {
  let result = explain_sample()
  let text = match test_at(result, ["text"]) {
    String(value) => value
    _ => ""
  }
  assert_true(text.contains("mode: first"))
  assert_true(text.contains("decision: \"adult\""))
  assert_true(text.contains("[PASS] adult"))
  assert_true(text.contains("[FAIL] minor"))
  assert_true(text.contains("matched outputs:"))
  assert_true(text.contains("adult (priority 2) -> \"adult\""))
  assert_true(text.contains("steps: "))
  assert_true(text.contains("conflict: false"))
}

///|
test "explain includes trace values" {
  let result = explain_sample()
  let text = match test_at(result, ["text"]) {
    String(value) => value
    _ => ""
  }
  assert_true(text.contains("trace: "))
  assert_true(text.contains("trace: 20 | 18 | true"))
}

///|
test "explain line count matches text" {
  let result = explain_sample()
  let text = match test_at(result, ["text"]) {
    String(value) => value
    _ => ""
  }
  let count = test_at(result, ["line_count"])
  let expected = text.split("\n").length().to_double()
  assert_eq(count, Number(expected))
}

///|
test "explain unique conflict report" {
  let result = run(
    parse_value(
      "{\"operation\":\"explain\",\"mode\":\"unique\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{\"age\":20}}",
    ),
  )
  let text = match test_at(result, ["text"]) {
    String(value) => value
    _ => ""
  }
  assert_true(text.contains("conflict: true"))
  assert_true(text.contains("conflicting rules: adult, fallback"))
  assert_true(text.contains("decision: null"))
}

///|
test "explain rejects multiple fact records" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"explain\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":[{},{ }]}",
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
test "explain validates mode and budget" {
  let failed_mode = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"explain\",\"mode\":\"wat\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":{}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed_mode)
  let failed_budget = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"explain\",\"budget\":0,\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":{}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed_budget)
}


///|
test "optimize folds literal arithmetic" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"1 + 2 * 3 == 7 && true\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"true\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("1"))
  assert_eq(test_at(result, ["changed"]), parse_value("true"))
  assert_eq(test_at(result, ["original_nodes"]), parse_value("9"))
}

///|
test "optimize keeps raising subtrees unfolded" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"flag && 1 / 0 > 1\"}",
    ),
  )
  assert_eq(
    test_at(result, ["canonical"]),
    parse_value("\"flag && 1 / 0 > 1\""),
  )
  assert_eq(test_at(result, ["changed"]), parse_value("false"))
}

///|
test "optimize drops literal true operands" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"true && flag || false\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"flag\""))
}

///|
test "optimize collapses short circuit true" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"false && anything || true\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"true\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("1"))
}

///|
test "optimize removes double negation" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"!!flag && !!active\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"flag && active\""))
}

///|
test "optimize folds nested constants inside calls" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"len(items) > 1 + 1 && abs(-5) == 5\"}",
    ),
  )
  assert_eq(
    test_at(result, ["canonical"]),
    parse_value("\"len(items) > 2\""),
  )
}

///|
test "optimized evaluate preserves value" {
  let facts = "{\"amount\":120,\"tier\":\"gold\"}"
  let plain = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"amount > 100 && tier == \\\"gold\\\" || false\",\"facts\":" +
      facts +
      "}",
    ),
  )
  let optimized = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"amount > 100 && tier == \\\"gold\\\" || false\",\"facts\":" +
      facts +
      ",\"optimize\":true}",
    ),
  )
  assert_eq(
    test_at(plain, ["value"]),
    test_at(optimized, ["value"]),
  )
  assert_eq(test_at(optimized, ["value"]), parse_value("true"))
}

///|
test "optimized evaluate preserves errors" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"flag && 1 / 0 > 1\",\"facts\":{\"flag\":true},\"optimize\":true}",
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
test "optimize idempotent on already minimal trees" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"amount > 100\"}",
    ),
  )
  assert_eq(test_at(result, ["changed"]), parse_value("false"))
  assert_eq(test_at(result, ["savings_percent"]), parse_value("0"))
}


///|
fn sample_program() -> Value raise {
  let compiled = run(
    parse_value(
      "{\"operation\":\"compile_rules\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age>=18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}]}",
    ),
  )
  test_at(compiled, ["program"])
}

///|
test "compile rules canonicalizes conditions" {
  let result = run(
    parse_value(
      "{\"operation\":\"compile_rules\",\"rules\":[{\"id\":\"adult\",\"when\":\"age>=18\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["program", "0", "condition"]),
    parse_value("\"age >= 18\""),
  )
  assert_eq(
    test_at(result, ["program", "0", "duplicate_condition"]),
    parse_value("false"),
  )
  assert_eq(test_at(result, ["duplicate_conditions"]), parse_value("0"))
}

///|
test "compile rules flags duplicate conditions" {
  let result = run(
    parse_value(
      "{\"operation\":\"compile_rules\",\"rules\":[{\"id\":\"a\",\"when\":\"x > 1\"},{\"id\":\"b\",\"when\":\"x>1\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["program", "1", "duplicate_condition"]),
    parse_value("true"),
  )
  assert_eq(test_at(result, ["duplicate_conditions"]), parse_value("1"))
}

///|
test "compile rules canonicalizes compute" {
  let result = run(
    parse_value(
      "{\"operation\":\"compile_rules\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"compute\":\"total*0.1\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["program", "0", "compute"]),
    parse_value("\"total * 0.1\""),
  )
}

///|
test "run program decides like rules" {
  let program = sample_program()
  let result = run(
    record([
      ("operation", String("run_program")),
      ("program", program),
      ("facts", parse_value("{\"age\":20}")),
    ]),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"adult\""),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
}

///|
test "run program rejects tampered condition" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"run_program\",\"program\":[{\"id\":\"r\",\"condition\":\"age  >=  18\",\"output\":1}],\"facts\":{}}",
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
test "run program rejects duplicate ids" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"run_program\",\"program\":[{\"id\":\"r\",\"condition\":\"true\",\"output\":1},{\"id\":\"r\",\"condition\":\"false\",\"output\":2}],\"facts\":{}}",
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
test "run program validates mode and budget" {
  let failed_mode = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"run_program\",\"program\":[{\"id\":\"r\",\"condition\":\"true\",\"output\":1}],\"facts\":{},\"mode\":\"wat\"}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed_mode)
  let failed_budget = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"run_program\",\"program\":[{\"id\":\"r\",\"condition\":\"true\",\"output\":1}],\"facts\":{},\"budget\":-1}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed_budget)
}

///|
test "run program per-record errors" {
  let program = sample_program()
  let result = run(
    record([
      ("operation", String("run_program")),
      ("program", program),
      ("facts", parse_value("[{\"age\":20},{}]")),
    ]),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"adult\""),
  )
  match test_at(result, ["results", "1"]) {
    Object(fields) => assert_true(fields.contains("error"))
    _ => assert_true(false)
  }
}


///|
test "coverage tallies hits and rates" {
  let result = run(
    parse_value(
      "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"adult\",\"when\":\"age >= 18\"},{\"id\":\"senior\",\"when\":\"age >= 65\"}],\"facts\":[{\"age\":70},{\"age\":30},{\"age\":10}]}",
    ),
  )
  assert_eq(test_at(result, ["records"]), parse_value("3"))
  assert_eq(test_at(result, ["covered_records"]), parse_value("2"))
  assert_eq(test_at(result, ["multi_hit_records"]), parse_value("1"))
  assert_eq(
    test_at(result, ["rules", "0", "hits"]),
    parse_value("2"),
  )
  assert_eq(
    test_at(result, ["rules", "1", "hits"]),
    parse_value("1"),
  )
  assert_eq(
    test_at(result, ["rules", "1", "hit_rate"]),
    parse_value("33.333333333333336"),
  )
  assert_eq(test_at(result, ["never_hit"]), parse_value("0"))
  assert_eq(test_at(result, ["always_hit"]), parse_value("0"))
}

///|
test "coverage pattern distribution sorted" {
  let result = run(
    parse_value(
      "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"a\",\"when\":\"x > 1\"},{\"id\":\"b\",\"when\":\"x > 2\"}],\"facts\":[{\"x\":3},{\"x\":2},{\"x\":0}]}",
    ),
  )
  match test_at(result, ["patterns"]) {
    Array(entries) => {
      assert_eq(entries.length(), 3)
      assert_eq(test_at(entries[0], ["matched"]), parse_value("\"a\""))
      assert_eq(test_at(entries[0], ["records"]), parse_value("1"))
      assert_eq(test_at(entries[1], ["matched"]), parse_value("\"a+b\""))
      assert_eq(test_at(entries[2], ["matched"]), parse_value("\"none\""))
      assert_eq(test_at(entries[2], ["share"]), parse_value("33.333333333333336"))
    }
    _ => assert_true(false)
  }
}

///|
test "coverage counts per-rule errors without aborting" {
  let result = run(
    parse_value(
      "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"needs\",\"when\":\"amount > 5\"},{\"id\":\"safe\",\"when\":\"exists(amount) && amount > 0\"}],\"facts\":[{\"amount\":10},{}]}",
    ),
  )
  assert_eq(test_at(result, ["error_records"]), parse_value("1"))
  assert_eq(
    test_at(result, ["rules", "0", "errors"]),
    parse_value("1"),
  )
  assert_eq(
    test_at(result, ["rules", "0", "evaluated"]),
    parse_value("1"),
  )
  assert_eq(
    test_at(result, ["rules", "1", "hits"]),
    parse_value("1"),
  )
}

///|
test "coverage always hit detection" {
  let result = run(
    parse_value(
      "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"all\",\"when\":\"true\"}],\"facts\":[{},{},{}]}",
    ),
  )
  assert_eq(test_at(result, ["always_hit"]), parse_value("1"))
  assert_eq(
    test_at(result, ["rules", "0", "hit_rate"]),
    parse_value("100"),
  )
}

///|
test "coverage validates budget" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"r\",\"when\":\"true\"}],\"facts\":[],\"budget\":99999999}",
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
test "rule graph links shared dependencies" {
  let result = run(
    parse_value(
      "{\"operation\":\"rule_graph\",\"rules\":[{\"id\":\"b\",\"when\":\"amount > 5\"},{\"id\":\"a\",\"when\":\"amount < 100 && tier == \\\"g\\\"\",\"compute\":\"amount * 2\"},{\"id\":\"c\",\"when\":\"color != null\"}]}",
    ),
  )
  assert_eq(test_at(result, ["nodes"]), parse_value("[\"a\",\"b\",\"c\"]"))
  match test_at(result, ["edges"]) {
    Array(edges) => {
      assert_eq(edges.length(), 1)
      assert_eq(test_at(edges[0], ["a"]), parse_value("\"a\""))
      assert_eq(test_at(edges[0], ["b"]), parse_value("\"b\""))
      assert_eq(test_at(edges[0], ["shared"]), parse_value("[\"amount\"]"))
    }
    _ => assert_true(false)
  }
  match test_at(result, ["components"]) {
    Array(components) => {
      assert_eq(components.length(), 2)
      assert_eq(components[0], parse_value("[\"a\",\"b\"]"))
      assert_eq(components[1], parse_value("[\"c\"]"))
    }
    _ => assert_true(false)
  }
  assert_eq(test_at(result, ["isolated"]), parse_value("[\"c\"]"))
}

///|
test "rule graph hub ranking" {
  let result = run(
    parse_value(
      "{\"operation\":\"rule_graph\",\"rules\":[{\"id\":\"r1\",\"when\":\"x > 1\"},{\"id\":\"r2\",\"when\":\"x < 9 && y == 1\"},{\"id\":\"r3\",\"when\":\"z == y\"}]}",
    ),
  )
  match test_at(result, ["hubs"]) {
    Array(hubs) => {
      assert_eq(test_at(hubs[0], ["path"]), parse_value("\"x\""))
      assert_eq(test_at(hubs[0], ["rule_count"]), parse_value("2"))
      assert_eq(test_at(hubs[1], ["path"]), parse_value("\"y\""))
      assert_eq(test_at(hubs[1], ["rule_count"]), parse_value("2"))
      assert_eq(test_at(hubs[2], ["rule_count"]), parse_value("1"))
    }
    _ => assert_true(false)
  }
}

///|
test "rule graph transitive components merge" {
  let result = run(
    parse_value(
      "{\"operation\":\"rule_graph\",\"rules\":[{\"id\":\"a\",\"when\":\"x > 1\"},{\"id\":\"b\",\"when\":\"x > 2 && y < 3\"},{\"id\":\"c\",\"when\":\"y > 4\"}]}",
    ),
  )
  match test_at(result, ["components"]) {
    Array(components) => {
      assert_eq(components.length(), 1)
      assert_eq(components[0], parse_value("[\"a\",\"b\",\"c\"]"))
    }
    _ => assert_true(false)
  }
  assert_eq(test_at(result, ["isolated"]), parse_value("[]"))
}

///|
test "rule graph empty input" {
  let result = run(
    parse_value("{\"operation\":\"rule_graph\",\"rules\":[]}"),
  )
  assert_eq(test_at(result, ["nodes"]), parse_value("[]"))
  assert_eq(test_at(result, ["edges"]), parse_value("[]"))
  assert_eq(test_at(result, ["isolated"]), parse_value("[]"))
}

///|
test "rule graph rejects duplicate ids" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"rule_graph\",\"rules\":[{\"id\":\"a\",\"when\":\"x > 1\"},{\"id\":\"a\",\"when\":\"y > 1\"}]}",
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
test "count_matches scores thresholds" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"count_matches(scores, \\\">\\\", 5) >= 2\",\"facts\":{\"scores\":[3,7,9,5]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "count_matches rejects unknown operator" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"count_matches(scores, \\\"~\\\", 5)\",\"facts\":{\"scores\":[1]}}",
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
test "count_matches rejects non-numeric elements" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"count_matches(scores, \\\">\\\", 5)\",\"facts\":{\"scores\":[1,\"x\"]}}",
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
test "any and all match reduce booleans" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"any_match(flags) && !all_match(flags)\",\"facts\":{\"flags\":[false,true,false]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
  let none = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"all_match(flags)\",\"facts\":{\"flags\":[]}}",
    ),
  )
  assert_eq(test_at(none, ["value"]), parse_value("true"))
}

///|
test "any match rejects non-boolean elements" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"evaluate\",\"expression\":\"any_match(flags)\",\"facts\":{\"flags\":[true,1]}}",
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
test "check pins quantifier signatures" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"count_matches(scores, \\\">\\\", 5) == 1 && any_match(flags)\",\"schema\":{\"scores\":\"array\",\"flags\":\"array\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(test_at(result, ["type"]), parse_value("\"boolean\""))
}


///|
test "pick projects nested paths" {
  let result = run(
    parse_value(
      "{\"operation\":\"pick\",\"facts\":{\"user\":{\"age\":30,\"name\":\"bob\"},\"tags\":[\"x\",\"y\"]},\"paths\":[\"user.age\",\"tags.1\",\"user.email\"]}",
    ),
  )
  assert_eq(
    test_at(result, ["picked", "user", "age"]),
    parse_value("30"),
  )
  assert_eq(
    test_at(result, ["picked", "tags", "1"]),
    parse_value("\"y\""),
  )
  assert_eq(test_at(result, ["missing"]), parse_value("[\"user.email\"]"))
  assert_eq(test_at(result, ["requested"]), parse_value("3"))
}

///|
test "pick rejects duplicate paths" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"pick\",\"facts\":{},\"paths\":[\"a\",\"a\"]}",
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
test "pick all present leaves missing empty" {
  let result = run(
    parse_value(
      "{\"operation\":\"pick\",\"facts\":{\"a\":{\"b\":1}},\"paths\":[\"a.b\"]}",
    ),
  )
  assert_eq(test_at(result, ["missing"]), parse_value("[]"))
  assert_eq(test_at(result, ["picked", "a", "b"]), parse_value("1"))
}

///|
test "pick out-of-range index reported missing" {
  let result = run(
    parse_value(
      "{\"operation\":\"pick\",\"facts\":{\"items\":[1]},\"paths\":[\"items.5\"]}",
    ),
  )
  assert_eq(test_at(result, ["missing"]), parse_value("[\"items.5\"]"))
  assert_eq(test_at(result, ["picked"]), parse_value("{}"))
}


///|
test "ast tree shape for binary and calls" {
  let result = run(
    parse_value(
      "{\"operation\":\"ast\",\"expression\":\"1 + len(items)\"}",
    ),
  )
  assert_eq(
    test_at(result, ["ast", "kind"]),
    parse_value("\"binary\""),
  )
  assert_eq(test_at(result, ["ast", "op"]), parse_value("\"+\""))
  assert_eq(
    test_at(result, ["ast", "left", "kind"]),
    parse_value("\"literal\""),
  )
  assert_eq(
    test_at(result, ["ast", "right", "name"]),
    parse_value("\"len\""),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"1 + len(items)\""))
}

///|
test "ast parse direction rebuilds expression" {
  let result = run(
    parse_value(
      "{\"operation\":\"ast\",\"ast\":{\"kind\":\"binary\",\"op\":\">=\",\"left\":{\"kind\":\"variable\",\"path\":\"age\"},\"right\":{\"kind\":\"literal\",\"value\":18}}}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"age >= 18\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("3"))
  assert_eq(test_at(result, ["depth"]), parse_value("2"))
}

///|
test "ast rejects unknown kinds and operators" {
  let bad_kind = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"ast\",\"ast\":{\"kind\":\"quantum\"}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(bad_kind)
  let bad_op = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"ast\",\"ast\":{\"kind\":\"binary\",\"op\":\"<>\",\"left\":{\"kind\":\"literal\",\"value\":1},\"right\":{\"kind\":\"literal\",\"value\":2}}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(bad_op)
  let bad_fn = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"ast\",\"ast\":{\"kind\":\"call\",\"name\":\"eval\",\"args\":[]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(bad_fn)
}

///|
test "ast roundtrip through both directions" {
  let source = run(
    parse_value(
      "{\"operation\":\"ast\",\"expression\":\"count_matches(scores, \\\">\\\", 5) > 1\"}",
    ),
  )
  let tree = test_at(source, ["ast"])
  let back = run(
    record([
      ("operation", String("ast")),
      ("ast", tree),
    ]),
  )
  assert_eq(
    test_at(back, ["canonical"]),
    parse_value("\"count_matches(scores, \\\">\\\", 5) > 1\""),
  )
}


///|
fn sample_bundle() -> Value raise {
  parse_value(
    "{\"versions\":[{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"base\",\"when\":\"true\",\"output\":1}]},{\"version\":\"1.1.0\",\"deprecates\":[\"1.0.0\"],\"rules\":[{\"id\":\"base\",\"when\":\"x > 1\",\"output\":2},{\"id\":\"extra\",\"when\":\"x > 2\",\"output\":3}]}]}",
  )
}

///|
test "bundle validate reports head and chain" {
  let result = run(record([("operation", String("bundle_validate")), ("versions", get(sample_bundle(), "versions"))]))
  assert_eq(test_at(result, ["head"]), parse_value("\"1.1.0\""))
  assert_eq(
    test_at(result, ["chain", "0"]),
    parse_value("\"1.0.0 -> 1.1.0\""),
  )
  assert_eq(test_at(result, ["rule_count_total"]), parse_value("3"))
  assert_eq(
    test_at(result, ["steps", "1", "duplicate_conditions"]),
    parse_value("0"),
  )
}

///|
test "bundle validate rejects duplicates and empty versions" {
  let dup = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"bundle_validate\",\"versions\":[{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"output\":1}]},{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"output\":1}]}]}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(dup)
  let empty = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"bundle_validate\",\"versions\":[{\"version\":\"1.0.0\",\"rules\":[]}]}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(empty)
}

///|
test "bundle validate rejects unknown deprecation" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"bundle_validate\",\"versions\":[{\"version\":\"2.0.0\",\"deprecates\":[\"0.9.0\"],\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"output\":1}]}]}",
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
test "bundle resolve pending steps from current" {
  let result = run(
    record([
      ("operation", String("bundle_resolve")),
      ("current", String("1.0.0")),
      ("versions", get(sample_bundle(), "versions")),
    ]),
  )
  assert_eq(test_at(result, ["head"]), parse_value("\"1.1.0\""))
  assert_eq(test_at(result, ["pending_count"]), parse_value("1"))
  assert_eq(test_at(result, ["up_to_date"]), parse_value("false"))
  assert_eq(test_at(result, ["pending_rule_count"]), parse_value("2"))
}

///|
test "bundle resolve up to date" {
  let result = run(
    record([
      ("operation", String("bundle_resolve")),
      ("current", String("1.1.0")),
      ("versions", get(sample_bundle(), "versions")),
    ]),
  )
  assert_eq(test_at(result, ["up_to_date"]), parse_value("true"))
  assert_eq(test_at(result, ["pending_count"]), parse_value("0"))
}

///|
test "bundle resolve rejects unknown current" {
  let failed = try {
    ignore(
      run(
        record([
          ("operation", String("bundle_resolve")),
          ("current", String("9.9.9")),
          ("versions", get(sample_bundle(), "versions")),
        ]),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}


///|
test "decision table compiles ranges to rules" {
  let result = run(
    parse_value(
      "{\"operation\":\"decision_table\",\"table\":{\"columns\":[\"amount\"],\"rows\":[{\"amount\":\">= 100\",\"outcome\":\"high\"},{\"amount\":\"> 0\",\"outcome\":\"low\"}]}}",
    ),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
  assert_eq(
    test_at(result, ["rules", "0", "when"]),
    parse_value("\"amount >= 100\""),
  )
  assert_eq(
    test_at(result, ["rules", "0", "priority"]),
    parse_value("2"),
  )
  assert_eq(
    test_at(result, ["rules", "1", "when"]),
    parse_value("\"amount > 0\""),
  )
}

///|
test "decision table multi-column conjunction" {
  let result = run(
    parse_value(
      "{\"operation\":\"decision_table\",\"table\":{\"columns\":[\"tier\",\"total\"],\"rows\":[{\"tier\":\"gold\",\"total\":\">= 500\",\"outcome\":\"vip\"}]}}",
    ),
  )
  assert_eq(
    test_at(result, ["rules", "0", "when"]),
    parse_value("\"tier == \\\"gold\\\" && total >= 500\""),
  )
}

///|
test "decide table end to end" {
  let result = run(
    parse_value(
      "{\"operation\":\"decide_table\",\"table\":{\"columns\":[\"amount\"],\"rows\":[{\"amount\":\">= 100\",\"outcome\":\"high\"},{\"amount\":\"> 0\",\"outcome\":\"low\"}]},\"facts\":[{\"amount\":150},{\"amount\":50},{\"amount\":0}]}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"high\""),
  )
  assert_eq(
    test_at(result, ["results", "1", "result", "decision"]),
    parse_value("\"low\""),
  )
  assert_eq(
    test_at(result, ["results", "2", "result", "decision"]),
    parse_value("null"),
  )
}

///|
test "decision table rejects duplicate outcomes" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"decision_table\",\"table\":{\"columns\":[\"x\"],\"rows\":[{\"x\":\"> 1\",\"outcome\":\"same\"},{\"x\":\"< 0\",\"outcome\":\"same\"}]}}",
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
test "decision table rejects missing cells" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"decision_table\",\"table\":{\"columns\":[\"x\",\"y\"],\"rows\":[{\"x\":\"> 1\",\"outcome\":\"ok\"}]}}",
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
test "decision table string cells compare equality" {
  let result = run(
    parse_value(
      "{\"operation\":\"decide_table\",\"table\":{\"columns\":[\"tier\"],\"rows\":[{\"tier\":\"gold\",\"outcome\":\"g\"}]},\"facts\":{\"tier\":\"gold\"}}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"g\""),
  )
}


///|
test "lint clean ruleset passes" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"}],\"schema\":{\"age\":\"number\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(test_at(result, ["finding_count"]), parse_value("0"))
  assert_eq(test_at(result, ["summary", "0", "findings"]), parse_value("0"))
  assert_eq(test_at(result, ["summary", "1", "findings"]), parse_value("0"))
}

///|
test "lint collects tautology and tie together" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"x\"},{\"id\":\"a\",\"when\":\"x > 1\",\"output\":1},{\"id\":\"b\",\"when\":\"x>1\",\"output\":2}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(test_at(result, ["finding_count"]), parse_value("3"))
  match test_at(result, ["findings"]) {
    Array(items) => {
      assert_eq(test_at(items[0], ["kind"]), parse_value("\"tautology\""))
      assert_eq(
        test_at(items[1], ["kind"]),
        parse_value("\"duplicate_condition\""),
      )
      assert_eq(test_at(items[2], ["kind"]), parse_value("\"priority_tie\""))
    }
    _ => assert_true(false)
  }
}

///|
test "lint surfaces schema type errors" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"bad\",\"when\":\"amount > \\\"x\\\"\",\"output\":1}],\"schema\":{\"amount\":\"number\"}}",
    ),
  )
  assert_eq(test_at(result, ["finding_count"]), parse_value("1"))
  match test_at(result, ["findings", "0"]) {
    Object(fields) => {
      assert_eq(
        fields.get("source"),
        Some(String("types")),
      )
      assert_eq(
        fields.get("kind"),
        Some(String("type_error")),
      )
    }
    _ => assert_true(false)
  }
}

///|
test "lint reports bundle integrity problems" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"versions\":[{\"version\":\"1.0.0\",\"rules\":[]}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(
    test_at(result, ["summary", "2", "source"]),
    parse_value("\"bundle\""),
  )
  assert_eq(
    test_at(result, ["summary", "2", "findings"]),
    parse_value("1"),
  )
}

///|
test "lint without bundle section reports zero" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(
    test_at(result, ["summary", "0", "findings"]),
    parse_value("1"),
  )
  assert_eq(
    test_at(result, ["summary", "2", "findings"]),
    parse_value("0"),
  )
}

///|
test "lint sections all present in report" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}]}",
    ),
  )
  match test_at(result, ["sections"]) {
    Array(sections) => {
      assert_eq(sections.length(), 3)
      assert_eq(
        test_at(sections[0], ["section"]),
        parse_value("\"analysis\""),
      )
      assert_eq(
        test_at(sections[1], ["section"]),
        parse_value("\"types\""),
      )
      assert_eq(
        test_at(sections[2], ["section"]),
        parse_value("\"bundle\""),
      )
    }
    _ => assert_true(false)
  }
}


///|
test "fmt normalizes conditions and counts changes" {
  let result = run(
    parse_value(
      "{\"operation\":\"fmt\",\"rules\":[{\"id\":\"a\",\"when\":\"age>=18\"},{\"id\":\"b\",\"when\":\"age < 65\"}]}",
    ),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
  assert_eq(test_at(result, ["changed_count"]), parse_value("1"))
  assert_eq(test_at(result, ["changed_ids"]), parse_value("[\"a\"]"))
  assert_eq(
    test_at(result, ["rules", "0", "when"]),
    parse_value("\"age >= 18\""),
  )
  assert_eq(
    test_at(result, ["rules", "1", "when"]),
    parse_value("\"age < 65\""),
  )
}

///|
test "fmt defaults priorities and keeps outputs" {
  let result = run(
    parse_value(
      "{\"operation\":\"fmt\",\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"output\":\"x\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["rules", "0", "priority"]),
    parse_value("0"),
  )
  assert_eq(
    test_at(result, ["rules", "0", "output"]),
    parse_value("\"x\""),
  )
}

///|
test "fmt normalizes compute too" {
  let result = run(
    parse_value(
      "{\"operation\":\"fmt\",\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"compute\":\"total*0.1\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["rules", "0", "compute"]),
    parse_value("\"total * 0.1\""),
  )
  assert_eq(test_at(result, ["changed_ids"]), parse_value("[\"a\"]"))
}

///|
test "fmt changed_only filters to drifted rules" {
  let result = run(
    parse_value(
      "{\"operation\":\"fmt\",\"changed_only\":true,\"rules\":[{\"id\":\"a\",\"when\":\"x>=1\"},{\"id\":\"b\",\"when\":\"x > 1\"}]}",
    ),
  )
  match test_at(result, ["rules"]) {
    Array(rules) => {
      assert_eq(rules.length(), 1)
      assert_eq(test_at(rules[0], ["id"]), parse_value("\"a\""))
    }
    _ => assert_true(false)
  }
}

///|
test "fmt output re-decides identically" {
  let rules_source = "[{\"id\":\"adult\",\"priority\":2,\"when\":\"age>=18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}]"
  let before = run(
    parse_value(
      "{\"operation\":\"decide\",\"rules\":" +
      rules_source +
      ",\"facts\":{\"age\":20}}",
    ),
  )
  let formatted = run(
    parse_value("{\"operation\":\"fmt\",\"rules\":" + rules_source + "}"),
  )
  let after = run(
    record([
      ("operation", String("decide")),
      ("rules", get(formatted, "rules")),
      ("facts", parse_value("{\"age\":20}")),
    ]),
  )
  assert_eq(
    test_at(before, ["results", "0", "result", "decision"]),
    test_at(after, ["results", "0", "result", "decision"]),
  )
  assert_eq(
    test_at(after, ["results", "0", "result", "decision"]),
    parse_value("\"adult\""),
  )
}

///|
test "fmt rejects non-string compute" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"fmt\",\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"compute\":5}]}",
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
test "export schema builds nested document" {
  let result = run(
    parse_value(
      "{\"operation\":\"export_schema\",\"schema\":{\"user.age\":\"number\",\"user.name\":\"string\",\"active\":\"boolean\"}}",
    ),
  )
  assert_eq(test_at(result, ["paths"]), parse_value("3"))
  assert_eq(test_at(result, ["draft"]), parse_value("\"2020-12\""))
  assert_eq(
    test_at(result, ["json_schema", "type"]),
    parse_value("\"object\""),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "active", "type"]),
    parse_value("\"boolean\""),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "user", "properties", "age", "type"]),
    parse_value("\"number\""),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "user", "properties", "name", "type"]),
    parse_value("\"string\""),
  )
}

///|
test "export schema maps null and structural types" {
  let result = run(
    parse_value(
      "{\"operation\":\"export_schema\",\"schema\":{\"extra\":\"null\",\"tags\":\"array\",\"user\":\"object\"}}",
    ),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "extra", "type"]),
    parse_value("\"null\""),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "tags", "type"]),
    parse_value("\"array\""),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "user", "type"]),
    parse_value("\"object\""),
  )
}

///|
test "export schema infers when no schema given" {
  let result = run(
    parse_value(
      "{\"operation\":\"export_schema\",\"facts\":[{\"user\":{\"age\":30},\"active\":true}]}",
    ),
  )
  assert_eq(test_at(result, ["paths"]), parse_value("3"))
  assert_eq(
    test_at(result, ["json_schema", "properties", "user", "properties", "age", "type"]),
    parse_value("\"number\""),
  )
  assert_eq(
    test_at(result, ["json_schema", "properties", "active", "type"]),
    parse_value("\"boolean\""),
  )
}

///|
test "export schema rejects non-object schema" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"export_schema\",\"schema\":[1]}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
