///|
extern "js" fn read_input(path : String) -> String =
  #| (path) => {
  #|   const fs = process.getBuiltinModule('node:fs');
  #|   const bytes = fs.readFileSync(path === '-' ? 0 : path);
  #|   if (bytes.length > 16777216) throw new Error('input exceeds 16 MiB');
  #|   return new TextDecoder('utf-8', {fatal:true}).decode(bytes);
  #| }

///|
extern "js" fn status(code : Int32) -> Unit =
  #| (code) => { process.exitCode = code; }

///|
/// Executes one parsed request. Returns the compact JSON result line
/// and whether the request failed; the caller keeps streaming so one
/// bad request never hides later results.

///|
/// True when a completed report carries findings: a top-level `ok: false`
/// (lint, compare drift) or a non-empty `findings` array (lint, analyze).
fn flagged(output : Json) -> Bool {
  match output {
    Json::Object(fields) =>
      match fields.get("ok") {
        Some(Json::False) => true
        _ =>
          match fields.get("findings") {
            Some(Json::Array(items)) => !items.is_empty()
            _ => false
          }
      }
    _ => false
  }
}

///|
fn process_line(request : Json) -> (String, Bool) {
  try {
    let output = @engine.execute(request)
    (output.stringify(), flagged(output))
  } catch {
    error =>
      (
        Json::object({ "error": Json::string(error.to_string()) }).stringify(),
        true,
      )
  }
}

///|
/// Streams newline-delimited JSON requests: one compact JSON result per
/// input line, blank lines skipped. Returns the number of lines that
/// failed or carried findings.
fn run_jsonl(content : String) -> Int32 {
  let mut failures = 0
  let mut index = 0
  for line in content.split("\n") {
    index += 1
    let text = line.trim().to_owned()
    if text == "" {
      continue
    }
    let line : String = try {
      let (rendered, failed) = process_line(@json.parse(text))
      if failed {
        failures += 1
      }
      rendered
    } catch {
      error => {
        failures += 1
        Json::object({ "error": Json::string(error.to_string()) }).stringify()
      }
    }
    println(line)
  }
  ignore(index)
  failures
}

///|
/// True when the input path selects newline-delimited streaming mode.
fn is_jsonl_path(path : String) -> Bool {
  path.has_suffix(".jsonl")
}

///|
fn main {
  let args = @env.args()
  if args.length() != 3 {
    println(
      "Usage: moon run cmd/main --target js -- request.json (or - for stdin; .jsonl streams one result per line)",
    )
    status(2)
  } else {
    let path = args[2]
    let input = read_input(path)
    if is_jsonl_path(path) {
      let failures = run_jsonl(input)
      if failures > 0 {
        status(1)
      }
    } else {
      try {
        let request = @json.parse(input)
        let output = @engine.execute(request)
        println(output.stringify(indent=2))
        // Exit codes: 0 clean report, 1 rejected request, 2 report with findings.
        if flagged(output) {
          status(2)
        }
      } catch {
        error => {
          println(
            Json::object({ "error": Json::string(error.to_string()) }).stringify(),
          )
          status(1)
        }
      }
    }
  }
}
