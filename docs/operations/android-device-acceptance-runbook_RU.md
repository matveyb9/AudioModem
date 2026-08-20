# Регламент device-acceptance для Android

**Статус:** Операционная процедура для ещё не выполненных измерений · **Последняя проверка:** 2026-08-21 · **Русский** · [English (canonical)](android-device-acceptance-runbook.md)

Этот регламент объясняет, как hardware tester может собрать проверяемое измерение маршрута **Android «динамик → микрофон»** для экспериментального `android-live-audio-adapter/v1`. Он не является результатом тестирования, перечнем поддерживаемых устройств, заявлением об интероперабельности или разрешением менять публичные compatibility claims. Source-contract check и CI-сборка APK подтверждают только свои source/artifact boundaries; для физического маршрута требуется отдельное наблюдение по этой процедуре.

## Граница сценария и доказательств

Проверяется только узкий маршрут: ограниченный текстовый payload `acoustic1` кодируется в 48 кГц, mono, signed PCM16 little-endian, воспроизводится foreground Android-источником, принимается микрофоном foreground Android-приёмника и декодируется после того, как tester остановит захват. Процедура не проверяет duplex, live-передачу файлов, Bluetooth, кабель, рацию, background operation, выбор устройства, automatic recovery, шифрование или поддержку Android в целом.

| Элемент | Обязательное условие | Что может подтвердить | Чего не подтверждает |
| --- | --- | --- | --- |
| Сборка | Используется committed revision с успешным Android APK CI job. Revision записывается точно. | Для этой revision был собран воспроизводимый debug APK. | Permission, playback, capture, маршрут, decode или compatibility. |
| Устройства | Android source и sink с API 26+. Записываются только `device_class` и, если модель можно раскрыть, `public_model`. | Наблюдаемую пару endpoint и API floor. | Другие модели и версии ОС. |
| Маршрут | `speaker_microphone`; тихая контролируемая среда, физическая расстановка точно описана в notes. | Наблюдение указанного физического маршрута. | Bluetooth, кабель, радио, шумоустойчивость или произвольную акустику. |
| Payload | Используется reviewed bounded text fixture с path и SHA-256. | Повторение комбинации fixture/profile/revision. | Доставку любого текста, изображений или файлов. |

## Подготовка

Возьмите APK из успешного Android CI run и определите его source commit. Не тестируйте локально изменённую рабочую копию. Зарядите оба endpoint, отключите постороннее аудио, начните в тихом помещении и выберите короткий не чувствительный text fixture. Не используйте разговоры, персональные данные, секреты или данные пользователей.

Adapter допускает только одну операцию за раз. Для этого маршрута держите **playback и capture на разных Android endpoint**. Убедитесь, что оба устройства имеют API не ниже 26. До теста canonical template должен остаться неизменным: `tools/device-acceptance/fixtures/android-speaker-microphone-template-v1.json` намеренно имеет `report_type: "template"` и не должен содержать observations.

> Руководство Android предписывает запрашивать dangerous permission в контексте действия, которому она нужна, и корректно деградировать при отказе. Поэтому capture check начинается только когда tester выбирает capture; не выдавайте микрофонную permission заранее лишь ради положительного результата. [1]

## Порядок выполнения

Следуйте последовательности и записывайте только фактически наблюдаемое. Остановленный, отклонённый, неудачный или inconclusive запуск — полезное evidence; его нельзя переписывать как успех.

