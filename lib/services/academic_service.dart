import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_snapshot.dart';
import '../models/attendance_record.dart';
import '../models/course.dart';
import '../models/course_session.dart';

/// Lectura en tiempo real de los datos académicos del estudiante.
///
/// Colecciones (ver `docs/MODELO_DE_DATOS.md` y `firestore.rules`):
/// - `courses`   : asignaturas; `students` contiene los uid matriculados.
/// - `sessions`  : sesiones de clase (`courseId`, `status`, `startsAt`…).
/// - `attendance`: una asistencia por estudiante y sesión.
class AcademicService {
  AcademicService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Firestore admite como máximo 30 valores en un filtro `whereIn`.
  static const _whereInLimit = 30;

  /// Emite un [AcademicSnapshot] cada vez que cambia cualquiera de las tres
  /// fuentes. Los errores (p. ej. reglas sin publicar) se propagan.
  static Stream<AcademicSnapshot> watch(String uid) {
    late StreamController<AcademicSnapshot> controller;
    StreamSubscription? coursesSub, attendanceSub;
    final sessionSubs = <StreamSubscription>[];

    List<Course>? courses;
    List<AttendanceRecord>? attendance;
    var sessionChunks = <int, List<CourseSession>>{};
    var expectedChunks = 0;
    var fromCache = false;

    void emit() {
      if (courses == null || attendance == null) return;
      if (sessionChunks.length < expectedChunks) return;
      controller.add(
        AcademicSnapshot(
          courses: courses!,
          sessions: [for (final c in sessionChunks.values) ...c],
          attendance: attendance!,
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
      emit();
    }

    controller = StreamController<AcademicSnapshot>(
      onListen: () {
        coursesSub = _db
            .collection('courses')
            .where('students', arrayContains: uid)
            .snapshots(includeMetadataChanges: true)
            .listen((snap) {
              fromCache = snap.metadata.isFromCache;
              final next = [
                for (final d in snap.docs) Course.fromMap(d.id, d.data()),
              ];
              final idsChanged =
                  courses == null ||
                  next
                      .map((c) => c.id)
                      .toSet()
                      .difference(courses!.map((c) => c.id).toSet())
                      .isNotEmpty ||
                  next.length != courses!.length;
              courses = next;
              if (idsChanged) {
                watchSessions([for (final c in next) c.id]);
              } else {
                emit();
              }
            }, onError: controller.addError);

        attendanceSub = _db
            .collection('attendance')
            .where('studentUid', isEqualTo: uid)
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
        await coursesSub?.cancel();
        await attendanceSub?.cancel();
        for (final s in sessionSubs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}
