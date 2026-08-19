# Quick start: verify a WAV transfer

**Last reviewed:** 2026-08-19 · **English (canonical)** · [Русский](getting-started_RU.md)

This guide verifies the first implemented AudioModem path. It does not test a speaker, microphone, Bluetooth device or radio. It deliberately uses a lossless WAV file so a failed round trip can be assigned to the container or codec rather than to an unknown live-audio route.

## Prerequisites

Install a stable Rust toolchain and clone the repository. The current Flutter UI is not connected to the Rust core yet, so the diagnostic CLI is the supported entry point for this test.

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

## Move the file and decode it

Copy `hello.wav` to the receiving machine using any ordinary file channel, then run:

```bash
cargo run -p adlp-cli -- decode hello.wav
```

The decoder prints the ADLP version, profile, session value, callsign, sample count and text. A decoder must reject malformed bootstrap framing or a CRC-32C mismatch before it returns the payload.

## What this proves—and what it does not

| This test proves | This test does not prove |
| --- | --- |
| The implemented ADLP v1 object can survive one deterministic WAV encode/decode cycle. | That speech-band audio, a speaker, microphone, cable, Bluetooth adapter or radio can carry the waveform. |
| The final integrity check detects the intentional corrupted-frame cases covered by the Rust tests. | That a callsign belongs to a person, device or key. |
| The test is portable between supported Rust development environments. | That a transmission is encrypted, confidential or authenticated. |

## Next steps

Read [Audio routes](audio-routes.md) to understand why WAV is the reference transport and what is required before a live route becomes supported. Read the [ADLP v1 specification](../../spec/protocol-v1.md) for the object layout.
