// Generated from tests/cases.json by scripts/fixtures.py; do not edit.

///|
fn fails(request : String) -> Bool {
  try {
    ignore(run(parse_value(request)))
    false
  } catch {
    _ => true
  }
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
  assert_true(
    fails("{\"operation\":\"evaluate\",\"expression\":\"1 / 0\",\"facts\":{}}"),
  )
}

///|
test "strict boolean" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"1 && true\",\"facts\":{}}",
    ),
  )
}

///|
test "duplicate rules" {
  assert_true(
    fails(
      "{\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"}],\"facts\":{}}",
    ),
  )
}

///|
test "in operator" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"\\\"g\\\" in tags\",\"facts\":{\"tags\":[\"g\",\"s\"]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "string concat" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"\\\"a\\\" + \\\"b\\\"\",\"facts\":{}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("\"ab\""))
}

///|
test "nonfinite result" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"1e308 * 10\",\"facts\":{}}",
    ),
  )
}

///|
test "unknown function" {
  assert_true(
    fails("{\"operation\":\"evaluate\",\"expression\":\"foo(1)\",\"facts\":{}}"),
  )
}

///|
test "unknown operation" {
  assert_true(fails("{\"operation\":\"wat\"}"))
}

///|
test "unknown decision mode" {
  assert_true(
    fails(
      "{\"rules\":[{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{},\"mode\":\"sometimes\"}",
    ),
  )
}

///|
test "budget out of range" {
  assert_true(
    fails(
      "{\"rules\":[{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":{},\"budget\":0}",
    ),
  )
}

///|
test "evaluate budget parameter" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"1 + 1\",\"facts\":{},\"budget\":100}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("2"))
}

///|
test "evaluate budget exceeded" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"1+1+1+1+1+1+1+1+1+1+1+1+1+1\",\"facts\":{},\"budget\":10}",
    ),
  )
}

///|
test "missing fact per-record error" {
  let result = run(
    parse_value(
      "{\"rules\":[{\"id\":\"r\",\"when\":\"amount > 5\",\"output\":\"hit\"}],\"facts\":[{\"amount\":10},{}]}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"hit\""),
  )
  assert_eq(test_at(result, ["results", "1", "index"]), parse_value("1"))
}

///|
test "conflict ids" {
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
  assert_eq(
    test_at(result, ["results", "0", "result", "conflict_ids"]),
    parse_value("[\"adult\",\"fallback\"]"),
  )
}

///|
test "check valid expression" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"expression\":\"amount > 5\",\"schema\":{\"amount\":\"number\"}}",
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
test "check rules duplicate id" {
  let result = run(
    parse_value(
      "{\"operation\":\"check\",\"rules\":[{\"id\":\"a\",\"when\":\"true\",\"output\":\"x\"},{\"id\":\"a\",\"when\":\"true\",\"output\":\"y\"}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(test_at(result, ["rules", "1", "valid"]), parse_value("false"))
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
test "upper function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"upper(name)\",\"facts\":{\"name\":\"Bob\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("\"BOB\""))
}

///|
test "upper requires string" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"upper(age)\",\"facts\":{\"age\":3}}",
    ),
  )
}

///|
test "trim function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"trim(code)\",\"facts\":{\"code\":\"  AB  \"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("\"AB\""))
}

///|
test "trim requires string" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"trim(flag)\",\"facts\":{\"flag\":true}}",
    ),
  )
}

///|
test "starts_with and ends_with" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"starts_with(code, \\\"PRE\\\") && ends_with(code, \\\"SUF\\\")\",\"facts\":{\"code\":\"PRE-SUF\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "starts_with type error" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"starts_with(code, 1)\",\"facts\":{\"code\":\"PRE\"}}",
    ),
  )
}

///|
test "replace function" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"replace(code, \\\"-\\\", \\\"_\\\")\",\"facts\":{\"code\":\"A-B\"}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("\"A_B\""))
}

///|
test "replace requires strings" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"replace(code, \\\"-\\\", 1)\",\"facts\":{\"code\":\"A-B\"}}",
    ),
  )
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
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"substring(code, 4, 9)\",\"facts\":{\"code\":\"AB\"}}",
    ),
  )
}

///|
test "floor value" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"floor(price)\",\"facts\":{\"price\":3.2}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("3"))
}

///|
test "ceil value" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"ceil(price)\",\"facts\":{\"price\":3.2}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("4"))
}

