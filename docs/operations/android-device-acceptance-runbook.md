# Android device-acceptance runbook

**Status:** Operational procedure for unexecuted measurements · **Last reviewed:** 2026-08-21 · **English (canonical)** · [Русский](android-device-acceptance-runbook_RU.md)

This runbook describes how a hardware tester may collect a reviewable **Android speaker-to-microphone** measurement for the experimental `android-live-audio-adapter/v1`. It is not a test result, device-support list, interoperability claim, or authorization to change public compatibility wording. A source-contract check and a CI APK build only establish their respective source and artifact boundaries; this procedure is required to gather a separate physical-route observation.

## Scope and evidence boundary

The tested route is deliberately narrow: a bounded `acoustic1` text payload is encoded to 48 kHz mono signed PCM16 little-endian, played by a foreground Android source endpoint, acoustically received by a foreground Android sink endpoint, and decoded after the tester stops capture. It does not test duplex operation, file live transfer, Bluetooth, cable, radio, background operation, device selection, automatic recovery, encryption, or general Android support.

| Item | Required condition | What it can establish | What it cannot establish |
| --- | --- | --- | --- |
| Build input | Use a committed revision whose Android APK CI job passed. Record that revision exactly. | A reproducible debug APK was built for that revision. | Permission, playback, capture, route, decode, or compatibility. |
| Devices | Use Android API 26+ source and sink endpoints. Record only `device_class` and, if voluntarily shareable, `public_model`. | The observed endpoint pair and API floor. | Coverage of other models or OS builds. |
| Route | `speaker_microphone`; use a quiet, controlled setup and record a precise physical arrangement in notes. | The stated physical route observation. | Bluetooth, cable, radio, noise resilience, or unrestricted acoustic operation. |
| Payload | Use the reviewed bounded text fixture and record its path and SHA-256. | Reproduction of that fixture/profile/revision combination. | Delivery of arbitrary text, images, or files. |

## Preparation

Prepare the APK from a successful Android CI run and identify its source commit. Do not test a locally modified checkout. Charge both endpoints, disable unrelated audio output, begin with a quiet room, and choose a short non-sensitive text fixture. Do not use conversations, personally identifying material, secrets, or customer data as a test payload.

The adapter supports only one operation at a time. Keep **playback and capture on separate Android endpoints** for this route. Ensure that both devices show an API level of at least 26. Before the test, keep the canonical template unchanged: `tools/device-acceptance/fixtures/android-speaker-microphone-template-v1.json` is intentionally a `report_type: "template"` and must contain no observations.

> Android guidance is to request a dangerous permission in the context of the action that needs it, then degrade gracefully if it is denied. The capture check below therefore begins only when the tester selects capture; do not try to grant microphone permission in advance merely to make a result look successful. [1]

## Execution procedure

Use the following sequence and write down only what was actually observed. A test that is stopped, denied, rejected, or inconclusive is valuable evidence and must not be rewritten as a success.

| Step | Tester action | Expected implementation behavior to observe | Record in report or notes |
| --- | --- | --- | --- |
| 1. Start state | Launch the APK on both endpoints. Confirm the Android live-audio controls are available rather than showing an unavailable reason. | The app reports the source adapter’s availability decision. | API levels, device classes, app revision, and any unavailable/error wording. |
| 2. Playback boundary | On the source endpoint, select the bounded text and start speaker playback. | The app asks for playback focus immediately before output. If focus is not granted, it must not proceed with playback. [2] | `focus_outcome`: `granted`, `delayed_then_granted`, or an inconclusive/rejected outcome with the displayed error. |
| 3. Permission denial control | On the sink endpoint, select capture and deny the system microphone prompt if it appears. | Capture must not start; the app must surface the denied state without retaining captured PCM. | The denial observation in narrative notes; do not create a successful measurement report from this control. |
| 4. Contextual permission | Select capture again and grant microphone permission through the system flow. | The request occurs because the user initiated capture. The app then attempts `AudioRecord` with the v1 format. [1] | `permission_state: "granted"`; any initialization error remains evidence, not a reason to omit the run. |
| 5. Physical route | Restart the bounded playback on source and start capture on sink. Keep devices stationary at the documented spacing/orientation. Stop capture explicitly after playback ends. | Capture frames are transient until the user stop; Rust performs the decode attempt after stop. | Run count, accepted/rejected count, profile, fixture hash, route description, and observed decode or error. |
| 6. Focus interruption | During a separate run, cause a real competing audio-focus event where safe (for example, start another local media app). Do not make emergency calls. | The implementation should stop the active route and not auto-resume. Audio focus can be preempted and playback should respond to loss. [2] | Whether interruption was observed, resulting state, and `interruption_policy: "stop_no_auto_resume"` only if actually confirmed. |
| 7. Route/lifecycle interruption | During separate runs, change an audio route only if the hardware safely permits it, and separately background/stop the activity. | The host is designed to stop/release the active route on routing or lifecycle changes; `AudioRouting` provides route-change notifications. [3] | `route_change_observed` as `true` or `false`, plus an exact narrative of the action and app state. |

Do not combine simultaneous playback and capture on one device, do not infer a route from an icon, and do not repeat a failing run until it appears successful while discarding earlier observations. Record all attempts in `run_count`; the validator requires `accepted_runs + rejected_runs = run_count`.

## Privacy and evidence handling

The default evidence mode is **no raw recording collected**. The application’s transient capture PCM must be discarded after the decode attempt, and the Android observation must use `raw_pcm_retention: "discarded"`. Do not commit raw PCM, WAV files, screenshots containing private data, logcat dumps containing payloads, microphone recordings, device serial numbers, account names, or location information.

If a separate recording is legitimately required for a later private review, first obtain the tester’s consent, remove unrelated speech where feasible, store it outside the repository, and publish only the availability class plus a SHA-256 digest. The validator permits `not_collected`, `private_available_on_request`, `public_redacted`, or `public_unrestricted`; use the least-disclosing truthful value. A file digest establishes file identity, not audio quality or route support.

## Creating and validating a measurement record

Copy—not edit—the Android template into a new, reviewed report location. Replace every placeholder through direct observation, set `report_type` to `measurement`, and include the required `adapter_observation` object only for an Android-to-Android `speaker_microphone` report. The validator requires this exact v1 format in both `requested_format` and `effective_format`:

```json
{
  "sample_rate_hz": 48000,
  "channels": 1,
  "sample_format": "pcm_s16le"
}
```

The same observation must truthfully contain `adapter_contract: "android-live-audio-adapter/v1"`, an API level of 26 or higher, `operation: "playback_capture"`, a granted permission state, a supported focus outcome, a boolean route-change result, `interruption_policy: "stop_no_auto_resume"`, and `raw_pcm_retention: "discarded"`. Run the validator before requesting review:

```bash
node tools/device-acceptance/validate-report.mjs path/to/real-android-report.json
```

Use `observed` only for the narrow, documented measurement; use `inconclusive` for incomplete/ambiguous runs; use `rejected` for a run that did not meet its observed decode criterion. A valid JSON file proves schema conformance only. Public compatibility language remains unchanged until maintainers review the complete report, reproducibility inputs, and privacy handling.

## References

[1] [Android Developers: Request runtime permissions](https://developer.android.com/training/permissions/requesting)

[2] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)

[3] [Android Developers: `AudioTrack.OnRoutingChangedListener` / `AudioRouting`](https://developer.android.com/reference/android/media/AudioTrack.OnRoutingChangedListener)
