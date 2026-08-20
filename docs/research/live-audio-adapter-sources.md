# Constrained live-audio adapter research notes

**Last reviewed:** 2026-08-20 · **English (canonical)**

The first live-audio milestone must define a typed application boundary before choosing a runtime plugin or declaring a route. The contract will treat permission, session activation, interruption, playback, capture and disposal as separately observable states. It will not infer a stable sample rate, hardware route, acoustic result or platform support from a plugin dependency.

| Source | Relevant finding | RFC consequence |
| --- | --- | --- |
| Flutter cookbook, *Record or stream audio input* | Audio input requires user permission and may require platform-specific configuration; capture configuration, streaming, stopping and disposal are distinct operations.[1] | Require explicit permission and lifecycle outcomes; do not expose capture bytes until a platform adapter exists and reports a supported PCM format. |
| `audio_session` documentation | iOS has an app-wide shared audio session; Android attributes are applied per player/track. Activation can be denied, and interruption/device events require a policy.[2] | Make session activation, interruption and route-change events explicit; the core contract must not own platform-session policy silently. |
| Android audio-focus guidance | Playback should request focus immediately before use, handle focus loss, and abandon focus when finished; focus behavior differs by Android version and context.[3] | Playback is an opt-in command whose failure does not start output. No automatic resume or ducking policy is promised in v1. |

## RFC posture

The constrained adapter contract will ship only an unavailable implementation. It gives the Flutter workbench a stable dependency seam and a truthful status message while device-acceptance reports, a single-route platform RFC and hardware evidence are still absent. No recording package, audio-session package or microphone permission is added in this milestone.

## References

[1]: https://docs.flutter.dev/cookbook/audio/record "Record or stream audio input"
[2]: https://pub.dev/packages/audio_session "audio_session package documentation"
[3]: https://developer.android.com/media/optimize/audio-focus "Manage audio focus"
