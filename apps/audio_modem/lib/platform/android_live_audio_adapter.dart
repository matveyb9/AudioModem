// Android foreground live-audio adapter v1. It owns no ADLP/DSP logic and
// remains unavailable outside its declared API/platform scope.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_audio_adapter.dart';

class AndroidLiveAudioAdapter implements LiveAudioAdapter {
  AndroidLiveAudioAdapter._({
    required this.availability,
    MethodChannel? methods,
    EventChannel? captureEvents,
  }) : _methods = methods ?? _defaultMethods,
       _captureEvents = captureEvents ?? _defaultCaptureEvents;

  @visibleForTesting
  factory AndroidLiveAudioAdapter.forTesting({
    required MethodChannel methods,
    required EventChannel captureEvents,
    LiveAudioAvailability availability = const LiveAudioAvailability.available(
      supportedFormat: PcmStreamFormat.audioModemV1,
    ),
  }) => AndroidLiveAudioAdapter._(
    availability: availability,
    methods: methods,
    captureEvents: captureEvents,
  );

  static const _channelName = 'org.audiomodem.audio_modem/live_audio_v1';
  static const MethodChannel _defaultMethods = MethodChannel(_channelName);
  static const EventChannel _defaultCaptureEvents = EventChannel(
    '$_channelName/capture_frames',
  );

  final MethodChannel _methods;
  final EventChannel _captureEvents;

  @override
  final LiveAudioAvailability availability;

  bool _disposed = false;

  static Future<LiveAudioAdapter> create() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const UnavailableLiveAudioAdapter(
        'Android foreground live audio is unavailable on this platform. Build or import a WAV instead.',
      );
    }
    try {
      final result = await _defaultMethods.invokeMapMethod<String, dynamic>(
        'getAvailability',
      );
      if (result?['available'] != true) {
        return UnavailableLiveAudioAdapter(
          result?['reason'] as String? ??
              'Android foreground live audio is unavailable on this device.',
        );
      }
      return AndroidLiveAudioAdapter._(
        availability: const LiveAudioAvailability.available(
          supportedFormat: PcmStreamFormat.audioModemV1,
        ),
      );
    } on PlatformException catch (error) {
      return UnavailableLiveAudioAdapter(
        'Android live-audio initialization is unavailable: ${error.message ?? error.code}',
      );
    }
  }

  void _ensureActiveAndFormat(PcmStreamFormat format) {
    if (_disposed) {
      throw StateError('Android live-audio adapter has been disposed.');
    }
    if (!availability.isAvailable) {
      throw StateError(
        availability.reason ?? 'Android live audio is unavailable.',
      );
    }
    if (!format.isAudioModemV1) {
      throw ArgumentError.value(
        format,
        'format',
        'Android live-audio v1 requires 48 kHz mono signed PCM16 LE.',
      );
    }
  }

  Map<String, Object> _formatArguments(PcmStreamFormat format) => {
    'sampleRateHz': format.sampleRateHz,
    'channels': format.channels,
    'sampleFormat': 'pcm_s16le',
  };

  @override
  Future<void> startPlayback({
    required Uint8List pcmFrames,
    required PcmStreamFormat format,
  }) async {
    _ensureActiveAndFormat(format);
    if (pcmFrames.isEmpty || pcmFrames.length.isOdd) {
      throw ArgumentError.value(
        pcmFrames,
        'pcmFrames',
        'Playback requires non-empty PCM16 LE frames.',
      );
    }
    await _methods.invokeMethod<void>('startPlayback', {
      ..._formatArguments(format),
      'pcmFrames': pcmFrames,
    });
  }

  @override
  Stream<Uint8List> startCapture({required PcmStreamFormat format}) {
    _ensureActiveAndFormat(format);
    late final StreamController<Uint8List> controller;
    StreamSubscription<dynamic>? subscription;

    controller = StreamController<Uint8List>(
      onListen: () async {
        subscription = _captureEvents.receiveBroadcastStream().listen(
          (Object? event) {
            if (event is Uint8List && event.isNotEmpty && event.length.isEven) {
              controller.add(event);
            } else {
              controller.addError(
                StateError(
                  'Android adapter emitted invalid PCM16 capture frames.',
                ),
              );
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
        try {
          await _methods.invokeMethod<void>(
            'startCapture',
            _formatArguments(format),
          );
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      },
      onCancel: () async {
        await subscription?.cancel();
        await stop();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await _methods.invokeMethod<void>('stop');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _methods.invokeMethod<void>('dispose');
  }
}
