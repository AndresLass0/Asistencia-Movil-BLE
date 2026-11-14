import 'dart:async';

import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/course_session.dart';
import 'package:proyecto_asistencia/models/incident.dart';
import 'package:proyecto_asistencia/models/justification.dart';
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
    justifications: _justifications,
    incidents: _incidents,
  );

  void _emit() => _ctrl.add(_snapshot);

  static String _period(DateTime d) => '${d.year}-${d.month <= 6 ? 1 : 2}';

  List<RosterEntry> _roster(String prefix, int count, {int unlinked = 0}) => [
    for (var i = 1; i <= count; i++)
      RosterEntry(
        code: '$prefix${i.toString().padLeft(3, '0')}',
        name: 'Estudiante de ejemplo ${i.toString().padLeft(2, '0')}',
        email: 'estudiante$i.demo@udla.edu.co',
        uid: i > count - unlinked ? null : 'demo-$prefix-$i',
      ),
  ];

  Course _course({
    required String id,
    required String name,
    required String period,
    required String room,
    required List<ClassSchedule> schedule,
    required List<RosterEntry> roster,
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
    roster: roster,
    students: [
      for (final r in roster)
        if (r.isLinked) r.uid!,
    ],
    maxAbsences: maxAbsences,
  );

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
      roster: _roster('101', 12, unlinked: 1),
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
      roster: _roster('102', 8),
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
      roster: const [],
    );
    final old = _course(
      id: 'demo-t4',
      name: 'Algoritmos',
      period: previous,
      room: 'Aula 105',
      schedule: const [],
      roster: _roster('103', 6),
    );
    _courses.addAll([live, db, nets, old]);

    void history(Course c, int start, int weeks, DateTime base) {
      final linked = c.roster.where((r) => r.isLinked).toList();
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
              id: AttendanceRecord.docId(s.id, linked[i].uid!),
              studentUid: linked[i].uid!,
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
    final linked = live.roster.where((r) => r.isLinked).toList();
    for (var i = 0; i < 7; i++) {
      _attendance.add(
        AttendanceRecord(
          id: AttendanceRecord.docId(open.id, linked[i].uid!),
          studentUid: linked[i].uid!,
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
        studentUid: db.roster.first.uid!,
        status: AbsenceStatus.justified,
        teacherUid: uid,
        updatedAt: lastDb.startsAt,
      ),
    );
    _incidents.add(
      Incident(
        id: 'demo-i1',
        studentUid: db.roster[1].uid!,
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

  @override
  Future<RosterLink> linkRoster(List<RosterEntry> roster) async {
    // En las pruebas todos los códigos se consideran registrados.
    return RosterLink(
      entries: [
        for (final e in roster) e.isLinked ? e : e.withUid('demo-${e.code}'),
      ],
      mismatches: const [],
    );
  }

  Course _owned(Course c, {String? id}) {
    final students = {
      for (final r in c.roster)
        if (r.isLinked) r.uid!,
    }.toList();
    return Course(
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
      roster: c.roster,
      students: students,
      registrationMinutes: c.registrationMinutes,
    );
  }

  @override
  Future<String> createCourse(Course course) async {
    final id = 'demo-new${_nextId++}';
    _courses.add(_owned(course, id: id));
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
  Future<void> deleteCourse(String courseId) async {
    _courses.removeWhere((c) => c.id == courseId);
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
  Future<void> markManualAttendance(
    CourseSession session,
    String studentUid,
  ) async {
    final id = AttendanceRecord.docId(session.id, studentUid);
    if (_attendance.any((r) => r.id == id)) return;
    _attendance.add(
      AttendanceRecord(
        id: id,
        studentUid: studentUid,
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
    String studentUid,
    AbsenceStatus status,
  ) async {
    _justifications
      ..removeWhere((j) => j.id == Justification.docId(session.id, studentUid))
      ..add(
        Justification(
          sessionId: session.id,
          courseId: session.courseId,
          studentUid: studentUid,
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
