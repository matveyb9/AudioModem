import 'dart:typed_data';

import 'package:audio_modem/bridge/wav_bootstrap_bridge.dart';
import 'package:audio_modem/main.dart';
import 'package:audio_modem/platform/live_audio_adapter.dart';
import 'package:audio_modem/platform/payload_file_adapter.dart';
import 'package:audio_modem/platform/wav_file_adapter.dart';
import 'package:audio_modem/transfer/transfer_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWavBridge implements WavBootstrapBridge {
  _FakeWavBridge({this.textDecodeFails = false});

  final bool textDecodeFails;
  String? encodedCarrier;
  String? decodedCarrier;
  String? encodedFileName;

  @override
  bool get isAvailable => true;

  @override
  Future<WavDecodeResult> decodeWav({
    required Uint8List wavBytes,
    required String carrier,
  }) async {
    if (textDecodeFails) {
      throw StateError('The WAV contains a non-text ADLP object.');
    }
    decodedCarrier = carrier;
    return WavDecodeResult(
      sessionId: 7,
      senderCallsign: 'N1',
      profile: 'fast',
      carrier: carrier,
      text: 'Привет через AudioModem',
      sampleRateHz: 48000,
      samplesConsumed: 512,
    );
  }

  @override
  Future<WavBuildResult> encodeText({
    required int sessionId,
    required String senderCallsign,
    required String text,
    required String profile,
    required String carrier,
  }) async {
    encodedCarrier = carrier;
    return WavBuildResult(
      sessionId: sessionId,
      profile: profile,
      carrier: carrier,
      sampleRateHz: 48000,
      wavBytes: Uint8List.fromList([82, 73, 70, 70]),
    );
  }

  @override
  Future<WavBuildResult> encodeFile({
    required int sessionId,
    required String senderCallsign,
    required String fileName,
    required String mimeType,
    required Uint8List payload,
    required String profile,
    required String carrier,
  }) async {
    encodedCarrier = carrier;
    encodedFileName = fileName;
    return WavBuildResult(
      sessionId: sessionId,
      profile: profile,
      carrier: carrier,
      sampleRateHz: 48000,
      wavBytes: Uint8List.fromList([82, 73, 70, 70]),
    );
  }

  @override
  Future<WavFileDecodeResult> decodeWavFile({
    required Uint8List wavBytes,
    required String carrier,
  }) async {
    decodedCarrier = carrier;
    return WavFileDecodeResult(
      sessionId: 8,
      senderCallsign: 'N1',
      profile: 'fast',
      carrier: carrier,
      fileName: 'sample.bin',
      mimeType: 'application/octet-stream',
      payload: Uint8List.fromList([0, 1, 2]),
      sampleRateHz: 48000,
      samplesConsumed: 768,
    );
  }

  @override
  Future<LivePcmBuildResult> encodeTextToLivePcm({
    required int sessionId,
    required String senderCallsign,
    required String text,
    required String profile,
    required String carrier,
  }) async {
    encodedCarrier = carrier;
    return LivePcmBuildResult(
      sessionId: sessionId,
      profile: profile,
      carrier: carrier,
      sampleRateHz: 48000,
      pcmFrames: Uint8List.fromList([0, 1]),
    );
  }

  @override
  Future<WavDecodeResult> decodeLivePcmText({
    required Uint8List pcmFrames,
    required String carrier,
  }) => decodeWav(wavBytes: pcmFrames, carrier: carrier);
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

class _FakePayloadFileAdapter implements PayloadFileAdapter {
  _FakePayloadFileAdapter({this.openedFile});

  final SelectedPayloadFile? openedFile;
  SavedPayloadFile? savedFile;

  @override
  Future<SelectedPayloadFile?> openPayload() async => openedFile;

