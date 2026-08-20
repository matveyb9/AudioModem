import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { validateReport } from './validate-report.mjs';

function fixture(name) {
  return JSON.parse(readFileSync(resolve('tools/device-acceptance/fixtures', name), 'utf8'));
}

validateReport(fixture('report-template-v1.json'));
assert.throws(
  () => validateReport(fixture('invalid-template-with-evidence.json')),
  /template report must not contain evidence/,
);
assert.throws(
  () => validateReport(fixture('invalid-measurement-missing-evidence.json')),
  /missing device/,
);

console.log('device-acceptance validator tests passed');