///|
test "floor requires number" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"floor(name)\",\"facts\":{\"name\":\"x\"}}",
    ),
  )
}

///|
test "round value" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"round(score)\",\"facts\":{\"score\":2.6}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("3"))
}

///|
test "round requires number" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"round(name)\",\"facts\":{\"name\":\"x\"}}",
    ),
  )
}

///|
test "min and max" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"min(a, b) + max(a, b)\",\"facts\":{\"a\":5,\"b\":2}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("7"))
}

///|
test "max requires numbers" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"max(a, b)\",\"facts\":{\"a\":1,\"b\":\"x\"}}",
    ),
  )
}

///|
test "sum array" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"sum(prices)\",\"facts\":{\"prices\":[1.5,2.5,2]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("6"))
}

///|
test "sum requires numeric elements" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"sum(prices)\",\"facts\":{\"prices\":[1,\"x\"]}}",
    ),
  )
}

///|
test "concat array" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"concat(parts)\",\"facts\":{\"parts\":[\"a\",\"b\",\"c\"]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("\"abc\""))
}

///|
test "concat requires string elements" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"concat(parts)\",\"facts\":{\"parts\":[\"a\",1]}}",
    ),
  )
}

///|
test "serialize canonical" {
  let result = run(
    parse_value("{\"operation\":\"serialize\",\"expression\":\"  1+2*3  \"}"),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"1 + 2 * 3\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("5"))
  assert_eq(test_at(result, ["depth"]), parse_value("3"))
}

///|
test "serialize grouping" {
  let result = run(
    parse_value("{\"operation\":\"serialize\",\"expression\":\"(1 + 2) * 3\"}"),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"(1 + 2) * 3\""))
}

///|
test "roundtrip equivalence" {
  let result = run(
    parse_value(
      "{\"operation\":\"roundtrip\",\"expression\":\"(price - discount) * quantity >= 100\",\"facts\":{\"price\":50,\"discount\":10,\"quantity\":3}}",
    ),
  )
  assert_eq(test_at(result, ["equivalent"]), parse_value("true"))
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "aggregate by tier" {
  let result = run(
    parse_value(
      "{\"operation\":\"aggregate\",\"facts\":[{\"tier\":\"g\",\"amount\":10},{\"tier\":\"s\",\"amount\":1},{\"tier\":\"g\",\"amount\":20},{\"tier\":\"s\",\"amount\":3}],\"key\":\"tier\",\"metrics\":[{\"name\":\"n\",\"op\":\"count\"},{\"name\":\"total\",\"op\":\"sum\",\"expression\":\"amount\"},{\"name\":\"avg\",\"op\":\"avg\",\"expression\":\"amount\"}]}",
    ),
  )
  assert_eq(test_at(result, ["group_count"]), parse_value("2"))
  assert_eq(test_at(result, ["groups", "0", "key"]), parse_value("\"g\""))
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "total"]),
    parse_value("30"),
  )
  assert_eq(
    test_at(result, ["groups", "0", "metrics", "avg"]),
    parse_value("15"),
  )
  assert_eq(
    test_at(result, ["groups", "1", "metrics", "total"]),
    parse_value("4"),
  )
}

///|
test "aggregate duplicate metric" {
  assert_true(
    fails(
      "{\"operation\":\"aggregate\",\"facts\":[],\"key\":\"1\",\"metrics\":[{\"name\":\"a\",\"op\":\"count\"},{\"name\":\"a\",\"op\":\"count\"}]}",
    ),
  )
}

///|
test "aggregate per-record errors" {
  let result = run(
    parse_value(
      "{\"operation\":\"aggregate\",\"facts\":[{\"amount\":5},{},{\"amount\":7}],\"key\":\"exists(amount)\",\"metrics\":[{\"name\":\"total\",\"op\":\"sum\",\"expression\":\"amount\"}]}",
    ),
  )
  assert_eq(test_at(result, ["record_errors"]), parse_value("1"))
  assert_eq(test_at(result, ["group_count"]), parse_value("2"))
  assert_eq(
    test_at(result, ["groups", "1", "metrics", "total"]),
    parse_value("12"),
  )
}

