import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/user_profile.dart';
import 'package:proyecto_asistencia/screens/home_screen.dart';
import 'package:proyecto_asistencia/services/attendance_service.dart';
import 'package:proyecto_asistencia/services/demo_backend.dart';

import 'helpers.dart';
import 'test_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  group('DemoStudentBackend', () {
    test(
      'datos de ejemplo con sesión abierta, riesgo y periodo anterior',
      () async {
        final backend = DemoStudentBackend(now: DateTime(2026, 11, 2, 18, 30));
        final data = await backend.watchAcademic(DemoStudentBackend.uid).first;
        expect(data.courses, hasLength(4));
        expect(data.pendingOpenCourses.single.id, 'demo-c1');
        expect(data.periods, hasLength(2));
        final risky = data.courses.firstWhere((c) => c.id == 'demo-c3');
        expect(data.statsFor(risky).absences, 2); // margen agotado
      },
    );

    test(
      'registra en memoria, no duplica y rechaza sin sesión abierta',
      () async {
        final backend = DemoStudentBackend();
        const uid = DemoStudentBackend.uid;
        final data = await backend.watchAcademic(uid).first;
        final open = data.pendingOpenCourses.single;

        final updates = backend.watchAcademic(uid).skip(1).first;
        final first = await backend.registerAttendance(uid, open);
        expect(first.isSuccess, isTrue);
        expect(first.alreadyRegistered, isFalse);
        expect((await updates).pendingOpenCourses, isEmpty);

        final again = await backend.registerAttendance(uid, open);
        expect(again.alreadyRegistered, isTrue);

        final other = data.courses.firstWhere((c) => c.id == 'demo-c2');
        final fail = await backend.registerAttendance(uid, other);
        expect(fail.failure, AttendanceFailure.noOpenSession);
      },
    );

    test('las preferencias se actualizan en memoria', () async {
      final backend = DemoStudentBackend();
      final next = backend.watchProfile(DemoStudentBackend.uid).skip(1).first;
      await backend.updateSettings(
        DemoStudentBackend.uid,
        const UserSettings(riskAlerts: false),
      );
      expect((await next)!.settings.riskAlerts, isFalse);
    });
  });

  group('HomeScreen en modo demostración', () {
    Widget home(DemoStudentBackend b) => HomeScreen(
      uid: DemoStudentBackend.uid,
      email: DemoStudentBackend.email,
      authDisplayName: DemoStudentBackend.name,
      backend: b,
    );

    testWidgets('muestra el aviso y recorre las pestañas', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(wrap(home(DemoStudentBackend())));
      await pumpFrames(tester);
      expect(
        find.text('Modo demostración: datos de ejemplo, no se guardan.'),
        findsOneWidget,
      );
      expect(find.text('Hola, Estudiante 👋'), findsOneWidget);
      expect(find.text('Programación Competitiva'), findsWidgets);

      for (final tab in ['Mis Clases', 'Historial', 'Perfil']) {
        await tester.tap(find.text(tab));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
      }
      expect(find.text(DemoStudentBackend.email), findsOneWidget);
    });

    testWidgets('registrar asistencia abre el comprobante de demostración', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(wrap(home(DemoStudentBackend())));
      await pumpFrames(tester);
      await tester.tap(find.text('Registrar asistencia').first);
      await pumpFrames(tester, frames: 15); // búsqueda mínima de 1,5 s
      expect(find.text('¡Asistencia registrada!'), findsOneWidget);
      expect(
        find.text('Modo demostración: este registro no se guarda.'),
        findsOneWidget,
      );
    });
  });
}
