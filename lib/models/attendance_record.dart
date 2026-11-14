import 'package:cloud_firestore/cloud_firestore.dart';

/// Cómo se registró una asistencia.
enum AttendanceMethod {
  /// El estudiante la registró durante la sesión abierta.
  session('session'),

  /// El docente la añadió manualmente (excepción).
  manual('manual');

  const AttendanceMethod(this.id);
  final String id;

  static AttendanceMethod fromId(Object? id) =>
      id == manual.id ? manual : session;
}

/// Asistencia registrada (`attendance/{sessionId}_{uid}`).
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentUid,
    required this.courseId,
    required this.sessionId,
    required this.registeredAt,
    this.method = AttendanceMethod.session,
    this.teacherUid = '',
  });

  final String id;
  final String studentUid;
  final String courseId;
  final String sessionId;
  final DateTime registeredAt;
  final AttendanceMethod method;

  /// Docente de la asignatura (permite que lo consulte en sus reportes).
  final String teacherUid;

  /// Id del documento: una sola asistencia por estudiante y sesión.
  static String docId(String sessionId, String uid) => '${sessionId}_$uid';

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['registeredAt'];
    return AttendanceRecord(
      id: id,
      studentUid: map['studentUid'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      // Escritura pendiente (sin hora del servidor todavía): hora local.
      registeredAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      method: AttendanceMethod.fromId(map['method']),
      teacherUid: map['teacherUid'] as String? ?? '',
    );
  }

  /// Código legible del comprobante, p. ej. "AS-261101-180342".
  String get code {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = registeredAt;
    return 'AS-${two(d.year % 100)}${two(d.month)}${two(d.day)}'
        '-${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}
