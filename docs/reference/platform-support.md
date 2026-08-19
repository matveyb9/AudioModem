# Platform support

**Last reviewed:** 2026-08-19 · **English (canonical)** · [Русский](platform-support_RU.md)

AudioModem keeps Flutter runners for Android, iOS, Windows, macOS, Linux and Web in one application directory. The Rust workspace supplies the container and WAV bootstrap codec. This structure is an implementation target, not a claim that every platform currently supports every route.

## Status matrix

| Platform | Flutter runner | Rust/WAV integration | Live audio | Notes |
| --- | --- | --- | --- | --- |
| Android | Scaffolded | Not connected | Planned | Requires microphone permission and platform route adapter. |
| iOS | Scaffolded | Not connected | Planned | Requires microphone permission and platform route adapter. |
| Windows | Scaffolded | Not connected | Planned | Requires native device enumeration and routing tests. |
| macOS | Scaffolded | Not connected | Planned | Requires native device enumeration and routing tests. |
| Linux | Scaffolded | Not connected | Planned | Requires backend selection and desktop audio tests. |
| Web | Scaffolded | Not connected | Research | Requires WASM codec integration and browser Web Audio constraints. |

## Interpretation

“Scaffolded” means the Flutter project has a platform runner and the UI can be built for that target. It does **not** mean the Rust codec, local file handling, microphone permission, playback, Bluetooth routing or acoustic transmission is available. A row becomes “supported” only when a reproducible build, automated checks, a documented compatibility note and a route-specific acceptance test exist.

## Compatibility reports

When opening a device-compatibility issue, include the app/revision, operating system and version, device class, selected route, nominal sample rate, selected profile, expected behavior and a minimal WAV fixture where relevant. Do not include private audio recordings or personal data.
