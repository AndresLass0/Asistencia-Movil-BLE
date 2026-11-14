import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_record.dart';
import '../models/course.dart';
import '../models/course_session.dart';
import 'device_key.dart';

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

  /// Este celular ya registró a otro estudiante en la sesión.
  deviceInUse,

  /// No se puede identificar el celular (web o escritorio).
  unsupportedDevice,

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
/// puede registrar asistencia mientras `sessions/{id}.status == 'open'`, con
/// la matrícula activa y desde un celular que no haya registrado a otro
/// estudiante en la misma sesión (lo exigen también las reglas).
/// La verificación por proximidad BLE aún no está implementada.
class AttendanceService {
  AttendanceService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _timeout = Duration(seconds: 15);

  /// Busca en el servidor (no en caché) la sesión abierta más reciente de
  /// la asignatura y registra la asistencia del estudiante.
  static Future<AttendanceResult> registerForCourse({
    required String uid,
    required String email,
    required Course course,
  }) async {
    final deviceKey = await DeviceKey.get();
    if (deviceKey == null) {
      return const AttendanceResult.failure(
        AttendanceFailure.unsupportedDevice,
      );
    }
    final me = email.trim().toLowerCase();
    try {
      final snap = await _db
          .collection('sessions')
          .where('courseId', isEqualTo: course.id)
          .where('status', isEqualTo: 'open')
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      // Solo cuentan las sesiones dentro de su ventana de registro.
      final sessions =
          [for (final d in snap.docs) CourseSession.fromMap(d.id, d.data())]
              .where((s) => s.isOpen)
              .toList()
            ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      if (sessions.isEmpty) {
        return const AttendanceResult.failure(AttendanceFailure.noOpenSession);
      }
      final session = sessions.first;

      final ref = _db
          .collection('attendance')
          .doc(AttendanceRecord.docId(session.id, me));
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

      // Un celular, un estudiante por sesión: el documento solo se puede
      // crear una vez (las reglas no permiten sobrescribirlo).
      final device = _db
          .collection('sessionDevices')
          .doc('${session.id}_$deviceKey');
      final used = await device
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      if (used.exists && used.data()?['email'] != me) {
        return const AttendanceResult.failure(AttendanceFailure.deviceInUse);
      }

      final batch = _db.batch()
        ..set(ref, {
          'email': me,
          'studentUid': uid,
          'courseId': course.id,
          'sessionId': session.id,
          'teacherUid': course.teacherUid,
          'method': AttendanceMethod.session.id,
          'deviceKey': deviceKey,
          'registeredAt': FieldValue.serverTimestamp(),
        });
      if (!used.exists) {
        batch.set(device, {
          'email': me,
          'sessionId': session.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit().timeout(_timeout);
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
    required String email,
    required String courseId,
    required String message,
    String? sessionId,
    String teacherUid = '',
  }) => _db
      .collection('incidents')
      .add({
        'studentUid': uid,
        'email': email.trim().toLowerCase(),
        'courseId': courseId,
        'sessionId': ?sessionId,
        'teacherUid': teacherUid,
        'message': message.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      })
      .timeout(_timeout);
}
