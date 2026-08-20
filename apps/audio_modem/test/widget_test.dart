import 'dart:typed_data';

import 'package:audio_modem/bridge/wav_bootstrap_bridge.dart';
import 'package:audio_modem/main.dart';
import 'package:audio_modem/platform/wav_file_adapter.dart';
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

class _FakeWavFileAdapter implements WavFileAdapter {
  _FakeWavFileAdapter({this.openedFile});

  final SelectedWavFile? openedFile;
  SavedWavFile? savedFile;

  @override
  Future<SelectedWavFile?> openWav() async => openedFile;

  @override
  Future<SavedWavFile?> saveWav({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    savedFile = SavedWavFile(
      name: suggestedName,
      location: Uri.parse('memory://$suggestedName'),
    );
    return savedFile;
  }
}

void main() {
  testWidgets('send workbench builds and verifies an in-memory WAV flow', (
    tester,
  ) async {
    final fileAdapter = _FakeWavFileAdapter();
    await tester.pumpWidget(
      AudioModemApp(bridge: _FakeWavBridge(), fileAdapter: fileAdapter),
    );

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

    final exportButton = find.widgetWithText(
      OutlinedButton,
      'Экспортировать WAV',
    );
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(fileAdapter.savedFile?.name, startsWith('adlp-'));
  });

  testWidgets('receive workbench imports and verifies a user-selected WAV', (
    tester,
  ) async {
    final fileAdapter = _FakeWavFileAdapter(
      openedFile: SelectedWavFile(
        name: 'received.wav',
        bytes: Uint8List.fromList([82, 73, 70, 70]),
      ),
    );
    await tester.pumpWidget(
      AudioModemApp(bridge: _FakeWavBridge(), fileAdapter: fileAdapter),
    );

    await tester.tap(find.byIcon(Icons.south_west));
    await tester.pumpAndSettle();

    final importButton = find.widgetWithText(FilledButton, 'Импортировать WAV');
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    expect(find.text('WAV object проверен.'), findsOneWidget);
    expect(find.text('Источник: received.wav'), findsOneWidget);
  });
}