  @override
  Future<SavedPayloadFile?> savePayload({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    savedFile = SavedPayloadFile(
      name: suggestedName,
      location: Uri.parse('memory://$suggestedName'),
    );
    return savedFile;
  }
}

void main() {
  test('live-audio v1 format is explicitly PCM16 mono at 48 kHz', () {
    expect(PcmStreamFormat.audioModemV1.isAudioModemV1, isTrue);
    const incompatible = PcmStreamFormat(
      sampleRateHz: 44100,
      channels: 2,
      sampleFormat: PcmSampleFormat.signedPcm16LittleEndian,
    );
    expect(incompatible.isAudioModemV1, isFalse);
  });

  test('unavailable live-audio adapter cannot start a route', () async {
    const adapter = UnavailableLiveAudioAdapter('No tested live route.');
    expect(adapter.availability.isAvailable, isFalse);
    expect(adapter.availability.reason, 'No tested live route.');
    await expectLater(
      adapter.startPlayback(
        pcmFrames: Uint8List(0),
        format: PcmStreamFormat.audioModemV1,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      adapter.startCapture(format: PcmStreamFormat.audioModemV1).first,
      throwsA(isA<StateError>()),
    );
  });

  test(
    'file bridge contract preserves typed metadata without a file UI',
    () async {
      final bridge = _FakeWavBridge();
      final built = await bridge.encodeFile(
        sessionId: 9,
        senderCallsign: 'N1',
        fileName: 'sample.bin',
        mimeType: 'application/octet-stream',
        payload: Uint8List.fromList([0, 1, 2]),
        profile: 'balanced',
        carrier: 'bootstrap',
      );
      final decoded = await bridge.decodeWavFile(
        wavBytes: built.wavBytes,
        carrier: 'bootstrap',
      );

      expect(bridge.encodedFileName, 'sample.bin');
      expect(decoded.fileName, 'sample.bin');
      expect(decoded.mimeType, 'application/octet-stream');
      expect(decoded.payload, Uint8List.fromList([0, 1, 2]));
    },
  );

  test('unavailable Rust bridge rejects the file contract', () async {
    const bridge = UnavailableWavBootstrapBridge('No native bridge.');
    await expectLater(
      bridge.encodeFile(
        sessionId: 1,
        senderCallsign: 'N1',
        fileName: 'sample.bin',
        mimeType: 'application/octet-stream',
        payload: Uint8List.fromList([1]),
        profile: 'balanced',
        carrier: 'bootstrap',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('transfer task separates busy and terminal shell states', () {
    final preparing = TransferTaskState.preparing('Preparing…');
    final completed = TransferTaskState.completed('Completed.');
    final unavailable = TransferTaskState.unavailable('No route.');

    expect(preparing.isBusy, isTrue);
    expect(preparing.isTerminal, isFalse);
    expect(completed.isBusy, isFalse);
    expect(completed.isTerminal, isTrue);
    expect(unavailable.label, 'НЕДОСТУПНО');
  });

  testWidgets('send workbench builds and verifies an in-memory WAV flow', (
    tester,
  ) async {
    final fileAdapter = _FakeWavFileAdapter();
    final bridge = _FakeWavBridge();
    await tester.pumpWidget(
      AudioModemApp(bridge: bridge, fileAdapter: fileAdapter),
    );

    expect(find.text('Соберите и проверьте WAV.'), findsOneWidget);
    expect(find.text('Надёжный'), findsOneWidget);

    final fastFinder = find.widgetWithText(ChoiceChip, 'Быстрый');
    await tester.ensureVisible(fastFinder);
    await tester.tap(fastFinder);
    await tester.pumpAndSettle();

    final fastPreset = tester.widget<ChoiceChip>(fastFinder);
    expect(fastPreset.selected, isTrue);

    final acousticFinder = find.widgetWithText(ChoiceChip, 'Acoustic-1');
    await tester.ensureVisible(acousticFinder);
    await tester.tap(acousticFinder);
    await tester.pumpAndSettle();

    final buildButton = find.widgetWithText(
      FilledButton,
      'Собрать и проверить WAV',
    );
    await tester.ensureVisible(buildButton);
    await tester.tap(buildButton);
    await tester.pumpAndSettle();

    expect(find.text('ПРОВЕРЕНО RUST'), findsOneWidget);
    expect(find.text('ГОТОВО'), findsOneWidget);
    expect(find.text('Text WAV собран и проверен.'), findsOneWidget);
    expect(find.text('4 байт'), findsOneWidget);
    expect(bridge.encodedCarrier, 'acoustic1');
    expect(bridge.decodedCarrier, 'acoustic1');

    final exportButton = find.widgetWithText(
      OutlinedButton,
      'Экспортировать WAV',
    );
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(fileAdapter.savedFile?.name, startsWith('adlp-acoustic1-'));
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

  testWidgets('file shell selects, verifies and exposes a bounded file WAV', (
    tester,
  ) async {
    final payloadAdapter = _FakePayloadFileAdapter(
      openedFile: SelectedPayloadFile(
        name: 'sample.bin',
        bytes: Uint8List.fromList([0, 1, 2]),
      ),
    );
    await tester.pumpWidget(
      AudioModemApp(
        bridge: _FakeWavBridge(),
        fileAdapter: _FakeWavFileAdapter(),
        payloadFileAdapter: payloadAdapter,
      ),
    );

    await tester.tap(find.text('Файл'));
    await tester.pumpAndSettle();
    final selectFileButton = find.widgetWithText(
      OutlinedButton,
      'Выбрать файл',
    );
    await tester.ensureVisible(selectFileButton);
    await tester.tap(selectFileButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('sample.bin · 3 байт'), findsNWidgets(2));

    final buildButton = find.widgetWithText(
      FilledButton,
      'Собрать и проверить WAV',
    );
    await tester.ensureVisible(buildButton);
    await tester.tap(buildButton);
    await tester.pumpAndSettle();

    expect(find.text('File WAV собран и проверен.'), findsOneWidget);
    expect(find.textContaining('sample.bin · 3 байт'), findsWidgets);
  });

  testWidgets('file WAV import exposes only a verified payload save action', (
    tester,
  ) async {
    final payloadAdapter = _FakePayloadFileAdapter();
    await tester.pumpWidget(
      AudioModemApp(
        bridge: _FakeWavBridge(textDecodeFails: true),
        fileAdapter: _FakeWavFileAdapter(
          openedFile: SelectedWavFile(
            name: 'received-file.wav',
            bytes: Uint8List.fromList([82, 73, 70, 70]),
          ),
        ),
        payloadFileAdapter: payloadAdapter,
      ),
    );

    await tester.tap(find.byIcon(Icons.south_west));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Импортировать WAV'));
    await tester.pumpAndSettle();

    expect(find.text('sample.bin'), findsOneWidget);

    final savePayloadButton = find.widgetWithText(
      OutlinedButton,
      'Сохранить проверенный файл',
    );
    await tester.ensureVisible(savePayloadButton);
    await tester.tap(savePayloadButton);
    await tester.pumpAndSettle();

    expect(payloadAdapter.savedFile?.name, 'sample.bin');
  });

  testWidgets('live route selection remains unavailable and does not encode', (
    tester,
  ) async {
    final bridge = _FakeWavBridge();
    await tester.pumpWidget(
      AudioModemApp(
        bridge: bridge,
        fileAdapter: _FakeWavFileAdapter(),
        liveAudioAdapter: const UnavailableLiveAudioAdapter(
          'No tested live route.',
        ),
      ),
    );

    final speakerRoute = find.text('Динамик');
    await tester.ensureVisible(speakerRoute);
    await tester.tap(speakerRoute);
    await tester.pumpAndSettle();

    final buildButton = find.widgetWithText(
      FilledButton,
      'Передать Android PCM',
    );
    await tester.ensureVisible(buildButton);
    await tester.tap(buildButton);
    await tester.pumpAndSettle();

    expect(find.text('No tested live route.'), findsNWidgets(2));
    expect(bridge.encodedCarrier, isNull);
  });
}
