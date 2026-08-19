# Flutter Rust Bridge integration note

**Last reviewed:** 2026-08-19 · **English (canonical)**

AudioModem uses `flutter_rust_bridge` v2 for the first Flutter-to-Rust WAV bootstrap slice. The official quickstart describes the model as a normal Flutter app plus a Rust crate plus generated glue, and requires regenerating bridge code when Rust API changes.[1] The local implementation therefore keeps hand-written Rust API in `apps/audio_modem/rust/src/api/`, generated Rust glue in `src/frb_generated.rs`, and generated Dart glue in `lib/src/rust/`.

The official crate documentation exposes the `frb` attribute and runtime helpers; the project uses normal public Rust functions and generated bindings for this initial synchronous-shaped API.[2] The generated facade calls the existing `audio-modem-core` and `adlp-protocol` crates rather than reimplementing wire or WAV logic.

## Regeneration

```bash
export PATH="/home/ubuntu/.local/flutter/bin:$HOME/.cargo/bin:$PATH"
cd apps/audio_modem/rust
flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
```

## References

[1]: https://cjycode.com/flutter_rust_bridge/quickstart "Flutter Rust Bridge v2 Quickstart"
[2]: https://docs.rs/flutter_rust_bridge/latest/flutter_rust_bridge/ "flutter_rust_bridge crate documentation"
