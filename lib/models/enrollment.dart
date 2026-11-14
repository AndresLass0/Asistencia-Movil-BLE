import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'course_session.dart';

/// Estado de una matrícula (`enrollments/{courseId}_{correo}`).
/// Transiciones y permisos: `docs/MODELO_DE_DATOS.md` y `firestore.rules`.
enum EnrollmentStatus {
  /// Matriculado: puede registrar asistencia y cuenta en los porcentajes.
  active('active', 'Matriculado'),

  /// El docente lo agregó a mano; falta que el estudiante acepte.
  invited('invited', 'Invitación pendiente'),

  /// El estudiante rechazó la invitación.
  declined('declined', 'Rechazó la invitación'),

  /// El estudiante canceló la asignatura.
  withdrawn('withdrawn', 'Canceló la asignatura'),

  /// No venía en la última lista importada (o el docente lo quitó).
  removed('removed', 'Fuera de la lista');

  const EnrollmentStatus(this.id, this.label);
  final String id;
  final String label;

  static EnrollmentStatus? fromId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// El estudiante puede ver la asignatura (sus datos o su historial).
  bool get studentCanSee => this != declined;

  /// Aparece en las listas actuales del docente (matriculados e invitados).
  bool get isCurrent => this == active || this == invited;
}

/// Cómo entró el estudiante a la lista.
enum EnrollmentSource {
  /// Lista oficial importada (Excel/CSV): queda activo directamente.
  import('import'),

  /// Agregado a mano por el docente: queda como invitación.
  manual('manual');

  const EnrollmentSource(this.id);
  final String id;

  static EnrollmentSource fromId(Object? id) =>
      id == manual.id ? manual : import;
}

/// Un estudiante en la lista de una asignatura.
///
/// Se identifica por su **correo institucional** (en minúsculas): es el dato
/// que comparten la lista oficial y la cuenta, y la app exige verificarlo.
class Enrollment {
  const Enrollment({
    required this.courseId,
    required this.email,
    required this.code,
    required this.name,
    required this.status,
    this.teacherUid = '',
    this.program = '',
    this.source = EnrollmentSource.import,
    this.createdAt,
    this.statusAt,
    this.teacherSeen = true,
  });

  final String courseId;
  final String email;
  final String code;
  final String name;
  final String program;
  final EnrollmentStatus status;
  final EnrollmentSource source;
  final String teacherUid;
  final DateTime? createdAt;

  /// Último cambio de estado (hora del servidor; null si está pendiente).
  final DateTime? statusAt;

  /// false cuando el estudiante rechazó o canceló y el docente aún no lo vio.
  final bool teacherSeen;

  static String docId(String courseId, String email) =>
      '${courseId}_${email.trim().toLowerCase()}';

  String get id => docId(courseId, email);

  bool get isActive => status == EnrollmentStatus.active;

  /// Aviso pendiente para el docente (rechazo o cancelación sin revisar).
  bool get needsTeacherAttention =>
      !teacherSeen &&
      (status == EnrollmentStatus.withdrawn ||
          status == EnrollmentStatus.declined);

  /// Si el estudiante debía asistir a [session] (para contar faltas).
  ///
  /// - Matriculado: las sesiones que terminaron después de matricularse.
  /// - Canceló o salió de la lista: las que empezaron antes de ese cambio.
  /// - Invitación o rechazo: ninguna.
  bool expectedAt(CourseSession session) {
    final changed = statusAt;
    switch (status) {
      case EnrollmentStatus.active:
        if (changed == null) return true;
        final end = session.closedAt ?? session.endsAt;
        return end == null || changed.isBefore(end);
      case EnrollmentStatus.withdrawn:
      case EnrollmentStatus.removed:
        return changed != null && session.startsAt.isBefore(changed);
      case EnrollmentStatus.invited:
      case EnrollmentStatus.declined:
        return false;
    }
  }

  /// "JP" para "Juan Pérez".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  /// La misma matrícula en otra asignatura (al crear la asignatura).
  Enrollment withCourseId(String id) => Enrollment(
    courseId: id,
    email: email,
    code: code,
    name: name,
    program: program,
    status: status,
    source: source,
    teacherUid: teacherUid,
    createdAt: createdAt,
    statusAt: statusAt,
    teacherSeen: teacherSeen,
  );

  Enrollment copyWith({
    String? code,
    String? name,
    String? program,
    EnrollmentStatus? status,
    EnrollmentSource? source,
    DateTime? statusAt,
    bool? teacherSeen,
  }) => Enrollment(
    courseId: courseId,
    email: email,
    code: code ?? this.code,
    name: name ?? this.name,
    program: program ?? this.program,
    status: status ?? this.status,
    source: source ?? this.source,
    teacherUid: teacherUid,
    createdAt: createdAt,
    statusAt: statusAt ?? this.statusAt,
    teacherSeen: teacherSeen ?? this.teacherSeen,
  );

  static Enrollment? tryParse(Map<String, dynamic> map) {
    final status = EnrollmentStatus.fromId(map['status']);
    final courseId = map['courseId'] as String? ?? '';
    final email = (map['email'] as String? ?? '').trim().toLowerCase();
    if (status == null || courseId.isEmpty || email.isEmpty) return null;
    DateTime? read(Object? v) => v is Timestamp ? v.toDate() : null;
    return Enrollment(
      courseId: courseId,
      email: email,
      code: map['code'] as String? ?? '',
      name: (map['name'] as String? ?? '').trim(),
      program: map['program'] as String? ?? '',
      status: status,
      source: EnrollmentSource.fromId(map['source']),
      teacherUid: map['teacherUid'] as String? ?? '',
      createdAt: read(map['createdAt']),
      statusAt: read(map['statusAt']),
      teacherSeen: map['teacherSeen'] != false,
    );
  }
}
