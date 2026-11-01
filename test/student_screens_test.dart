import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/academic_snapshot.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/user_profile.dart';
import 'package:proyecto_asistencia/screens/attendance/attendance_failed_screen.dart';
import 'package:proyecto_asistencia/screens/attendance/attendance_success_screen.dart';
import 'package:proyecto_asistencia/screens/course_detail_screen.dart';
import 'package:proyecto_asistencia/screens/tabs/attendance_tab.dart';
import 'package:proyecto_asistencia/screens/tabs/classes_tab.dart';
import 'package:proyecto_asistencia/screens/tabs/dashboard_tab.dart';
import 'package:proyecto_asistencia/screens/tabs/history_tab.dart';
import 'package:proyecto_asistencia/screens/tabs/profile_tab.dart';
import 'package:proyecto_asistencia/services/attendance_service.dart';
import 'package:proyecto_asistencia/widgets/app_bottom_nav.dart';

import 'fixtures.dart';
import 'helpers.dart';
import 'test_fonts.dart';

final _data = AcademicState.data(sampleSnapshot());

DashboardTab _dashboard(
  AcademicState state, {
  UserSettings settings = const UserSettings(),
  ValueChanged<Course?>? onRegister,
  ValueChanged<Course>? onOpen,
}) => DashboardTab(
  firstName: 'Ana',
  state: state,
  settings: settings,
  now: testNow,
  onRegisterAttendance: onRegister ?? (_) {},
  onOpenCourse: onOpen ?? (_) {},
);

AttendanceSuccessScreen _success({bool already = false}) {
  final data = sampleSnapshot();
  return AttendanceSuccessScreen(
    record: data.attendance.first, // s1, registrada 6:03 PM
    course: programming,
    session: data.sessions.first, // s1, inició 6:00 PM
    alreadyRegistered: already,
  );
}

