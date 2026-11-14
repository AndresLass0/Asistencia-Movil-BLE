import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_snapshot.dart';
import '../models/attendance_record.dart';
import '../models/course.dart';
import '../models/course_session.dart';
import '../models/enrollment.dart';

/// Lectura en tiempo real de los datos académicos del estudiante.
///
/// Colecciones (ver `docs/MODELO_DE_DATOS.md` y `firestore.rules`):
/// - `enrollments`: sus matrículas (`email == su correo`).
/// - `courses`    : cada asignatura de una matrícula visible (por id).
/// - `sessions`   : sesiones de esas asignaturas.
/// - `attendance` : sus asistencias (`email == su correo`).
class AcademicService {
  AcademicService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Firestore admite como máximo 30 valores en un filtro `whereIn`.
  static const _whereInLimit = 30;

  /// Emite un [AcademicSnapshot] cada vez que cambia cualquiera de las
  /// fuentes. Los errores (p. ej. reglas sin publicar) se propagan.
  static Stream<AcademicSnapshot> watch(String email) {
    final me = email.trim().toLowerCase();
    late StreamController<AcademicSnapshot> controller;
    StreamSubscription? enrollmentsSub, attendanceSub;
    final courseSubs = <String, StreamSubscription>{};
    final sessionSubs = <StreamSubscription>[];

    List<Enrollment>? enrollments;
    List<AttendanceRecord>? attendance;
    final courses = <String, Course?>{}; // null = aún sin leer o eliminada
    final loaded = <String>{};
    var sessionChunks = <int, List<CourseSession>>{};
    var expectedChunks = 0;
    var sessionIds = <String>[];
    var fromCache = false;

    void emit() {
      if (enrollments == null || attendance == null) return;
      if (loaded.length < courseSubs.length) return;
      if (sessionChunks.length < expectedChunks) return;
      controller.add(
        AcademicSnapshot(
          courses: courses.values.whereType<Course>().toList(),
          sessions: [for (final c in sessionChunks.values) ...c],
          attendance: attendance!,
          enrollments: enrollments!,
          isFromCache: fromCache,
        ),
      );
    }

    void watchSessions(List<String> ids) {
      for (final s in sessionSubs) {
        s.cancel();
      }
      sessionSubs.clear();
      sessionChunks = {};
      sessionIds = ids;
      expectedChunks = (ids.length / _whereInLimit).ceil();
      for (var i = 0; i < expectedChunks; i++) {
        final chunk = ids.skip(i * _whereInLimit).take(_whereInLimit).toList();
        sessionSubs.add(
          _db
              .collection('sessions')
              .where('courseId', whereIn: chunk)
              .snapshots()
              .listen((snap) {
                sessionChunks[i] = [
                  for (final d in snap.docs)
                    CourseSession.fromMap(d.id, d.data()),
                ];
                emit();
              }, onError: controller.addError),
        );
      }
    }

    void sync(List<Enrollment> list) {
      final visible = {
        for (final e in list)
          if (e.status.studentCanSee) e.courseId,
      };
      for (final id in courseSubs.keys.toList()) {
        if (visible.contains(id)) continue;
        courseSubs.remove(id)?.cancel();
        courses.remove(id);
        loaded.remove(id);
      }
      for (final id in visible) {
        if (courseSubs.containsKey(id)) continue;
        courseSubs[id] = _db.collection('courses').doc(id).snapshots().listen((
          doc,
        ) {
          final data = doc.data();
          courses[id] = data == null ? null : Course.fromMap(doc.id, data);
          loaded.add(id);
          emit();
        }, onError: controller.addError);
      }
      // Las invitaciones no necesitan sesiones.
      final withSessions = [
        for (final e in list)
          if (e.status.studentCanSee && e.status != EnrollmentStatus.invited)
            e.courseId,
      ]..sort();
      if (withSessions.join(',') != sessionIds.join(',')) {
        watchSessions(withSessions);
      }
    }

    controller = StreamController<AcademicSnapshot>(
      onListen: () {
        enrollmentsSub = _db
            .collection('enrollments')
            .where('email', isEqualTo: me)
            .snapshots(includeMetadataChanges: true)
            .listen((snap) {
              fromCache = snap.metadata.isFromCache;
              enrollments = [
                for (final d in snap.docs) Enrollment.tryParse(d.data()),
              ].whereType<Enrollment>().toList();
              sync(enrollments!);
              emit();
            }, onError: controller.addError);

        attendanceSub = _db
            .collection('attendance')
            .where('email', isEqualTo: me)
            .snapshots()
            .listen((snap) {
              attendance = [
                for (final d in snap.docs)
                  AttendanceRecord.fromMap(d.id, d.data()),
              ];
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await enrollmentsSub?.cancel();
        await attendanceSub?.cancel();
        for (final s in courseSubs.values) {
          await s.cancel();
        }
        for (final s in sessionSubs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// El estudiante acepta o rechaza una invitación, o cancela la
  /// asignatura. Las reglas solo permiten esas transiciones sobre su propia
  /// matrícula.
  static Future<void> setMyStatus(
    Enrollment enrollment,
    EnrollmentStatus status,
  ) => _db
      .collection('enrollments')
      .doc(enrollment.id)
      .update({
        'status': status.id,
        'statusAt': FieldValue.serverTimestamp(),
        'teacherSeen': false,
      })
      .timeout(const Duration(seconds: 15));
}
