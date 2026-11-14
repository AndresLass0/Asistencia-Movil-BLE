import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/teacher_snapshot.dart';
import 'package:proyecto_asistencia/screens/teacher/active_session_screen.dart';
import 'package:proyecto_asistencia/screens/teacher/course_form_screen.dart';
import 'package:proyecto_asistencia/screens/teacher/session_summary_screen.dart';
import 'package:proyecto_asistencia/screens/teacher/tabs/teacher_classes_tab.dart';
import 'package:proyecto_asistencia/screens/teacher/tabs/teacher_history_tab.dart';
import 'package:proyecto_asistencia/screens/teacher/tabs/teacher_profile_tab.dart';
import 'package:proyecto_asistencia/screens/teacher/tabs/teacher_reports_tab.dart';
import 'package:proyecto_asistencia/screens/teacher/teacher_gate.dart';
import 'package:proyecto_asistencia/screens/teacher/teacher_home_screen.dart';
import 'package:proyecto_asistencia/services/demo_backend.dart';
import 'package:proyecto_asistencia/services/teacher_backend.dart';

import 'helpers.dart';
import 'test_fonts.dart';

Widget _home(DemoTeacherBackend b) => TeacherHomeScreen(
  uid: DemoTeacherBackend.uid,
  email: DemoTeacherBackend.email,
  authDisplayName: DemoTeacherBackend.name,
  backend: b,
);

/// Backend de demostración con un acceso distinto (para TeacherGate).
class _AccessBackend extends DemoTeacherBackend {
  _AccessBackend(this.access);
  final TeacherAccess access;
  @override
  Future<TeacherAccess> checkAccess() async => access;
}

