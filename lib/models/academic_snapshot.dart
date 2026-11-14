import 'attendance_record.dart';
import 'course.dart';
import 'course_session.dart';
import 'enrollment.dart';

/// Estado de una clase programada para hoy según la hora actual.
enum ClassTimeStatus { upcoming, inProgress, finished }

/// Una franja del horario que cae hoy.
class TodayClass {
  const TodayClass({
    required this.course,
    required this.schedule,
    required this.status,
  });

  final Course course;
  final ClassSchedule schedule;
  final ClassTimeStatus status;
}

/// Próxima clase programada (fecha y hora concretas).
class UpcomingClass {
  const UpcomingClass({
    required this.course,
    required this.schedule,
    required this.startsAt,
  });

  final Course course;
  final ClassSchedule schedule;
  final DateTime startsAt;
}

/// Estadísticas de asistencia de una asignatura.
class CourseStats {
  const CourseStats({
    required this.attended,
    required this.absences,
    this.openSession,
    this.openSessionRecord,
  });

  /// Sesiones con asistencia registrada.
  final int attended;

  /// Sesiones cerradas sin asistencia registrada.
  final int absences;

  /// Sesión abierta ahora (si hay).
  final CourseSession? openSession;

  /// Asistencia ya registrada en [openSession] (si hay).
  final AttendanceRecord? openSessionRecord;

  /// Sesiones que cuentan para el porcentaje.
  int get held => attended + absences;

  /// Porcentaje de asistencia (0–100) o null si aún no hay sesiones.
  int? get percent => held == 0 ? null : (attended * 100 / held).round();

  bool get hasOpenSession => openSession != null;

  /// Hay una sesión abierta en la que aún no se registró asistencia.
  bool get canRegister => openSession != null && openSessionRecord == null;
}

/// Resumen agregado de varias asignaturas.
class AttendanceSummary {
  const AttendanceSummary({required this.attended, required this.absences});

  final int attended;
  final int absences;

  int get held => attended + absences;
  int? get percent => held == 0 ? null : (attended * 100 / held).round();
}

/// Invitación de un docente a una asignatura (matrícula `invited`).
class CourseInvitation {
  const CourseInvitation({required this.course, required this.enrollment});

  final Course course;
  final Enrollment enrollment;
}

/// Todo lo que las pantallas del estudiante necesitan, calculado a partir
/// de los documentos de Firestore. Es inmutable y sin dependencias de UI,
/// por eso se puede probar con datos de ejemplo.
///
/// [enrollments] son las matrículas del estudiante. Una asignatura sin
/// matrícula conocida se trata como matriculada (datos de prueba).
class AcademicSnapshot {
  AcademicSnapshot({
    required List<Course> courses,
    required List<CourseSession> sessions,
    required List<AttendanceRecord> attendance,
    List<Enrollment> enrollments = const [],
    this.isFromCache = false,
  }) : sessions = List.unmodifiable(sessions),
       attendance = List.unmodifiable(attendance),
       enrollments = List.unmodifiable(enrollments),
       courses = List.unmodifiable(_visible(courses, enrollments)),
       invitations = List.unmodifiable(_invitations(courses, enrollments)) {
    for (final r in attendance) {
      _recordBySession[r.sessionId] = r;
    }
    for (final e in enrollments) {
      _enrollmentByCourse[e.courseId] = e;
    }
  }

  static Map<String, Enrollment> _byCourse(List<Enrollment> list) => {
    for (final e in list) e.courseId: e,
  };

  /// Asignaturas que el estudiante ve: matriculado, canceló o salió de la
  /// lista (para su historial). Las invitaciones van aparte.
  static List<Course> _visible(List<Course> all, List<Enrollment> list) {
    final map = _byCourse(list);
    return [
      for (final c in all)
        if (map[c.id] == null ||
            (map[c.id]!.status.studentCanSee &&
                map[c.id]!.status != EnrollmentStatus.invited))
          c,
    ];
  }

  static List<CourseInvitation> _invitations(
    List<Course> all,
    List<Enrollment> list,
  ) {
    final map = _byCourse(list);
    return [
      for (final c in all)
        if (map[c.id]?.status == EnrollmentStatus.invited)
          CourseInvitation(course: c, enrollment: map[c.id]!),
    ];
  }

  static final empty = AcademicSnapshot(
    courses: const [],
    sessions: const [],
    attendance: const [],
  );

  /// Asignaturas visibles (sin las invitaciones pendientes).
  final List<Course> courses;
  final List<CourseSession> sessions;
  final List<AttendanceRecord> attendance;
  final List<Enrollment> enrollments;

  /// Invitaciones pendientes de aceptar o rechazar.
  final List<CourseInvitation> invitations;

  /// true si los datos vienen de la caché local (sin conexión).
  final bool isFromCache;

  final Map<String, AttendanceRecord> _recordBySession = {};
  final Map<String, Enrollment> _enrollmentByCourse = {};

  /// Matrícula del estudiante en la asignatura (null si no se conoce).
  Enrollment? enrollmentFor(String courseId) => _enrollmentByCourse[courseId];

  /// Matriculado ahora (puede registrar asistencia).
  bool isActiveIn(String courseId) =>
      _enrollmentByCourse[courseId]?.isActive ?? true;

