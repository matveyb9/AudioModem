# Android foreground live-audio implementation slice

[English (canonical)](android-live-audio.md) · **Русский перевод**

> **Translation of:** [docs/architecture/android-live-audio.md](android-live-audio.md). **Last synced:** 2026-08-21.

**Статус:** Experimental source implementation. Документ описывает source implementation в границах [Android foreground live-audio adapter v1 RFC](../../spec/android-live-audio-adapter-v1_RU.md). Он не устанавливает Android target build, granted runtime permission, observed physical route, acoustic interoperability, device compatibility или support status.

## Реализованная граница

| Слой | Реализованная ответственность | Не реализовано или не установлено |
| --- | --- | --- |
| Rust core | Acoustic-1 напрямую encodes/decodes mono signed PCM16 LE, используя существующий carrier/FEC/ADLP path. | Live timing recovery, AGC, echo cancellation, resampling или physical-channel claim. |
| Rust bridge | Bounded text-to-live-PCM и captured-PCM-to-verified-text methods принимают только `acoustic1`; bootstrap остаётся WAV-only. | File live PCM, unbounded stream decode или hardware access. |
| Flutter | Typed Android adapter валидирует v1 PCM, запускает user-initiated playback/capture и передаёт capture frames в Rust только после user stop. | ADLP/DSP в Dart, background operation, automatic resume, device picker или retained raw PCM. |
| Android host | `AudioTrack` streaming playback, `AudioRecord` capture, contextual `RECORD_AUDIO`, playback focus, stop/release при interruption/lifecycle stop и EventChannel для transient capture frames. | Bluetooth/cable/radio routing, `setPreferredDevice`, foreground service, duplex, Android device validation или support claim. |

Единственный encoded live object — bounded text object с experimental `acoustic1`. Перед `AudioTrack` Flutter просит Rust encode PCM и один раз декодирует тот же in-memory PCM через Rust как codec boundary check. Эта проверка не доказывает acoustic output или receiver delivery.

```text
text → Rust ADLP + Acoustic-1 PCM → Flutter Android adapter → AudioTrack
                                                    │
AudioRecord → transient EventChannel PCM → Flutter → Rust Acoustic-1 + ADLP verification
```

Capture начинается только после нажатия Android capture control. Kotlin host запрашивает `RECORD_AUDIO` только тогда. При user stop, route/lifecycle stop или event cancellation host stop/release native objects; Flutter discard temporary PCM buffer после decode attempt. Playback запрашивает focus непосредственно перед `AudioTrack.play()` и stop/release при focus loss. Эти решения реализуют Android focus и permission constraints из RFC. [1] [2] [3]

## Evidence state

Committed Rust tests, Flutter MethodChannel tests и portable widget tests проверяют contract paths. Это не native Android или hardware tests. Target build, permission prompt, focus transition, capture device format, actual output route и speaker-to-microphone decode остаются непроверенными до запуска на real hardware.

| Claim candidate | Current evidence | Permitted wording |
| --- | --- | --- |
| Rust live PCM conversion | Rust core/bridge unit tests | `source-tested PCM contract` |
| Flutter lifecycle mapping | Portable MethodChannel и widget tests | `source-tested adapter behavior` |
| Android compilation/runtime | Коммитнутых данных нет | No claim |
| Physical route | Нет measurement report | No claim |
| Platform или route support | Нет reviewed build и route evidence | No claim |

[Android speaker-to-microphone template](../../tools/device-acceptance/fixtures/android-speaker-microphone-template-v1.json) остаётся unexecuted. Future real `physical_route` record обязан включать Android adapter observation fields, enforced validator'ом, и не должен retain/upload raw PCM по умолчанию.

## References

[1] [Android Developers: `AudioRecord` API reference](https://developer.android.com/reference/android/media/AudioRecord)

[2] [Android Developers: `AudioTrack` API reference](https://developer.android.com/reference/android/media/AudioTrack)

[3] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)