/// Desmonta las pantallas (la sesión activa tiene un temporizador).
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(loadRealFonts);

  group('Acceso del docente (TeacherGate)', () {
    testWidgets('autorizado: muestra la vista del docente', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(
        wrap(
          TeacherGate(
            uid: 'demo-teacher',
            email: DemoTeacherBackend.email,
            backend: DemoTeacherBackend(),
          ),
        ),
      );
      await pumpFrames(tester);
      expect(find.text('Mis clases'), findsOneWidget);
      expect(find.text('Portal Docente'), findsOneWidget);
    });

    testWidgets('sin autorización: no entra a la vista del docente', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TeacherGate(
            uid: 'x',
            email: 'otro@udla.edu.co',
            backend: _AccessBackend(TeacherAccess.notAuthorized),
          ),
        ),
      );
      await pumpFrames(tester);
      expect(
        find.text('Cuenta docente pendiente de autorización'),
        findsOneWidget,
      );
      expect(find.text('Mis clases'), findsNothing);
    });

    testWidgets('correo sin verificar: pide verificarlo', (tester) async {
      await tester.pumpWidget(
        wrap(
          TeacherGate(
            uid: 'x',
            email: 'd@udla.edu.co',
            backend: _AccessBackend(TeacherAccess.emailNotVerified),
          ),
        ),
      );
      await pumpFrames(tester);
      expect(find.text('Verifica tu correo'), findsOneWidget);
      expect(find.text('Reenviar correo'), findsOneWidget);
    });
  });

  group('Vista del docente (demostración)', () {
    testWidgets('las 4 pestañas cargan sin errores', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(wrap(_home(DemoTeacherBackend())));
      await pumpFrames(tester);
      expect(
        find.text('Modo demostración: datos de ejemplo, no se guardan.'),
        findsOneWidget,
      );
      expect(find.text('Sesión en curso'), findsOneWidget);
      expect(find.text('Mis asignaturas'), findsOneWidget);

      await tester.tap(find.text('Historial'));
      await pumpFrames(tester);
      expect(find.text('Historial de clases'), findsWidgets);

      await tester.tap(find.text('Reportes'));
      await pumpFrames(tester);
      expect(find.text('Reportes de asistencia'), findsOneWidget);
      expect(find.text('Alerta temprana'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Ejemplo: no pude registrar'),
        400,
      );
      expect(find.textContaining('Ejemplo: no pude registrar'), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await pumpFrames(tester);
      expect(find.text(DemoTeacherBackend.email), findsOneWidget);
      expect(find.text('Próximamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'sesión en curso → finalizar → resumen → justificar inasistencia',
      (tester) async {
        useTallView(tester);
        final backend = DemoTeacherBackend();
        await tester.pumpWidget(wrap(_home(backend)));
        await pumpFrames(tester);

        await tester.tap(find.text('Ver sesión en curso'));
        await pumpFrames(tester);
        expect(find.byType(ActiveSessionScreen), findsOneWidget);
        expect(find.text('Asistencia registrada: 7 / 12'), findsOneWidget);
        expect(find.text('Sin cuenta en BioAsistencia'), findsOneWidget);

        // Registro manual de una excepción.
        await tester.tap(find.text('Marcar presente').first);
        await pumpFrames(tester);
        await tester.tap(find.text('Registrar'));
        await pumpFrames(tester);
        expect(find.text('Asistencia registrada: 8 / 12'), findsOneWidget);
        expect(find.textContaining('Registro manual'), findsOneWidget);

        await tester.tap(find.text('Finalizar asistencia'));
        await pumpFrames(tester);
        await tester.tap(find.text('Finalizar'));
        await pumpFrames(tester, frames: 10);
        expect(find.byType(SessionSummaryScreen), findsOneWidget);
        expect(find.text('Sesión finalizada con éxito'), findsOneWidget);

        await tester.tap(find.text('Justificar').first);
        await pumpFrames(tester);
        expect(find.text('Inasistencia justificada'), findsOneWidget);
        await _unmount(tester);
      },
    );

    testWidgets('iniciar asistencia elige duración y abre la sesión', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(wrap(_home(DemoTeacherBackend())));
      await pumpFrames(tester);
      // "Bases de Datos" no tiene sesión activa.
      await tester.tap(find.text('Iniciar asistencia').first);
      await pumpFrames(tester);
      expect(find.text('Configurar duración'), findsOneWidget);
      await tester.tap(find.text('10 min'));
      await tester.tap(find.text('Iniciar sesión de asistencia'));
      await pumpFrames(tester, frames: 10);
      expect(find.byType(ActiveSessionScreen), findsOneWidget);
      expect(find.text('REGISTRO ABIERTO'), findsOneWidget);
      expect(find.text('Asistencia registrada: 0 / 8'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('crear clase con estudiante manual', (tester) async {
      useTallView(tester);
      final backend = DemoTeacherBackend();
      await tester.pumpWidget(
        wrap(CourseFormScreen(backend: backend, teacherName: 'Docente')),
      );
      await pumpFrames(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la asignatura *'),
        'Sistemas Distribuidos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Ana Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Código estudiantil'),
        '12345',
      );
      await tester.ensureVisible(find.text('Añadir a la lista'));
      await pumpFrames(tester);
      await tester.tap(find.text('Añadir a la lista'));
      await pumpFrames(tester);
      expect(find.text('Crear clase con 1 estudiantes'), findsOneWidget);

      final save = find.text('Crear clase con 1 estudiantes');
      await tester.ensureVisible(save);
      await pumpFrames(tester);
      await tester.tap(save);
      await pumpFrames(tester);
      final data = (await tester.runAsync(() => backend.watch('x').first))!;
      final course = data.courses.firstWhere(
        (c) => c.name == 'Sistemas Distribuidos',
      );
      expect(course.roster.single.isLinked, isTrue); // demo: se vincula
      expect(course.students, hasLength(1));
    });

    testWidgets('validaciones del formulario', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(
        wrap(
          CourseFormScreen(
            backend: DemoTeacherBackend(),
            teacherName: 'Docente',
          ),
        ),
      );
      await pumpFrames(tester);
      await tester.ensureVisible(find.text('Crear clase sin estudiantes'));
      await pumpFrames(tester);
      await tester.tap(find.text('Crear clase sin estudiantes'));
      await pumpFrames(tester);
      expect(find.text('Escribe el nombre de la asignatura.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Código estudiantil'),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Ana',
      );
      await tester.ensureVisible(find.text('Añadir a la lista'));
      await pumpFrames(tester);
      await tester.tap(find.text('Añadir a la lista'));
      await pumpFrames(tester);
      expect(
        find.text('El código debe tener entre 5 y 15 dígitos.'),
        findsOneWidget,
      );
    });
  });

  group('Sin desbordamientos (320 dp, 130 %)', () {
    late TeacherState state;
    setUpAll(() async {
      state = TeacherState.data(await DemoTeacherBackend().watch('x').first);
    });

    expectNoOverflow(
      'Clases',
      () => TeacherClassesTab(
        state: state,
        teacherName: 'María Fernanda Rodríguez Castañeda',
        faculty: 'Facultad de Ciencias Básicas',
        onCreate: () {},
        onEdit: (_) {},
        onDelete: (_) {},
        onStart: (_) {},
        onOpenSession: (_) {},
      ),
    );
    expectNoOverflow(
      'Historial',
      () => TeacherHistoryTab(
        state: state,
        onOpenSummary: (_) {},
        onExportPdf: (_) {},
        onExportExcel: (_) {},
      ),
    );
    expectNoOverflow(
      'Reportes',
      () => TeacherReportsTab(
        state: state,
        onExportPdf: (_) {},
        onExportExcel: (_) {},
      ),
    );
    expectNoOverflow(
      'Perfil',
      () => TeacherProfileTab(
        displayName: 'Docente',
        email: DemoTeacherBackend.email,
        profile: null,
        state: state,
        backend: DemoTeacherBackend(),
      ),
    );
    expectNoOverflow(
      'Formulario',
      () => CourseFormScreen(backend: DemoTeacherBackend(), teacherName: 'D'),
    );
    expectNoOverflow(
      'Resumen',
      () => SessionSummaryScreen(
        sessionId: state.data!.heldSessions().first.id,
        state: ValueNotifier(state),
        backend: DemoTeacherBackend(),
        teacherName: 'D',
      ),
    );
  });

  testWidgets('sin desbordamientos (320 dp, 130 %): Sesión activa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = TeacherState.data(
      (await tester.runAsync(() => DemoTeacherBackend().watch('x').first))!,
    );
    await tester.pumpWidget(
      wrap(
        ActiveSessionScreen(
          sessionId: 'demo-open',
          state: ValueNotifier(state),
          backend: DemoTeacherBackend(),
          onFinished: (_) {},
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
