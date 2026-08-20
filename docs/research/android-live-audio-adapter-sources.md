# Android live-audio adapter research note

**Status:** Informative research for an experimental route RFC. It is not a compatibility claim.

## Decision

The first platform-specific live-audio design target is **Android foreground playback and capture**. It fits the existing Flutter shell and lets the project exercise a permission-bearing mobile route without expanding into Linux session-manager policy. The design target is deliberately narrower than “Android support”: it will establish an adapter contract and a route-specific evidence method, not a general device matrix.

| Consideration | Android first target | Linux desktop deferred target |
| --- | --- | --- |
| Platform surface | `AudioRecord` pulls capture frames and `AudioTrack` pushes PCM playback frames. [1] [2] | PipeWire has devices, nodes, ports, links and a session manager that configures and re-links them. [5] [6] |
| User-consent boundary | `RECORD_AUDIO` is a runtime permission and should be requested in the context of the action that needs it. [1] [3] | Device enablement, profiles, routes and access policy are distribution/session-manager concerns. [6] |
| Playback lifecycle | The app should obtain audio focus immediately before playback, react to focus loss, and abandon focus after playback ends. Android 15 adds a foreground/top-app condition for requesting focus. [4] | Dynamic sink/source changes and links are managed across PipeWire and a session manager. [5] [6] |
| First acceptance scope | A foreground, user-initiated, default-route experiment with explicit device observations. | A later route RFC must select backend, session-manager assumptions and a reproducible Linux environment. |

## Constraints carried into the RFC

`AudioRecord` requires `RECORD_AUDIO`; it records by application reads and reports initialization/operation errors. Its buffer needs to be read before it overruns. [1] The Android adapter must therefore create capture only after the foreground user action and granted permission, reject an uninitialized record, surface read errors, stop/release deterministically and never retain raw microphone PCM after the active attempt.

`AudioTrack` accepts PCM through application writes and supports streaming mode. [2] The adapter should write the existing Rust-produced PCM in bounded chunks, stop/release deterministically, and report write or initialization failure rather than declaring a transmission completed. It must request focus immediately before user-initiated playback and cease playback on permanent or transient focus loss; delayed focus is a waiting state, not permission to start. [4]

The existing `PcmStreamFormat.audioModemV1` remains the application intent: **48 kHz, mono, signed PCM16 little-endian**. Android API documentation guarantees neither that a requested 48 kHz capture configuration is available on every device nor that an actual route remains unchanged. The adapter must inspect the created format/routed device and enter a rejected or route-changed diagnostic state when it cannot preserve the v1 format. `setPreferredDevice()` is only a preference, so first implementation must not advertise cable, Bluetooth, headset or radio routing. [1] [2]

The first adapter will not start a foreground service, operate while the app is backgrounded, record continuously, auto-resume after interruption, choose a Bluetooth route, perform duplex echo cancellation, or claim speaker-to-microphone delivery. Android permission guidance requires a feature to degrade gracefully after denial or revocation; the WAV workflow remains available in those states. [3]

## Sources

[1] [Android Developers: `AudioRecord` API reference](https://developer.android.com/reference/android/media/AudioRecord)

[2] [Android Developers: `AudioTrack` API reference](https://developer.android.com/reference/android/media/AudioTrack)

[3] [Android Developers: Request runtime permissions](https://developer.android.com/training/permissions/requesting)

[4] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)

[5] [PipeWire: Overview](https://docs.pipewire.org/devel/page_overview.html)

[6] [WirePlumber: Understanding session management](https://pipewire.pages.freedesktop.org/wireplumber/design/understanding_session_management.html)
