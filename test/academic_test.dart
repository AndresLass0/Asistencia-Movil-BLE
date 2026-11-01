import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/academic_snapshot.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/services/report_service.dart';

import 'fixtures.dart';

void main() {
  // Necesario para leer los recursos (fuentes del PDF) con rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Course / ClassSchedule', () {
    test('parsea horario válido y descarta inválidos', () {
      expect(
        ClassSchedule.tryParse({'day': 1, 'start': '18:00', 'end': '20:00'}),
        isNotNull,
      );
      expect(
        ClassSchedule.tryParse({'day': 8, 'start': '18:00', 'end': '20:00'}),
        isNull,
      );
      expect(
        ClassSchedule.tryParse({'day': 1, 'start': '20:00', 'end': '18:00'}),
        isNull,
      );
      expect(
        ClassSchedule.tryParse({'day': 1, 'start': '25:00', 'end': '26:00'}),
        isNull,
      );
      expect(ClassSchedule.tryParse('texto'), isNull);
    });

    test('scheduleLabel agrupa días con el mismo horario', () {
      expect(programming.scheduleLabel, 'Lun y Mié · 6:00 PM — 8:00 PM');
      expect(calculus.scheduleLabel, 'Horario no registrado');
    });

    test('fromMap tolera campos ausentes', () {
      final c = Course.fromMap('x', {});
      expect(c.name, 'Asignatura sin nombre');
      expect(c.location, '');
      expect(c.maxAbsences, isNull);
    });

    test('location omite partes vacías', () {
      expect(programming.location, 'Aula 302 • Edificio A');
    });
  });

  group('AcademicSnapshot', () {
    final data = sampleSnapshot();

    test('periodos ordenados y periodo actual', () {
      expect(data.periods, ['2026-2', '2026-1']);
      expect(data.currentPeriod, '2026-2');
      expect(data.currentCourses.map((c) => c.id), ['c2', 'c1', 'c3']);
    });

    test('estadísticas por asignatura', () {
      final s = data.statsFor(programming);
      expect(s.attended, 1);
      expect(s.absences, 1);
      expect(s.held, 2);
      expect(s.percent, 50);
      expect(s.canRegister, isTrue);
      expect(data.statsFor(networks).percent, isNull);
    });

    test('una sesión abierta sin registro no cuenta como falta', () {
      expect(data.statsFor(programming).absences, 1);
    });

    test('resúmenes', () {
      expect(data.overall.attended, 3);
      expect(data.overall.absences, 1);
      expect(data.overall.percent, 75);
      final current = data.summaryFor(data.currentCourses);
      expect(current.held, 3);
      expect(current.percent, 67);
    });

    test('clases de hoy con su estado', () {
      final today = data.todayClasses(testNow);
      expect(today.map((t) => t.course.id), ['c2', 'c1']);
      expect(today[0].status, ClassTimeStatus.finished);
      expect(today[1].status, ClassTimeStatus.inProgress);
    });

    test('siguiente clase', () {
      final next = data.nextClass(testNow)!;
      expect(next.course.id, 'c1');
      expect(next.startsAt, DateTime(2026, 11, 4, 18));
    });

    test('sesiones pendientes y asignatura sugerida', () {
      expect(data.pendingOpenCourses.map((c) => c.id), ['c1']);
      expect(data.suggestedAttendanceCourse(testNow)?.id, 'c1');
    });

    test('sin sesión abierta sugiere la clase en horario', () {
      final d = sampleSnapshot(courses: [databases, networks]);
      final at = DateTime(2026, 11, 2, 15);
      expect(d.suggestedAttendanceCourse(at)?.id, 'c2');
      expect(d.suggestedAttendanceCourse(DateTime(2026, 11, 3, 15)), isNull);
    });

    test('registrar la sesión abierta la quita de pendientes', () {
      final d = AcademicSnapshot(
        courses: data.courses,
        sessions: data.sessions,
        attendance: [
          ...data.attendance,
          record('s3', 'c1', DateTime(2026, 11, 2, 18, 4)),
        ],
      );
      expect(d.pendingOpenCourses, isEmpty);
      expect(d.statsFor(programming).openSessionRecord, isNotNull);
      expect(d.statsFor(programming).attended, 2);
    });
  });

  test('PDF del historial se genera con datos reales', () async {
    final bytes = await ReportService.buildHistoryPdf(
      studentName: 'Ana Pérez',
      email: 'ana@udla.edu.co',
      code: '1020304050',
      data: sampleSnapshot(),
      generatedAt: testNow,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
