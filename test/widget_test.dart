import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saca_el_carnet/main.dart';

void main() {
  testWidgets('VialiApp arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const VialiApp(showOnboarding: false));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('VialiApp muestra onboarding cuando se solicita', (WidgetTester tester) async {
    await tester.pumpWidget(const VialiApp(showOnboarding: true));
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump();
    expect(find.text('Hola, soy Viali'), findsOneWidget);
  });
}
