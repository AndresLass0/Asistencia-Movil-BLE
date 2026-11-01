import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [child] sin Firebase ni Google Fonts (tema por defecto).
Widget wrap(Widget child, {double textScale = 1.0}) => MaterialApp(
  builder: (context, w) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: w!,
  ),
  home: child is Scaffold ? child : Scaffold(body: child),
);

/// Quita el SnackBar visible (en formularios largos puede tapar el botón).
Future<void> clearSnackBars(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

/// [settle]: false cuando hay animaciones infinitas (pestaña de asistencia).
Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool settle = true,
}) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.tap(f);
  await tester.pump();
}

/// Comprueba que [build] no desborda en 320 dp con texto al 130 %.
void expectNoOverflow(String name, Widget Function() build) {
  testWidgets('sin desbordamientos (320 dp, 130 %): $name', (tester) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(build(), textScale: 1.3));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

/// Avanza varios fotogramas (navegación con animaciones infinitas debajo).
Future<void> pumpFrames(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Vista alta para que las listas perezosas construyan todo su contenido.
void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
