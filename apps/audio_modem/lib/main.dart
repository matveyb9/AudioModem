// AudioModem Flutter workbench: UI stays transport-aware while Rust owns ADLP and WAV codec behavior.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'bridge/wav_bootstrap_bridge.dart';
import 'platform/live_audio_adapter.dart';
import 'platform/payload_file_adapter.dart';
import 'platform/wav_file_adapter.dart';
import 'transfer/transfer_task.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WavBootstrapBridge bridge;
  try {
    bridge = await NativeWavBootstrapBridge.create();
  } catch (error) {
    bridge = UnavailableWavBootstrapBridge(
      'Rust/WAV bridge initialization failed: $error',
    );
  }
  runApp(
    AudioModemApp(
      bridge: bridge,
      fileAdapter: const PlatformWavFileAdapter(),
      payloadFileAdapter: const PlatformPayloadFileAdapter(),
      liveAudioAdapter: const UnavailableLiveAudioAdapter(),
    ),
  );
}

class AudioModemApp extends StatelessWidget {
  const AudioModemApp({
    super.key,
    required this.bridge,
    required this.fileAdapter,
    this.payloadFileAdapter = const PlatformPayloadFileAdapter(),
    this.liveAudioAdapter = const UnavailableLiveAudioAdapter(),
  });

  final WavBootstrapBridge bridge;
  final WavFileAdapter fileAdapter;
  final PayloadFileAdapter payloadFileAdapter;
  final LiveAudioAdapter liveAudioAdapter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AudioModem',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB000),
          brightness: Brightness.light,
          surface: const Color(0xFFFFFCF5),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFCF5),
        useMaterial3: true,
      ),
      home: TransferWorkbench(
        bridge: bridge,
        fileAdapter: fileAdapter,
        payloadFileAdapter: payloadFileAdapter,
        liveAudioAdapter: liveAudioAdapter,
      ),
    );
  }
}

class TransferWorkbench extends StatefulWidget {
  const TransferWorkbench({
    super.key,
    required this.bridge,
    required this.fileAdapter,
    required this.payloadFileAdapter,
    required this.liveAudioAdapter,
  });

  final WavBootstrapBridge bridge;
  final WavFileAdapter fileAdapter;
  final PayloadFileAdapter payloadFileAdapter;
  final LiveAudioAdapter liveAudioAdapter;

  @override
  State<TransferWorkbench> createState() => _TransferWorkbenchState();
}

class _TransferWorkbenchState extends State<TransferWorkbench> {
  final _callsign = TextEditingController(text: 'N1');
  final _text = TextEditingController(text: 'Привет через AudioModem');
  TransferPreset _preset = TransferPreset.balanced;
  CarrierKind _carrier = CarrierKind.bootstrap;
  TransferRoute _route = TransferRoute.wav;
  TransferObjectKind _objectKind = TransferObjectKind.text;
  int _tabIndex = 0;
  TransferTaskState _task = const TransferTaskState.idle();
  WavBuildResult? _builtWav;
  WavDecodeResult? _decodedWav;
  WavFileDecodeResult? _decodedFileWav;
  SelectedPayloadFile? _selectedPayloadFile;
  String? _activeWavName;
  Uint8List? _activeWavBytes;
  CarrierKind? _activeCarrier;
  String? _bridgeError;

  bool get _isWorking => _task.isBusy;

  @override
  void dispose() {
    _callsign.dispose();
    _text.dispose();
    super.dispose();
  }

