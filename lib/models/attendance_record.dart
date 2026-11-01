import 'package:cloud_firestore/cloud_firestore.dart';

/// Asistencia registrada (`attendance/{sessionId}_{uid}`).
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentUid,
    required this.courseId,
    required this.sessionId,
    required this.registeredAt,
  });

  final String id;
  final String studentUid;
  final String courseId;
  final String sessionId;
  final DateTime registeredAt;

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
