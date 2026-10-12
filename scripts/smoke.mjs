// Full-operation smoke pass: one executable check per engine
// operation plus the compile-run loop, quantifiers, pick, AST
// interchange, coded error surfacing and JSONL isolation.
import {spawnSync} from 'node:child_process';
import {engine, root} from './engine.mjs';
import path from 'node:path';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';

const cli = path.join(root, '_build/js/debug/build/cmd/main/main.js');
const stream = (requests, suffix = '.jsonl') => {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'mpf-smoke-')), `requests${suffix}`);
  fs.writeFileSync(file, requests.map(r => JSON.stringify(r)).join('\n') + '\n');
  const result = spawnSync(process.execPath, [cli, file], {encoding: 'utf8', timeout: 120000});
  return {
    exit: result.status,
    lines: result.stdout.trim().split('\n').map(line => JSON.parse(line)),
  };
};

let passed = 0;
const check = (name, fn) => {
  fn();
  passed++;
  console.log(`ok   ${name}`);
};

check('decide', () => {
  const result = engine({
    operation: 'decide',
    rules: [{id: 'r', priority: 1, when: 'x > 5', output: 'big'}],
    facts: {x: 10},
  });
  assert.equal(result.results[0].result.decision, 'big');
});

check('evaluate', () => {
  const result = engine({operation: 'evaluate', expression: 'sum(items) / len(items)', facts: {items: [2, 4, 6]}});
  assert.equal(result.value, 4);
});

check('check', () => {
  const result = engine({operation: 'check', expression: 'amount > "x"', schema: {amount: 'number'}});
  assert.equal(result.ok, false);
});

check('serialize', () => {
  const result = engine({operation: 'serialize', expression: '(1 + 2) * 3'});
  assert.equal(result.canonical, '(1 + 2) * 3');
});

check('roundtrip', () => {
  const result = engine({operation: 'roundtrip', expression: 'a && b || c', facts: {a: true, b: false, c: true}});
  assert.equal(result.equivalent, true);
});

check('optimize', () => {
  const result = engine({operation: 'optimize', expression: 'true && flag || false'});
  assert.equal(result.canonical, 'flag');
});

check('aggregate', () => {
  const result = engine({
    operation: 'aggregate',
    facts: [{t: 'a', v: 1}, {t: 'a', v: 3}, {t: 'b', v: 10}],
    key: 't',
    metrics: [{name: 'n', op: 'count'}, {name: 'total', op: 'sum', expression: 'v'}],
  });
  assert.equal(result.groups[0].metrics.total, 4);
});

check('infer', () => {
  const result = engine({operation: 'infer', facts: [{user: {age: 30}}]});
  assert.equal(result.schema['user.age'], 'number');
});

check('analyze', () => {
  const result = engine({operation: 'analyze', rules: [{id: 'r', when: 'true', output: 1}]});
  assert.equal(result.findings[0].kind, 'tautology');
});

check('coverage', () => {
  const result = engine({
    operation: 'coverage',
    rules: [{id: 'r', when: 'x > 5'}],
    facts: [{x: 10}, {x: 1}],
  });
  assert.equal(result.rules[0].hits, 1);
});

check('rule_graph', () => {
  const result = engine({
    operation: 'rule_graph',
    rules: [{id: 'a', when: 'x > 1'}, {id: 'b', when: 'x > 2'}],
  });
  assert.equal(result.edges.length, 1);
});

check('explain', () => {
  const result = engine({
    operation: 'explain',
    rules: [{id: 'r', when: 'x > 5', output: 1}],
    facts: {x: 10},
  });
  assert.ok(result.text.includes('[PASS] r'));
});

check('diff', () => {
  const result = engine({operation: 'diff', old: [{id: 'a', when: 'true'}], new: [{id: 'a', when: 'true'}, {id: 'b', when: 'true'}]});
  assert.deepEqual(result.added, ['b']);
});

check('decision_table and decide_table', () => {
  const compiled = engine({
    operation: 'decision_table',
    table: {columns: ['amount'], rows: [{amount: '>= 100', outcome: 'high'}, {amount: '> 0', outcome: 'low'}]},
  });
  assert.equal(compiled.rule_count, 2);
  assert.equal(compiled.rules[0].when, 'amount >= 100');
  const decided = engine({
    operation: 'decide_table',
    table: {columns: ['amount'], rows: [{amount: '>= 100', outcome: 'high'}]},
    facts: {amount: 150},
  });
  assert.equal(decided.results[0].result.decision, 'high');
});

