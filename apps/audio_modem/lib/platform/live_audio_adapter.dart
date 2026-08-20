// Product-layer live-audio contract. This file deliberately does not initialize
// a recording/playback plugin, request permissions, or access audio hardware.

import 'dart:typed_data';

enum PcmSampleFormat { signedPcm16LittleEndian }

class PcmStreamFormat {
  const PcmStreamFormat({
    required this.sampleRateHz,
    required this.channels,
    required this.sampleFormat,
  });

  static const audioModemV1 = PcmStreamFormat(
    sampleRateHz: 48000,
    channels: 1,
    sampleFormat: PcmSampleFormat.signedPcm16LittleEndian,
  );

  final int sampleRateHz;
  final int channels;
  final PcmSampleFormat sampleFormat;

  bool get isAudioModemV1 =>
      sampleRateHz == audioModemV1.sampleRateHz &&
      channels == audioModemV1.channels &&
      sampleFormat == audioModemV1.sampleFormat;
}

class LiveAudioAvailability {
  const LiveAudioAvailability.unavailable(this.reason)
    : isAvailable = false,
      supportedFormat = PcmStreamFormat.audioModemV1;

  const LiveAudioAvailability.available({required this.supportedFormat})
    : isAvailable = true,
      reason = null;

  final bool isAvailable;
  final String? reason;
  final PcmStreamFormat supportedFormat;
}

abstract interface class LiveAudioAdapter {
  LiveAudioAvailability get availability;

  Future<void> startPlayback({
    required Uint8List pcmFrames,
    required PcmStreamFormat format,
  });

  Stream<Uint8List> startCapture({required PcmStreamFormat format});

  Future<void> stop();

  Future<void> dispose();
}

class UnavailableLiveAudioAdapter implements LiveAudioAdapter {
  const UnavailableLiveAudioAdapter([
    this._reason = 'Live-audio adapters are not implemented. Build or import a WAV instead.',
  ]);

  final String _reason;

  @override
  LiveAudioAvailability get availability =>
      LiveAudioAvailability.unavailable(_reason);

  StateError _error() => StateError(_reason);

  @override
  Future<void> startPlayback({
    required Uint8List pcmFrames,
    required PcmStreamFormat format,
  }) => Future.error(_error());

  @override
  Stream<Uint8List> startCapture({required PcmStreamFormat format}) =>
      Stream.error(_error());

  @override
  Future<void> stop() => Future.error(_error());

  @override
  Future<void> dispose() => Future.value();
}
