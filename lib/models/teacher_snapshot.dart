import 'academic_snapshot.dart';
import 'attendance_record.dart';
import 'course.dart';
import 'course_session.dart';
import 'enrollment.dart';
import 'incident.dart';
import 'justification.dart';

/// Un estudiante en la planilla de una sesión.
class AttendanceRow {
  const AttendanceRow({required this.student, this.record, this.justification});

  final Enrollment student;
  final AttendanceRecord? record;
  final Justification? justification;

  bool get present => record != null;

  /// Sigue en la lista de la asignatura (no canceló ni salió de ella).
  bool get enrolled => student.isActive;
}

/// Planilla y totales de una sesión.
class SessionReport {
  SessionReport({
    required this.course,
    required this.session,
    required List<AttendanceRow> rows,
  }) : rows = List.unmodifiable(rows);

  final Course course;
  final CourseSession session;
  final List<AttendanceRow> rows;

  List<AttendanceRow> get presentRows => rows.where((r) => r.present).toList()
    ..sort((a, b) => a.record!.registeredAt.compareTo(b.record!.registeredAt));

  List<AttendanceRow> get absentRows =>
      rows.where((r) => !r.present).toList()
        ..sort((a, b) => a.student.name.compareTo(b.student.name));

  int get total => rows.length;
  int get present => rows.where((r) => r.present).length;
  int get absent => total - present;
  int get justified => rows
      .where(
        (r) => !r.present && r.justification?.status == AbsenceStatus.justified,
      )
      .length;

  /// Porcentaje de presentes (0–100) o null si no hay estudiantes.
  int? get percent => total == 0 ? null : (present * 100 / total).round();
}

/// Asistencia acumulada de un estudiante en una asignatura.
class StudentStanding {
  const StudentStanding({
    required this.course,
    required this.student,
    required this.attended,
    required this.absences,
  });

  final Course course;
  final Enrollment student;
  final int attended;
  final int absences;

  int get held => attended + absences;
  int? get percent => held == 0 ? null : (attended * 100 / held).round();

  /// Faltas que le quedan según `maxAbsences` (null si no está definido).
  int? get remaining => course.maxAbsences == null
      ? null
      : (course.maxAbsences! - absences).clamp(0, course.maxAbsences!);

  /// Mismo criterio que la alerta del estudiante: 1 falta o menos restante.
  bool get atRisk => remaining != null && remaining! <= 1;
}

/// Resumen de una asignatura del docente.
class CourseReport {
  const CourseReport({
    required this.course,
    required this.heldSessions,
    required this.present,
    required this.possible,
    required this.standings,
    this.enrolled = 0,
  });

  final Course course;
  final List<CourseSession> heldSessions;

  /// Estudiantes matriculados ahora.
  final int enrolled;

  /// Asistencias en las sesiones realizadas.
  final int present;

  /// Asistencias posibles (estudiantes × sesiones realizadas).
  final int possible;
  final List<StudentStanding> standings;

  int? get percent => possible == 0 ? null : (present * 100 / possible).round();

  /// Promedio de presentes por sesión.
  double? get averagePresent =>
      heldSessions.isEmpty ? null : present / heldSessions.length;

  List<StudentStanding> get atRisk =>
      standings.where((s) => s.atRisk).toList()
        ..sort((a, b) => (a.remaining ?? 0).compareTo(b.remaining ?? 0));
}

/// Asistencia de un mes (para la gráfica de Reportes).
class MonthlyAttendance {
  const MonthlyAttendance({
    required this.year,
    required this.month,
    required this.present,
    required this.possible,
  });

  final int year;
  final int month;
  final int present;
  final int possible;

  int? get percent => possible == 0 ? null : (present * 100 / possible).round();
}

/// Totales de un periodo (o de todos si el periodo es null).
class TeacherSummary {
  const TeacherSummary({
    required this.courses,
    required this.students,
    required this.heldSessions,
    required this.present,
    required this.possible,
    required this.atRisk,
  });

  final int courses;
  final int students;
  final int heldSessions;
  final int present;
  final int possible;
  final int atRisk;

  int? get percent => possible == 0 ? null : (present * 100 / possible).round();
}

