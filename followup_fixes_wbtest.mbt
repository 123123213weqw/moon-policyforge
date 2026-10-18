///|
test "diff rejects duplicated rule identity" {
  let rule = record([
    ("id", String("a")),
    ("when", String("true")),
    ("output", Number(1.0)),
  ])
  let bad = try {
    ignore(
      run(
        record([
          ("operation", String("diff")),
          ("old", Array([rule, rule])),
          ("new", Array([])),
        ]),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
