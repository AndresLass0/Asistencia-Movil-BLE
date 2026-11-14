import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/user_profile.dart';
import 'package:proyecto_asistencia/screens/home_screen.dart';
import 'package:proyecto_asistencia/services/attendance_service.dart';

import 'fakes/fake_student_backend.dart';
import 'helpers.dart';
import 'test_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  group('FakeStudentBackend', () {
    test(
      'datos de ejemplo con sesión abierta, riesgo y periodo anterior',
      () async {
        final backend = FakeStudentBackend(now: DateTime(2026, 11, 2, 18, 30));
        final data = await backend.watchAcademic(FakeStudentBackend.uid).first;
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
        final backend = FakeStudentBackend();
        const uid = FakeStudentBackend.uid;
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
      final backend = FakeStudentBackend();
      final next = backend.watchProfile(FakeStudentBackend.uid).skip(1).first;
      await backend.updateSettings(
        FakeStudentBackend.uid,
        const UserSettings(riskAlerts: false),
      );
      expect((await next)!.settings.riskAlerts, isFalse);
    });
  });

  group('HomeScreen con datos de prueba', () {
    Widget home(FakeStudentBackend b) => HomeScreen(
      uid: FakeStudentBackend.uid,
      email: FakeStudentBackend.email,
      authDisplayName: FakeStudentBackend.name,
      backend: b,
    );

    testWidgets('recorre las pestañas sin aviso de demostración', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(wrap(home(FakeStudentBackend())));
      await pumpFrames(tester);
      expect(find.textContaining('Modo demostración'), findsNothing);
      expect(find.text('Hola, Estudiante 👋'), findsOneWidget);
      expect(find.text('Programación Competitiva'), findsWidgets);

      for (final tab in ['Mis Clases', 'Historial', 'Perfil']) {
        await tester.tap(find.text(tab));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
      }
      expect(find.text(FakeStudentBackend.email), findsOneWidget);
    });

    testWidgets('registrar asistencia abre el comprobante', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(wrap(home(FakeStudentBackend())));
      await pumpFrames(tester);
      await tester.tap(find.text('Registrar asistencia').first);
      await pumpFrames(tester, frames: 15); // búsqueda mínima de 1,5 s
      expect(find.text('¡Asistencia registrada!'), findsOneWidget);
      expect(find.text('Registro guardado en BioAsistencia.'), findsOneWidget);
    });

    testWidgets('aceptar una invitación la pasa a Mis Clases', (tester) async {
      useTallView(tester);
      final backend = FakeStudentBackend();
      await tester.pumpWidget(wrap(home(backend)));
      await pumpFrames(tester);
      expect(find.text('Invitación a una clase'), findsOneWidget);
      expect(find.textContaining('Computación Móvil'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await pumpFrames(tester);
      expect(find.text('Invitación a una clase'), findsNothing);
      expect(find.text('Te uniste a Computación Móvil.'), findsOneWidget);
      final data = (await tester.runAsync(
        () => backend.watchAcademic(FakeStudentBackend.email).first,
      ))!;
      expect(data.currentCourses.map((c) => c.id), contains('demo-c5'));
    });

    testWidgets('cancelar una asignatura desde el detalle', (tester) async {
      useTallView(tester);
      final backend = FakeStudentBackend();
      await tester.pumpWidget(wrap(home(backend)));
      await pumpFrames(tester);
      await tester.tap(find.text('Mis Clases'));
      await pumpFrames(tester);
      await tester.tap(find.text('Ver detalle de clase').first);
      await pumpFrames(tester);

      final cancel = find.text('Cancelar asignatura');
      await tester.ensureVisible(cancel);
      await pumpFrames(tester);
      await tester.tap(cancel);
      await pumpFrames(tester);
      expect(find.textContaining('el docente recibirá un aviso'), findsOne);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancelar asignatura'),
      );
      await pumpFrames(tester);
      expect(find.textContaining('Cancelaste esta asignatura'), findsOneWidget);
      expect(find.text('Cancelar asignatura'), findsNothing);
    });
  });
}
