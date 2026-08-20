import 'package:audio_modem/platform/android_live_audio_adapter.dart';
import 'package:audio_modem/platform/live_audio_adapter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('test.audiomodem/live_audio/methods');
  const captureEvents = EventChannel('test.audiomodem/live_audio/capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(captureEvents, null);
  });

  test(
    'Android adapter rejects incompatible PCM before native invocation',
    () async {
      final adapter = AndroidLiveAudioAdapter.forTesting(
        methods: methods,
        captureEvents: captureEvents,
      );
      var invoked = false;
      messenger.setMockMethodCallHandler(methods, (_) async {
        invoked = true;
        return null;
      });

      const incompatible = PcmStreamFormat(
        sampleRateHz: 44100,
        channels: 1,
        sampleFormat: PcmSampleFormat.signedPcm16LittleEndian,
      );
      await expectLater(
        adapter.startPlayback(
          pcmFrames: Uint8List.fromList([0, 1]),
          format: incompatible,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(invoked, isFalse);
    },
  );

  test(
    'Android adapter sends exact v1 PCM arguments to native playback',
    () async {
      final adapter = AndroidLiveAudioAdapter.forTesting(
        methods: methods,
        captureEvents: captureEvents,
      );
      MethodCall? call;
      messenger.setMockMethodCallHandler(methods, (value) async {
        call = value;
        return null;
      });

      await adapter.startPlayback(
        pcmFrames: Uint8List.fromList([0, 1, 2, 3]),
        format: PcmStreamFormat.audioModemV1,
      );

      expect(call?.method, 'startPlayback');
      expect(call?.arguments['sampleRateHz'], 48000);
      expect(call?.arguments['channels'], 1);
      expect(call?.arguments['sampleFormat'], 'pcm_s16le');
      expect(call?.arguments['pcmFrames'], Uint8List.fromList([0, 1, 2, 3]));
    },
  );

  test('Android adapter forwards only valid capture PCM16 frames', () async {
    final adapter = AndroidLiveAudioAdapter.forTesting(
      methods: methods,
      captureEvents: captureEvents,
    );
    messenger.setMockMethodCallHandler(methods, (_) async => null);
    messenger.setMockStreamHandler(
      captureEvents,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success(Uint8List.fromList([4, 5]));
        },
      ),
    );

    final frames = await adapter
        .startCapture(format: PcmStreamFormat.audioModemV1)
        .first;
    expect(frames, Uint8List.fromList([4, 5]));
  });
}
