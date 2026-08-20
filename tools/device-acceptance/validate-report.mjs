import { readFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';

const SCHEMA_VERSION = 'audio-modem-device-acceptance/v1';
const REPORT_ID = /^DARP-[a-z0-9-]{3,64}$/;
const REVISION = /^[0-9a-f]{7,40}$/;
const SHA256 = /^[0-9a-f]{64}$/;
const PROFILES = new Set(['reliable', 'balanced', 'fast', 'narrowband']);
const ROUTES = new Set(['speaker_microphone', 'audio_cable', 'bluetooth', 'radio_interface']);
const PLATFORMS = new Set(['android', 'ios', 'windows', 'macos', 'linux', 'web', 'external']);
const EVIDENCE_CLASSES = new Set(['codec_reproduction', 'controlled_pcm', 'physical_route']);
const RECORDING_AVAILABILITY = new Set([
  'not_collected',
  'private_available_on_request',
  'public_redacted',
  'public_unrestricted',
]);
const OUTCOME_CLASSES = new Set(['observed', 'inconclusive', 'rejected']);
const ANDROID_ADAPTER_CONTRACT = 'android-live-audio-adapter/v1';

function fail(message) {
  throw new Error(message);
}

function object(value, field) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${field} must be an object`);
  }
  return value;
}

function string(value, field, { min = 1, max = Number.MAX_SAFE_INTEGER, pattern } = {}) {
  if (typeof value !== 'string' || value.length < min || value.length > max) {
    fail(`${field} must be a string with length ${min}..${max}`);
  }
  if (pattern && !pattern.test(value)) {
    fail(`${field} has an invalid format`);
  }
}

function integer(value, field, minimum = 0) {
  if (!Number.isInteger(value) || value < minimum) {
    fail(`${field} must be an integer >= ${minimum}`);
  }
}

function onlyKeys(value, field, allowed) {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      fail(`${field}.${key} is not allowed`);
    }
  }
}

function required(value, field) {
  if (!(field in value)) {
    fail(`missing ${field}`);
  }
  return value[field];
}

function validateEndpoint(value, field) {
  const endpoint = object(value, field);
  onlyKeys(endpoint, field, new Set(['platform', 'device_class', 'public_model']));
  const platform = required(endpoint, 'platform');
  if (!PLATFORMS.has(platform)) {
    fail(`${field}.platform is unsupported`);
  }
  string(required(endpoint, 'device_class'), `${field}.device_class`, { min: 1, max: 80 });
  if ('public_model' in endpoint) {
    string(endpoint.public_model, `${field}.public_model`, { min: 1, max: 120 });
  }
}

function isAndroidSpeakerMicrophone(report) {
  return (
    report.device?.route === 'speaker_microphone' &&
    report.device?.source?.platform === 'android' &&
    report.device?.sink?.platform === 'android'
  );
}

function validateAudioModemV1Format(value, field) {
  const format = object(value, field);
  onlyKeys(format, field, new Set(['sample_rate_hz', 'channels', 'sample_format']));
  if (required(format, 'sample_rate_hz') !== 48000) {
    fail(`${field}.sample_rate_hz must be 48000`);
  }
  if (required(format, 'channels') !== 1) {
    fail(`${field}.channels must be 1`);
  }
  if (required(format, 'sample_format') !== 'pcm_s16le') {
    fail(`${field}.sample_format must be pcm_s16le`);
  }
}

function validateAndroidAdapterObservation(value) {
  const observation = object(value, 'adapter_observation');
  onlyKeys(
    observation,
    'adapter_observation',
    new Set([
      'adapter_contract',
      'api_level',
      'operation',
      'requested_format',
      'effective_format',
      'permission_state',
      'focus_outcome',
      'route_change_observed',
      'interruption_policy',
      'raw_pcm_retention',
    ]),
  );
  if (required(observation, 'adapter_contract') !== ANDROID_ADAPTER_CONTRACT) {
    fail('adapter_observation.adapter_contract is unsupported');
  }
  integer(required(observation, 'api_level'), 'adapter_observation.api_level', 26);
  if (required(observation, 'operation') !== 'playback_capture') {
    fail('adapter_observation.operation must be playback_capture');
  }
  validateAudioModemV1Format(
    required(observation, 'requested_format'),
    'adapter_observation.requested_format',
  );
  validateAudioModemV1Format(
    required(observation, 'effective_format'),
    'adapter_observation.effective_format',
  );
  if (required(observation, 'permission_state') !== 'granted') {
    fail('adapter_observation.permission_state must be granted');
  }
  const focusOutcome = required(observation, 'focus_outcome');
  if (focusOutcome !== 'granted' && focusOutcome !== 'delayed_then_granted') {
    fail('adapter_observation.focus_outcome is unsupported');
  }
  if (typeof required(observation, 'route_change_observed') !== 'boolean') {
    fail('adapter_observation.route_change_observed must be a boolean');
  }
  if (required(observation, 'interruption_policy') !== 'stop_no_auto_resume') {
    fail('adapter_observation.interruption_policy must be stop_no_auto_resume');
  }
  if (required(observation, 'raw_pcm_retention') !== 'discarded') {
    fail('adapter_observation.raw_pcm_retention must be discarded');
  }
}

function validateMeasurement(report) {
  for (const field of ['device', 'test', 'evidence', 'outcome']) {
    required(report, field);
  }
  const device = object(report.device, 'device');
  onlyKeys(device, 'device', new Set(['route', 'source', 'sink']));
  if (!ROUTES.has(required(device, 'route'))) {
    fail('device.route is unsupported');
  }
  validateEndpoint(required(device, 'source'), 'device.source');
  validateEndpoint(required(device, 'sink'), 'device.sink');

  const test = object(report.test, 'test');
  onlyKeys(test, 'test', new Set(['app_revision', 'carrier', 'profile', 'fixture_path', 'fixture_sha256', 'command']));
  string(required(test, 'app_revision'), 'test.app_revision', { pattern: REVISION });
  if (required(test, 'carrier') !== 'acoustic1') {
    fail('test.carrier must be acoustic1');
  }
  if (!PROFILES.has(required(test, 'profile'))) {
    fail('test.profile is unsupported');
  }
  string(required(test, 'fixture_path'), 'test.fixture_path', { pattern: /^[A-Za-z0-9._/-]+$/ });
  string(required(test, 'fixture_sha256'), 'test.fixture_sha256', { pattern: SHA256 });
  string(required(test, 'command'), 'test.command', { min: 1, max: 2000 });

  const evidence = object(report.evidence, 'evidence');
  onlyKeys(evidence, 'evidence', new Set(['evidence_class', 'run_count', 'accepted_runs', 'rejected_runs', 'recording_availability', 'recording_sha256']));
  if (!EVIDENCE_CLASSES.has(required(evidence, 'evidence_class'))) {
    fail('evidence.evidence_class is unsupported');
  }
  integer(required(evidence, 'run_count'), 'evidence.run_count', 1);
  integer(required(evidence, 'accepted_runs'), 'evidence.accepted_runs');
  integer(required(evidence, 'rejected_runs'), 'evidence.rejected_runs');
  if (evidence.accepted_runs + evidence.rejected_runs !== evidence.run_count) {
    fail('evidence accepted_runs + rejected_runs must equal run_count');
  }
  if (!RECORDING_AVAILABILITY.has(required(evidence, 'recording_availability'))) {
    fail('evidence.recording_availability is unsupported');
  }
  if (evidence.recording_availability !== 'not_collected') {
    string(required(evidence, 'recording_sha256'), 'evidence.recording_sha256', { pattern: SHA256 });
  }

  const outcome = object(report.outcome, 'outcome');
  onlyKeys(outcome, 'outcome', new Set(['classification', 'summary']));
  if (!OUTCOME_CLASSES.has(required(outcome, 'classification'))) {
    fail('outcome.classification is unsupported');
  }
  string(required(outcome, 'summary'), 'outcome.summary', { min: 1, max: 1000 });

  if (isAndroidSpeakerMicrophone(report)) {
    validateAndroidAdapterObservation(required(report, 'adapter_observation'));
  } else if ('adapter_observation' in report) {
    fail('adapter_observation is only allowed for Android speaker_microphone measurements');
  }
}

export function validateReport(report) {
  const value = object(report, 'report');
  onlyKeys(value, 'report', new Set(['schema_version', 'report_type', 'report_id', 'privacy_acknowledged', 'notes', 'device', 'test', 'evidence', 'outcome', 'adapter_observation']));
  if (required(value, 'schema_version') !== SCHEMA_VERSION) {
    fail('schema_version is unsupported');
  }
  const reportType = required(value, 'report_type');
  if (reportType !== 'template' && reportType !== 'measurement') {
    fail('report_type must be template or measurement');
  }
  string(required(value, 'report_id'), 'report_id', { pattern: REPORT_ID });
  if (required(value, 'privacy_acknowledged') !== true) {
    fail('privacy_acknowledged must be true');
  }
  if ('notes' in value) {
    string(value.notes, 'notes', { min: 1, max: 1000 });
  }
  if (reportType === 'template') {
    for (const field of ['device', 'test', 'evidence', 'outcome', 'adapter_observation']) {
      if (field in value) {
        fail(`template report must not contain ${field}`);
      }
    }
    return;
  }
  validateMeasurement(value);
}

function main() {
  const reportPath = process.argv[2];
  if (!reportPath || process.argv.length !== 3) {
    console.error('Usage: node tools/device-acceptance/validate-report.mjs <report.json>');
    process.exitCode = 2;
    return;
  }
  const absolutePath = resolve(reportPath);
  let report;
  try {
    report = JSON.parse(readFileSync(absolutePath, 'utf8'));
    validateReport(report);
  } catch (error) {
    console.error(`invalid device-acceptance report ${basename(absolutePath)}: ${error.message}`);
    process.exitCode = 1;
    return;
  }
  console.log(`valid device-acceptance report: ${basename(absolutePath)} (${report.report_type})`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
