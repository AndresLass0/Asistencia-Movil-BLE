import 'dart:async';

import 'package:proyecto_asistencia/models/academic_snapshot.dart';
import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/course_session.dart';
import 'package:proyecto_asistencia/models/user_profile.dart';
import 'package:proyecto_asistencia/services/attendance_service.dart';
import 'package:proyecto_asistencia/services/student_backend.dart';

export 'fake_teacher_backend.dart';

/// Emite el valor actual al suscribirse y después cada cambio. La
/// suscripción es síncrona, así no se pierde ninguna actualización.
Stream<T> watchValue<T>(T Function() current, Stream<T> changes) =>
    Stream.multi((c) {
      c.add(current());
      final sub = changes.listen(c.add);
      c.onCancel = sub.cancel;
    });

/// Backend del estudiante en memoria, solo para las pruebas automáticas.
class FakeStudentBackend extends StudentBackend {
  FakeStudentBackend({DateTime? now}) : _now = now ?? DateTime.now() {
    _build();
  }

  static const uid = 'demo';
  static const email = 'estudiante.prueba@udla.edu.co';
  static const name = 'Estudiante de prueba';

  final DateTime _now;
  final _courses = <Course>[];
  final _sessions = <CourseSession>[];
  final _attendance = <AttendanceRecord>[];
  final _academicCtrl = StreamController<AcademicSnapshot>.broadcast();
  final _profileCtrl = StreamController<UserProfile?>.broadcast();

  UserProfile _profile = const UserProfile(
    name: name,
    email: email,
    role: UserRole.student,
    code: '0000000000',
    faculty: '',
    bleEnabled: false,
  );

  AcademicSnapshot get _snapshot => AcademicSnapshot(
    courses: _courses,
    sessions: _sessions,
    attendance: _attendance,
  );

  /// Periodo "AAAA-1" (ene–jun) o "AAAA-2" (jul–dic) de una fecha.
  static String _period(DateTime d) => '${d.year}-${d.month <= 6 ? 1 : 2}';

  DateTime _at(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

  /// Datos de ejemplo relativos a la hora actual, para que Inicio, Mis Clases
  /// y Asistencia muestren todos sus estados (sesión abierta, clase
  /// finalizada, siguiente clase, alerta de riesgo y periodo anterior).
  void _build() {
    final today = DateTime(_now.year, _now.month, _now.day);
    final nowMin = _now.hour * 60 + _now.minute;
    final current = _period(_now);
    final prevDate = DateTime(_now.year, _now.month - 6, 1);
    final previous = _period(prevDate);
    final w = _now.weekday;
    int day(int offset) => (w - 1 + offset) % 7 + 1;

    // Clase en curso hoy (sesión abierta, sin registrar).
    final liveStart = (nowMin - 20).clamp(0, 21 * 60);
    final live = Course(
      id: 'demo-c1',
      name: 'Programación Competitiva',
      period: current,
      group: '01',
      teacherName: 'Docente de ejemplo',
      room: 'Aula 101',
      schedule: [
        ClassSchedule(
          weekday: w,
          startMinutes: liveStart,
          endMinutes: liveStart + 120,
        ),
        ClassSchedule(
          weekday: day(2),
          startMinutes: liveStart,
          endMinutes: liveStart + 120,
        ),
      ],
      maxAbsences: 3,
    );
    // Clase de hoy ya finalizada (si la hora lo permite) y registrada.
    final earlyStart = (nowMin - 300).clamp(6 * 60, 21 * 60);
    final finished = Course(
      id: 'demo-c2',
      name: 'Bases de Datos',
      period: current,
      group: '02',
      teacherName: 'Docente de ejemplo',
      room: 'Laboratorio 2',
      schedule: [
        ClassSchedule(
          weekday: w,
          startMinutes: earlyStart,
          endMinutes: earlyStart + 120,
        ),
      ],
    );
    // Siguiente clase: mañana a las 8:00 AM; al límite de faltas.
    final risky = Course(
      id: 'demo-c3',
      name: 'Redes de Comunicación',
      period: current,
      group: '01',
      teacherName: 'Docente de ejemplo',
      room: 'Aula 204',
      schedule: [
        ClassSchedule(weekday: day(1), startMinutes: 480, endMinutes: 600),
      ],
      maxAbsences: 2,
    );
    final past = Course(
      id: 'demo-c4',
      name: 'Cálculo Diferencial',
      period: previous,
      group: '01',
      teacherName: 'Docente de ejemplo',
      room: 'Aula 105',
    );
    _courses.addAll([live, finished, risky, past]);

    var n = 0;
    void addWeekly(Course c, int start, int weeks, Set<int> absences) {
      for (var i = 1; i <= weeks; i++) {
        final startsAt = _at(today.subtract(Duration(days: 7 * i)), start);
        final s = CourseSession(
          id: 'demo-s${n++}',
          courseId: c.id,
          isOpen: false,
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(hours: 2)),
        );
        _sessions.add(s);
        if (!absences.contains(i)) {
          _attendance.add(_record(s, startsAt.add(Duration(minutes: 2 + i))));
        }
      }
    }

    addWeekly(live, liveStart, 6, {3});
    addWeekly(finished, earlyStart, 6, {});
    addWeekly(risky, 480, 6, {2, 5});

    // Sesión abierta ahora por el docente.
    _sessions.add(
      CourseSession(
        id: 'demo-open',
        courseId: live.id,
        isOpen: true,
        startsAt: _at(today, liveStart),
      ),
    );
    // Sesión de hoy ya cerrada y registrada.
    if (earlyStart + 120 <= nowMin) {
      final s = CourseSession(
        id: 'demo-today',
        courseId: finished.id,
        isOpen: false,
        startsAt: _at(today, earlyStart),
        endsAt: _at(today, earlyStart + 120),
      );
      _sessions.add(s);
      _attendance.add(_record(s, s.startsAt.add(const Duration(minutes: 4))));
    }
    // Periodo anterior: 10 sesiones, 1 falta.
    for (var i = 0; i < 10; i++) {
      final startsAt = DateTime(prevDate.year, prevDate.month, 2 + i * 7, 10);
      final s = CourseSession(
        id: 'demo-p$i',
        courseId: past.id,
        isOpen: false,
        startsAt: startsAt,
        endsAt: startsAt.add(const Duration(hours: 2)),
      );
      _sessions.add(s);
      if (i != 4) {
        _attendance.add(_record(s, startsAt.add(const Duration(minutes: 3))));
      }
    }
  }