///|
test "infer nested schema" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"user\":{\"age\":30,\"name\":\"bob\"},\"active\":true,\"tags\":[\"a\"],\"score\":1.5}]}",
    ),
  )
  assert_eq(test_at(result, ["schema", "user.age"]), parse_value("\"number\""))
  assert_eq(test_at(result, ["schema", "user.name"]), parse_value("\"string\""))
  assert_eq(test_at(result, ["schema", "active"]), parse_value("\"boolean\""))
  assert_eq(test_at(result, ["schema", "tags"]), parse_value("\"array\""))
  assert_eq(test_at(result, ["scanned"]), parse_value("1"))
}

///|
test "infer mixed types" {
  let result = run(
    parse_value(
      "{\"operation\":\"infer\",\"facts\":[{\"value\":1},{\"value\":\"x\"}]}",
    ),
  )
  assert_eq(test_at(result, ["mixed", "0", "path"]), parse_value("\"value\""))
  assert_eq(test_at(result, ["scanned"]), parse_value("2"))
}

///|
test "analyze dependencies" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"r\",\"priority\":5,\"when\":\"user.age >= 18 && len(tags) > 0\",\"compute\":\"total * 2\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["rules", "0", "dependencies", "0"]),
    parse_value("\"tags\""),
  )
  assert_eq(
    test_at(result, ["rules", "0", "dependencies", "1"]),
    parse_value("\"total\""),
  )
  assert_eq(
    test_at(result, ["rules", "0", "dependencies", "2"]),
    parse_value("\"user.age\""),
  )
  assert_eq(test_at(result, ["rules", "0", "nodes"]), parse_value("8"))
  assert_eq(test_at(result, ["finding_count"]), parse_value("0"))
}

///|
test "analyze tautology and duplicates" {
  let result = run(
    parse_value(
      "{\"operation\":\"analyze\",\"rules\":[{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"x\"},{\"id\":\"a\",\"priority\":1,\"when\":\"amount > 10\",\"output\":1},{\"id\":\"b\",\"priority\":9,\"when\":\"amount > 10\",\"output\":2}]}",
    ),
  )
  assert_eq(test_at(result, ["finding_count"]), parse_value("2"))
  assert_eq(
    test_at(result, ["findings", "0", "kind"]),
    parse_value("\"tautology\""),
  )
  assert_eq(
    test_at(result, ["findings", "1", "kind"]),
    parse_value("\"duplicate_condition\""),
  )
}

///|
test "explain report" {
  let result = run(
    parse_value(
      "{\"operation\":\"explain\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"minor\",\"when\":\"age < 18\",\"output\":\"minor\"}],\"facts\":{\"age\":20}}",
    ),
  )
  assert_eq(test_at(result, ["line_count"]), parse_value("14"))
}

///|
test "explain rejects multiple records" {
  assert_true(
    fails(
      "{\"operation\":\"explain\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"facts\":[{},{}]}",
    ),
  )
}

