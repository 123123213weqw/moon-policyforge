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

check('validate facts', () => {
  const result = engine({
    operation: 'validate',
    schema: {age: 'number'},
    required: ['age'],
    facts: [{age: 30}, {}, {age: 'x'}],
  });
  assert.equal(result.error_records, 2);
  assert.equal(result.results[0].ok, true);
  assert.equal(result.results[1].errors[0].found, 'missing');
  assert.equal(result.results[2].errors[0].found, 'string');
});

check('conflicts relations', () => {
  const result = engine({
    operation: 'conflicts',
    rules: [
      {id: 'a', when: 'amount > 5'},
      {id: 'b', when: 'amount > 10'},
      {id: 'c', when: 'amount < 0'},
    ],
  });
  assert.equal(result.pairs[0].relation, 'a_subsumes_b');
  assert.equal(result.pairs[1].relation, 'disjoint');
});

check('stats self-description', () => {
  const result = engine({
    operation: 'stats',
    rules: [{id: 'a', priority: 2, when: 'amount > 10', compute: 'amount * 0.1'}],
  });
  assert.equal(result.compute_count, 1);
  assert.equal(result.max_priority, 2);
  assert.equal(result.paths[0].path, 'amount');
});

check('snapshot and compare regression', () => {
  const rules = [{id: 'adult', priority: 2, when: 'age >= 18', output: 'adult'}];
  const facts = [{age: 20}, {age: 10}];
  const snap = engine({operation: 'snapshot', rules, facts});
  assert.equal(snap.count, 2);
  const same = engine({operation: 'compare', rules, facts, snapshots: snap.snapshots});
  assert.equal(same.ok, true);
  assert.equal(same.unchanged, 2);
  const edited = [{id: 'adult', priority: 2, when: 'age >= 25', output: 'adult'}];
  const diff = engine({operation: 'compare', rules: edited, facts, snapshots: snap.snapshots});
  assert.equal(diff.ok, false);
  assert.equal(diff.changed, 1);
});

check('plan_waves', () => {
  const result = engine({
    operation: 'plan_waves',
    rules: [{id: 'a', when: 'amount > 1'}, {id: 'b', when: 'amount > 2'}, {id: 'c', when: 'color != null'}],
  });
  assert.equal(result.wave_count, 2);
  assert.deepEqual(result.waves[0].rules, ['a', 'b']);
});

check('template rendering', () => {
  const result = engine({
    operation: 'template',
    rules: [{id: 'vip_{{tier}}', when: 'total >= {{min}}', compute: 'total * {{rate}}'}],
    params: {tier: 'gold', min: 500, rate: 0.15},
  });
  assert.equal(result.ok, true);
  assert.equal(result.rules[0].when, 'total >= 500');
  assert.equal(result.rules[0].compute, 'total * 0.15');
});

check('score complexity', () => {
  const result = engine({
    operation: 'score',
    rules: [{id: 'easy', when: 'age >= 18'}, {id: 'tangled', when: '(a && b) || (c && d) || (e && f) || (g && h) || (i && j) || (k && l)'}],
  });
  assert.equal(result.rules[0].rank, 'simple');
  assert.equal(result.rules[1].rank, 'complex');
  assert.ok(result.rules[1].reasons.length > 0);
});

check('explain_rules phrasing', () => {
  const result = engine({
    operation: 'explain_rules',
    rules: [{id: 'adult', when: 'age >= 18'}],
  });
  assert.equal(result.explanations[0].explanation, 'Age must be at least 18.');
});

check('merge provenance', () => {
  const result = engine({
    operation: 'merge', strategy: 'last',
    sets: [
      {name: 'base', rules: [{id: 'shared', when: 'x > 1', output: 1}]},
      {name: 'overlay', rules: [{id: 'shared', when: 'x > 1', output: 2}]},
    ],
  });
  assert.equal(result.conflict_count, 1);
  assert.equal(result.rule_count, 1);
  assert.equal(result.rules[0].origin, 'overlay');
  assert.equal(result.rules[0].rule.output, 2);
});

check('matrix mode comparison', () => {
  const result = engine({
    operation: 'matrix',
    rules: [{id: 'a', priority: 2, when: 'age >= 18', output: 'adult'}, {id: 'senior', priority: 3, when: 'age >= 65', output: 'senior'}],
    facts: [{age: 70}, {age: 30}],
  });
  assert.equal(result.disagreements, 1);
  assert.equal(result.rows[0].all_count, 2);
});

check('audit trail', () => {
  const result = engine({
    operation: 'audit',
    rules: [{id: 'a', when: 'x > 1', output: 1}],
    facts: [{x: 5}],
  });
  assert.ok(result.rule_digest.length > 0);
  assert.equal(result.entries[0].matched[0].id, 'a');
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
