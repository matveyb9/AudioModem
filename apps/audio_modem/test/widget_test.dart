import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audio_modem/main.dart';

void main() {
  testWidgets('send workbench exposes the bootstrap WAV flow', (tester) async {
    await tester.pumpWidget(const AudioModemApp());

    expect(find.text('Соберите передачу.'), findsOneWidget);
    expect(find.text('Надёжный'), findsOneWidget);
    expect(find.text('Собрать WAV'), findsOneWidget);

    final fastFinder = find.widgetWithText(ChoiceChip, 'Быстрый');
    await tester.ensureVisible(fastFinder);
    await tester.tap(fastFinder);
    await tester.pumpAndSettle();

    final fastPreset = tester.widget<ChoiceChip>(fastFinder);
    expect(fastPreset.selected, isTrue);
  });
}
