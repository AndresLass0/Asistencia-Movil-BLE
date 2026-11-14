import 'package:cloud_firestore/cloud_firestore.dart';

/// Incidencia que un estudiante reportó al docente (`incidents/{id}`).
class Incident {
  const Incident({
    required this.id,
    required this.studentUid,
    required this.email,
    required this.courseId,
    required this.message,
    required this.createdAt,
    this.sessionId,
  });

  final String id;
  final String studentUid;

  /// Correo institucional del estudiante (minúsculas).
  final String email;
  final String courseId;
  final String? sessionId;
  final String message;
  final DateTime createdAt;

  factory Incident.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return Incident(
      id: id,
      studentUid: map['studentUid'] as String? ?? '',
      email: (map['email'] as String? ?? '').toLowerCase(),
      courseId: map['courseId'] as String? ?? '',
      sessionId: map['sessionId'] as String?,
      message: map['message'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
