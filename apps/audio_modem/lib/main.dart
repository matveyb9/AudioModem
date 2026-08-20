// AudioModem Flutter workbench: UI stays transport-aware while Rust owns ADLP and WAV codec behavior.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'bridge/wav_bootstrap_bridge.dart';
import 'platform/live_audio_adapter.dart';
import 'platform/wav_file_adapter.dart';

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
      liveAudioAdapter: const UnavailableLiveAudioAdapter(),
    ),
  );
}

class AudioModemApp extends StatelessWidget {
  const AudioModemApp({
    super.key,
    required this.bridge,
    required this.fileAdapter,
    this.liveAudioAdapter = const UnavailableLiveAudioAdapter(),
  });

  final WavBootstrapBridge bridge;
  final WavFileAdapter fileAdapter;
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
    required this.liveAudioAdapter,
  });

  final WavBootstrapBridge bridge;
  final WavFileAdapter fileAdapter;
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
  int _tabIndex = 0;
  bool _isWorking = false;
  WavBuildResult? _builtWav;
  WavDecodeResult? _decodedWav;
  String? _activeWavName;
  Uint8List? _activeWavBytes;
  CarrierKind? _activeCarrier;
  String? _bridgeError;

  @override
  void dispose() {
    _callsign.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _buildAndVerifyWav() async {
    if (_route != TransferRoute.wav) {
      _showMessage(
        widget.liveAudioAdapter.availability.reason ??
            'Live-audio маршрут недоступен. Выберите WAV-маршрут.',
      );
      return;
    }
    if (!widget.bridge.isAvailable) {
      _showMessage('Rust/WAV bridge недоступен в этой сборке.');
      return;
    }
    setState(() {
      _isWorking = true;
      _bridgeError = null;
    });
    try {
      final sessionId = DateTime.now().microsecondsSinceEpoch;
      final built = await widget.bridge.encodeText(
        sessionId: sessionId,
        senderCallsign: _callsign.text.trim(),
        text: _text.text,
        profile: _preset.bridgeProfile,
        carrier: _carrier.bridgeCarrier,
      );
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
        _activeWavName = _suggestedWavName(built.sessionId, _carrier);
        _activeWavBytes = built.wavBytes;
        _activeCarrier = _carrier;
      });
      _showMessage('WAV собран и проверен Rust decoder.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _bridgeError = error.toString());
      _showMessage('Rust bridge отклонил передачу. Проверьте поля объекта.');
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _verifyCurrentWav() async {
    final wavBytes = _activeWavBytes;
    final carrier = _activeCarrier;
    if (wavBytes == null || carrier == null) {
      _showMessage('Сначала соберите или импортируйте WAV.');
      return;
    }
    setState(() {
      _isWorking = true;
      _bridgeError = null;
    });
    try {
      final decoded = await widget.bridge.decodeWav(
        wavBytes: wavBytes,
        carrier: carrier.bridgeCarrier,
      );
      if (!mounted) {
        return;
      }
      setState(() => _decodedWav = decoded);
      _showMessage('WAV повторно проверен Rust decoder.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _bridgeError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _exportBuiltWav() async {
    final built = _builtWav;
    if (built == null) {
      _showMessage('Сначала соберите WAV во вкладке «Передать».');
      return;
    }
    setState(() {
      _isWorking = true;
      _bridgeError = null;
    });
    try {
      final saved = await widget.fileAdapter.saveWav(
        suggestedName: _suggestedWavName(built.sessionId, _carrier),
        bytes: built.wavBytes,
      );
      if (!mounted) {
        return;
      }
      if (saved == null) {
        _showMessage('Экспорт WAV отменён.');
      } else {
        _showMessage('WAV сохранён: ${saved.name}.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _bridgeError = error.toString());
      _showMessage('Не удалось сохранить WAV.');
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _importAndVerifyWav() async {
    if (!widget.bridge.isAvailable) {
      _showMessage('Rust/WAV bridge недоступен в этой сборке.');
      return;
    }
    setState(() {
      _isWorking = true;
      _bridgeError = null;
    });
    try {
      final selected = await widget.fileAdapter.openWav();
      if (selected == null) {
        if (mounted) {
          _showMessage('Импорт WAV отменён.');
        }
        return;
      }
      final decoded = await widget.bridge.decodeWav(
        wavBytes: selected.bytes,
        carrier: _carrier.bridgeCarrier,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeWavName = selected.name;
        _activeWavBytes = selected.bytes;
        _activeCarrier = _carrier;
        _decodedWav = decoded;
      });
      _showMessage('WAV импортирован и проверен Rust decoder.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _bridgeError = error.toString());
      _showMessage(
        'Импортированный файл не является корректной WAV передачей.',
      );
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
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
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Позывной отправителя',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Текст',
                alignLabelWithHint: true,
                hintText: 'Введите сообщение для ADLP-контейнера',
              ),
            ),
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
                      onSelected: (_) => setState(() => _preset = preset),
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
                      onSelected: (_) => setState(() => _carrier = carrier),
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
              onSelectionChanged: (value) =>
                  setState(() => _route = value.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(BuildContext context, int bytes) {
    final built = _builtWav;
    final decoded = _decodedWav;
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
              Metric(label: 'Текст', value: '$bytes байт UTF-8'),
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
                  _isWorking ? 'Проверка Rust…' : 'Собрать и проверить WAV',
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
              if (built != null && decoded != null) ...[
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
                  value: '${decoded.sampleRateHz ~/ 1000} kHz / CRC ok',
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
                  decoded == null
                      ? 'Нет WAV для проверки.'
                      : 'WAV object проверен.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  decoded == null
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
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed:
                      _isWorking ||
                          _builtWav == null ||
                          !widget.bridge.isAvailable
                      ? null
                      : _verifyCurrentWav,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторно проверить WAV'),
                ),
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