  AttendanceRecord _record(CourseSession s, DateTime at) => AttendanceRecord(
    id: AttendanceRecord.docId(s.id, uid),
    studentUid: uid,
    courseId: s.courseId,
    sessionId: s.id,
    registeredAt: at,
  );

  void _emit() => _academicCtrl.add(_snapshot);

  /// Emite el valor actual al suscribirse y después cada cambio (la
  /// suscripción es síncrona, así no se pierde ninguna actualización).
  static Stream<T> _watch<T>(T Function() current, Stream<T> changes) =>
      watchValue(current, changes);

  @override
  Stream<AcademicSnapshot> watchAcademic(String uid) =>
      _watch(() => _snapshot, _academicCtrl.stream);

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _watch(() => _profile, _profileCtrl.stream);

  @override
  Future<AttendanceResult> registerAttendance(String uid, Course course) async {
    final open = _sessions
        .where((s) => s.courseId == course.id && s.isOpen)
        .toList();
    if (open.isEmpty) {
      return const AttendanceResult.failure(AttendanceFailure.noOpenSession);
    }
    final session = open.first;
    final id = AttendanceRecord.docId(session.id, uid);
    final existing = _attendance.where((r) => r.id == id);
    if (existing.isNotEmpty) {
      return AttendanceResult.success(
        existing.first,
        session,
        alreadyRegistered: true,
      );
    }
    final record = _record(session, DateTime.now());
    _attendance.add(record);
    _emit();
    return AttendanceResult.success(record, session);
  }

  @override
  Future<void> reportIncident({
    required String uid,
    required String courseId,
    required String message,
    String? sessionId,
    String teacherUid = '',
  }) async {
    // En las pruebas no se envía nada.
  }

  void _setProfile(UserProfile p) {
    _profile = p;
    _profileCtrl.add(p);
  }

  UserProfile _copy({
    String? program,
    int? semester,
    bool clearSemester = false,
    String? campus,
    UserSettings? settings,
    bool? bleEnabled,
  }) => UserProfile(
    name: _profile.name,
    email: _profile.email,
    role: _profile.role,
    code: _profile.code,
    faculty: _profile.faculty,
    bleEnabled: bleEnabled ?? _profile.bleEnabled,
    program: program ?? _profile.program,
    semester: clearSemester ? null : (semester ?? _profile.semester),
    campus: campus ?? _profile.campus,
    settings: settings ?? _profile.settings,
  );

  @override
  Future<void> updateAcademicInfo(
    String uid, {
    required String program,
    required int? semester,
    required String campus,
  }) async => _setProfile(
    _copy(
      program: program.trim(),
      semester: semester,
      clearSemester: semester == null,
      campus: campus.trim(),
    ),
  );

  @override
  Future<void> updateSettings(String uid, UserSettings settings) async =>
      _setProfile(_copy(settings: settings));

  @override
  Future<void> updateBleEnabled(String uid, bool enabled) async =>
      _setProfile(_copy(bleEnabled: enabled));

  @override
  Future<void> signOut() async {}
}