void main() {
  setUpAll(loadRealFonts);

  group('Barra inferior', () {
    testWidgets('5 pestañas y botón central de asistencia', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        wrap(
          Scaffold(
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              onTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      for (final label in [
        'Inicio',
        'Mis Clases',
        'Asistencia',
        'Historial',
        'Perfil',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.byIcon(Icons.sensors));
      expect(tapped, AppBottomNav.attendanceIndex);
      await tester.tap(find.text('Mis Clases'));
      expect(tapped, 1);
    });
  });

  group('Inicio', () {
    testWidgets('muestra datos reales del estudiante', (tester) async {
      Course? registered;
      await tester.pumpWidget(
        wrap(_dashboard(_data, onRegister: (c) => registered = c)),
      );
      expect(find.text('Hola, Ana 👋'), findsOneWidget);
      expect(find.text('2 asignaturas'), findsOneWidget);
      expect(find.text('Sesión abierta'), findsOneWidget);
      expect(find.text('Presente'), findsOneWidget); // Bases de Datos hoy
      expect(
        find.text('Has asistido a 2 de 3 clases del periodo.'),
        findsOneWidget,
      );
      expect(find.text('Miércoles'), findsOneWidget); // siguiente clase
      expect(find.textContaining('80%'), findsNothing);

      await tapText(tester, 'Registrar\nasistencia');
      expect(registered?.id, 'c1');
    });

    testWidgets('alerta de riesgo solo si la asignatura define margen', (
      tester,
    ) async {
      final risky = sampleSnapshot(
        courses: [
          Course.fromMap('c1', {
            'name': 'Programación Competitiva',
            'period': '2026-2',
            'maxAbsences': 2,
          }),
        ],
      );
      await tester.pumpWidget(wrap(_dashboard(AcademicState.data(risky))));
      expect(find.textContaining('te queda 1 falta'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          _dashboard(
            AcademicState.data(risky),
            settings: const UserSettings(riskAlerts: false),
          ),
        ),
      );
      expect(find.textContaining('te queda 1 falta'), findsNothing);

      await tester.pumpWidget(wrap(_dashboard(_data))); // margen 3, 1 falta
      expect(find.textContaining('te queda'), findsNothing);
    });

    testWidgets('estados de carga, error y sin asignaturas', (tester) async {
      await tester.pumpWidget(wrap(_dashboard(const AcademicState.loading())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          _dashboard(
            AcademicState.error(
              FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
            ),
          ),
        ),
      );
      expect(find.text('No se pudieron cargar tus clases'), findsOneWidget);

      await tester.pumpWidget(
        wrap(_dashboard(AcademicState.data(AcademicSnapshot.empty))),
      );
      expect(find.text('Aún no tienes asignaturas'), findsOneWidget);
    });
  });

  group('Mis Clases', () {
    Widget classes({
      ValueChanged<Course>? onRegister,
      ValueChanged<Course>? onOpen,
    }) => ClassesTab(
      state: _data,
      now: testNow,
      onRegister: onRegister ?? (_) {},
      onOpenCourse: onOpen ?? (_) {},
    );

    testWidgets('banner de sesión abierta, filtros y búsqueda', (tester) async {
      useTallView(tester);
      Course? registered;
      await tester.pumpWidget(wrap(classes(onRegister: (c) => registered = c)));
      expect(find.text('Sesión abierta ahora'), findsOneWidget);
      expect(find.text('Todas (3)'), findsOneWidget);
      expect(find.text('Con sesión activa (1)'), findsOneWidget);
      expect(find.text('En línea'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Registrar asistencia').first,
      );
      expect(registered?.id, 'c1');

      await tapText(tester, 'Con sesión activa (1)');
      expect(find.text('Bases de Datos'), findsNothing);
      expect(find.text('Programación Competitiva'), findsWidgets);

      await tapText(tester, 'Todas (3)');
      await tester.enterText(find.byType(TextField), 'lab 201');
      await tester.pumpAndSettle();
      expect(find.text('Bases de Datos'), findsOneWidget);
      expect(find.text('Redes de Comunicación'), findsNothing);
    });

    testWidgets('ocultar el banner y abrir el detalle', (tester) async {
      useTallView(tester);
      Course? opened;
      await tester.pumpWidget(wrap(classes(onOpen: (c) => opened = c)));
      await tester.tap(find.byTooltip('Ocultar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Sesión abierta ahora'), findsNothing);
      await tester.tap(find.text('Ver detalle de clase').first);
      expect(opened, isNotNull);
    });
  });

  testWidgets('Detalle de asignatura lista sesiones con su estado', (
    tester,
  ) async {
    useTallView(tester);
    final notifier = ValueNotifier(_data);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      wrap(
        CourseDetailScreen(
          courseId: 'c1',
          academic: notifier,
          uid: uid,
          onRegister: (_) {},
        ),
      ),
    );
    expect(find.text('Programación Competitiva'), findsOneWidget);
    expect(find.text('Abierta'), findsOneWidget);
    expect(find.text('Ausente'), findsOneWidget);
    expect(find.textContaining('Presente ·'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget); // margen: 3 - 1 falta
  });

  group('Asistencia', () {
    testWidgets('sin clase para registrar muestra estado vacío', (
      tester,
    ) async {
      int? goTo;
      await tester.pumpWidget(
        wrap(
          AttendanceTab(
            uid: uid,
            course: null,
            isLoading: false,
            onGoToTab: (i) => goTo = i,
          ),
        ),
      );
      expect(find.text('No hay una clase para registrar'), findsOneWidget);
      await tapText(tester, 'Ver mis clases');
      expect(goTo, 1);
    });

    testWidgets('registro correcto → comprobante → historial', (tester) async {
      final data = sampleSnapshot();
      int? goTo;
      await tester.pumpWidget(
        wrap(
          AttendanceTab(
            uid: uid,
            course: programming,
            isLoading: false,
            onGoToTab: (i) => goTo = i,
            minSearchTime: Duration.zero,
            register: (_) async => AttendanceResult.success(
              data.attendance.first,
              data.sessions.first,
            ),
          ),
        ),
      );
      await pumpFrames(tester);
      expect(find.byType(AttendanceSuccessScreen), findsOneWidget);
      expect(find.text('Comprobante AS-261026-180300'), findsOneWidget);
      await tapText(tester, 'Ver en mi historial', settle: false);
      await pumpFrames(tester);
      expect(goTo, 3);
    });

    testWidgets('sin sesión abierta → pantalla de fallo → reintentar', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        wrap(
          AttendanceTab(
            uid: uid,
            course: programming,
            isLoading: false,
            onGoToTab: (_) {},
            minSearchTime: Duration.zero,
            register: (_) async {
              calls++;
              return const AttendanceResult.failure(
                AttendanceFailure.noOpenSession,
              );
            },
          ),
        ),
      );
      await pumpFrames(tester);
      expect(find.text('No encontramos la señal de la clase'), findsOneWidget);
      expect(find.byIcon(Icons.sensors_off), findsOneWidget);
      await tapText(tester, 'Intentar nuevamente', settle: false);
      await pumpFrames(tester);
      expect(calls, 2);
    });
  });

  group('Comprobante', () {
    testWidgets('datos reales de la sesión y sin referencias ajenas', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_success()));
      expect(find.text('¡Asistencia registrada!'), findsOneWidget);
      expect(find.text('+3 min desde el inicio'), findsOneWidget);
      expect(find.text('Sesión abierta por el docente'), findsOneWidget);
      expect(find.textContaining('Universidad Nacional'), findsNothing);
      expect(find.textContaining('SIA'), findsNothing);
      expect(find.textContaining('SHA'), findsNothing);
    });

    testWidgets('asistencia ya existente no se presenta como nueva', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_success(already: true)));
      expect(find.text('Ya habías registrado tu asistencia'), findsOneWidget);
    });
  });

  testWidgets('Fallo por conexión muestra mensaje específico', (tester) async {
    await tester.pumpWidget(
      wrap(
        AttendanceFailedScreen(
          course: programming,
          failure: AttendanceFailure.offline,
          uid: uid,
        ),
      ),
    );
    expect(find.text('Sin conexión con el servidor'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  group('Historial (progreso)', () {
    testWidgets('promedio histórico, periodos y exportación', (tester) async {
      useTallView(tester);
      var exported = false;
      await tester.pumpWidget(
        wrap(
          HistoryTab(
            state: _data,
            onOpenCourse: (_) {},
            onExport: () async => exported = true,
          ),
        ),
      );
      expect(find.text('75%'), findsWidgets);
      expect(find.text('2 periodos registrados'), findsOneWidget);
      expect(find.text('En curso'), findsOneWidget);
      expect(find.text('Margen: 2 permitidas'), findsOneWidget);
      expect(find.text('Cálculo'), findsNothing);

      await tapText(tester, '2026-1');
      expect(find.text('Cálculo'), findsOneWidget);
      expect(find.text('En curso'), findsNothing);

      await tapText(tester, 'Descargar historial académico (PDF)');
      await tester.pumpAndSettle();
      expect(exported, isTrue);
    });
  });

  group('Perfil', () {
    const profile = UserProfile(
      name: 'Ana Pérez',
      email: 'ana@udla.edu.co',
      role: UserRole.student,
      code: '1020304050',
      faculty: 'Facultad de Ingeniería',
      bleEnabled: false,
    );

    testWidgets('datos reales y campos opcionales sin inventar', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProfileTab(
            uid: uid,
            displayName: 'Ana Pérez',
            email: 'ana@udla.edu.co',
            profile: profile,
            state: _data,
          ),
        ),
      );
      expect(find.text('Cód. 1020304050'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget); // índice presencial
      expect(
        find.text('Sin registrar'),
        findsNWidgets(3),
      ); // semestre, programa, sede
      expect(find.text('Facultad de Ingeniería'), findsOneWidget);
      expect(find.text('Próximamente'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.textContaining('80%'), findsNothing);
    });

    testWidgets('sin perfil muestra aviso', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProfileTab(
            uid: uid,
            displayName: '',
            email: 'x@udla.edu.co',
            profile: null,
            state: const AcademicState.loading(),
          ),
        ),
      );
      expect(
        find.textContaining('Perfil académico no disponible'),
        findsOneWidget,
      );
    });
  });

  // Desbordamientos en pantallas estrechas con texto ampliado.
  expectNoOverflow('Inicio', () => _dashboard(_data));
  expectNoOverflow(
    'Mis Clases',
    () => ClassesTab(
      state: _data,
      now: testNow,
      onRegister: (_) {},
      onOpenCourse: (_) {},
    ),
  );
  expectNoOverflow(
    'Historial',
    () => HistoryTab(state: _data, onOpenCourse: (_) {}, onExport: null),
  );
  expectNoOverflow(
    'Perfil',
    () => const ProfileTab(
      uid: uid,
      displayName: 'Ana Pérez',
      email: 'ana@udla.edu.co',
      profile: UserProfile(
        name: 'Ana Pérez',
        email: 'ana@udla.edu.co',
        role: UserRole.student,
        code: '1020304050',
        faculty: 'Facultad de Ciencias Contables, Económicas y Administrativas',
        bleEnabled: true,
      ),
      state: AcademicState.loading(),
    ),
  );
  expectNoOverflow('Comprobante', () => _success());
  expectNoOverflow('Fallo', () => const _FailedForTest());
  expectNoOverflow(
    'Detalle',
    () => CourseDetailScreen(
      courseId: 'c1',
      academic: ValueNotifier(_data),
      uid: uid,
      onRegister: (_) {},
    ),
  );
}

class _FailedForTest extends StatelessWidget {
  const _FailedForTest();

  @override
  Widget build(BuildContext context) => AttendanceFailedScreen(
    course: programming,
    failure: AttendanceFailure.noOpenSession,
    uid: uid,
  );
}