///|
test "optimize literals" {
  let result = run(
    parse_value(
      "{\"operation\":\"optimize\",\"expression\":\"1 + 2 * 3 == 7 && true\"}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"true\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("1"))
  assert_eq(test_at(result, ["changed"]), parse_value("true"))
}

///|
test "optimize preserves raising subtrees" {
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
test "evaluate with optimize flag" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"amount > 100 && tier == \\\"gold\\\" || false\",\"facts\":{\"amount\":120,\"tier\":\"gold\"},\"optimize\":true}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "compile and run program" {
  let result = run(
    parse_value(
      "{\"operation\":\"compile_rules\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age>=18\",\"output\":\"adult\"}]}",
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
test "run program rejects non-canonical" {
  assert_true(
    fails(
      "{\"operation\":\"run_program\",\"program\":[{\"id\":\"r\",\"condition\":\"age  >=  18\",\"output\":1}],\"facts\":{\"age\":20}}",
    ),
  )
}

///|
test "coverage tallies" {
  let result = run(
    parse_value(
      "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"adult\",\"when\":\"age >= 18\"},{\"id\":\"senior\",\"when\":\"age >= 65\"}],\"facts\":[{\"age\":70},{\"age\":30},{\"age\":10}]}",
    ),
  )
  assert_eq(test_at(result, ["records"]), parse_value("3"))
  assert_eq(test_at(result, ["covered_records"]), parse_value("2"))
  assert_eq(test_at(result, ["multi_hit_records"]), parse_value("1"))
  assert_eq(test_at(result, ["rules", "0", "hits"]), parse_value("2"))
  assert_eq(test_at(result, ["rules", "1", "hits"]), parse_value("1"))
}

///|
test "coverage errors tolerated" {
  let result = run(
    parse_value(
      "{\"operation\":\"coverage\",\"rules\":[{\"id\":\"needs\",\"when\":\"amount > 5\"},{\"id\":\"safe\",\"when\":\"exists(amount) && amount > 0\"}],\"facts\":[{\"amount\":10},{}]}",
    ),
  )
  assert_eq(test_at(result, ["error_records"]), parse_value("1"))
  assert_eq(test_at(result, ["rules", "0", "errors"]), parse_value("1"))
  assert_eq(test_at(result, ["rules", "1", "hits"]), parse_value("1"))
}

///|
test "rule graph components" {
  let result = run(
    parse_value(
      "{\"operation\":\"rule_graph\",\"rules\":[{\"id\":\"a\",\"when\":\"amount < 100 && tier == \\\"g\\\"\",\"compute\":\"amount * 2\"},{\"id\":\"b\",\"when\":\"amount > 5\"},{\"id\":\"c\",\"when\":\"color != null\"}]}",
    ),
  )
  assert_eq(
    test_at(result, ["edges", "0", "shared", "0"]),
    parse_value("\"amount\""),
  )
  assert_eq(test_at(result, ["components", "0"]), parse_value("[\"a\",\"b\"]"))
  assert_eq(test_at(result, ["components", "1"]), parse_value("[\"c\"]"))
  assert_eq(test_at(result, ["isolated"]), parse_value("[\"c\"]"))
}

///|
test "ordering follows code units not length" {
  let result = run(
    parse_value(
      "{\"operation\":\"rule_graph\",\"rules\":[{\"id\":\"n2\",\"when\":\"x10 > 1\"},{\"id\":\"n10\",\"when\":\"x2 > 1 && y > 1\"},{\"id\":\"n2x\",\"when\":\"x2 > 2\"}]}",
    ),
  )
  assert_eq(test_at(result, ["nodes", "0"]), parse_value("\"n10\""))
  assert_eq(test_at(result, ["nodes", "1"]), parse_value("\"n2\""))
  assert_eq(test_at(result, ["nodes", "2"]), parse_value("\"n2x\""))
}

///|
test "rule set diff orders ids by code unit" {
  let result = run(
    parse_value(
      "{\"operation\":\"diff\",\"old\":[{\"id\":\"r2\",\"when\":\"a > 1\"}],\"new\":[{\"id\":\"r10\",\"when\":\"a > 1\"},{\"id\":\"r2\",\"when\":\"a > 2\"}]}",
    ),
  )
  assert_eq(test_at(result, ["added"]), parse_value("[\"r10\"]"))
  assert_eq(test_at(result, ["removed"]), parse_value("[]"))
  assert_eq(test_at(result, ["changed"]), parse_value("[\"r2\"]"))
}

///|
test "count_matches" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"count_matches(scores, \\\">\\\", 5)\",\"facts\":{\"scores\":[3,7,9,5]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("2"))
}

///|
test "count_matches rejects bad operator" {
  assert_true(
    fails(
      "{\"operation\":\"evaluate\",\"expression\":\"count_matches(scores, \\\"~\\\", 5)\",\"facts\":{\"scores\":[1]}}",
    ),
  )
}

///|
test "any_match" {
  let result = run(
    parse_value(
      "{\"operation\":\"evaluate\",\"expression\":\"any_match(flags)\",\"facts\":{\"flags\":[false,true]}}",
    ),
  )
  assert_eq(test_at(result, ["value"]), parse_value("true"))
}

///|
test "pick projection" {
  let result = run(
    parse_value(
      "{\"operation\":\"pick\",\"facts\":{\"user\":{\"age\":30,\"name\":\"bob\"},\"tags\":[\"x\",\"y\"]},\"paths\":[\"user.age\",\"tags.1\",\"user.email\"]}",
    ),
  )
  assert_eq(test_at(result, ["picked", "user", "age"]), parse_value("30"))
  assert_eq(test_at(result, ["picked", "tags", "1"]), parse_value("\"y\""))
  assert_eq(test_at(result, ["missing"]), parse_value("[\"user.email\"]"))
  assert_eq(test_at(result, ["requested"]), parse_value("3"))
}

///|
test "ast tree" {
  let result = run(
    parse_value("{\"operation\":\"ast\",\"expression\":\"1 + len(items)\"}"),
  )
  assert_eq(test_at(result, ["ast", "kind"]), parse_value("\"binary\""))
  assert_eq(test_at(result, ["ast", "op"]), parse_value("\"+\""))
  assert_eq(test_at(result, ["ast", "right", "name"]), parse_value("\"len\""))
  assert_eq(test_at(result, ["canonical"]), parse_value("\"1 + len(items)\""))
}

///|
test "ast parse" {
  let result = run(
    parse_value(
      "{\"operation\":\"ast\",\"ast\":{\"kind\":\"binary\",\"op\":\">=\",\"left\":{\"kind\":\"variable\",\"path\":\"age\"},\"right\":{\"kind\":\"literal\",\"value\":18}}}",
    ),
  )
  assert_eq(test_at(result, ["canonical"]), parse_value("\"age >= 18\""))
  assert_eq(test_at(result, ["nodes"]), parse_value("3"))
}

///|
test "ast rejects unknown function" {
  assert_true(
    fails(
      "{\"operation\":\"ast\",\"ast\":{\"kind\":\"call\",\"name\":\"eval\",\"args\":[]}}",
    ),
  )
}

///|
test "bundle validate" {
  let result = run(
    parse_value(
      "{\"operation\":\"bundle_validate\",\"versions\":[{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"base\",\"when\":\"true\",\"output\":1}]},{\"version\":\"1.1.0\",\"deprecates\":[\"1.0.0\"],\"rules\":[{\"id\":\"base\",\"when\":\"x > 1\",\"output\":2}]}]}",
    ),
  )
  assert_eq(test_at(result, ["head"]), parse_value("\"1.1.0\""))
  assert_eq(test_at(result, ["chain", "0"]), parse_value("\"1.0.0 -> 1.1.0\""))
  assert_eq(test_at(result, ["rule_count_total"]), parse_value("2"))
}

///|
test "bundle resolve up to date" {
  let result = run(
    parse_value(
      "{\"operation\":\"bundle_resolve\",\"current\":\"1.1.0\",\"versions\":[{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"base\",\"when\":\"true\",\"output\":1}]},{\"version\":\"1.1.0\",\"rules\":[{\"id\":\"base\",\"when\":\"x > 1\",\"output\":2}]}]}",
    ),
  )
  assert_eq(test_at(result, ["up_to_date"]), parse_value("true"))
  assert_eq(test_at(result, ["pending_count"]), parse_value("0"))
}

///|
test "decision table compile" {
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
  assert_eq(test_at(result, ["rules", "0", "priority"]), parse_value("2"))
}

///|
test "decide table" {
  let result = run(
    parse_value(
      "{\"operation\":\"decide_table\",\"table\":{\"columns\":[\"amount\"],\"rows\":[{\"amount\":\">= 100\",\"outcome\":\"high\"},{\"amount\":\"> 0\",\"outcome\":\"low\"}]},\"facts\":[{\"amount\":150},{\"amount\":0}]}",
    ),
  )
  assert_eq(
    test_at(result, ["results", "0", "result", "decision"]),
    parse_value("\"high\""),
  )
}

///|
test "decision table duplicate outcome" {
  assert_true(
    fails(
      "{\"operation\":\"decision_table\",\"table\":{\"columns\":[\"x\"],\"rows\":[{\"x\":\"> 1\",\"outcome\":\"same\"},{\"x\":\"< 0\",\"outcome\":\"same\"}]}}",
    ),
  )
}

///|
test "lint clean" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"}],\"schema\":{\"age\":\"number\"}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(test_at(result, ["finding_count"]), parse_value("0"))
}

///|
test "lint finds tautology and tie" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"x\"},{\"id\":\"a\",\"when\":\"x > 1\",\"output\":1},{\"id\":\"b\",\"when\":\"x>1\",\"output\":2}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(test_at(result, ["finding_count"]), parse_value("3"))
  assert_eq(
    test_at(result, ["findings", "0", "kind"]),
    parse_value("\"tautology\""),
  )
  assert_eq(
    test_at(result, ["findings", "2", "kind"]),
    parse_value("\"priority_tie\""),
  )
}

///|
test "lint bundle error" {
  let result = run(
    parse_value(
      "{\"operation\":\"lint\",\"rules\":[{\"id\":\"r\",\"when\":\"true\",\"output\":1}],\"versions\":[{\"version\":\"1.0.0\",\"rules\":[]}]}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(test_at(result, ["summary", "2", "findings"]), parse_value("1"))
}

///|
test "fmt normalizes ruleset" {
  let result = run(
    parse_value(
      "{\"operation\":\"fmt\",\"rules\":[{\"id\":\"a\",\"when\":\"age>=18\",\"output\":\"adult\"},{\"id\":\"b\",\"when\":\"true\",\"output\":\"other\"}]}",
    ),
  )
  assert_eq(test_at(result, ["changed_count"]), parse_value("1"))
  assert_eq(test_at(result, ["changed_ids"]), parse_value("[\"a\"]"))
  assert_eq(
    test_at(result, ["rules", "0", "when"]),
    parse_value("\"age >= 18\""),
  )
  assert_eq(test_at(result, ["rules", "0", "priority"]), parse_value("0"))
}

///|
test "fmt changed only" {
  let result = run(
    parse_value(
      "{\"operation\":\"fmt\",\"changed_only\":true,\"rules\":[{\"id\":\"a\",\"when\":\"x>=1\"},{\"id\":\"b\",\"when\":\"x > 1\"}]}",
    ),
  )
  assert_eq(test_at(result, ["rules", "0", "id"]), parse_value("\"a\""))
}

///|
test "export schema" {
  let result = run(
    parse_value(
      "{\"operation\":\"export_schema\",\"schema\":{\"user.age\":\"number\",\"active\":\"boolean\"}}",
    ),
  )
  assert_eq(test_at(result, ["draft"]), parse_value("\"2020-12\""))
  assert_eq(test_at(result, ["paths"]), parse_value("2"))
  assert_eq(test_at(result, ["json_schema", "type"]), parse_value("\"object\""))
  assert_eq(
    test_at(result, ["json_schema", "properties", "active", "type"]),
    parse_value("\"boolean\""),
  )
  assert_eq(
    test_at(result, [
      "json_schema", "properties", "user", "properties", "age", "type",
    ]),
    parse_value("\"number\""),
  )
}

///|
test "export schema infers" {
  let result = run(
    parse_value(
      "{\"operation\":\"export_schema\",\"facts\":[{\"user\":{\"age\":30}}]}",
    ),
  )
  assert_eq(
    test_at(result, [
      "json_schema", "properties", "user", "properties", "age", "type",
    ]),
    parse_value("\"number\""),
  )
}

///|
test "migrate applies steps" {
  let result = run(
    parse_value(
      "{\"operation\":\"migrate\",\"current\":\"1.0.0\",\"versions\":[{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"base\",\"when\":\"true\",\"output\":\"v1\"}]},{\"version\":\"1.1.0\",\"rules\":[{\"id\":\"base\",\"when\":\"x > 1\",\"output\":\"v2\"},{\"id\":\"extra\",\"when\":\"y > 2\",\"output\":\"extra\"}]}]}",
    ),
  )
  assert_eq(test_at(result, ["version"]), parse_value("\"1.1.0\""))
  assert_eq(test_at(result, ["applied_steps"]), parse_value("1"))
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
  assert_eq(test_at(result, ["program", "0", "output"]), parse_value("\"v2\""))
}

///|
test "migrate up to date" {
  let result = run(
    parse_value(
      "{\"operation\":\"migrate\",\"current\":\"1.1.0\",\"versions\":[{\"version\":\"1.0.0\",\"rules\":[{\"id\":\"base\",\"when\":\"true\",\"output\":\"v1\"}]},{\"version\":\"1.1.0\",\"rules\":[{\"id\":\"base\",\"when\":\"x > 1\",\"output\":\"v2\"}]}]}",
    ),
  )
  assert_eq(test_at(result, ["applied_steps"]), parse_value("0"))
  assert_eq(test_at(result, ["rule_count"]), parse_value("1"))
}

///|
test "validate clean and required" {
  let result = run(
    parse_value(
      "{\"operation\":\"validate\",\"schema\":{\"age\":\"number\",\"tier\":\"string\"},\"required\":[\"age\"],\"facts\":[{\"age\":30,\"tier\":\"gold\"},{\"age\":20},{\"tier\":\"bronze\"}]}",
    ),
  )
  assert_eq(test_at(result, ["records"]), parse_value("3"))
  assert_eq(test_at(result, ["error_records"]), parse_value("1"))
  assert_eq(test_at(result, ["results", "0", "ok"]), parse_value("true"))
  assert_eq(test_at(result, ["results", "1", "ok"]), parse_value("true"))
  assert_eq(test_at(result, ["results", "2", "ok"]), parse_value("false"))
}

///|
test "validate type mismatch" {
  let result = run(
    parse_value(
      "{\"operation\":\"validate\",\"schema\":{\"age\":\"number\"},\"facts\":{\"age\":\"old\"}}",
    ),
  )
  assert_eq(test_at(result, ["error_count"]), parse_value("1"))
  assert_eq(
    test_at(result, ["results", "0", "errors", "0", "path"]),
    parse_value("\"age\""),
  )
  assert_eq(
    test_at(result, ["results", "0", "errors", "0", "found"]),
    parse_value("\"string\""),
  )
}

///|
test "conflicts disjoint and subsumption" {
  let result = run(
    parse_value(
      "{\"operation\":\"conflicts\",\"rules\":[{\"id\":\"a\",\"when\":\"amount > 5\"},{\"id\":\"b\",\"when\":\"amount > 10\"},{\"id\":\"c\",\"when\":\"amount < 0\"}]}",
    ),
  )
  assert_eq(test_at(result, ["pair_count"]), parse_value("3"))
  assert_eq(
    test_at(result, ["pairs", "0", "relation"]),
    parse_value("\"a_subsumes_b\""),
  )
  assert_eq(
    test_at(result, ["pairs", "1", "relation"]),
    parse_value("\"disjoint\""),
  )
  assert_eq(test_at(result, ["summary", "0", "count"]), parse_value("2"))
  assert_eq(test_at(result, ["summary", "2", "count"]), parse_value("1"))
}

///|
test "stats summary" {
  let result = run(
    parse_value(
      "{\"operation\":\"stats\",\"rules\":[{\"id\":\"a\",\"priority\":2,\"when\":\"amount > 10 && tier == \\\"g\\\"\",\"compute\":\"amount * 0.1\"},{\"id\":\"b\",\"when\":\"amount > 5\"}]}",
    ),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
  assert_eq(test_at(result, ["compute_count"]), parse_value("1"))
  assert_eq(test_at(result, ["min_priority"]), parse_value("0"))
  assert_eq(test_at(result, ["max_priority"]), parse_value("2"))
  assert_eq(test_at(result, ["paths", "0", "path"]), parse_value("\"amount\""))
  assert_eq(test_at(result, ["paths", "0", "rules"]), parse_value("2"))
}

///|
test "plan waves" {
  let result = run(
    parse_value(
      "{\"operation\":\"plan_waves\",\"rules\":[{\"id\":\"a\",\"when\":\"amount < 100 && tier == \\\"g\\\"\"},{\"id\":\"b\",\"when\":\"amount > 5\"},{\"id\":\"c\",\"when\":\"color != null\"}]}",
    ),
  )
  assert_eq(test_at(result, ["wave_count"]), parse_value("2"))
  assert_eq(test_at(result, ["rule_count"]), parse_value("3"))
  assert_eq(
    test_at(result, ["waves", "0", "rules"]),
    parse_value("[\"a\",\"b\"]"),
  )
  assert_eq(
    test_at(result, ["waves", "0", "coupled_by", "0"]),
    parse_value("\"amount\""),
  )
  assert_eq(test_at(result, ["waves", "1", "rules"]), parse_value("[\"c\"]"))
}

///|
test "snapshot fingerprints" {
  let result = run(
    parse_value(
      "{\"operation\":\"snapshot\",\"rules\":[{\"id\":\"adult\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"fallback\",\"when\":\"true\",\"output\":\"other\"}],\"facts\":[{\"age\":20},{\"age\":10}]}",
    ),
  )
  assert_eq(test_at(result, ["count"]), parse_value("2"))
  assert_eq(test_at(result, ["snapshots", "0", "index"]), parse_value("0"))
}

///|
test "template render" {
  let result = run(
    parse_value(
      "{\"operation\":\"template\",\"rules\":[{\"id\":\"vip_{{tier}}\",\"priority\":2,\"when\":\"tier == {{tier}} && total >= {{min}}\",\"compute\":\"total * {{rate}}\"}],\"params\":{\"tier\":\"gold\",\"min\":500,\"rate\":0.15}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("true"))
  assert_eq(
    test_at(result, ["rules", "0", "when"]),
    parse_value("\"tier == \\\"gold\\\" && total >= 500\""),
  )
  assert_eq(
    test_at(result, ["rules", "0", "compute"]),
    parse_value("\"total * 0.15\""),
  )
  assert_eq(test_at(result, ["rules", "0", "id"]), parse_value("\"vip_gold\""))
}

///|
test "template missing params" {
  let result = run(
    parse_value(
      "{\"operation\":\"template\",\"rules\":[{\"id\":\"a\",\"when\":\"x > {{threshold}}\"}],\"params\":{}}",
    ),
  )
  assert_eq(test_at(result, ["ok"]), parse_value("false"))
  assert_eq(test_at(result, ["missing_params"]), parse_value("[\"threshold\"]"))
}

///|
test "score ranks conditions" {
  let result = run(
    parse_value(
      "{\"operation\":\"score\",\"rules\":[{\"id\":\"easy\",\"when\":\"age >= 18\"},{\"id\":\"hard\",\"when\":\"(a && b) || (c && d) || (e && f) || (g && h) || (i && j) || (k && l)\"}]}",
    ),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
  assert_eq(test_at(result, ["rules", "0", "rank"]), parse_value("\"simple\""))
  assert_eq(test_at(result, ["rules", "0", "score"]), parse_value("100"))
  assert_eq(test_at(result, ["simple"]), parse_value("1"))
  assert_eq(test_at(result, ["rules", "1", "rank"]), parse_value("\"complex\""))
  assert_eq(test_at(result, ["complex"]), parse_value("1"))
}

///|
test "explain rules sentence" {
  let result = run(
    parse_value(
      "{\"operation\":\"explain_rules\",\"rules\":[{\"id\":\"adult\",\"when\":\"age >= 18\"}]}",
    ),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("1"))
  assert_eq(
    test_at(result, ["explanations", "0", "explanation"]),
    parse_value("\"Age must be at least 18.\""),
  )
  assert_eq(
    test_at(result, ["explanations", "0", "canonical"]),
    parse_value("\"age >= 18\""),
  )
}

///|
test "merge with provenance" {
  let result = run(
    parse_value(
      "{\"operation\":\"merge\",\"strategy\":\"last\",\"sets\":[{\"name\":\"base\",\"rules\":[{\"id\":\"adult\",\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"shared\",\"when\":\"x > 1\",\"output\":1}]},{\"name\":\"overlay\",\"rules\":[{\"id\":\"shared\",\"when\":\"x > 1\",\"output\":2}]}]}",
    ),
  )
  assert_eq(test_at(result, ["rule_count"]), parse_value("2"))
  assert_eq(test_at(result, ["conflict_count"]), parse_value("1"))
  assert_eq(test_at(result, ["conflicted_ids"]), parse_value("[\"shared\"]"))
  assert_eq(test_at(result, ["rules", "0", "origin"]), parse_value("\"base\""))
  assert_eq(
    test_at(result, ["rules", "1", "origin"]),
    parse_value("\"overlay\""),
  )
  assert_eq(test_at(result, ["rules", "1", "rule", "output"]), parse_value("2"))
}

///|
test "matrix mode comparison" {
  let result = run(
    parse_value(
      "{\"operation\":\"matrix\",\"rules\":[{\"id\":\"a\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"},{\"id\":\"senior\",\"priority\":3,\"when\":\"age >= 65\",\"output\":\"senior\"}],\"facts\":[{\"age\":70},{\"age\":30}]}",
    ),
  )
  assert_eq(test_at(result, ["agreements"]), parse_value("1"))
  assert_eq(test_at(result, ["disagreements"]), parse_value("1"))
  assert_eq(test_at(result, ["rows", "0", "agree"]), parse_value("false"))
  assert_eq(test_at(result, ["rows", "0", "first"]), parse_value("\"senior\""))
  assert_eq(test_at(result, ["rows", "0", "all_count"]), parse_value("2"))
  assert_eq(test_at(result, ["rows", "1", "unique"]), parse_value("\"adult\""))
}

///|
test "audit trail" {
  let result = run(
    parse_value(
      "{\"operation\":\"audit\",\"rules\":[{\"id\":\"a\",\"priority\":2,\"when\":\"age >= 18\",\"output\":\"adult\"}],\"facts\":[{\"age\":30}]}",
    ),
  )
  assert_eq(test_at(result, ["mode"]), parse_value("\"first\""))
  assert_eq(test_at(result, ["record_count"]), parse_value("1"))
  assert_eq(
    test_at(result, ["entries", "0", "decision"]),
    parse_value("\"adult\""),
  )
  assert_eq(
    test_at(result, ["entries", "0", "matched", "0", "id"]),
    parse_value("\"a\""),
  )
}
