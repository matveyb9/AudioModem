# Troubleshooting

**Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](troubleshooting_RU.md)

This page documents the currently observable bootstrap, Acoustic-1 and Acoustic-2 controlled PCM paths. It does not supply workarounds for live capture, Bluetooth or radio because those routes are not implemented. A useful report contains facts that another contributor can reproduce.

| Symptom | First check | Expected outcome |
| --- | --- | --- |
| `cargo run` cannot find a package | Run from the repository root and use `-p adlp-cli`. | Cargo finds the workspace member. |
| `encode-text` rejects the profile | Use `reliable`, `balanced`, `fast` or `narrowband`. | The CLI accepts the profile or defaults to `balanced`. |
| `decode` rejects a WAV file | Confirm that the file came from the bootstrap CLI and was not transcoded. | The decoder accepts canonical mono 48 kHz signed 16-bit PCM WAV carrying the bootstrap signal. |
| `decode-acoustic1` rejects a WAV file | Confirm the carrier command matches the file and the file is canonical 48 kHz PCM. | The decoder accepts only Acoustic-1 framing; a bootstrap WAV is intentionally rejected. |
| `measure-acoustic1` rejects a transform | Record every supplied transform argument and test the unmodified file first. | Invalid bounds, periodic deletion or failed Acoustic-1 framing return an error; no payload/measurement is printed. |
| Decoded text is missing | Preserve the CLI output and file checksum; run `cargo test --workspace`. | The decoder must not print a payload after a failed framing or CRC-32C check. |
| A native codec is unavailable in the web build | Use a native runner for the current Rust codec workflows. | This is expected: the web target deliberately has no WASM codec. |
| A live route is missing in the Flutter UI | Check the platform support matrix. | The native bridge/local WAV workflow exists, but live-audio adapters are still not implemented. |

## Report template

Use the device-compatibility issue form for device observations. For a codec or CLI failure, include the following information in a bug report.

```text
AudioModem revision:
Operating system and version:
Rust version:
Command run:
Selected profile:
Selected carrier:
Acoustic-2 transform arguments, if used:
Expected result:
Actual result:
Reproduction steps:
WAV SHA-256 (do not upload private content):
```

## Security-sensitive findings

Do not report a potential confidentiality, integrity or authentication vulnerability in a public issue. Follow [SECURITY.md](../SECURITY.md) instead. A callsign being forgeable is expected in ADLP v1 and is not, by itself, a vulnerability.