  bool get hasCourses => courses.isNotEmpty;

  Course? courseById(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  AttendanceRecord? recordForSession(String sessionId) =>
      _recordBySession[sessionId];

  /// Periodos con asignaturas, del más reciente al más antiguo.
  List<String> get periods {
    final set = courses.map((c) => c.period).where((p) => p.isNotEmpty).toSet();
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Periodo más reciente (se considera el actual) o null.
  String? get currentPeriod => periods.isEmpty ? null : periods.first;

  List<Course> coursesInPeriod(String? period) => [
    for (final c in courses)
      if (period == null || c.period == period) c,
  ]..sort((a, b) => a.name.compareTo(b.name));

  /// Asignaturas del periodo actual en las que está matriculado ahora.
  List<Course> get currentCourses => [
    for (final c in coursesInPeriod(currentPeriod))
      if (isActiveIn(c.id)) c,
  ];

  /// Sesiones de una asignatura, de la más reciente a la más antigua.
  List<CourseSession> sessionsFor(String courseId) => [
    for (final s in sessions)
      if (s.courseId == courseId) s,
  ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  CourseStats statsFor(Course course) {
    var attended = 0, absences = 0;
    CourseSession? open;
    final enrollment = _enrollmentByCourse[course.id];
    final active = enrollment?.isActive ?? true;
    for (final s in sessions) {
      if (s.courseId != course.id) continue;
      final record = _recordBySession[s.id];
      if (record != null) {
        attended++;
      } else if (!s.isOpen && (enrollment?.expectedAt(s) ?? true)) {
        // Solo cuentan las sesiones en las que estaba matriculado.
        absences++;
      }
      if (active &&
          s.isOpen &&
          (open == null || s.startsAt.isAfter(open.startsAt))) {
        open = s;
      }
    }
    return CourseStats(
      attended: attended,
      absences: absences,
      openSession: open,
      openSessionRecord: open == null ? null : _recordBySession[open.id],
    );
  }

  AttendanceSummary summaryFor(Iterable<Course> list) {
    var attended = 0, absences = 0;
    for (final c in list) {
      final s = statsFor(c);
      attended += s.attended;
      absences += s.absences;
    }
    return AttendanceSummary(attended: attended, absences: absences);
  }

  /// Resumen de todas las asignaturas de todos los periodos.
  AttendanceSummary get overall => summaryFor(courses);

  /// Asignaturas del periodo actual con sesión abierta y sin asistencia.
  List<Course> get pendingOpenCourses => [
    for (final c in currentCourses)
      if (statsFor(c).canRegister) c,
  ];

  /// Clases de hoy según el horario, ordenadas por hora de inicio.
  List<TodayClass> todayClasses(DateTime now) =>
      todayClassesOf(currentCourses, now);

  /// Próxima clase que aún no ha empezado (hasta 7 días adelante).
  UpcomingClass? nextClass(DateTime now) => nextClassOf(currentCourses, now);

  /// Asignatura que conviene usar para registrar asistencia ahora:
  /// primero una con sesión abierta pendiente; si no, una en horario.
  Course? suggestedAttendanceCourse(DateTime now) {
    final pending = pendingOpenCourses;
    if (pending.isNotEmpty) return pending.first;
    for (final t in todayClasses(now)) {
      if (t.status == ClassTimeStatus.inProgress) return t.course;
    }
    return null;
  }
}

/// Franjas de hoy de [courses] según la hora, ordenadas por inicio.
/// (Compartido por las vistas del estudiante y del docente.)
List<TodayClass> todayClassesOf(Iterable<Course> courses, DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  final result = <TodayClass>[];
  for (final c in courses) {
    for (final s in c.schedule) {
      if (s.weekday != now.weekday) continue;
      final status = minutes < s.startMinutes
          ? ClassTimeStatus.upcoming
          : minutes < s.endMinutes
          ? ClassTimeStatus.inProgress
          : ClassTimeStatus.finished;
      result.add(TodayClass(course: c, schedule: s, status: status));
    }
  }
  return result
    ..sort((a, b) => a.schedule.startMinutes - b.schedule.startMinutes);
}

/// Próxima franja de [courses] que aún no ha empezado (hasta 7 días).
UpcomingClass? nextClassOf(Iterable<Course> courses, DateTime now) {
  UpcomingClass? best;
  final today = DateTime(now.year, now.month, now.day);
  for (final c in courses) {
    for (final s in c.schedule) {
      var offset = (s.weekday - now.weekday) % 7;
      var start = s.startOn(today.add(Duration(days: offset)));
      if (!start.isAfter(now)) {
        offset += 7;
        start = s.startOn(today.add(Duration(days: offset)));
      }
      if (best == null || start.isBefore(best.startsAt)) {
        best = UpcomingClass(course: c, schedule: s, startsAt: start);
      }
    }
  }
  return best;
}

/// Estado de carga de los datos académicos que HomeScreen comparte con las
/// pestañas.
class AcademicState {
  const AcademicState.loading() : data = null, error = null;
  const AcademicState.data(AcademicSnapshot this.data) : error = null;
  const AcademicState.error(Object this.error) : data = null;

  final AcademicSnapshot? data;
  final Object? error;

  bool get isLoading => data == null && error == null;
}
