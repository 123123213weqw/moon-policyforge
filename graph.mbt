///|
/// Rule dependency graph.
///
/// The rule_graph operation links two rules when their fact-path
/// dependencies overlap; a shared path is an update-order coupling: if
/// callers ever rewrite facts between rule waves, rules in one
/// component may observe each other's inputs. Reports the adjacency in
/// deterministic ID order, connected components via union-find,
/// component sizes, isolated rules, and hub paths that appear in many
/// rules.

///|
fn overlap(a : Array[String], b : Array[String]) -> Array[String] {
  let shared : Array[String] = []
  let lookup : Map[String, Bool] = Map([])
  for path in b {
    lookup[path] = true
  }
  for path in a {
    if lookup.contains(path) {
      shared.push(path)
    }
  }
  shared
}

///|
/// Union-find helpers over a parent array. Roots are the fixed points
/// of parent chains; union attaches one root to the other.
fn uf_find(parent : Array[Int32], x : Int32) -> Int32 {
  let mut cur = x
  while parent[cur] != cur {
    cur = parent[cur]
  }
  cur
}

///|
fn uf_union(parent : Array[Int32], rx : Int32, ry : Int32) -> Unit {
  if rx != ry {
    parent[rx] = ry
  }
}

///|
fn rule_graph_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  if rules.is_empty() {
    return record([
      ("nodes", strings([])),
      ("edges", Array([])),
      ("components", Array([])),
      ("isolated", strings([])),
      ("hubs", Array([])),
    ])
  }
  let ids : Array[String] = []
  let deps : Array[Array[String]] = []
  let seen : Map[String, Bool] = Map([])
  let index_of : Map[String, Int32] = Map([])
  let mut index = 0
  for item in rules {
    let id = str(get(item, "id"))
    if seen.contains(id) {
      raise input_error("E4001", "duplicate rule ID: " + id)
    }
    seen[id] = true
    index_of[id] = index
    ids.push(id)
    let paths : Map[String, Bool] = Map([])
    collect_paths(compile(str(get(item, "when"))), paths)
    match get(item, "compute") {
      Null => ()
      String(source) => collect_paths(compile(source), paths)
      _ => raise input_error("E4007", "compute must be a string")
    }
    deps.push(sorted_paths(paths))
    index += 1
  }
  let order : Array[Int32] = []
  for i = 0; i < ids.length(); i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(x, y) { stable_string_compare(ids[x], ids[y]) })
  let edges : Array[Value] = []
  let union : Array[Int32] = []
  for i = 0; i < ids.length(); i = i + 1 {
    union.push(i)
  }
  let path_count : Map[String, Int32] = Map([])
  for path_list in deps {
    for path in path_list {
      match path_count.get(path) {
        Some(count) => path_count[path] = count + 1
        None => path_count[path] = 1
      }
    }
  }
  for oi = 0; oi < order.length(); oi = oi + 1 {
    let i = order[oi]
    for oj = oi + 1; oj < order.length(); oj = oj + 1 {
      let j = order[oj]
      let shared = overlap(deps[i], deps[j])
      if !shared.is_empty() {
        edges.push(
          record([
            ("a", String(ids[i])),
            ("b", String(ids[j])),
            ("shared", strings(shared)),
          ]),
        )
        uf_union(union, uf_find(union, i), uf_find(union, j))
      }
    }
  }
  let component_members : Map[String, Array[String]] = Map([])
  for i = 0; i < ids.length(); i = i + 1 {
    let root = uf_find(union, i).to_string()
    match component_members.get(root) {
      Some(members) => members.push(ids[i])
      None => component_members[root] = [ids[i]]
    }
  }
  let component_roots : Array[String] = []
  for root, _ in component_members {
    component_roots.push(root)
  }
  component_roots.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let components : Array[Value] = []
  let isolated : Array[String] = []
  for root in component_roots {
    let members = component_members[root]
    members.sort_by(fn(a, b) { stable_string_compare(a, b) })
    components.push(strings(members))
    if members.length() == 1 {
      isolated.push(members[0])
    }
  }
  let hub_names : Array[String] = []
  for path, _ in path_count {
    hub_names.push(path)
  }
  hub_names.sort_by(fn(a, b) {
    let ca = match path_count.get(a) {
      Some(count) => count
      None => 0
    }
    let cb = match path_count.get(b) {
      Some(count) => count
      None => 0
    }
    if ca != cb {
      cb - ca
    } else {
      stable_string_compare(a, b)
    }
  })
  let hubs : Array[Value] = []
  for path in hub_names {
    hubs.push(
      record([
        ("path", String(path)),
        (
          "rule_count",
          Number(
            (match path_count.get(path) {
              Some(count) => count
              None => 0
            }).to_double(),
          ),
        ),
      ]),
    )
  }
  let sorted_ids = ids.copy()
  sorted_ids.sort_by(fn(a, b) { stable_string_compare(a, b) })
  record([
    ("nodes", strings(sorted_ids)),
    ("edges", Array(edges)),
    ("components", Array(components)),
    ("isolated", strings(isolated)),
    ("hubs", Array(hubs)),
  ])
}
