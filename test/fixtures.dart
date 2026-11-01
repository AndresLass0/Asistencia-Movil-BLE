import 'package:proyecto_asistencia/models/academic_snapshot.dart';
import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/course_session.dart';

/// Datos de ejemplo SOLO para pruebas (no se usan en la app).
/// Referencia: lunes 2 de noviembre de 2026, 6:30 PM.
final testNow = DateTime(2026, 11, 2, 18, 30);

const uid = 'u1';

Course course({
  required String id,
  required String name,
  String period = '2026-2',
  List<Map<String, Object>> schedule = const [],
  int? maxAbsences,
  String room = 'Aula 302',
}) => Course.fromMap(id, {
  'name': name,
  'period': period,
  'group': '01',
  'teacherName': 'Docente de prueba',
  'room': room,
  'building': 'Edificio A',
  'schedule': schedule,
  'maxAbsences': ?maxAbsences,
});

CourseSession session(
  String id,
  String courseId,
  DateTime start, {
  bool open = false,
}) => CourseSession(id: id, courseId: courseId, isOpen: open, startsAt: start);

AttendanceRecord record(String sessionId, String courseId, DateTime at) =>
    AttendanceRecord(
      id: AttendanceRecord.docId(sessionId, uid),
      studentUid: uid,
      courseId: courseId,
      sessionId: sessionId,
      registeredAt: at,
    );

final programming = course(
  id: 'c1',
  name: 'Programación Competitiva',
  schedule: [
    {'day': 1, 'start': '18:00', 'end': '20:00'},
    {'day': 3, 'start': '18:00', 'end': '20:00'},
  ],
  maxAbsences: 3,
);
final databases = course(
  id: 'c2',
  name: 'Bases de Datos',
  schedule: [
    {'day': 1, 'start': '14:00', 'end': '16:00'},
  ],
  room: 'Lab 201',
);
final networks = course(
  id: 'c3',
  name: 'Redes de Comunicación',
  schedule: [
    {'day': 5, 'start': '08:00', 'end': '10:00'},
  ],
);
final calculus = course(id: 'c4', name: 'Cálculo', period: '2026-1');

/// c1: 1 asistida, 1 falta, sesión abierta sin registrar.
/// c2: 1 asistida hoy. c3: sin sesiones. c4 (periodo anterior): 1 asistida.
AcademicSnapshot sampleSnapshot({List<Course>? courses}) => AcademicSnapshot(
  courses: courses ?? [programming, databases, networks, calculus],
  sessions: [
    session('s1', 'c1', DateTime(2026, 10, 26, 18)),
    session('s2', 'c1', DateTime(2026, 10, 28, 18)),
    session('s3', 'c1', DateTime(2026, 11, 2, 18), open: true),
    session('s4', 'c2', DateTime(2026, 11, 2, 14)),
    session('s5', 'c4', DateTime(2026, 5, 4, 10)),
  ],
  attendance: [
    record('s1', 'c1', DateTime(2026, 10, 26, 18, 3)),
    record('s4', 'c2', DateTime(2026, 11, 2, 14, 5)),
    record('s5', 'c4', DateTime(2026, 5, 4, 10, 1)),
  ],
);
