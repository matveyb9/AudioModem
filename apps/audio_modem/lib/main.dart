import 'package:flutter/material.dart';

void main() => runApp(const AudioModemApp());

class AudioModemApp extends StatelessWidget {
  const AudioModemApp({super.key});

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
      home: const TransferWorkbench(),
    );
  }
}

class TransferWorkbench extends StatefulWidget {
  const TransferWorkbench({super.key});

  @override
  State<TransferWorkbench> createState() => _TransferWorkbenchState();
}

class _TransferWorkbenchState extends State<TransferWorkbench> {
  final _callsign = TextEditingController(text: 'N1');
  final _text = TextEditingController(text: 'Привет через AudioModem');
  TransferPreset _preset = TransferPreset.balanced;
  TransferRoute _route = TransferRoute.wav;
  int _tabIndex = 0;

  @override
  void dispose() {
    _callsign.dispose();
    _text.dispose();
    super.dispose();
  }

  void _showBridgeNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'UI готов. Rust/WAV bridge будет подключён следующим вертикальным срезом; передача ещё не запускается.',
        ),
      ),
    );
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
    final bytes = _text.text.codeUnits.length;
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
          'Соберите передачу.',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Первый вертикальный срез создаёт версионированный объект и WAV в Rust. Этот экран фиксирует кроссплатформенный UI-контракт до FFI-подключения.',
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
              const Text(
                'ПЛАН ПЕРЕДАЧИ',
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
              Metric(label: 'Маршрут', value: _route.label),
              Metric(label: 'Текст', value: '$bytes байт'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showBridgeNotice,
                icon: const Icon(Icons.graphic_eq),
                label: const Text('Собрать WAV'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Пока доступно через Rust CLI. Кнопка намеренно не имитирует успешную передачу.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПРИЁМ / ОЖИДАНИЕ',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Слушайте маршрут, а не транспорт.',
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
                  Icons.hearing_outlined,
                  size: 40,
                  color: Color(0xFFFFB000),
                ),
                const SizedBox(height: 16),
                Text(
                  'Rust/WAV decoder готов для CLI.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Нативный источник PCM, Web Audio и FFI bridge будут добавлены следующим вертикальным срезом. До тех пор интерфейс не показывает ложный статус приёма.',
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _showBridgeNotice,
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
}

enum TransferPreset {
  reliable('Надёжный', 'Acoustic-1/Reliable'),
  balanced('Сбалансированный', 'Acoustic-1/Balanced'),
  fast('Быстрый', 'Acoustic-1/Fast');

  const TransferPreset(this.label, this.profileId);
  final String label;
  final String profileId;
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
