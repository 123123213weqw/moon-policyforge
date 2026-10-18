///|
/// Decision regression snapshots.
///
/// The snapshot operation runs a rule set over a fact batch and
/// returns a compact fingerprint per record: the decision value, the
/// sorted matched-rule IDs and the conflict flag, hashed into a short
/// digest. The compare operation re-decides and diffs against a
/// stored snapshot, reporting exactly which records changed and what
/// the old and new decisions were. This is the regression gate for
/// rule edits: capture before, compare after, review every diff.

///|

///|
/// Deterministic 32-bit FNV-1a over a byte sequence, rendered as 8
/// hex characters. Self-implemented so the fingerprint is identical
/// across all four backends without external digest dependencies;
/// collision risk at decision-snapshot counts is negligible.
fn fnv1a32(bytes : Array[Byte]) -> String {
  let mut h = 0x811c9dc5U
  let prime = 0x01000193U
  for b in bytes {
    h = (h ^ b.to_uint()) * prime
  }
  h.to_string(radix=16)
}

///|
fn fingerprint_of(result : Value) -> String raise {
  let matched_ids : Array[String] = []
  match get(result, "matched") {
    Array(matched) =>
      for entry in matched {
        matched_ids.push(str(get(entry, "id")))
      }
    _ => ()
  }
  matched_ids.sort_by(fn(a, b) { stable_string_compare(a, b) })
  let conflict = get(result, "conflict") is Bool(true)
  let fingerprint : Map[String, Value] = Map([])
  fingerprint["decision"] = get(result, "decision")
  fingerprint["matched"] = strings(matched_ids)
  fingerprint["conflict"] = Bool(conflict)
  let canonical_text = canonical(Object(fingerprint))
  let bytes : Array[Byte] = []
  for ch in canonical_text {
    let code = ch.to_int()
    if code < 128 {
      bytes.push(code.to_byte())
    } else {
      // two-byte UTF-8 is enough for the identifier and decimal space
      bytes.push((0xC0 | (code >> 6)).to_byte())
      bytes.push((0x80 | (code & 0x3F)).to_byte())
    }
  }
  fnv1a32(bytes)
}

///|
fn snapshot_request(request : Value) -> Value raise {
  let mode = optional_str(get(request, "mode"), "first")
  let decided = run(
    record([
      ("operation", String("decide")),
      ("rules", get(request, "rules")),
      ("facts", get(request, "facts")),
      ("mode", String(mode)),
      ("default", get(request, "default")),
      ("budget", get(request, "budget")),
    ]),
  )
  match get(decided, "results") {
    Array(results) => {
      let fingerprints : Array[Value] = []
      for entry in results {
        let fp = match get(entry, "result") {
          Object(_) => String(fingerprint_of(get(entry, "result")))
          _ => String("error")
        }
        fingerprints.push(
          record([("index", get(entry, "index")), ("fingerprint", fp)]),
        )
      }
      record([
        ("snapshots", Array(fingerprints)),
        ("count", Number(fingerprints.length().to_double())),
      ])
    }
    _ => raise input_error("E3002", "decide produced no results")
  }
}

///|
fn compare_request(request : Value) -> Value raise {
  let current = get(snapshot_request(request), "snapshots")
  let stored = arr(get(request, "snapshots"))
  if stored.length() == 0 {
    raise input_error("E3002", "compare needs a stored snapshot")
  }
  let stored_by_index : Map[Int32, String] = Map([])
  for entry in stored {
    let index = num(get(entry, "index")).to_int()
    stored_by_index[index] = str(get(entry, "fingerprint"))
  }
  let diffs : Array[Value] = []
  let mut same = 0
  let mut missing = 0
  let mut added = 0
  match current {
    Array(entries) =>
      for entry in entries {
        let index = num(get(entry, "index")).to_int()
        let now = str(get(entry, "fingerprint"))
        match stored_by_index.get(index) {
          None => {
            added += 1
            diffs.push(
              record([
                ("index", Number(index.to_double())),
                ("kind", String("added")),
                ("fingerprint", String(now)),
              ]),
            )
          }
          Some(before) =>
            if before != now {
              diffs.push(
                record([
                  ("index", Number(index.to_double())),
                  ("kind", String("changed")),
                  ("before", String(before)),
                  ("after", String(now)),
                ]),
              )
            } else {
              same += 1
            }
        }
      }
    _ => ()
  }
  for index, _ in stored_by_index {
    let mut found = false
    match current {
      Array(entries) =>
        for entry in entries {
          if num(get(entry, "index")).to_int() == index {
            found = true
          }
        }
      _ => ()
    }
    if !found {
      missing += 1
      diffs.push(
        record([
          ("index", Number(index.to_double())),
          ("kind", String("removed")),
        ]),
      )
    }
  }
  // Sort outside the raising context: precompute indices first.
  let indexed : Array[(Double, Value)] = []
  for diff in diffs {
    let index_value = match get(diff, "index") {
      Number(n) => n
      _ => 0.0
    }
    indexed.push((index_value, diff))
  }
  indexed.sort_by(fn(a, b) { a.0.compare(b.0) })
  let sorted_diffs : Array[Value] = []
  for pair in indexed {
    sorted_diffs.push(pair.1)
  }
  let diffs = sorted_diffs
  record([
    ("ok", Bool(diffs.is_empty())),
    ("unchanged", Number(same.to_double())),
    ("changed", Number((diffs.length() - added - missing).to_double())),
    ("added", Number(added.to_double())),
    ("removed", Number(missing.to_double())),
    ("diffs", Array(diffs)),
  ])
}
