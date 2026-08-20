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

const androidSpeakerMicrophoneMeasurement = {
  schema_version: 'audio-modem-device-acceptance/v1',
  report_type: 'measurement',
  report_id: 'DARP-android-validator-fixture',
  privacy_acknowledged: true,
  device: {
    route: 'speaker_microphone',
    source: { platform: 'android', device_class: 'built_in_speaker' },
    sink: { platform: 'android', device_class: 'built_in_microphone' },
  },
  test: {
    app_revision: '1234567',
    carrier: 'acoustic1',
    profile: 'balanced',
    fixture_path: 'crates/audio-modem-core/tests/fixtures/adlp-v1-acoustic1.wav',
    fixture_sha256: 'a'.repeat(64),
    command: 'validator fixture only; not a device observation',
  },
  evidence: {
    evidence_class: 'physical_route',
    run_count: 1,
    accepted_runs: 0,
    rejected_runs: 1,
    recording_availability: 'not_collected',
  },
  outcome: {
    classification: 'rejected',
    summary: 'Validator fixture only; not a device observation.',
  },
  adapter_observation: {
    adapter_contract: 'android-live-audio-adapter/v1',
    api_level: 26,
    operation: 'playback_capture',
    requested_format: {
      sample_rate_hz: 48000,
      channels: 1,
      sample_format: 'pcm_s16le',
    },
    effective_format: {
      sample_rate_hz: 48000,
      channels: 1,
      sample_format: 'pcm_s16le',
    },
    permission_state: 'granted',
    focus_outcome: 'granted',
    route_change_observed: false,
    interruption_policy: 'stop_no_auto_resume',
    raw_pcm_retention: 'discarded',
  },
};
validateReport(androidSpeakerMicrophoneMeasurement);

const missingAndroidObservation = structuredClone(androidSpeakerMicrophoneMeasurement);
delete missingAndroidObservation.adapter_observation;
assert.throws(
  () => validateReport(missingAndroidObservation),
  /missing adapter_observation/,
);

const invalidAndroidFormat = structuredClone(androidSpeakerMicrophoneMeasurement);
invalidAndroidFormat.adapter_observation.effective_format.sample_rate_hz = 44100;
assert.throws(
  () => validateReport(invalidAndroidFormat),
  /effective_format.sample_rate_hz must be 48000/,
);

console.log('device-acceptance validator tests passed');
