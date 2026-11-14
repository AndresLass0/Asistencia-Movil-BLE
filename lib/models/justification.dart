import 'package:cloud_firestore/cloud_firestore.dart';

/// Revisión del docente sobre una inasistencia.
enum AbsenceStatus {
  /// Inasistencia justificada por el docente.
  justified('justified', 'Inasistencia justificada'),

  /// Falta confirmada por el docente.
  confirmed('confirmed', 'Falta confirmada');

  const AbsenceStatus(this.id, this.label);
  final String id;
  final String label;

  static AbsenceStatus? fromId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Revisión de una inasistencia (`justifications/{sessionId}_{studentUid}`).
///
/// Es una anotación del docente: la inasistencia sigue contando como falta
/// en los porcentajes (no hay una regla institucional confirmada sobre las
/// faltas justificadas).
class Justification {
  const Justification({
    required this.sessionId,
    required this.courseId,
    required this.studentUid,
    required this.status,
    this.teacherUid = '',
    this.updatedAt,
  });

  final String sessionId;
  final String courseId;
  final String studentUid;
  final AbsenceStatus status;
  final String teacherUid;
  final DateTime? updatedAt;

  static String docId(String sessionId, String studentUid) =>
      '${sessionId}_$studentUid';

  String get id => docId(sessionId, studentUid);

  static Justification? tryParse(Map<String, dynamic> map) {
    final status = AbsenceStatus.fromId(map['status']);
    if (status == null) return null;
    final ts = map['updatedAt'];
    return Justification(
      sessionId: map['sessionId'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      studentUid: map['studentUid'] as String? ?? '',
      status: status,
      teacherUid: map['teacherUid'] as String? ?? '',
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