| Шаг | Действие tester | Наблюдаемое ожидаемое поведение реализации | Что фиксировать |
| --- | --- | --- | --- |
| 1. Начальное состояние | Запустите APK на обоих endpoint. Убедитесь, что Android live-audio controls доступны, а не показывают unavailable reason. | App сообщает решение availability source adapter. | API levels, device classes, app revision и любой unavailable/error text. |
| 2. Граница playback | На source выберите bounded text и начните speaker playback. | Перед output app запрашивает playback focus. Если focus не granted, playback не должен начаться. [2] | `focus_outcome`: `granted`, `delayed_then_granted` либо inconclusive/rejected outcome с отображённой ошибкой. |
| 3. Контроль отказа permission | На sink выберите capture и откажите в system microphone prompt, если он появится. | Capture не должен начаться; app должна показать denied state без retention captured PCM. | Наблюдение отказа в narrative notes; не создавайте успешный measurement report по этому контролю. |
| 4. Контекстная permission | Повторно выберите capture и выдайте microphone permission через system flow. | Запрос появляется из user-initiated capture. Затем app пытается создать `AudioRecord` в v1 format. [1] | `permission_state: "granted"`; любая initialization error остаётся evidence, а не причиной пропустить run. |
| 5. Физический маршрут | Снова начните bounded playback на source и capture на sink. Сохраняйте documented distance/orientation. Явно остановите capture после окончания playback. | Capture frames временные до user stop; после stop Rust делает decode attempt. | Run count, accepted/rejected count, profile, fixture hash, route description и observed decode/error. |
| 6. Focus interruption | В отдельном run вызовите безопасное реальное competing audio-focus событие, например запустите другое local media app. Не совершайте emergency calls. | Реализация должна остановить active route и не auto-resume. Audio focus может быть вытеснен, playback должен реагировать на loss. [2] | Было ли interruption observed, resulting state и `interruption_policy: "stop_no_auto_resume"` только при фактическом подтверждении. |
| 7. Route/lifecycle interruption | В отдельных runs измените audio route только если это безопасно для hardware, а отдельно background/stop activity. | Host спроектирован stop/release active route на routing/lifecycle changes; `AudioRouting` даёт route-change notifications. [3] | `route_change_observed` как `true` или `false` и точное narrative action/app state. |

Не объединяйте playback и capture на одном device, не выводите маршрут лишь по icon и не повторяйте failed run до появления успеха с удалением ранних observations. В `run_count` включаются все попытки: validator требует `accepted_runs + rejected_runs = run_count`.

## Privacy и обращение с evidence

Default evidence mode — **raw recording не собирается**. Временный capture PCM приложения должен быть discarded после decode attempt, а Android observation должен содержать `raw_pcm_retention: "discarded"`. Не коммитьте raw PCM, WAV, screenshots с private data, logcat dumps с payload, microphone recordings, device serial numbers, account names или location data.

Если отдельная запись действительно требуется для будущего private review, сначала получите consent tester, по возможности удалите постороннюю речь, храните файл вне репозитория и публикуйте только availability class вместе с SHA-256 digest. Validator допускает `not_collected`, `private_available_on_request`, `public_redacted` и `public_unrestricted`; выбирайте наименее раскрывающий правдивый вариант. File digest подтверждает identity файла, но не audio quality и не route support.

## Создание и валидация measurement record

Скопируйте, но не редактируйте Android template в новый report, доступный для review. Заполните каждое поле только direct observation, измените `report_type` на `measurement` и включайте обязательный `adapter_observation` только для Android-to-Android `speaker_microphone` report. Validator требует в `requested_format` и `effective_format` именно такой v1 format:

```json
{
  "sample_rate_hz": 48000,
  "channels": 1,
  "sample_format": "pcm_s16le"
}
```

То же observation правдиво содержит `adapter_contract: "android-live-audio-adapter/v1"`, API level 26+, `operation: "playback_capture"`, granted permission state, supported focus outcome, boolean route-change result, `interruption_policy: "stop_no_auto_resume"` и `raw_pcm_retention: "discarded"`. До запроса review запустите validator:

```bash
node tools/device-acceptance/validate-report.mjs path/to/real-android-report.json
```

`observed` используется только для узкого documented measurement; `inconclusive` — для неполных/неоднозначных runs; `rejected` — для run, который не выполнил observed decode criterion. Valid JSON доказывает только schema conformance. Public compatibility wording не меняется, пока maintainers не review complete report, reproducibility inputs и privacy handling.

## References

[1] [Android Developers: Request runtime permissions](https://developer.android.com/training/permissions/requesting)

[2] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)

[3] [Android Developers: `AudioTrack.OnRoutingChangedListener` / `AudioRouting`](https://developer.android.com/reference/android/media/AudioTrack.OnRoutingChangedListener)