  void _setTask(TransferTaskState task, {String? bridgeError}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _task = task;
      _bridgeError = bridgeError;
    });
  }

  void _resetTaskAfterEdit() {
    setState(() {
      if (_task.isTerminal) {
        _task = const TransferTaskState.idle();
      }
    });
  }

  Future<void> _selectPayloadFile() async {
    _setTask(TransferTaskState.preparing('Выбор файла для ADLP объекта…'));
    try {
      final selected = await widget.payloadFileAdapter.openPayload();
      if (!mounted) {
        return;
      }
      if (selected == null) {
        _setTask(TransferTaskState.cancelled('Выбор файла отменён.'));
        return;
      }
      setState(() {
        _selectedPayloadFile = selected;
        _task = TransferTaskState.completed(
          'Файл выбран для WAV reference path.',
          detail: '${selected.name} · ${selected.bytes.length} байт',
        );
      });
    } catch (error) {
      _setTask(
        TransferTaskState.rejected(
          'Не удалось прочитать выбранный файл.',
          detail: error.toString(),
        ),
        bridgeError: error.toString(),
      );
    }
  }

  String _mimeTypeFor(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.txt')) return 'text/plain';
    if (normalized.endsWith('.json')) return 'application/json';
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }

  Future<void> _buildAndVerifyWav() async {
    if (_route != TransferRoute.wav) {
      final reason =
          widget.liveAudioAdapter.availability.reason ??
          'Live-audio маршрут недоступен. Выберите WAV-маршрут.';
      _setTask(TransferTaskState.unavailable(reason));
      _showMessage(reason);
      return;
    }
    if (!widget.bridge.isAvailable) {
      const reason = 'Rust/WAV bridge недоступен в этой сборке.';
      _setTask(TransferTaskState.unavailable(reason));
      _showMessage(reason);
      return;
    }
    final selectedPayloadFile = _selectedPayloadFile;
    if (_objectKind == TransferObjectKind.file && selectedPayloadFile == null) {
      const reason = 'Сначала выберите файл для ADLP объекта.';
      _setTask(TransferTaskState.rejected(reason));
      _showMessage(reason);
      return;
    }
    _setTask(TransferTaskState.preparing('Сборка ADLP/WAV в Rust…'));
    try {
      final sessionId = DateTime.now().microsecondsSinceEpoch;
      if (_objectKind == TransferObjectKind.text) {
        final built = await widget.bridge.encodeText(
          sessionId: sessionId,
          senderCallsign: _callsign.text.trim(),
          text: _text.text,
          profile: _preset.bridgeProfile,
          carrier: _carrier.bridgeCarrier,
        );
        _setTask(TransferTaskState.verifying('Проверка WAV Rust decoder…'));
        final decoded = await widget.bridge.decodeWav(
          wavBytes: built.wavBytes,
          carrier: _carrier.bridgeCarrier,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _builtWav = built;
          _decodedWav = decoded;
          _decodedFileWav = null;
          _activeWavName = _suggestedWavName(built.sessionId, _carrier);
          _activeWavBytes = built.wavBytes;
          _activeCarrier = _carrier;
          _task = TransferTaskState.completed(
            'Text WAV собран и проверен.',
            detail: 'Rust decoder подтвердил framing, manifest и CRC-32C.',
          );
        });
      } else {
        final payload = selectedPayloadFile!;
        final built = await widget.bridge.encodeFile(
          sessionId: sessionId,
          senderCallsign: _callsign.text.trim(),
          fileName: payload.name,
          mimeType: _mimeTypeFor(payload.name),
          payload: payload.bytes,
          profile: _preset.bridgeProfile,
          carrier: _carrier.bridgeCarrier,
        );
        _setTask(
          TransferTaskState.verifying('Проверка file WAV Rust decoder…'),
        );
        final decoded = await widget.bridge.decodeWavFile(
          wavBytes: built.wavBytes,
          carrier: _carrier.bridgeCarrier,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _builtWav = built;
          _decodedWav = null;
          _decodedFileWav = decoded;
          _activeWavName = _suggestedWavName(built.sessionId, _carrier);
          _activeWavBytes = built.wavBytes;
          _activeCarrier = _carrier;
          _task = TransferTaskState.completed(
            'File WAV собран и проверен.',
            detail: '${decoded.fileName} · ${decoded.payload.length} байт',
          );
        });
      }
      _showMessage('WAV собран и проверен Rust decoder.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setTask(
        TransferTaskState.rejected(
          'Rust bridge отклонил передачу.',
          detail: error.toString(),
        ),
        bridgeError: error.toString(),
      );
      _showMessage('Rust bridge отклонил передачу. Проверьте поля объекта.');
    }
  }

  Future<void> _verifyCurrentWav() async {
    final wavBytes = _activeWavBytes;
    final carrier = _activeCarrier;
    if (wavBytes == null || carrier == null) {
      const reason = 'Сначала соберите или импортируйте WAV.';
      _setTask(TransferTaskState.rejected(reason));
      _showMessage(reason);
      return;
    }
    _setTask(TransferTaskState.verifying('Повторная проверка WAV…'));
    try {
      if (_decodedFileWav != null) {
        final decoded = await widget.bridge.decodeWavFile(
          wavBytes: wavBytes,
          carrier: carrier.bridgeCarrier,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _decodedFileWav = decoded;
          _decodedWav = null;
          _task = TransferTaskState.completed(
            'File WAV повторно проверен.',
            detail: '${decoded.fileName} · ${decoded.payload.length} байт',
          );
        });
      } else {
        final decoded = await widget.bridge.decodeWav(
          wavBytes: wavBytes,
          carrier: carrier.bridgeCarrier,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _decodedWav = decoded;
          _decodedFileWav = null;
          _task = TransferTaskState.completed(
            'WAV повторно проверен.',
            detail: 'Rust decoder подтвердил текущие WAV bytes.',
          );
        });
      }
      _showMessage('WAV повторно проверен Rust decoder.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setTask(
        TransferTaskState.rejected(
          'Rust decoder отклонил текущий WAV.',
          detail: error.toString(),
        ),
        bridgeError: error.toString(),
      );
    }
  }

  Future<void> _exportBuiltWav() async {
    final built = _builtWav;
    if (built == null) {
      const reason = 'Сначала соберите WAV во вкладке «Передать».';
      _setTask(TransferTaskState.rejected(reason));
      _showMessage(reason);
      return;
    }
    _setTask(TransferTaskState.preparing('Сохранение WAV…'));
    try {
      final saved = await widget.fileAdapter.saveWav(
        suggestedName: _suggestedWavName(built.sessionId, _carrier),
        bytes: built.wavBytes,
      );
      if (!mounted) {
        return;
      }
      if (saved == null) {
        _setTask(TransferTaskState.cancelled('Экспорт WAV отменён.'));
        _showMessage('Экспорт WAV отменён.');
      } else {
        _setTask(
          TransferTaskState.completed(
            'WAV сохранён.',
            detail: 'Файл: ${saved.name}',
          ),
        );
        _showMessage('WAV сохранён: ${saved.name}.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setTask(
        TransferTaskState.rejected(
          'Не удалось сохранить WAV.',
          detail: error.toString(),
        ),
        bridgeError: error.toString(),
      );
      _showMessage('Не удалось сохранить WAV.');
    }
  }

  Future<void> _importAndVerifyWav() async {
    if (!widget.bridge.isAvailable) {
      const reason = 'Rust/WAV bridge недоступен в этой сборке.';
      _setTask(TransferTaskState.unavailable(reason));
      _showMessage(reason);
      return;
    }
    _setTask(TransferTaskState.preparing('Выбор WAV для импорта…'));
    try {
      final selected = await widget.fileAdapter.openWav();
      if (selected == null) {
        if (mounted) {
          _setTask(TransferTaskState.cancelled('Импорт WAV отменён.'));
          _showMessage('Импорт WAV отменён.');
        }
        return;
      }
      _setTask(TransferTaskState.verifying('Проверка импортированного WAV…'));
      WavDecodeResult? decodedText;
      WavFileDecodeResult? decodedFile;
      try {
        decodedText = await widget.bridge.decodeWav(
          wavBytes: selected.bytes,
          carrier: _carrier.bridgeCarrier,
        );
      } catch (_) {
        decodedFile = await widget.bridge.decodeWavFile(
          wavBytes: selected.bytes,
          carrier: _carrier.bridgeCarrier,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _activeWavName = selected.name;
        _activeWavBytes = selected.bytes;
        _activeCarrier = _carrier;
        _decodedWav = decodedText;
        _decodedFileWav = decodedFile;
        _task = TransferTaskState.completed(
          'WAV импортирован и проверен.',
          detail: decodedFile == null
              ? 'Text object · источник: ${selected.name}'
              : '${decodedFile.fileName} · ${decodedFile.payload.length} байт',
        );
      });
      _showMessage('WAV импортирован и проверен Rust decoder.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setTask(
        TransferTaskState.rejected(
          'Импортированный файл не является корректной WAV передачей.',
          detail: error.toString(),
        ),
        bridgeError: error.toString(),
      );
      _showMessage(
        'Импортированный файл не является корректной WAV передачей.',
      );
    }
  }

  Future<void> _saveDecodedPayload() async {
    final decoded = _decodedFileWav;
    if (decoded == null) {
      const reason = 'Нет проверенного file payload для сохранения.';
      _setTask(TransferTaskState.rejected(reason));
      _showMessage(reason);
      return;
    }
    _setTask(
      TransferTaskState.preparing('Сохранение проверенного file payload…'),
    );
    try {
      final saved = await widget.payloadFileAdapter.savePayload(
        suggestedName: decoded.fileName,
        bytes: decoded.payload,
      );
      if (!mounted) {
        return;
      }
      if (saved == null) {
        _setTask(
          TransferTaskState.cancelled('Сохранение file payload отменено.'),
        );
        return;
      }
      _setTask(
        TransferTaskState.completed(
          'Проверенный file payload сохранён.',
          detail: saved.name,
        ),
      );
      _showMessage('Файл сохранён: ${saved.name}.');
    } catch (error) {
      _setTask(
        TransferTaskState.rejected(
          'Не удалось сохранить file payload.',
          detail: error.toString(),
        ),
        bridgeError: error.toString(),
      );
      _showMessage('Не удалось сохранить file payload.');
    }
  }

  String _suggestedWavName(int sessionId, CarrierKind carrier) =>
      'adlp-${carrier.fileStem}-$sessionId.wav';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _tabIndex,
              labelType: isWide
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.none,
              onDestinationSelected: (value) =>
                  setState(() => _tabIndex = value),
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: SignalMark(),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.north_east),
                  label: Text('Передать'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.south_west),
                  label: Text('Принять'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _tabIndex == 0
                    ? _buildSend(context)
                    : _buildReceive(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSend(BuildContext context) {
    final bytes = utf8.encode(_text.text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПЕРЕДАЧА / ADLP-1',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Соберите и проверьте WAV.',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Rust создаёт версионированный ADLP object, кодирует выбранный canonical WAV carrier в памяти и сразу декодирует его для проверки целостности.',
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(width: 440, child: _messageCard(context)),
            SizedBox(width: 320, child: _planCard(context, bytes)),
          ],
        ),
      ],
    );
  }

  Widget _messageCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Объект', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _callsign,
              maxLength: 32,
              onChanged: (_) {
                _resetTaskAfterEdit();
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Позывной отправителя',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Text('Тип объекта', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TransferObjectKind>(
              segments: TransferObjectKind.values
                  .map(
                    (kind) => ButtonSegment(
                      value: kind,
                      icon: Icon(kind.icon),
                      label: Text(kind.label),
                    ),
                  )
                  .toList(),
              selected: {_objectKind},
              onSelectionChanged: (value) {
                _resetTaskAfterEdit();
                setState(() => _objectKind = value.first);
              },
            ),
            const SizedBox(height: 12),
            if (_objectKind == TransferObjectKind.text)
              TextField(
                controller: _text,
                minLines: 5,
                maxLines: 8,
                onChanged: (_) {
                  _resetTaskAfterEdit();
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'Текст',
                  alignLabelWithHint: true,
                  hintText: 'Введите сообщение для ADLP-контейнера',
                ),
              )
            else
              _payloadSelectionCard(context),
            const SizedBox(height: 18),
            Text(
              'Пресет передачи',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransferPreset.values
                  .map(
                    (preset) => ChoiceChip(
                      label: Text(preset.label),
                      selected: _preset == preset,
                      onSelected: (_) {
                        _resetTaskAfterEdit();
                        setState(() => _preset = preset);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text('WAV carrier', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CarrierKind.values
                  .map(
                    (carrier) => ChoiceChip(
                      label: Text(carrier.label),
                      selected: _carrier == carrier,
                      onSelected: (_) {
                        _resetTaskAfterEdit();
                        setState(() => _carrier = carrier);
                      },
                      tooltip: carrier.description,
                    ),
                  )
                  .toList(),
            ),
            if (_carrier == CarrierKind.acoustic1) ...[
              const SizedBox(height: 8),
              const Text(
                'Acoustic-1 — экспериментальный PCM carrier для контролируемых WAV tests; это не live-audio маршрут.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Маршрут аудио',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TransferRoute>(
              segments: TransferRoute.values
                  .map(
                    (route) => ButtonSegment(
                      value: route,
                      label: Text(route.label),
                      icon: Icon(route.icon),
                    ),
                  )
                  .toList(),
              selected: {_route},
              onSelectionChanged: (value) {
                _resetTaskAfterEdit();
                setState(() => _route = value.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _payloadSelectionCard(BuildContext context) {
    final selected = _selectedPayloadFile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        border: Border.all(color: const Color(0xFFE2C987)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Файл для ADLP объекта',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            selected == null
                ? 'Файл не выбран. Rust facade примет не более 8 KiB payload.'
                : '${selected.name} · ${selected.bytes.length} байт · ${_mimeTypeFor(selected.name)}',
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isWorking ? null : _selectPayloadFile,
            icon: const Icon(Icons.attach_file),
            label: Text(
              selected == null ? 'Выбрать файл' : 'Выбрать другой файл',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Это локальный WAV reference workflow. Выбор файла не включает микрофон, Bluetooth, кабель или радиомаршрут.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Color(0xFF6D6A62),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, int bytes) {
    final built = _builtWav;
    final decoded = _decodedWav;
    final decodedFile = _decodedFileWav;
    return Card(
      color: const Color(0xFF242321),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle(
          style: const TextStyle(color: Color(0xFFFFFCF5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CarrierStrip(),
              const SizedBox(height: 24),
              Text(
                _carrier.label.toUpperCase(),
                style: TextStyle(
                  letterSpacing: 1.4,
                  fontSize: 12,
                  color: Color(0xFFFFB000),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _preset.label,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Metric(label: 'Контейнер', value: 'ADLP / v1'),
              Metric(label: 'Профиль', value: _preset.profileId),
              Metric(label: 'Carrier', value: _carrier.label),
              Metric(label: 'Маршрут', value: _route.label),
              Metric(label: 'Объект', value: _objectKind.label),
              Metric(
                label: _objectKind == TransferObjectKind.text
                    ? 'Текст'
                    : 'Файл',
                value: _objectKind == TransferObjectKind.text
                    ? '$bytes байт UTF-8'
                    : _selectedPayloadFile == null
                    ? 'не выбран'
                    : '${_selectedPayloadFile!.bytes.length} байт',
              ),
              const SizedBox(height: 16),
              TaskStatePanel(task: _task),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isWorking || !widget.bridge.isAvailable
                    ? null
                    : _buildAndVerifyWav,
                icon: _isWorking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq),
                label: Text(
                  _isWorking ? _task.message : 'Собрать и проверить WAV',
                ),
              ),
              if (!widget.bridge.isAvailable) ...[
                const SizedBox(height: 12),
                const Text(
                  'Native Rust bridge недоступен в этой сборке.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFC9C5B9),
                  ),
                ),
              ],
              if (built != null &&
                  (decoded != null || decodedFile != null)) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF6D6A62)),
                const SizedBox(height: 8),
                const Text(
                  'ПРОВЕРЕНО RUST',
                  style: TextStyle(
                    letterSpacing: 1.2,
                    fontSize: 11,
                    color: Color(0xFFFFB000),
                  ),
                ),
                const SizedBox(height: 8),
                Metric(label: 'WAV', value: '${built.wavBytes.length} байт'),
                Metric(
                  label: 'Decoder',
                  value:
                      '${(decoded?.sampleRateHz ?? decodedFile!.sampleRateHz) ~/ 1000} kHz / CRC ok',
                ),
                if (decodedFile case final file?)
                  Metric(
                    label: 'Файл',
                    value: '${file.fileName} · ${file.payload.length} байт',
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isWorking ? null : _exportBuiltWav,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Экспортировать WAV'),
                ),
              ],
              if (_bridgeError case final error?) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFFFB000),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'WAV можно экспортировать и импортировать локально. Live-audio adapter contract добавлен, но capture, playback, cable, Bluetooth и radio adapters ещё не реализованы.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFFC9C5B9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceive(BuildContext context) {
    final decoded = _decodedWav;
    final decodedFile = _decodedFileWav;
    final hasDecodedObject = decoded != null || decodedFile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПРИЁМ / WAV BOOTSTRAP',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Проверьте объект у приёмника.',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 40,
                  color: Color(0xFFFFB000),
                ),
                const SizedBox(height: 16),
                Text(
                  !hasDecodedObject
                      ? 'Нет WAV для проверки.'
                      : 'WAV object проверен.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  !hasDecodedObject
                      ? 'Сначала соберите WAV во вкладке «Передать» или импортируйте готовую передачу.'
                      : 'Decoder вернул только объект, прошедший framing, manifest и CRC-32C проверку.',
                ),
                if (_activeWavName case final name?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Источник: $name',
                    style: const TextStyle(color: Color(0xFF6D6A62)),
                  ),
                ],
                if (decoded != null) ...[
                  const SizedBox(height: 20),
                  _receiptRow('Позывной', decoded.senderCallsign),
                  _receiptRow('Профиль', decoded.profile),
                  _receiptRow('Carrier', decoded.carrier),
                  _receiptRow('Текст', decoded.text),
                  _receiptRow(
                    'Семплы',
                    '${decoded.samplesConsumed} @ ${decoded.sampleRateHz} Hz',
                  ),
                ],
                if (decodedFile != null) ...[
                  const SizedBox(height: 20),
                  _receiptRow('Позывной', decodedFile.senderCallsign),
                  _receiptRow('Профиль', decodedFile.profile),
                  _receiptRow('Carrier', decodedFile.carrier),
                  _receiptRow('Файл', decodedFile.fileName),
                  _receiptRow('MIME', decodedFile.mimeType),
                  _receiptRow('Payload', '${decodedFile.payload.length} байт'),
                  _receiptRow(
                    'Семплы',
                    '${decodedFile.samplesConsumed} @ ${decodedFile.sampleRateHz} Hz',
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed:
                      _isWorking ||
                          _activeWavBytes == null ||
                          !widget.bridge.isAvailable
                      ? null
                      : _verifyCurrentWav,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторно проверить WAV'),
                ),
                if (decodedFile != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : _saveDecodedPayload,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Сохранить проверенный файл'),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isWorking || !widget.bridge.isAvailable
                      ? null
                      : _importAndVerifyWav,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Импортировать WAV'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Color(0xFF6D6A62))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

enum TransferPreset {
  reliable('Надёжный', 'ADLP / Reliable', 'reliable'),
  balanced('Сбалансированный', 'ADLP / Balanced', 'balanced'),
  fast('Быстрый', 'ADLP / Fast', 'fast');

  const TransferPreset(this.label, this.profileId, this.bridgeProfile);
  final String label;
  final String profileId;
  final String bridgeProfile;
}

enum CarrierKind {
  bootstrap(
    'WAV bootstrap',
    'bootstrap',
    'bootstrap',
    'Детерминированный lossless reference carrier.',
  ),
  acoustic1(
    'Acoustic-1',
    'acoustic1',
    'acoustic1',
    'Экспериментальный B-FSK carrier с Hamming FEC для контролируемых WAV tests.',
  );

  const CarrierKind(
    this.label,
    this.bridgeCarrier,
    this.fileStem,
    this.description,
  );

  final String label;
  final String bridgeCarrier;
  final String fileStem;
  final String description;
}

enum TransferRoute {
  wav('WAV', Icons.audio_file_outlined),
  speaker('Динамик', Icons.volume_up_outlined),
  cable('Кабель', Icons.cable_outlined);

  const TransferRoute(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum TransferObjectKind {
  text('Текст', Icons.notes_outlined),
  file('Файл', Icons.insert_drive_file_outlined);

  const TransferObjectKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class SignalMark extends StatelessWidget {
  const SignalMark({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 42,
    height: 34,
    child: CustomPaint(painter: SignalMarkPainter()),
  );
}

class SignalMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFB000)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var y = 7.0; y <= 23; y += 8) {
      canvas.drawLine(Offset(2, y), Offset(30, y), paint);
    }
    canvas.drawLine(const Offset(35, 4), const Offset(35, 27), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CarrierStrip extends StatelessWidget {
  const CarrierStrip({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      18,
      (index) => Expanded(
        child: Container(
          height: index.isEven ? 5 : 2,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          color: index == 12
              ? const Color(0xFFFFB000)
              : const Color(0xFF6D6A62),
        ),
      ),
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFC9C5B9))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class TaskStatePanel extends StatelessWidget {
  const TaskStatePanel({super.key, required this.task});

  final TransferTaskState task;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.phase) {
      TransferTaskPhase.completed => const Color(0xFFFFB000),
      TransferTaskPhase.rejected ||
      TransferTaskPhase.unavailable => const Color(0xFFFF8A65),
      TransferTaskPhase.cancelled => const Color(0xFFC9C5B9),
      _ => const Color(0xFFB8D8BA),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            task.message,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          if (task.detail case final detail?) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFFC9C5B9), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
