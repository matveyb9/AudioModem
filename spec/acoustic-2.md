# Acoustic-2 controlled measurement profile

**Status:** Experimental measurement contract · **English (canonical)** · [Русский](acoustic-2_RU.md)

Acoustic-2 is not a new ADLP wire format or a live-audio carrier. It is a reproducible measurement layer around the existing experimental Acoustic-1 PCM/WAV codec. It lets contributors apply declared integer-domain sample transforms, invoke the unchanged Acoustic-1 decoder and record a small set of codec-observable acquisition values.

The resulting measurement is evidence only for the named input WAV, exact transform parameters and current codec implementation. It is not evidence of a speaker, microphone, room, OS audio stack, cable, Bluetooth device, radio interface, SNR, BER, range, clock drift or interoperability.

## Input and output contract

The input is a canonical mono 16-bit PCM, 48 kHz WAV accepted by the Acoustic-1 decoder. The harness first parses the canonical WAV, applies the transform sequence below, re-encodes canonical WAV bytes and calls the existing `acoustic1::decode_wav` function. It never parses ADLP bytes itself.

| Field | Type and bound | Meaning |
| --- | --- | --- |
| `leading_silence_samples` | `0..=480` | Zero-valued samples inserted before the frame. The upper bound equals Acoustic-1's bounded acquisition search window. |
| `gain_per_mille` | `1..=1,000` | Fixed integer gain applied to every sample, then saturated to signed 16-bit PCM. It models attenuation only. |
| `noise_peak` | `0..=1,000` | Peak absolute integer additive noise from the defined deterministic generator. It is not an SNR value. |
| `noise_seed` | `u32` | Seed for the defined linear congruential generator; identical inputs and seed must yield identical samples. |
| `clip_abs` | absent or `1..=32,767` | Symmetric hard clip threshold applied after gain and noise. |
| `drop_every_nth_sample` | absent or `>=2` | Remove every nth transformed sample. This represents a fixed sample deletion experiment, not resampling, clock drift or jitter. |

Transforms are ordered as **gain → additive noise → clip → periodic sample deletion → leading silence**. Saturating integer arithmetic is mandatory. A result reports the input/output sample counts, dropped-sample count, transform descriptor, selected Acoustic-1 acquisition offset, samples consumed and decoded ADLP profile only when the existing decoder accepts the result.

## Measurement cases

The repository regression suite must cover at least the following deterministic cases using a fixed Acoustic-1 object.

| Case | Expected result | Claim excluded |
| --- | --- | --- |
| Baseline, no transform | Accepted with candidate offset `0`. | Any live route. |
| Bounded leading silence | Accepted with an acquisition candidate inside the 480-sample search window. | General timing recovery. |
| Attenuation and bounded seeded noise | Accepted under the exact declared parameters. | SNR threshold or noisy-room tolerance. |
| Hard clipping | Accepted or rejected only according to the fixed declared vector. | Microphone/speaker distortion tolerance. |
| Periodic deletion | Rejection under the fixed declared vector. | Clock-drift, resampling or jitter behavior. |
| Offset beyond 480 samples | Rejection. | Arbitrary frame acquisition. |

## Compatibility and evolution

This profile does not alter Acoustic-1 framing, Hamming(7,4), ADLP CRC-32C or either existing golden WAV. A result change caused by modified transform semantics, decode behavior or fixture bytes is a measurement compatibility change and must include updated tests, rationale and release notes.

Before a live-audio adapter can use these results, the project needs a separate route RFC, device classes, capture/playback settings, accepted measurement method, raw recordings, reproducible scripts and a declared acceptance matrix. The background research and limits are recorded in [Acoustic-2 measurement sources](../docs/research/acoustic-2-measurement-sources.md).
