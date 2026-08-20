// Product-layer bridge adapter. Rust remains the only source of ADLP and WAV codec logic.

import 'package:flutter/foundation.dart';

import '../src/rust/api/wav_bootstrap.dart' as rust;
import '../src/rust/frb_generated.dart';

class WavBuildResult {
  const WavBuildResult({
    required this.sessionId,
    required this.profile,
    required this.carrier,
    required this.sampleRateHz,
    required this.wavBytes,
  });

  final int sessionId;
  final String profile;
  final String carrier;
  final int sampleRateHz;
  final Uint8List wavBytes;
}

class WavDecodeResult {
  const WavDecodeResult({
    required this.sessionId,
    required this.senderCallsign,
    required this.profile,
    required this.carrier,
    required this.text,
    required this.sampleRateHz,
    required this.samplesConsumed,
  });

  final int sessionId;
  final String senderCallsign;
  final String profile;
  final String carrier;
  final String text;
  final int sampleRateHz;
  final int samplesConsumed;
}

abstract interface class WavBootstrapBridge {
  bool get isAvailable;

  Future<WavBuildResult> encodeText({
    required int sessionId,
    required String senderCallsign,
    required String text,
    required String profile,
    required String carrier,
  });

  Future<WavDecodeResult> decodeWav({
    required Uint8List wavBytes,
    required String carrier,
  });
}

class NativeWavBootstrapBridge implements WavBootstrapBridge {
  NativeWavBootstrapBridge._();

  static Future<NativeWavBootstrapBridge> create() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'The native Rust WAV bridge is not available in the web build yet.',
      );
    }
    await AudioModemRust.init();
    return NativeWavBootstrapBridge._();
  }

  @override
  bool get isAvailable => !kIsWeb;

  @override
  Future<WavBuildResult> encodeText({
    required int sessionId,
    required String senderCallsign,
    required String text,
    required String profile,
    required String carrier,
  }) async {
    final result = await rust.encodeTextToWav(
      sessionId: sessionId,
      senderCallsign: senderCallsign,
      text: text,
      profile: profile,
      carrier: carrier,
    );
    return WavBuildResult(
      sessionId: result.sessionId,
      profile: result.profile,
      carrier: result.carrier,
      sampleRateHz: result.sampleRateHz,
      wavBytes: result.wavBytes,
    );
  }

  @override
  Future<WavDecodeResult> decodeWav({
    required Uint8List wavBytes,
    required String carrier,
  }) async {
    final result = await rust.decodeWavText(
      wavBytes: wavBytes,
      carrier: carrier,
    );
    return WavDecodeResult(
      sessionId: result.sessionId,
      senderCallsign: result.senderCallsign,
      profile: result.profile,
      carrier: result.carrier,
      text: result.text,
      sampleRateHz: result.sampleRateHz,
      samplesConsumed: result.samplesConsumed,
    );
  }
}

class UnavailableWavBootstrapBridge implements WavBootstrapBridge {
  const UnavailableWavBootstrapBridge(this.reason);

  final String reason;

  @override
  bool get isAvailable => false;

  @override
  Future<WavBuildResult> encodeText({
    required int sessionId,
    required String senderCallsign,
    required String text,
    required String profile,
    required String carrier,
  }) => Future.error(StateError(reason));

  @override
  Future<WavDecodeResult> decodeWav({
    required Uint8List wavBytes,
    required String carrier,
  }) => Future.error(StateError(reason));
}
