import 'dart:async';

import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/course_session.dart';
import 'package:proyecto_asistencia/models/enrollment.dart';
import 'package:proyecto_asistencia/models/incident.dart';
import 'package:proyecto_asistencia/models/justification.dart';
import 'package:proyecto_asistencia/models/roster_plan.dart';
import 'package:proyecto_asistencia/models/teacher_snapshot.dart';
import 'package:proyecto_asistencia/models/user_profile.dart';
import 'package:proyecto_asistencia/services/teacher_backend.dart';

import 'fake_student_backend.dart' show watchValue;

/// Backend del docente en memoria, solo para las pruebas automáticas.
/// Los nombres y códigos son de ejemplo y nada se guarda.
class FakeTeacherBackend extends TeacherBackend {
  FakeTeacherBackend({DateTime? now}) : _now = now ?? DateTime.now() {
    _build();
  }

  static const uid = 'demo-teacher';
  static const email = 'docente.prueba@udla.edu.co';
  static const name = 'Docente de prueba';

  final DateTime _now;
  final _courses = <Course>[];
  final _sessions = <CourseSession>[];
  final _attendance = <AttendanceRecord>[];
  final _enrollments = <Enrollment>[];
  final _justifications = <Justification>[];
  final _incidents = <Incident>[];
  final _ctrl = StreamController<TeacherSnapshot>.broadcast();
  var _nextId = 0;

  final UserProfile _profile = const UserProfile(
    name: name,
    email: email,
    role: UserRole.teacher,
    code: '0000000001',
    faculty: '',
    bleEnabled: false,
  );

  TeacherSnapshot get _snapshot => TeacherSnapshot(
    courses: _courses,
    sessions: _sessions,
    attendance: _attendance,
    enrollments: _enrollments,
    justifications: _justifications,
    incidents: _incidents,
  );

  void _emit() => _ctrl.add(_snapshot);

  static String _period(DateTime d) => '${d.year}-${d.month <= 6 ? 1 : 2}';

  /// Lista de ejemplo: [count] estudiantes; los últimos [invited] con la
  /// invitación pendiente.
  List<Enrollment> _roster(
    String courseId,
    String prefix,
    int count, {
    int invited = 0,
  }) => [
    for (var i = 1; i <= count; i++)
      Enrollment(
        courseId: courseId,
        code: '$prefix${i.toString().padLeft(3, '0')}',
        name: 'Estudiante de ejemplo ${i.toString().padLeft(2, '0')}',
        email: 'estudiante$prefix.$i@udla.edu.co',
        status: i > count - invited
            ? EnrollmentStatus.invited
            : EnrollmentStatus.active,
        source: i > count - invited
            ? EnrollmentSource.manual
            : EnrollmentSource.import,
        teacherUid: uid,
        statusAt: DateTime(2000),
      ),
  ];

  Course _course({
    required String id,
    required String name,
    required String period,
    required String room,
    required List<ClassSchedule> schedule,
    int? maxAbsences,
    String group = '01',
  }) => Course(
    id: id,
    name: name,
    period: period,
    group: group,
    teacherName: FakeTeacherBackend.name,
    teacherUid: uid,
    room: room,
    schedule: schedule,
    maxAbsences: maxAbsences,
  );

  List<Enrollment> _activeOf(Course c) => [
    for (final e in _enrollments)
      if (e.courseId == c.id && e.isActive) e,
  ];

