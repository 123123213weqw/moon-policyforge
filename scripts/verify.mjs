// One-command verification ladder: every stage runs through the real
// CLI and any failure exits nonzero with the offending stage's output.
// Usage: node scripts/verify.mjs [--quick]   (--quick skips scale+fuzz)
import {spawnSync} from 'node:child_process';
import {root} from './engine.mjs';
import path from 'node:path';

const quick = process.argv.includes('--quick');

const run = (name, command, args) => {
  process.stdout.write(`${name.padEnd(34)} `);
  const result = spawnSync(command, args, {
    cwd: root, encoding: 'utf8', timeout: 600000,
    maxBuffer: 64 * 1024 * 1024,
  });
  const tail = (result.stdout || '').trim().split('\n').pop();
  if (result.status !== 0) {
    console.log(`FAIL (exit ${result.status})`);
    console.log((result.stdout || '') + (result.stderr || ''));
    process.exit(1);
  }
  console.log(tail || 'ok');
};

run('white-box + CLI fixtures', 'node', ['scripts/check.mjs']);
run('jsonl streaming', 'node', ['scripts/jsonl_check.mjs']);
run('smoke pass', 'node', ['scripts/smoke.mjs']);
run('python arithmetic oracle', 'python3', ['-B', 'scripts/reference.py']);
if (!quick) {
  run('documentation replay', 'python3', ['-B', 'scripts/check_docs.py']);
  run('error-code taxonomy', 'python3', ['-B', 'scripts/error_codes.py']);
  run('scale validation (100k)', 'python3', ['-B', 'scripts/scale_check.py']);
  run('expression differential fuzz', 'python3', ['-B', 'scripts/fuzz_diff.py']);
  run('decide differential fuzz', 'python3', ['-B', 'scripts/fuzz_rules.py']);
}
console.log('All verification stages passed');
