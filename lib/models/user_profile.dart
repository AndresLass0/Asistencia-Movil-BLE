/// Rol del usuario en el campus.
enum UserRole {
  student('student', 'Estudiante', 'Código de estudiante'),
  teacher('teacher', 'Docente', 'Código o documento docente');

  const UserRole(this.id, this.label, this.codeLabel);

  /// Valor guardado en Firestore.
  final String id;

  /// Nombre visible del rol.
  final String label;

  /// Etiqueta del campo de código para este rol.
  final String codeLabel;

  static UserRole fromId(String? id) =>
      id == teacher.id ? UserRole.teacher : UserRole.student;
}

/// Preferencias de alertas dentro de la app (`users/{uid}.settings`).
class UserSettings {
  const UserSettings({this.liveSessionAlerts = true, this.riskAlerts = true});

  /// Avisar cuando el docente abre una sesión de una de mis asignaturas.
  final bool liveSessionAlerts;

  /// Avisar cuando quede 1 falta o menos del margen definido por la
  /// asignatura (solo asignaturas con `maxAbsences`).
  final bool riskAlerts;

  factory UserSettings.fromMap(Object? raw) {
    if (raw is! Map) return const UserSettings();
    return UserSettings(
      liveSessionAlerts: raw['liveSessionAlerts'] as bool? ?? true,
      riskAlerts: raw['riskAlerts'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'liveSessionAlerts': liveSessionAlerts,
    'riskAlerts': riskAlerts,
  };

  UserSettings copyWith({bool? liveSessionAlerts, bool? riskAlerts}) =>
      UserSettings(
        liveSessionAlerts: liveSessionAlerts ?? this.liveSessionAlerts,
        riskAlerts: riskAlerts ?? this.riskAlerts,
      );
}

/// Perfil académico guardado en Firestore (`users/{uid}`).
///
/// [program], [semester] y [campus] son opcionales y los completa el propio
/// usuario desde Perfil (no hay una fuente institucional conectada).
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.role,
    required this.code,
    required this.faculty,
    required this.bleEnabled,
    this.program = '',
    this.semester,
    this.campus = '',
    this.settings = const UserSettings(),
  });

  final String name;
  final String email;
  final UserRole role;
  final String code;
  final String faculty;
  final bool bleEnabled;
  final String program;
  final int? semester;
  final String campus;
  final UserSettings settings;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final semester = map['semester'];
    return UserProfile(
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserRole.fromId(map['role'] as String?),
      code: map['code'] as String? ?? '',
      faculty: map['faculty'] as String? ?? '',
      bleEnabled: map['bleEnabled'] as bool? ?? false,
      program: map['program'] as String? ?? '',
      semester: semester is int && semester > 0 ? semester : null,
      campus: map['campus'] as String? ?? '',
      settings: UserSettings.fromMap(map['settings']),
    );
  }

  /// Campos que se escriben al crear el perfil (registro).
  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'role': role.id,
    'code': code,
    'faculty': faculty,
    'bleEnabled': bleEnabled,
  };
}
