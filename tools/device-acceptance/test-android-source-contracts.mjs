#!/usr/bin/env node

/**
 * Source-only guard for the Android live-audio v1 boundary.
 *
 * It intentionally validates declarations shared across Flutter, Kotlin,
 * Gradle and the manifest without claiming an APK, emulator or physical-route
 * result. Runtime/device acceptance belongs to separately reviewed evidence.
 */
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repository = resolve(here, '../..');

const paths = {
  gradle: resolve(repository, 'apps/audio_modem/android/app/build.gradle.kts'),
  bridgeGradle: resolve(repository, 'apps/audio_modem/rust_builder/android/build.gradle'),
  manifest: resolve(
    repository,
    'apps/audio_modem/android/app/src/main/AndroidManifest.xml',
  ),
  kotlin: resolve(
    repository,
    'apps/audio_modem/android/app/src/main/kotlin/org/audiomodem/audio_modem/MainActivity.kt',
  ),
  dartAdapter: resolve(
    repository,
    'apps/audio_modem/lib/platform/android_live_audio_adapter.dart',
  ),
  dartContract: resolve(
    repository,
    'apps/audio_modem/lib/platform/live_audio_adapter.dart',
  ),
};

const contents = Object.fromEntries(
  await Promise.all(
    Object.entries(paths).map(async ([key, path]) => [key, await readFile(path, 'utf8')]),
  ),
);

let failures = 0;

function expect(source, pattern, description) {
  if (pattern.test(source)) {
    console.log(`PASS ${description}`);
    return;
  }
  failures += 1;
  console.error(`FAIL ${description}`);
}

expect(
  contents.gradle,
  /minSdk\s*=\s*26\b/,
  'Gradle declares Android API 26 as the install floor',
);
expect(
  contents.bridgeGradle,
  /compileSdkVersion\s+36\b/,
  'generated Rust bridge library compiles against Android API 36',
);
expect(
  contents.manifest,
  /<uses-permission\s+android:name="android\.permission\.RECORD_AUDIO"\s*\/>/,
  'manifest declares RECORD_AUDIO',
);
expect(
  contents.kotlin,
  /const val CHANNEL\s*=\s*"org\.audiomodem\.audio_modem\/live_audio_v1"/,
  'Kotlin host declares the canonical MethodChannel name',
);
expect(
  contents.kotlin,
  /EventChannel\([^\n]+"\$CHANNEL\/capture_frames"\)/,
  'Kotlin host derives the canonical capture EventChannel name',
);
expect(
  contents.kotlin,
  /const val SAMPLE_RATE_HZ\s*=\s*48_000[\s\S]*const val CHANNELS\s*=\s*1[\s\S]*const val SAMPLE_FORMAT\s*=\s*"pcm_s16le"/,
  'Kotlin host declares 48 kHz mono signed PCM16 LE',
);
expect(
  contents.kotlin,
  /Build\.VERSION\.SDK_INT\s*<\s*Build\.VERSION_CODES\.O/,
  'Kotlin availability rejects API levels below 26',
);
expect(
  contents.dartAdapter,
  /static const _channelName\s*=\s*'org\.audiomodem\.audio_modem\/live_audio_v1'/,
  'Dart adapter declares the canonical MethodChannel name',
);
expect(
  contents.dartAdapter,
  /'\$_channelName\/capture_frames'/,
  'Dart adapter derives the canonical capture EventChannel name',
);
expect(
  contents.dartAdapter,
  /'sampleFormat':\s*'pcm_s16le'/,
  'Dart adapter serializes the signed PCM16 LE wire-format label',
);
expect(
  contents.dartContract,
  /static const audioModemV1\s*=\s*PcmStreamFormat\([\s\S]*sampleRateHz:\s*48000,[\s\S]*channels:\s*1,[\s\S]*sampleFormat:\s*PcmSampleFormat\.signedPcm16LittleEndian,/,
  'Dart contract declares 48 kHz mono signed PCM16 LE',
);

if (failures > 0) {
  console.error(`Android source contracts failed: ${failures}.`);
  process.exitCode = 1;
} else {
  console.log('Android source contracts passed. This is not target or hardware acceptance evidence.');
}
