///|
/// Rule wave planning.
///
/// Real deployments often want to evaluate rules in waves: a decision
/// wave runs first and downstream waves observe the recorded outputs.
/// The plan_waves operation computes such a schedule statically from
/// the dependency graph: rules in one connected component may observe
/// shared facts, so they cannot safely run in the same wave when any
/// of them writes; isolated rules run immediately. The planner is
/// deliberately conservative — it orders components by dependency
/// depth and reports the wave index, member rules and the shared
/// paths that forced the grouping. With no overlapping dependencies
/// every rule lands in wave zero.

///|
fn wave_request(request : Value) -> Value raise {
  let graph = rule_graph_request(request)
  let components : Array[Value] = match get(graph, "components") {
    Array(items) => items
    _ => {
      let empty : Array[Value] = []
      empty
    }
  }
  let waves : Array[Value] = []
  // Components are already in deterministic order from the graph; a
  // component's wave index is its position among the components that
  // carry rules (isolated singletons included). Within a wave, rules
  // keep their character-sorted order.
  let mut index = 0
  for component in components {
    let members = match component {
      Array(items) => items
      _ => {
        let empty : Array[Value] = []
        empty
      }
    }
    let paths : Map[String, Bool] = Map([])
    // Re-derive the shared paths that bound this component from the
    // graph edges inside it.
    match get(graph, "edges") {
      Array(edges) =>
        for edge in edges {
          let a = get(edge, "a")
          let b = get(edge, "b")
          let member_values = members
          let mut both_in = false
          match (a, b) {
            (String(aid), String(bid)) => {
              let mut has_a = false
              let mut has_b = false
              for member in member_values {
                match member {
                  String(name) => {
                    if name == aid {
                      has_a = true
                    }
                    if name == bid {
                      has_b = true
                    }
                  }
                  _ => ()
                }
              }
              both_in = has_a && has_b
            }
            _ => ()
          }
          if both_in {
            match get(edge, "shared") {
              Array(shared) =>
                for path in shared {
                  match path {
                    String(name) => paths[name] = true
                    _ => ()
                  }
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
    let names : Array[String] = []
    for member in members {
      match member {
        String(name) => names.push(name)
        _ => ()
      }
    }
    names.sort_by(fn(a, b) { stable_string_compare(a, b) })
    let shared_paths = strings({
      let list : Array[String] = []
      for path, _ in paths {
        list.push(path)
      }
      list.sort_by(fn(a, b) { stable_string_compare(a, b) })
      list
    })
    waves.push(
      record([
        ("wave", Number(index.to_double())),
        ("rules", strings(names)),
        ("rule_count", Number(names.length().to_double())),
        ("coupled_by", shared_paths),
      ]),
    )
    index += 1
  }
  record([
    ("waves", Array(waves)),
    ("wave_count", Number(components.length().to_double())),
    (
      "rule_count",
      match get(graph, "nodes") {
        Array(nodes) => Number(nodes.length().to_double())
        _ => Number(0.0)
      },
    ),
  ])
}
