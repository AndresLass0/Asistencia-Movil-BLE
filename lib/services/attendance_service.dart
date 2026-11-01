import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_record.dart';
import '../models/course.dart';
import '../models/course_session.dart';

/// Qué eligió el usuario al cerrar una pantalla de resultado.
enum AttendanceAction { home, retry, history }

/// Por qué no se pudo registrar la asistencia.
enum AttendanceFailure {
  /// El docente no tiene una sesión abierta para la asignatura.
  noOpenSession,

  /// Sin conexión con el servidor.
  offline,

  /// Las reglas rechazaron la operación (no matriculado, sesión cerrada…).
  denied,

  /// Otro error.
  unknown,
}

/// Resultado de un intento de registro.
class AttendanceResult {
  const AttendanceResult.success(
    this.record,
    this.session, {
    this.alreadyRegistered = false,
  }) : failure = null;
  const AttendanceResult.failure(this.failure)
    : record = null,
      session = null,
      alreadyRegistered = false;

  final AttendanceRecord? record;
  final CourseSession? session;
  final AttendanceFailure? failure;

  /// La asistencia ya existía para esa sesión (no se duplicó).
  final bool alreadyRegistered;

  bool get isSuccess => record != null;
}

/// Registro de asistencia contra Cloud Firestore.
///
/// La validación actual es la **sesión abierta por el docente**: solo se
/// puede registrar asistencia mientras `sessions/{id}.status == 'open'` y el
/// estudiante esté matriculado (lo exigen también las reglas).
/// La verificación por proximidad BLE aún no está implementada.
class AttendanceService {
  AttendanceService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _timeout = Duration(seconds: 15);

  /// Busca en el servidor (no en caché) la sesión abierta más reciente de
  /// la asignatura y registra la asistencia del estudiante.
  static Future<AttendanceResult> registerForCourse({
    required String uid,
    required Course course,
  }) async {
    try {
      final snap = await _db
          .collection('sessions')
          .where('courseId', isEqualTo: course.id)
          .where('status', isEqualTo: 'open')
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      if (snap.docs.isEmpty) {
        return const AttendanceResult.failure(AttendanceFailure.noOpenSession);
      }
      final sessions = [
        for (final d in snap.docs) CourseSession.fromMap(d.id, d.data()),
      ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      final session = sessions.first;

      final ref = _db
          .collection('attendance')
          .doc(AttendanceRecord.docId(session.id, uid));
      final existing = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      if (existing.exists) {
        return AttendanceResult.success(
          AttendanceRecord.fromMap(existing.id, existing.data()!),
          session,
          alreadyRegistered: true,
        );
      }

      await ref
          .set({
            'studentUid': uid,
            'courseId': course.id,
            'sessionId': session.id,
            'registeredAt': FieldValue.serverTimestamp(),
          })
          .timeout(_timeout);
      final saved = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      return AttendanceResult.success(
        AttendanceRecord.fromMap(saved.id, saved.data()!),
        session,
      );
    } on TimeoutException {
      return const AttendanceResult.failure(AttendanceFailure.offline);
    } on FirebaseException catch (e) {
      return AttendanceResult.failure(switch (e.code) {
        'unavailable' => AttendanceFailure.offline,
        'permission-denied' => AttendanceFailure.denied,
        _ => AttendanceFailure.unknown,
      });
    }
  }

  /// Guarda un reporte de incidencia para el docente (`incidents`).
  static Future<void> reportIncident({
    required String uid,
    required String courseId,
    required String message,
    String? sessionId,
  }) => _db
      .collection('incidents')
      .add({
        'studentUid': uid,
        'courseId': courseId,
        'sessionId': ?sessionId,
        'message': message.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      })
      .timeout(_timeout);
}
