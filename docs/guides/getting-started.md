# Quick start: verify a WAV transfer

**Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](getting-started_RU.md)

This guide verifies the first implemented AudioModem path. It does not test a speaker, microphone, Bluetooth device or radio. It deliberately uses a lossless WAV file so a failed round trip can be assigned to the container or codec rather than to an unknown live-audio route.

## Prerequisites

Install a stable Rust toolchain and clone the repository. The native Flutter UI now uses the same Rust core and can locally save or open WAV files, but the diagnostic CLI remains the most direct reproducible entry point for this test. The web build intentionally does not expose the native codec.

```bash
git clone https://github.com/matveyb9/AudioModem.git
cd AudioModem
cargo test --workspace
```

## Encode text as WAV

The final argument is optional and defaults to `balanced`. For bootstrap compatibility, use one of `reliable`, `balanced`, `fast` or `narrowband`.

```bash
cargo run -p adlp-cli -- encode-text hello.wav N1 "Hello from AudioModem" reliable
```

The command serializes an ADLP v1 text object, then maps it into a mono 48 kHz, signed 16-bit PCM WAV file. `N1` is a callsign displayed in open metadata. It does **not** identify or authenticate the sender.

## Move a text WAV and decode it

Copy `hello.wav` to the receiving machine using any ordinary file channel, then run:

```bash
cargo run -p adlp-cli -- decode hello.wav
```

The decoder prints the ADLP version, profile, session value, callsign, sample count and text. A decoder must reject malformed bootstrap framing or a CRC-32C mismatch before it returns the payload.

## Encode a small file as WAV

The Rust CLI can also verify a bounded ADLP `File` object before there is a Flutter file-transfer UI. The first facade limit is **8 KiB** of file payload. Supply an explicit MIME type when known; the default is `application/octet-stream`.

```bash
printf 'fixture bytes\n' > sample.bin
cargo run -p adlp-cli -- encode-file sample.wav N1 sample.bin application/octet-stream balanced
cargo run -p adlp-cli -- decode sample.wav
```

The decoder prints the original leaf file name, declared MIME type and payload size after ADLP framing and CRC-32C validation. This is a reproducible Rust/WAV contract only. It does **not** yet provide a Flutter file picker/receipt workflow, persistence, file-size policy beyond the initial facade limit, or a physical audio route.

## Controlled Acoustic-1 WAV experiment

Acoustic-1 is a separate experimental B-FSK carrier. It uses a different encoder and decoder, so both commands must name the carrier explicitly. Its framing, bounded synchronisation, Hamming(7,4) layer and limits are defined in the [Acoustic-1 RFC](../../spec/acoustic-1.md).

```bash
cargo run -p adlp-cli -- encode-acoustic1-text acoustic1.wav N1 "Controlled test" balanced
cargo run -p adlp-cli -- decode-acoustic1 acoustic1.wav
```

An Acoustic-1 WAV round trip proves controlled PCM/WAV codec behavior only. It does not prove speaker-to-microphone synchronisation, room-noise tolerance, gain handling, radio compatibility or any live route.

## Acoustic-2 controlled measurement

Acoustic-2 applies declared integer-domain transforms to an existing Acoustic-1 WAV, then reports only what the existing codec can observe. The optional values below are leading silence, gain per mille, noise peak, noise seed and hard-clip threshold.

```bash
cargo run -p adlp-cli -- measure-acoustic1 acoustic1.wav 137 500 200 2885812225 8000
```

The command prints an accepted/rejected codec result, sample counts, bounded acquisition offset and ADLP profile. The numbers are reproducible for that exact WAV and parameter vector; they are not BER, SNR, range, room-noise, clock-drift or device compatibility metrics. See the [Acoustic-2 contract](../../spec/acoustic-2.md) for the full transform order and bounds.

## What this proves—and what it does not

| This test proves | This test does not prove |
| --- | --- |
| The implemented ADLP v1 object can survive one deterministic WAV encode/decode cycle. | That speech-band audio, a speaker, microphone, cable, Bluetooth adapter or radio can carry the waveform. |
| A bounded file object preserves its name, declared MIME type and bytes through the Rust CLI WAV reference path. | That the Flutter application can send or save a file-object transfer yet. |
| The final integrity check detects the intentional corrupted-frame cases covered by the Rust tests; Acoustic-1 also has bounded noise, framing, FEC and golden-vector regression cases. | That a callsign belongs to a person, device or key. |
| An Acoustic-2 transform vector has deterministic PCM output and codec-observable acquisition values. | That synthetic gain/noise/clip/deletion values predict a physical audio channel. |
| The test is portable between supported Rust development environments. | That a transmission is encrypted, confidential or authenticated. |

## Next steps

Read [Audio routes](audio-routes.md) to understand why WAV is the reference transport and what is required before a live route becomes supported. Read the [ADLP v1 specification](../../spec/protocol-v1.md) for the object layout, the [Acoustic-1 RFC](../../spec/acoustic-1.md) for experimental carrier compatibility and the [Acoustic-2 contract](../../spec/acoustic-2.md) for controlled measurements.
