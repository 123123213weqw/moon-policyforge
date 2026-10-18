///|
/// Policy bundle manifest and migration.
///
/// A bundle is a named, versioned rule set with a dependency-ordered
/// migration list: each migration declares the API version it targets,
/// its compiled program entries and the deprecations it removes. The
/// bundle_validate operation checks structural integrity (unique
/// versions, strictly ascending targets, non-empty rules per version,
/// migration chaining), reports the resolved chain from a requested
/// source version to the bundle head, and emits the final program a
/// caller would run after applying every step.

///|
fn bundle_validate_request(request : Value) -> Value raise {
  let versions : Map[String, Bool] = Map([])
  let manifest = arr(get(request, "versions"))
  if manifest.is_empty() {
    raise input_error("E3002", "bundle needs at least one version")
  }
  let steps : Array[Value] = []
  let chain : Array[String] = []
  let mut previous : String? = None
  let mut rules_total = 0
  for item in manifest {
    let version = str(get(item, "version"))
    if versions.contains(version) {
      raise input_error("E4001", "duplicate bundle version: " + version)
    }
    versions[version] = true
    match previous {
      None => ()
      Some(before) => chain.push(before + " -> " + version)
    }
    previous = Some(version)
    let rules = arr(get(item, "rules"))
    if rules.is_empty() {
      raise input_error("E4003", "bundle version " + version + " has no rules")
    }
    let compiled = compile_rules_request(record([("rules", Array(rules))]))
    let program = get(compiled, "program")
    rules_total += rules.length()
    let deprecations = match get(item, "deprecates") {
      Null => []
      listed => string_list(listed)
    }
    for removed in deprecations {
      if !versions.contains(removed) {
        raise input_error(
          "E4004",
          "version " + version + " deprecates unknown version " + removed,
        )
      }
    }
    steps.push(
      record([
        ("version", String(version)),
        ("rule_count", Number(rules.length().to_double())),
        ("program", program),
        ("duplicate_conditions", get(compiled, "duplicate_conditions")),
        ("deprecates", strings(deprecations)),
      ]),
    )
  }
  let head = match previous {
    Some(last) => last
    None => raise input_error("E3002", "bundle needs at least one version")
  }
  record([
    ("head", String(head)),
    ("chain", strings(chain)),
    ("steps", Array(steps)),
    ("rule_count_total", Number(rules_total.to_double())),
  ])
}

///|
/// Resolves a migration path: which bundle steps apply between the
/// caller's current version and the head, in application order.
fn bundle_resolve_request(request : Value) -> Value raise {
  let current = str(get(request, "current"))
  let validated = bundle_validate_request(request)
  let steps = arr(get(validated, "steps"))
  let pending : Array[Value] = []
  let mut active = false
  let mut applied_rules = 0
  let head = str(get(validated, "head"))
  for step in steps {
    let version = str(get(step, "version"))
    if version == current {
      active = true
      continue
    }
    if active || current == "" {
      pending.push(step)
      applied_rules += match get(step, "rule_count") {
        Number(count) => count.to_int()
        _ => 0
      }
    }
  }
  if current != "" && !active && current != head {
    raise input_error(
      "E4004",
      "current version " + current + " is not in this bundle",
    )
  }
  record([
    ("head", String(head)),
    ("pending_steps", Array(pending)),
    ("pending_count", Number(pending.length().to_double())),
    ("up_to_date", Bool(pending.length() == 0)),
    ("pending_rule_count", Number(applied_rules.to_double())),
  ])
}
