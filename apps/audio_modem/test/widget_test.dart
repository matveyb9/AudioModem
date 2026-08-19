import 'dart:typed_data';

import 'package:audio_modem/bridge/wav_bootstrap_bridge.dart';
import 'package:audio_modem/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWavBridge implements WavBootstrapBridge {
  @override
  bool get isAvailable => true;

  @override
  Future<WavDecodeResult> decodeWav(Uint8List wavBytes) async =>
      const WavDecodeResult(
        sessionId: 7,
        senderCallsign: 'N1',
        profile: 'fast',
        text: 'Привет через AudioModem',
        sampleRateHz: 48000,
        samplesConsumed: 512,
      );

  @override
  Future<WavBuildResult> encodeText({
    required int sessionId,
    required String senderCallsign,
    required String text,
    required String profile,
  }) async => WavBuildResult(
    sessionId: sessionId,
    profile: profile,
    sampleRateHz: 48000,
    wavBytes: Uint8List.fromList([82, 73, 70, 70]),
  );
}

void main() {
  testWidgets('send workbench builds and verifies an in-memory WAV flow', (
    tester,
  ) async {
    await tester.pumpWidget(AudioModemApp(bridge: _FakeWavBridge()));

    expect(find.text('Соберите и проверьте WAV.'), findsOneWidget);
    expect(find.text('Надёжный'), findsOneWidget);

    final fastFinder = find.widgetWithText(ChoiceChip, 'Быстрый');
    await tester.ensureVisible(fastFinder);
    await tester.tap(fastFinder);
    await tester.pumpAndSettle();

    final fastPreset = tester.widget<ChoiceChip>(fastFinder);
    expect(fastPreset.selected, isTrue);

    final buildButton = find.widgetWithText(
      FilledButton,
      'Собрать и проверить WAV',
    );
    await tester.ensureVisible(buildButton);
    await tester.tap(buildButton);
    await tester.pumpAndSettle();

    expect(find.text('ПРОВЕРЕНО RUST'), findsOneWidget);
    expect(find.text('4 байт'), findsOneWidget);
  });
}