/// Todo lo que necesitan las pantallas del docente, calculado a partir de
/// los documentos de Firestore. Es inmutable y sin dependencias de UI.
///
/// Una sesión "realizada" es la que ya no admite registros: el docente la
/// finalizó o terminó su ventana de registro ([CourseSession.endsAt]).
class TeacherSnapshot {
  TeacherSnapshot({
    required List<Course> courses,
    required List<CourseSession> sessions,
    required List<AttendanceRecord> attendance,
    List<Enrollment> enrollments = const [],
    List<Justification> justifications = const [],
    List<Incident> incidents = const [],
    this.isFromCache = false,
    DateTime Function()? clock,
  }) : courses = List.unmodifiable(courses),
       sessions = List.unmodifiable(sessions),
       attendance = List.unmodifiable(attendance),
       enrollments = List.unmodifiable(enrollments),
       justifications = List.unmodifiable(justifications),
       incidents = List.unmodifiable(
         [...incidents]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
       ),
       _clock = clock ?? DateTime.now {
    for (final r in attendance) {
      _recordsBySession.putIfAbsent(r.sessionId, () => {})[r.email] = r;
    }
    for (final j in justifications) {
      _justifications[j.id] = j;
    }
    for (final e in enrollments) {
      _enrollmentsByCourse.putIfAbsent(e.courseId, () => []).add(e);
    }
    for (final list in _enrollmentsByCourse.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  final List<Course> courses;
  final List<CourseSession> sessions;
  final List<AttendanceRecord> attendance;

  /// Matrículas de todas las asignaturas del docente (cualquier estado).
  final List<Enrollment> enrollments;
  final List<Justification> justifications;

  /// Incidencias reportadas por los estudiantes, la más reciente primero.
  final List<Incident> incidents;
  final bool isFromCache;
  final DateTime Function() _clock;

  final Map<String, Map<String, AttendanceRecord>> _recordsBySession = {};
  final Map<String, Justification> _justifications = {};
  final Map<String, List<Enrollment>> _enrollmentsByCourse = {};

  DateTime get now => _clock();

  bool get hasCourses => courses.isNotEmpty;

  Course? courseById(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  CourseSession? sessionById(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Periodos con asignaturas, del más reciente al más antiguo.
  List<String> get periods {
    final set = courses.map((c) => c.period).where((p) => p.isNotEmpty).toSet();
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  String? get currentPeriod => periods.isEmpty ? null : periods.first;

  List<Course> coursesInPeriod(String? period) => [
    for (final c in courses)
      if (period == null || c.period == period) c,
  ]..sort((a, b) => a.name.compareTo(b.name));

  List<Course> get currentCourses => coursesInPeriod(currentPeriod);

  bool isHeld(CourseSession s) => !s.isOpenAt(now);

  /// Sesiones de una asignatura, de la más reciente a la más antigua.
  List<CourseSession> sessionsFor(String courseId) => [
    for (final s in sessions)
      if (s.courseId == courseId) s,
  ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  /// Sesión sin finalizar de la asignatura (abierta o con la ventana
  /// vencida pendiente de finalizar), la más reciente.
  CourseSession? activeSessionFor(String courseId) {
    for (final s in sessionsFor(courseId)) {
      if (s.statusOpen) return s;
    }
    return null;
  }

  /// Todas las sesiones sin finalizar, de la más reciente a la más antigua.
  List<CourseSession> get activeSessions =>
      sessions.where((s) => s.statusOpen).toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  /// Sesiones realizadas, de la más reciente a la más antigua.
  List<CourseSession> heldSessions({String? period, String? courseId}) {
    final ids = {
      for (final c in coursesInPeriod(period))
        if (courseId == null || c.id == courseId) c.id,
    };
    return sessions.where((s) => ids.contains(s.courseId) && isHeld(s)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  Map<String, AttendanceRecord> recordsFor(String sessionId) =>
      _recordsBySession[sessionId] ?? const {};

  Justification? justificationFor(String sessionId, String email) =>
      _justifications[Justification.docId(sessionId, email)];

  /// Todas las matrículas de la asignatura, por nombre.
  List<Enrollment> enrollmentsOf(String courseId) =>
      _enrollmentsByCourse[courseId] ?? const [];

  /// Lista actual: matriculados e invitaciones pendientes.
  List<Enrollment> currentListOf(String courseId) => [
    for (final e in enrollmentsOf(courseId))
      if (e.status.isCurrent) e,
  ];

  /// Matriculados ahora.
  int enrolledCount(String courseId) =>
      enrollmentsOf(courseId).where((e) => e.isActive).length;

  Enrollment? enrollmentFor(String courseId, String email) {
    for (final e in enrollmentsOf(courseId)) {
      if (e.email == email) return e;
    }
    return null;
  }

  /// Avisos para el docente: rechazos y cancelaciones sin revisar, el más
  /// reciente primero.
  List<Enrollment> get alerts {
    final list = enrollments.where((e) => e.needsTeacherAttention).toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return list
      ..sort((a, b) => (b.statusAt ?? epoch).compareTo(a.statusAt ?? epoch));
  }

  /// Si el estudiante debía estar en la planilla de [session].
  bool _expected(Enrollment e, CourseSession session) =>
      e.expectedAt(session) || (e.isActive && session.isOpenAt(now));

  SessionReport reportFor(CourseSession session) {
    final course =
        courseById(session.courseId) ??
        Course(id: session.courseId, name: 'Asignatura eliminada', period: '');
    final records = recordsFor(session.id);
    final known = <String>{};
    final rows = <AttendanceRow>[];
    for (final st in enrollmentsOf(course.id)) {
      if (!_expected(st, session)) continue;
      known.add(st.email);
      rows.add(
        AttendanceRow(
          student: st,
          record: records[st.email],
          justification: justificationFor(session.id, st.email),
        ),
      );
    }
    // Asistencias de estudiantes que no debían estar en la planilla (p. ej.
    // quitados de la lista después de registrarse).
    for (final r in records.values) {
      if (known.contains(r.email)) continue;
      rows.add(
        AttendanceRow(
          student:
              enrollmentFor(course.id, r.email) ??
              Enrollment(
                courseId: course.id,
                email: r.email,
                code: '',
                name: 'Estudiante fuera de la lista',
                status: EnrollmentStatus.removed,
              ),
          record: r,
        ),
      );
    }
    return SessionReport(course: course, session: session, rows: rows);
  }

  CourseReport reportForCourse(Course course) {
    final held = sessionsFor(course.id).where(isHeld).toList();
    var present = 0;
    var possible = 0;
    for (final s in held) {
      final r = reportFor(s);
      present += r.present;
      possible += r.total;
    }
    final standings = <StudentStanding>[
      for (final st in enrollmentsOf(course.id))
        if (st.isActive)
          () {
            var attended = 0, absences = 0;
            for (final s in held) {
              if (recordsFor(s.id).containsKey(st.email)) {
                attended++;
              } else if (st.expectedAt(s)) {
                absences++;
              }
            }
            return StudentStanding(
              course: course,
              student: st,
              attended: attended,
              absences: absences,
            );
          }(),
    ];
    return CourseReport(
      course: course,
      heldSessions: held,
      present: present,
      possible: possible,
      standings: standings,
      enrolled: enrolledCount(course.id),
    );
  }

  TeacherSummary summary(String? period) {
    final list = coursesInPeriod(period);
    var students = 0, held = 0, present = 0, possible = 0, risk = 0;
    for (final c in list) {
      final r = reportForCourse(c);
      students += enrolledCount(c.id);
      held += r.heldSessions.length;
      present += r.present;
      possible += r.possible;
      risk += r.atRisk.length;
    }
    return TeacherSummary(
      courses: list.length,
      students: students,
      heldSessions: held,
      present: present,
      possible: possible,
      atRisk: risk,
    );
  }

  /// Asistencia por mes de las sesiones realizadas, en orden cronológico.
  List<MonthlyAttendance> monthly(String? period) {
    final acc = <int, List<int>>{}; // yyyymm -> [present, possible]
    for (final s in heldSessions(period: period)) {
      final r = reportFor(s);
      final key = s.startsAt.year * 100 + s.startsAt.month;
      final v = acc.putIfAbsent(key, () => [0, 0]);
      v[0] += r.present;
      v[1] += r.total;
    }
    final keys = acc.keys.toList()..sort();
    return [
      for (final k in keys)
        MonthlyAttendance(
          year: k ~/ 100,
          month: k % 100,
          present: acc[k]![0],
          possible: acc[k]![1],
        ),
    ];
  }

  /// Incidencias de las asignaturas de un periodo (o de todas).
  List<Incident> incidentsIn(String? period) {
    final ids = {for (final c in coursesInPeriod(period)) c.id};
    return incidents.where((i) => ids.contains(i.courseId)).toList();
  }

  /// Nombre del estudiante en la lista de la asignatura (o un genérico).
  String studentName(String courseId, String email) {
    final entry = enrollmentFor(courseId, email);
    return entry == null || entry.name.isEmpty ? 'Estudiante' : entry.name;
  }

  /// Próxima franja de las asignaturas del periodo actual.
  UpcomingClass? nextClass(DateTime now) => nextClassOf(currentCourses, now);

  /// Franjas de hoy del periodo actual.
  List<TodayClass> todayClasses(DateTime now) =>
      todayClassesOf(currentCourses, now);
}

/// Estado de carga que TeacherHomeScreen comparte con sus pestañas.
class TeacherState {
  const TeacherState.loading() : data = null, error = null;
  const TeacherState.data(TeacherSnapshot this.data) : error = null;
  const TeacherState.error(Object this.error) : data = null;

  final TeacherSnapshot? data;
  final Object? error;

  bool get isLoading => data == null && error == null;
}
