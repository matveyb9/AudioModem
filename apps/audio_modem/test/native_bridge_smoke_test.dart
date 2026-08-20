// Native integration smoke test: Flutter calls the generated bridge while Rust remains the ADLP/WAV authority.

import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:audio_modem/bridge/wav_bootstrap_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final runNativeSmoke =
      Platform.environment['AUDIOMODEM_RUN_NATIVE_BRIDGE_SMOKE'] == '1';

  test(
    'native bridge round-trips a bounded file object through WAV bytes',
    () async {
      final bridge = await NativeWavBootstrapBridge.create();
      final built = await bridge.encodeFile(
        sessionId: 42,
        senderCallsign: 'NATIVE',
        fileName: 'native-fixture.bin',
        mimeType: 'application/octet-stream',
        payload: Uint8List.fromList([0, 1, 2, 255]),
        profile: 'balanced',
        carrier: 'bootstrap',
      );
      final decoded = await bridge.decodeWavFile(
        wavBytes: built.wavBytes,
        carrier: 'bootstrap',
      );

      expect(built.sampleRateHz, 48000);
      expect(decoded.sessionId, 42);
      expect(decoded.senderCallsign, 'NATIVE');
      expect(decoded.fileName, 'native-fixture.bin');
      expect(decoded.mimeType, 'application/octet-stream');
      expect(decoded.payload, Uint8List.fromList([0, 1, 2, 255]));
    },
    skip: !runNativeSmoke,
  );

  test(
    'native bridge rejects a file WAV when the selected carrier differs',
    () async {
      final bridge = await NativeWavBootstrapBridge.create();
      final built = await bridge.encodeFile(
        sessionId: 43,
        senderCallsign: 'NATIVE',
        fileName: 'carrier-fixture.bin',
        mimeType: 'application/octet-stream',
        payload: Uint8List.fromList([1]),
        profile: 'fast',
        carrier: 'acoustic1',
      );

      await expectLater(
        bridge.decodeWavFile(wavBytes: built.wavBytes, carrier: 'bootstrap'),
        throwsA(isA<Object>()),
      );
    },
    skip: !runNativeSmoke,
  );
}
