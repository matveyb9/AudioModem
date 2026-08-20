# Контролируемый measurement profile Acoustic-2

[English (canonical)](acoustic-2.md) · **Русский перевод**

> **Translation of:** [spec/acoustic-2.md](acoustic-2.md). **Last synced:** 2026-08-20. Английский оригинал нормативен для compatibility implementation.

Acoustic-2 не является новым ADLP wire format или live-audio carrier. Это воспроизводимый measurement layer вокруг существующего экспериментального Acoustic-1 PCM/WAV codec. Он позволяет contributors применять объявленные integer-domain sample transforms, вызывать неизменённый Acoustic-1 decoder и записывать небольшой набор codec-observable acquisition values.

Полученное measurement является evidence только для named input WAV, точных transform parameters и текущей реализации codec. Оно не является evidence для динамика, микрофона, помещения, OS audio stack, кабеля, Bluetooth device, radio interface, SNR, BER, дальности, clock drift или interoperability.

## Контракт входа и выхода

Входом является canonical mono 16-bit PCM, 48 kHz WAV, принимаемый Acoustic-1 decoder. Harness сначала разбирает canonical WAV, применяет указанную ниже transform sequence, повторно кодирует canonical WAV bytes и вызывает существующую функцию `acoustic1::decode_wav`. Он никогда не разбирает ADLP bytes самостоятельно.

| Поле | Тип и bound | Значение |
| --- | --- | --- |
| `leading_silence_samples` | `0..=480` | Zero-valued samples, вставляемые перед frame. Upper bound равен Acoustic-1 bounded acquisition search window. |
| `gain_per_mille` | `1..=1,000` | Fixed integer gain для каждого sample с последующей saturating операцией в signed 16-bit PCM. Моделирует только attenuation. |
| `noise_peak` | `0..=1,000` | Peak absolute integer additive noise из определённого deterministic generator. Это не SNR value. |
| `noise_seed` | `u32` | Seed определённого linear congruential generator; одинаковые inputs и seed обязаны дать одинаковые samples. |
| `clip_abs` | отсутствует или `1..=32,767` | Symmetric hard clip threshold после gain и noise. |
| `drop_every_nth_sample` | отсутствует или `>=2` | Удалить каждый nth transformed sample. Это fixed sample deletion experiment, а не resampling, clock drift или jitter. |

Transforms применяются в порядке **gain → additive noise → clip → periodic sample deletion → leading silence**. Saturating integer arithmetic обязателен. Result сообщает input/output sample counts, dropped-sample count, transform descriptor, выбранный Acoustic-1 acquisition offset, samples consumed и decoded ADLP profile только когда существующий decoder принимает результат.

## Measurement cases

Repository regression suite обязана покрывать как минимум следующие deterministic cases с fixed Acoustic-1 object.

| Case | Ожидаемый результат | Исключённое утверждение |
| --- | --- | --- |
| Baseline без transform | Accepted с candidate offset `0`. | Любой live route. |
| Bounded leading silence | Accepted с acquisition candidate внутри 480-sample search window. | General timing recovery. |
| Attenuation и bounded seeded noise | Accepted при точно объявленных parameters. | SNR threshold или noisy-room tolerance. |
| Hard clipping | Accepted или rejected только по fixed declared vector. | Microphone/speaker distortion tolerance. |
| Periodic deletion | Rejection при fixed declared vector. | Clock-drift, resampling или jitter behavior. |
| Offset свыше 480 samples | Rejection. | Arbitrary frame acquisition. |

## Compatibility и дальнейшее развитие

Этот profile не меняет Acoustic-1 framing, Hamming(7,4), ADLP CRC-32C или существующие golden WAV. Изменение result из-за transform semantics, decode behavior или fixture bytes является measurement compatibility change и требует updated tests, rationale и release notes.

До использования этих results live-audio adapter'ом проекту нужен отдельный route RFC, device classes, capture/playback settings, accepted measurement method, raw recordings, reproducible scripts и declared acceptance matrix. Исследовательские основания и limits зафиксированы в [Acoustic-2 measurement sources](../docs/research/acoustic-2-measurement-sources.md).