  void _build() {
    final today = DateTime(_now.year, _now.month, _now.day);
    final nowMin = _now.hour * 60 + _now.minute;
    final w = _now.weekday;
    int day(int offset) => (w - 1 + offset) % 7 + 1;
    final current = _period(_now);
    final previous = _period(DateTime(_now.year, _now.month - 6, 1));
    final liveStart = (nowMin - 5).clamp(0, 21 * 60);

    final live = _course(
      id: 'demo-t1',
      name: 'Programación Competitiva',
      period: current,
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
    final db = _course(
      id: 'demo-t2',
      name: 'Bases de Datos',
      period: current,
      room: 'Laboratorio 2',
      group: '02',
      schedule: [
        ClassSchedule(weekday: day(1), startMinutes: 480, endMinutes: 600),
      ],
      maxAbsences: 3,
    );
    final nets = _course(
      id: 'demo-t3',
      name: 'Redes de Comunicación',
      period: current,
      room: 'Aula 204',
      schedule: [
        ClassSchedule(weekday: day(3), startMinutes: 840, endMinutes: 960),
      ],
    );
    final old = _course(
      id: 'demo-t4',
      name: 'Algoritmos',
      period: previous,
      room: 'Aula 105',
      schedule: const [],
    );
    _courses.addAll([live, db, nets, old]);
    _enrollments.addAll([
      ..._roster(live.id, '101', 12, invited: 1),
      ..._roster(db.id, '102', 8),
      ..._roster(old.id, '103', 6),
      // Un estudiante que canceló (aviso pendiente para el docente).
      Enrollment(
        courseId: db.id,
        code: '102099',
        name: 'Estudiante que canceló',
        email: 'cancelo.102@udla.edu.co',
        status: EnrollmentStatus.withdrawn,
        teacherUid: uid,
        statusAt: _now.subtract(const Duration(days: 1)),
        teacherSeen: false,
      ),
    ]);

    void history(Course c, int start, int weeks, DateTime base) {
      final linked = _activeOf(c);
      for (var wk = 1; wk <= weeks; wk++) {
        final startsAt = base
            .subtract(Duration(days: 7 * wk))
            .add(Duration(minutes: start));
        final s = CourseSession(
          id: 'demo-ts${_nextId++}',
          courseId: c.id,
          isOpen: false,
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(minutes: 15)),
          closedAt: startsAt.add(const Duration(minutes: 15)),
          teacherUid: uid,
        );
        _sessions.add(s);
        for (var i = 0; i < linked.length; i++) {
          // Patrón fijo de inasistencias para que haya casos de riesgo.
          final absent = (i + wk) % 5 == 0 || (i == 0 && wk <= 2);
          if (absent) continue;
          _attendance.add(
            AttendanceRecord(
              id: AttendanceRecord.docId(s.id, linked[i].email),
              email: linked[i].email,
              courseId: c.id,
              sessionId: s.id,
              registeredAt: startsAt.add(Duration(minutes: 1 + i % 9)),
              teacherUid: uid,
            ),
          );
        }
      }
    }

    history(live, liveStart, 6, today);
    history(db, 480, 5, today.add(const Duration(days: 1)));
    history(old, 600, 8, DateTime(_now.year, _now.month - 5, 1));

    // Sesión abierta ahora en la clase en curso, con algunos registros.
    final open = CourseSession(
      id: 'demo-open',
      courseId: live.id,
      isOpen: true,
      startsAt: _now.subtract(const Duration(minutes: 4)),
      endsAt: _now.add(const Duration(minutes: 11)),
      teacherUid: uid,
    );
    _sessions.add(open);
    final linked = _activeOf(live);
    for (var i = 0; i < 7; i++) {
      _attendance.add(
        AttendanceRecord(
          id: AttendanceRecord.docId(open.id, linked[i].email),
          email: linked[i].email,
          courseId: live.id,
          sessionId: open.id,
          registeredAt: open.startsAt.add(Duration(seconds: 20 + 30 * i)),
          teacherUid: uid,
        ),
      );
    }

    final lastDb = _sessions.firstWhere((s) => s.courseId == db.id);
    _justifications.add(
      Justification(
        sessionId: lastDb.id,
        courseId: db.id,
        email: _activeOf(db).first.email,
        status: AbsenceStatus.justified,
        teacherUid: uid,
        updatedAt: lastDb.startsAt,
      ),
    );
    _incidents.add(
      Incident(
        id: 'demo-i1',
        studentUid: 'demo-102-2',
        email: _activeOf(db)[1].email,
        courseId: db.id,
        sessionId: lastDb.id,
        message:
            'Ejemplo: no pude registrar la asistencia porque no tenía '
            'conexión a internet.',
        createdAt: lastDb.startsAt.add(const Duration(minutes: 20)),
      ),
    );
  }

  @override
  Future<TeacherAccess> checkAccess() async => TeacherAccess.authorized;

