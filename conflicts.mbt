///|
/// Semantic condition relations.
///
/// analyze detects textual duplicates; conflicts goes further for the
/// fragment business rules actually live in: conjunctions of numeric
/// range atoms (path op literal). For every rule pair it decomposes
/// both conditions into per-path interval constraints and reports:
///
/// - `disjoint`: some shared path has provably non-overlapping ranges,
///   so the pair can never both match (unique mode is safe for them;
///   first mode has a dead branch somewhere).
/// - `subsumes A -> B`: rule B's condition implies rule A's — wherever
///   B matches, A matches too, so under first mode B only wins by
///   priority, and lower-priority B is unreachable.
///
/// Conditions outside the fragment (disjunctions at any level, string
/// literals, non-conjunct shapes) are marked `unanalyzed` and skipped,
/// keeping every reported relation sound.

///|
priv enum Bound {
  Lower(Double, Bool) // value, is_inclusive
  Upper(Double, Bool)
  Equal(Double)
  NotEqual(Double)
} derive(Eq)

///|
priv struct Atom {
  path : String
  bound : Bound
}

///|
fn decompose(
  expr : Expression,
  atoms : Array[Atom],
) -> Bool {
  // Returns false when the condition leaves the analyzable fragment.
  match expr {
    Binary("&&", left, right) => decompose(left, atoms) && decompose(right, atoms)
    Binary(op, Variable(path), Literal(Number(value))) => {
      let bound = match op {
        ">" => Lower(value, false)
        ">=" => Lower(value, true)
        "<" => Upper(value, false)
        "<=" => Upper(value, true)
        "==" => Equal(value)
        "!=" => NotEqual(value)
        _ => return false
      }
      atoms.push({ path, bound })
      true
    }
    Binary(op2, Literal(Number(value)), Variable(path)) => {
      // mirrored comparison: 5 < x  =>  x > 5
      let bound = match op2 {
        "<" => Lower(value, false)
        "<=" => Lower(value, true)
        ">" => Upper(value, false)
        ">=" => Upper(value, true)
        "==" => Equal(value)
        "!=" => NotEqual(value)
        _ => return false
      }
      atoms.push({ path, bound })
      true
    }
    Binary("||", _, _) => false
    Binary(_, _, _) => false
    Call("exists", [Variable(_)]) => true // no numeric constraint, harmless
    _ => false
  }
}

///|
fn implies_single(a : Bound, b : Bound) -> Bool {
  // Does a (the implied-from atom) entail b? a is the tighter rule's
  // constraint; we ask whether a's constraint satisfies b's.
  match (a, b) {
    (Lower(va, ia), Lower(vb, ib)) =>
      va > vb || (va == vb && (ib || !ia))
    (Upper(va, ia), Upper(vb, ib)) =>
      va < vb || (va == vb && (ib || !ia))
    (Equal(va), Lower(vb, ib)) => va > vb || (va == vb && ib)
    (Equal(va), Upper(vb, ib)) => va < vb || (va == vb && ib)
    (Equal(va), Equal(vb)) => va == vb
    (_, Equal(vb)) => false // range alone cannot entail an equality
    (_, NotEqual(_)) => false // conservative: ranges do not entail neq
    (NotEqual(va), Lower(vb, _)) => va >= vb
    (NotEqual(va), Upper(vb, _)) => va <= vb
    (NotEqual(_), NotEqual(_)) => false
    (_, _) => false
  }
}

///|
fn atoms_imply(as_ : Array[Atom], bs : Array[Atom]) -> Bool {
  // Every constraint in bs is entailed by the conjunction in as_.
  for b in bs {
    if b.bound is NotEqual(_) {
      // a not-equal is only entailed by the same not-equal
      let mut found = false
      for a in as_ {
        if a.path == b.path && a.bound == b.bound {
          found = true
        }
      }
      if !found {
        return false
      }
      continue
    }
    let mut entailed = false
    for a in as_ {
      if a.path == b.path && implies_single(a.bound, b.bound) {
        entailed = true
      }
    }
    if !entailed {
      return false
    }
  }
  true
}

