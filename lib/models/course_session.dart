import 'package:cloud_firestore/cloud_firestore.dart';

/// Sesión de asistencia abierta por el docente (`sessions/{id}`).
///
/// Los estudiantes matriculados pueden registrar su asistencia mientras
/// `status == 'open'` y, si la sesión tiene `endsAt`, antes de esa hora
/// (cierre automático; también lo exigen las reglas de Firestore).
class CourseSession {
  const CourseSession({
    required this.id,
    required this.courseId,
    required bool isOpen,
    required this.startsAt,
    this.endsAt,
    this.closedAt,
    this.teacherUid = '',
  }) : statusOpen = isOpen;

  final String id;
  final String courseId;

  /// `status == 'open'` en Firestore (el docente aún no la finalizó).
  final bool statusOpen;
  final DateTime startsAt;

  /// Fin de la ventana de registro (null = sin límite de tiempo).
  final DateTime? endsAt;

  /// Hora en que el docente la finalizó (si lo hizo).
  final DateTime? closedAt;
  final String teacherUid;

  /// Abierta para registrar ahora: sin finalizar y dentro de la ventana.
  bool get isOpen => isOpenAt(DateTime.now());

  bool isOpenAt(DateTime now) =>
      statusOpen && (endsAt == null || now.isBefore(endsAt!));

  /// La ventana terminó pero el docente aún no la finalizó.
  bool isExpiredAt(DateTime now) => statusOpen && !isOpenAt(now);

  /// Duración efectiva de la sesión (hasta el cierre o el fin de la ventana).
  Duration? get duration {
    final end = closedAt ?? endsAt;
    return end?.difference(startsAt);
  }

  factory CourseSession.fromMap(String id, Map<String, dynamic> map) {
    DateTime? read(Object? v) => v is Timestamp ? v.toDate() : null;
    return CourseSession(
      id: id,
      courseId: map['courseId'] as String? ?? '',
      isOpen: map['status'] == 'open',
      // Escritura pendiente (sin hora del servidor todavía): hora local.
      startsAt: read(map['startsAt']) ?? DateTime.now(),
      endsAt: read(map['endsAt']),
      closedAt: read(map['closedAt']),
      teacherUid: map['teacherUid'] as String? ?? '',
    );
  }
}
