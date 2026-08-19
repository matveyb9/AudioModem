# Troubleshooting

**Last reviewed:** 2026-08-19 · **English (canonical)** · [Русский](troubleshooting_RU.md)

This page documents the currently observable bootstrap path. It does not supply workarounds for live capture, Bluetooth or radio because those routes are not implemented. A useful report contains facts that another contributor can reproduce.

| Symptom | First check | Expected outcome |
| --- | --- | --- |
| `cargo run` cannot find a package | Run from the repository root and use `-p adlp-cli`. | Cargo finds the workspace member. |
| `encode-text` rejects the profile | Use `reliable`, `balanced`, `fast` or `narrowband`. | The CLI accepts the profile or defaults to `balanced`. |
| `decode` rejects a WAV file | Confirm that the file came from the bootstrap CLI and was not transcoded. | The decoder accepts canonical mono 48 kHz signed 16-bit PCM WAV carrying the bootstrap signal. |
| Decoded text is missing | Preserve the CLI output and file checksum; run `cargo test --workspace`. | The decoder must not print a payload after a failed framing or CRC-32C check. |
| A live route is missing in the Flutter UI | Check the platform support matrix. | This is expected until the Rust bridge and live-audio adapters are implemented. |

## Report template

Use the device-compatibility issue form for device observations. For a codec or CLI failure, include the following information in a bug report.

```text
AudioModem revision:
Operating system and version:
Rust version:
Command run:
Selected profile:
Expected result:
Actual result:
Reproduction steps:
WAV SHA-256 (do not upload private content):
```

## Security-sensitive findings

Do not report a potential confidentiality, integrity or authentication vulnerability in a public issue. Follow [SECURITY.md](../SECURITY.md) instead. A callsign being forgeable is expected in ADLP v1 and is not, by itself, a vulnerability.
