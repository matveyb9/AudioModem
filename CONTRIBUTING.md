# Contributing to AudioModem

Thank you for contributing. AudioModem is an experimental, safety-conscious communications project: clarity, reproducibility and compatibility are first-class requirements.

Discuss substantial work in an Issue or Discussion before implementation. Changes to the container, frame protocol, error correction, modulation, key handling or compatibility policy require an RFC under [GOVERNANCE.md](GOVERNANCE.md). Never report vulnerabilities publicly; use [SECURITY.md](SECURITY.md).

Before opening a PR, run the relevant formatter, linter, tests and build for each modified area. Rust changes must pass workspace formatting, Clippy and tests. Flutter changes must pass `dart format`, `flutter analyze` and tests. Every PR explains purpose, validation, compatibility impact and linked Issue/RFC.

Protocol/DSP changes need parser coverage, malformed-input tests and golden WAV vectors. A released profile identifier is immutable: interoperability changes require a new ID and migration note. Do not commit user recordings, voices, user files, secrets, private keys, device identifiers or non-public radio traffic. Test artifacts must be synthetic or explicitly licensed, compact and documented.
