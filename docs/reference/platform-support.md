# Platform support

**Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](platform-support_RU.md)

AudioModem keeps Flutter runners for Android, iOS, Windows, macOS, Linux and Web in one application directory. The Rust workspace supplies the container and WAV bootstrap codec. This structure is an implementation target, not a claim that every platform currently supports every route.

## Status matrix

| Platform | Flutter runner | Rust/WAV integration | Local WAV workflow | Live audio | Notes |
| --- | --- | --- | --- | --- | --- |
| Android | Scaffolded | Bridge source integrated; target build/run not verified | Source implementation; target dialog not verified | Planned | Requires target build, permission and route-adapter acceptance tests. |
| iOS | Scaffolded | Bridge source integrated; target build/run not verified | Source implementation; target dialog not verified | Planned | Requires target build, permission and route-adapter acceptance tests. |
| Windows | Scaffolded | Bridge source integrated; target build/run not verified | Source implementation; target dialog not verified | Planned | Requires native device enumeration and routing tests. |
| macOS | Scaffolded | Bridge source integrated; target build/run not verified | Source implementation; target dialog not verified | Planned | Requires native device enumeration and routing tests. |
| Linux | Debug bundle verified | Native Cargokit/Rust bridge build verified | Source implementation; dialog interaction not acceptance-tested | Planned | Requires backend selection, runtime dialog and desktop audio tests. |
| Web | Release build verified | Unavailable by design: no WASM codec | Picker UI can build; native Rust decode is unavailable | Research | Requires WASM codec integration and browser Web Audio constraints. |

## Interpretation

“Scaffolded” means the Flutter project has a platform runner. “Bridge source integrated” means the shared Flutter/Rust source contains the bridge and file workflow; it is not a target runtime claim. Linux is the only native target with a verified debug bundle in this repository. No row implies microphone permission, playback, Bluetooth routing, device compatibility or acoustic transmission. A route becomes “supported” only when a reproducible build, automated checks, a documented compatibility note and a route-specific acceptance test exist.

## Compatibility reports

When opening a device-compatibility issue, include the app/revision, operating system and version, device class, selected route, nominal sample rate, selected profile, expected behavior and a minimal WAV fixture where relevant. Do not include private audio recordings or personal data.
