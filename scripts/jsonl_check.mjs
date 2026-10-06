import {spawnSync} from 'node:child_process';
import {engine, root} from './engine.mjs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const cli = path.join(root, '_build/js/debug/build/cmd/main/main.js');
const lines = [
  JSON.stringify({operation: 'evaluate', expression: '1 + 2 * 3', facts: {}}),
  JSON.stringify({operation: 'evaluate', expression: '1 / 0', facts: {}}),
  '',
  JSON.stringify({operation: 'evaluate', expression: 'upper(name)', facts: {name: 'bob'}}),
  'not json at all',
  JSON.stringify({operation: 'evaluate', expression: 'len(items)', facts: {items: [1, 2, 3]}}),
];
const file = path.join(os.tmpdir(), 'mpf-jsonl-check.jsonl');
fs.writeFileSync(file, lines.join('\n') + '\n');
const result = spawnSync(process.execPath, [cli, file], {
  encoding: 'utf8', timeout: 60000,
});
assert.equal(result.status, 1, 'failures imply nonzero exit');
const out = result.stdout.trim().split('\n');
assert.equal(out.length, 5, 'blank line skipped, five results');
assert.deepEqual(JSON.parse(out[0]), {value: 7});
assert.ok(JSON.parse(out[1]).error, 'division by zero becomes an error line');
assert.deepEqual(JSON.parse(out[2]), {value: 'BOB'});
assert.ok(JSON.parse(out[3]).error, 'unparseable line becomes an error line');
assert.deepEqual(JSON.parse(out[4]), {value: 3});
assert.ok(!result.stdout.includes('  "value"'), 'output stays compact');

const stdin = spawnSync(process.execPath, [cli, '-'], {
  input: lines[0], encoding: 'utf8', timeout: 60000,
});
assert.equal(stdin.status, 0, 'stdin stays single-request mode');
assert.ok(JSON.parse(stdin.stdout).value === 7);
console.log('JSONL streaming cases passed:', out.length);
