import 'attendance_record.dart';
import 'course.dart';
import 'course_session.dart';

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

/// Todo lo que las pantallas del estudiante necesitan, calculado a partir
/// de los documentos de Firestore. Es inmutable y sin dependencias de UI,
/// por eso se puede probar con datos de ejemplo.
class AcademicSnapshot {
  AcademicSnapshot({
    required List<Course> courses,
    required List<CourseSession> sessions,
    required List<AttendanceRecord> attendance,
    this.isFromCache = false,
  }) : courses = List.unmodifiable(courses),
       sessions = List.unmodifiable(sessions),
       attendance = List.unmodifiable(attendance) {
    for (final r in attendance) {
      _recordBySession[r.sessionId] = r;
    }
  }

  static final empty = AcademicSnapshot(
    courses: const [],
    sessions: const [],
    attendance: const [],
  );

  final List<Course> courses;
  final List<CourseSession> sessions;
  final List<AttendanceRecord> attendance;

  /// true si los datos vienen de la caché local (sin conexión).
  final bool isFromCache;

  final Map<String, AttendanceRecord> _recordBySession = {};

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

  List<Course> get currentCourses => coursesInPeriod(currentPeriod);

  /// Sesiones de una asignatura, de la más reciente a la más antigua.
  List<CourseSession> sessionsFor(String courseId) => [
    for (final s in sessions)
      if (s.courseId == courseId) s,
  ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  CourseStats statsFor(Course course) {
    var attended = 0, absences = 0;
    CourseSession? open;
    for (final s in sessions) {
      if (s.courseId != course.id) continue;
      final record = _recordBySession[s.id];
      if (record != null) {
        attended++;
      } else if (!s.isOpen) {
        absences++;
      }
      if (s.isOpen && (open == null || s.startsAt.isAfter(open.startsAt))) {
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
  List<TodayClass> todayClasses(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    final result = <TodayClass>[];
    for (final c in currentCourses) {
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

  /// Próxima clase que aún no ha empezado (hasta 7 días adelante).
  UpcomingClass? nextClass(DateTime now) {
    UpcomingClass? best;
    final today = DateTime(now.year, now.month, now.day);
    for (final c in currentCourses) {
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
