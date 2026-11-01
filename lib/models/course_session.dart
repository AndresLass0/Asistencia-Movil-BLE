import 'package:cloud_firestore/cloud_firestore.dart';

/// Sesión de clase abierta por el docente (`sessions/{id}`).
///
/// Mientras `status == 'open'`, los estudiantes matriculados pueden
/// registrar su asistencia.
class CourseSession {
  const CourseSession({
    required this.id,
    required this.courseId,
    required this.isOpen,
    required this.startsAt,
    this.endsAt,
  });

  final String id;
  final String courseId;
  final bool isOpen;
  final DateTime startsAt;
  final DateTime? endsAt;

  factory CourseSession.fromMap(String id, Map<String, dynamic> map) {
    DateTime? read(Object? v) => v is Timestamp ? v.toDate() : null;
    return CourseSession(
      id: id,
      courseId: map['courseId'] as String? ?? '',
      isOpen: map['status'] == 'open',
      startsAt: read(map['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: read(map['endsAt']),
    );
  }
}
