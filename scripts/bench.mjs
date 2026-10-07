import {spawnSync} from 'node:child_process';
import {engine, root} from './engine.mjs';
import path from 'node:path';
import fs from 'node:fs';

const cli = path.join(root, '_build/js/debug/build/cmd/main/main.js');
const cli_request = (request) => {
  const result = spawnSync(process.execPath, [cli, '-'], {
    input: JSON.stringify(request), encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 300000,
  });
  if (result.status !== 0) throw new Error(result.stdout || result.stderr);
  return JSON.parse(result.stdout);
};

const RULES = [
  {id: 'high', priority: 2, when: 'amount >= 800', compute: 'amount * 0.02'},
  {id: 'gold', priority: 1, when: 'tier == "gold"', output: 'gold_5pct'},
  {id: 'std', priority: 0, when: 'true', output: 'none'},
];
const TIERS = ['bronze', 'silver', 'gold'];

function bench(name, count, build) {
  const request = build(count);
  const payload = JSON.stringify(request);
  const started = process.hrtime.bigint();
  cli_request(request);
  const seconds = Number(process.hrtime.bigint() - started) / 1e9;
  const per_second = count / seconds;
  console.log(`${name.padEnd(28)} ${String(count).padStart(7)} records  ${seconds.toFixed(2)}s  ${Math.round(per_second).toLocaleString('en-US')} records/s`);
  fs.writeFileSync(`/tmp/mpf-bench-${name.split(' ')[0]}.json`, String(Math.round(per_second)));
}

bench('decide first', 20000, (count) => ({
  operation: 'decide', rules: RULES, mode: 'first',
  facts: Array.from({length: count}, (_, i) => ({amount: (i * 37) % 1000, tier: TIERS[i % 3]})),
}));
bench('decide all', 20000, (count) => ({
  operation: 'decide', rules: RULES, mode: 'all',
  facts: Array.from({length: count}, (_, i) => ({amount: (i * 37) % 1000, tier: TIERS[i % 3]})),
}));
bench('decide unique', 20000, (count) => ({
  operation: 'decide', rules: RULES, mode: 'unique',
  facts: Array.from({length: count}, (_, i) => ({amount: (i * 37) % 1000, tier: TIERS[i % 3]})),
}));
bench('aggregate', 20000, (count) => ({
  operation: 'aggregate',
  facts: Array.from({length: count}, (_, i) => ({amount: (i * 37) % 1000, tier: TIERS[i % 3]})),
  key: 'tier',
  metrics: [
    {name: 'n', op: 'count'},
    {name: 'total', op: 'sum', expression: 'amount'},
    {name: 'avg', op: 'avg', expression: 'amount'},
  ],
}));
bench('evaluate expressions', 2000, (count) => ({
  operation: 'decide',
  rules: [{id: 'calc', priority: 1, when: 'true', compute: '(price - discount) * quantity >= 100 && upper(tier) == "GOLD"'}],
  mode: 'all',
  facts: Array.from({length: count}, (_, i) => ({price: 50, discount: 10, quantity: 3, tier: 'gold'})),
}));
console.log('Benchmarks completed');