  @override
  Future<void> sendVerificationEmail() async {}

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      watchValue<UserProfile?>(() => _profile, const Stream.empty());

  @override
  Stream<TeacherSnapshot> watch(String uid) =>
      watchValue(() => _snapshot, _ctrl.stream);

  Course _owned(Course c, {String? id}) => Course(
    id: id ?? c.id,
    name: c.name,
    period: c.period,
    group: c.group,
    teacherName: name,
    teacherUid: uid,
    room: c.room,
    building: c.building,
    schedule: c.schedule,
    maxAbsences: c.maxAbsences,
    code: c.code,
    registrationMinutes: c.registrationMinutes,
  );

  void _apply(List<EnrollmentChange> changes) {
    final now = DateTime.now();
    for (final c in changes) {
      final e = c.statusChanged
          ? c.target.copyWith(statusAt: now, teacherSeen: true)
          : c.target.copyWith(teacherSeen: true);
      _enrollments
        ..removeWhere((o) => o.id == e.id)
        ..add(e);
    }
  }

  @override
  Future<String> createCourse(
    Course course, {
    List<Enrollment> roster = const [],
  }) async {
    final id = 'demo-new${_nextId++}';
    _courses.add(_owned(course, id: id));
    _apply(
      RosterPlan.diff(const [], [for (final e in roster) e.withCourseId(id)]),
    );
    _emit();
    return id;
  }

  @override
  Future<void> updateCourse(Course course) async {
    final i = _courses.indexWhere((c) => c.id == course.id);
    if (i >= 0) _courses[i] = _owned(course);
    _emit();
  }

  @override
  Future<void> applyRosterChanges(
    Course course,
    List<EnrollmentChange> changes,
  ) async {
    _apply(changes);
    _emit();
  }

  @override
  Future<void> deleteCourse(Course course, List<Enrollment> enrollments) async {
    _courses.removeWhere((c) => c.id == course.id);
    _enrollments.removeWhere((e) => e.courseId == course.id);
    _emit();
  }

  @override
  Future<void> markAlertSeen(Enrollment enrollment) async {
    final i = _enrollments.indexWhere((e) => e.id == enrollment.id);
    if (i >= 0) _enrollments[i] = _enrollments[i].copyWith(teacherSeen: true);
    _emit();
  }

  @override
  Future<CourseSession> startSession(Course course, int minutes) async {
    final now = DateTime.now();
    final s = CourseSession(
      id: 'demo-ts${_nextId++}',
      courseId: course.id,
      isOpen: true,
      startsAt: now,
      endsAt: now.add(Duration(minutes: minutes)),
      teacherUid: uid,
    );
    _sessions.add(s);
    _emit();
    return s;
  }

  @override
  Future<void> closeSession(String sessionId) async {
    final i = _sessions.indexWhere((s) => s.id == sessionId);
    if (i < 0) return;
    final s = _sessions[i];
    final now = DateTime.now();
    _sessions[i] = CourseSession(
      id: s.id,
      courseId: s.courseId,
      isOpen: false,
      startsAt: s.startsAt,
      endsAt: s.endsAt != null && s.endsAt!.isBefore(now) ? s.endsAt : now,
      closedAt: now,
      teacherUid: uid,
    );
    _emit();
  }

  @override
  Future<void> markManualAttendance(CourseSession session, String email) async {
    final id = AttendanceRecord.docId(session.id, email);
    if (_attendance.any((r) => r.id == id)) return;
    _attendance.add(
      AttendanceRecord(
        id: id,
        email: email,
        courseId: session.courseId,
        sessionId: session.id,
        registeredAt: DateTime.now(),
        method: AttendanceMethod.manual,
        teacherUid: uid,
      ),
    );
    _emit();
  }

  @override
  Future<void> setAbsenceStatus(
    CourseSession session,
    String email,
    AbsenceStatus status,
  ) async {
    _justifications
      ..removeWhere((j) => j.id == Justification.docId(session.id, email))
      ..add(
        Justification(
          sessionId: session.id,
          courseId: session.courseId,
          email: email,
          status: status,
          teacherUid: uid,
          updatedAt: DateTime.now(),
        ),
      );
    _emit();
  }

  @override
  Future<void> signOut() async {}
}
