# ADLP WAV golden fixtures

`adlp-v1-text-balanced.wav` is a canonical WAV bootstrap fixture for deterministic regression coverage. It is generated only with the repository CLI and must not be replaced by an editor export or a manually modified file.

| Field | Canonical value |
| --- | --- |
| Generator | `cargo run -p adlp-cli -- encode-text` |
| Session ID | `1` |
| Callsign | `GOLDEN1` |
| Profile | `balanced` |
| UTF-8 text | `AudioModem ADLP golden fixture v1` |
| WAV shape | RIFF, mono, 16-bit PCM, 48 kHz |
| Size | `40,364` bytes |
| SHA-256 | `c13b9091604a6eaeb3bbb5570498ada82113c0c52e7cfb44fd9373c2cb001bf6` |

The Rust regression test both decodes this immutable fixture and regenerates it from the fixed ADLP object. A byte difference is therefore a deliberate codec compatibility change and must be reviewed together with an updated fixture, hash, protocol rationale, and release note.