///|
fn ranges_disjoint(as_ : Array[Atom], bs : Array[Atom]) -> Bool {
  // Two constraint sets on a shared path are disjoint when some pair
  // of bounds cannot both hold: a strict lower at or above an upper,
  // or equalities at different values.
  let mut i = 0
  while i < as_.length() {
    let a = as_[i]
    let mut j = 0
    while j < bs.length() {
      let b = bs[j]
      if a.path == b.path {
        let hit = match (a.bound, b.bound) {
          (Equal(va), Equal(vb)) => va != vb
          (Equal(va), Upper(vb, ib)) => va > vb || (va == vb && !ib)
          (Upper(va, ia), Equal(vb)) => va < vb || (va == vb && !ia)
          (Equal(va), Lower(vb, ib)) => va < vb || (va == vb && !ib)
          (Lower(va, ia), Equal(vb)) => va > vb || (va == vb && !ia)
          (Lower(va, ia), Upper(vb, ib)) =>
            va > vb || (va == vb && !(ia && ib))
          (Upper(va, ia), Lower(vb, ib)) =>
            va < vb || (va == vb && !(ia && ib))
          (_, _) => false
        }
        if hit {
          return true
        }
      }
      j += 1
    }
    i += 1
  }
  false
}

///|
priv struct CompiledRule {
  id : String
  atoms : Array[Atom]
  analyzable : Bool
}

///|
fn conflicts_request(request : Value) -> Value raise {
  let rules = arr(get(request, "rules"))
  let compiled : Array[CompiledRule] = []
  let mut index = 0
  for item in rules {
    let id = str(get(item, "id"))
    let condition = compile(str(get(item, "when")))
    let atoms : Array[Atom] = []
    let analyzable = decompose(condition, atoms)
    compiled.push({ id, atoms, analyzable })
    index += 1
  }
  ignore(index)
  let relations : Array[Value] = []
  for i = 0; i < compiled.length(); i = i + 1 {
    for j = i + 1; j < compiled.length(); j = j + 1 {
      let a = compiled[i]
      let b = compiled[j]
      let pair : Map[String, Value] = Map([])
      pair["a"] = String(a.id)
      pair["b"] = String(b.id)
      if !a.analyzable || !b.analyzable {
        pair["relation"] = String("unanalyzed")
        relations.push(Object(pair))
        continue
      }
      if ranges_disjoint(a.atoms, b.atoms) {
        pair["relation"] = String("disjoint")
        relations.push(Object(pair))
        continue
      }
      // Standard subsumption naming: X subsumes Y when X is the more
      // general condition (every Y match is also an X match).
      let a_implies_b = atoms_imply(a.atoms, b.atoms) // a tighter: a matches => b matches
      let b_implies_a = atoms_imply(b.atoms, a.atoms)
      if a_implies_b && b_implies_a {
        pair["relation"] = String("equivalent")
        relations.push(Object(pair))
      } else if a_implies_b {
        pair["relation"] = String("b_subsumes_a")
        relations.push(Object(pair))
      } else if b_implies_a {
        pair["relation"] = String("a_subsumes_b")
        relations.push(Object(pair))
      }
    }
  }
  let counts : Map[String, Int] = Map([])
  for relation in relations {
    let kind = match get(relation, "relation") {
      String(name) => name
      _ => "?"
    }
    match counts.get(kind) {
      Some(n) => counts[kind] = n + 1
      None => counts[kind] = 1
    }
  }
  let kinds = ["disjoint", "equivalent", "a_subsumes_b", "b_subsumes_a", "unanalyzed"]
  let summary : Array[Value] = []
  for kind in kinds {
    summary.push(
      record([
        ("relation", String(kind)),
        (
          "count",
          Number((match counts.get(kind) {
            Some(n) => n
            None => 0
          }).to_double()),
        ),
      ]),
    )
  }
  record([
    ("pairs", Array(relations)),
    ("pair_count", Number(relations.length().to_double())),
    ("summary", Array(summary)),
  ])
}