check('bundle validate and resolve', () => {
  const versions = [
    {version: '1.0.0', rules: [{id: 'base', when: 'true', output: 1}]},
    {version: '1.1.0', rules: [{id: 'base', when: 'x > 1', output: 2}]},
  ];
  const validated = engine({operation: 'bundle_validate', versions});
  assert.equal(validated.head, '1.1.0');
  const current = engine({operation: 'bundle_resolve', current: '1.0.0', versions});
  assert.equal(current.pending_count, 1);
  assert.equal(current.up_to_date, false);
});

check('quantifiers', () => {
  const result = engine({operation: 'evaluate', expression: 'count_matches(scores, ">", 5)', facts: {scores: [3, 7, 9]}});
  assert.equal(result.value, 2);
  assert.equal(engine({operation: 'evaluate', expression: 'any_match(flags)', facts: {flags: [false, true]}}).value, true);
});

check('pick projection', () => {
  const result = engine({operation: 'pick', facts: {user: {age: 30}}, paths: ['user.age', 'user.missing']});
  assert.equal(result.picked.user.age, 30);
  assert.deepEqual(result.missing, ['user.missing']);
});

check('ast interchange', () => {
  const tree = engine({operation: 'ast', expression: 'age >= 18'});
  assert.equal(tree.ast.kind, 'binary');
  const back = engine({operation: 'ast', ast: tree.ast});
  assert.equal(back.canonical, 'age >= 18');
});

check('lint governance', () => {
  const result = engine({
    operation: 'lint',
    rules: [
      {id: 'fallback', when: 'true', output: 'x'},
      {id: 'a', when: 'x > 1', output: 1},
      {id: 'b', when: 'x>1', output: 2},
    ],
  });
  assert.equal(result.ok, false);
  assert.equal(result.finding_count, 3);
  assert.equal(engine({
    operation: 'lint',
    rules: [{id: 'adult', when: 'age >= 18', output: 'adult'}],
    schema: {age: 'number'},
  }).ok, true);
});

check('fmt formatting gate', () => {
  const result = engine({
    operation: 'fmt',
    rules: [{id: 'a', when: 'age>=18', output: 1}, {id: 'b', when: 'x > 1'}],
  });
  assert.deepEqual(result.changed_ids, ['a']);
  assert.equal(result.rules[0].when, 'age >= 18');
  const only = engine({
    operation: 'fmt', changed_only: true,
    rules: [{id: 'a', when: 'age>=18'}, {id: 'b', when: 'x > 1'}],
  });
  assert.equal(only.rules.length, 1);
});

check('export_schema', () => {
  const result = engine({operation: 'export_schema', schema: {'user.age': 'number', active: 'boolean'}});
  assert.equal(result.draft, '2020-12');
  assert.equal(result.paths, 2);
});

check('migrate application', () => {
  const versions = [
    {version: '1.0.0', rules: [{id: 'base', when: 'true', output: 'v1'}]},
    {version: '1.1.0', rules: [{id: 'base', when: 'x > 1', output: 'v2'}]},
  ];
  const migrated = engine({operation: 'migrate', current: '1.0.0', versions});
  assert.equal(migrated.applied_steps, 1);
  assert.equal(migrated.program[0].output, 'v2');
  const executed = engine({operation: 'run_program', program: migrated.program, facts: {x: 5}});
  assert.equal(executed.results[0].result.decision, 'v2');
});

check('compile_rules and run_program', () => {
  const compiled = engine({operation: 'compile_rules', rules: [{id: 'r', when: 'x>=5', output: 'hit'}]});
  assert.equal(compiled.program[0].condition, 'x >= 5');
  const executed = engine({operation: 'run_program', program: compiled.program, facts: [{x: 10}, {}]});
  assert.equal(executed.results[0].result.decision, 'hit');
  assert.ok('error' in executed.results[1]);
});

check('coded error surfaces through the CLI', () => {
  assert.throws(() => engine({operation: 'evaluate', expression: '1 / 0', facts: {}}), err => String(err).includes('E2008'));
});

check('jsonl streaming honors per-line isolation', () => {
  const {exit, lines} = stream([
    {operation: 'evaluate', expression: '1 + 1', facts: {}},
    {operation: 'evaluate', expression: 'ghost', facts: {}},
    {operation: 'evaluate', expression: '2 + 2', facts: {}},
  ]);
  assert.equal(exit, 1);
  assert.deepEqual(lines[0], {value: 2});
  assert.ok(lines[1].error.includes('E2001'));
  assert.deepEqual(lines[2], {value: 4});
});

console.log(`Smoke pass complete: ${passed} checks`);
