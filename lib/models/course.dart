import '../core/date_format.dart';

/// Franja semanal de una asignatura (p. ej. lunes 18:00–20:00).
///
/// En Firestore: `{day: 1..7 (1 = lunes), start: "18:00", end: "20:00"}`.
class ClassSchedule {
  const ClassSchedule({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// 1 = lunes … 7 = domingo (igual que [DateTime.weekday]).
  final int weekday;
  final int startMinutes;
  final int endMinutes;

  static const _short = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _long = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  /// Devuelve null si el mapa no tiene un formato válido.
  static ClassSchedule? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    final start = _parseTime(raw['start']);
    final end = _parseTime(raw['end']);
    if (day is! int || day < 1 || day > 7 || start == null || end == null) {
      return null;
    }
    if (end <= start) return null;
    return ClassSchedule(weekday: day, startMinutes: start, endMinutes: end);
  }

  static int? _parseTime(Object? value) {
    if (value is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  String get shortDay => _short[weekday - 1];
  String get longDay => _long[weekday - 1];

  static String formatMinutes(int minutes) =>
      time12h(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

  String get startLabel => formatMinutes(startMinutes);
  String get endLabel => formatMinutes(endMinutes);

  /// "6:00 PM — 8:00 PM"
  String get timeRange => '$startLabel — $endLabel';

  /// Inicio de esta franja en la fecha [day].
  DateTime startOn(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
    startMinutes ~/ 60,
    startMinutes % 60,
  );
}

/// Asignatura en la que está matriculado el estudiante (`courses/{id}`).
class Course {
  const Course({
    required this.id,
    required this.name,
    required this.period,
    this.group = '',
    this.teacherName = '',
    this.room = '',
    this.building = '',
    this.schedule = const [],
    this.maxAbsences,
  });

  final String id;
  final String name;

  /// Periodo académico, p. ej. "2026-1". Se ordena como texto.
  final String period;
  final String group;
  final String teacherName;
  final String room;
  final String building;
  final List<ClassSchedule> schedule;

  /// Faltas permitidas, si la institución/docente lo definió para la
  /// asignatura. Si es null no se muestra ningún margen ni alerta.
  final int? maxAbsences;

  factory Course.fromMap(String id, Map<String, dynamic> map) {
    final rawSchedule = map['schedule'];
    final max = map['maxAbsences'];
    return Course(
      id: id,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Asignatura sin nombre',
      period: map['period'] as String? ?? '',
      group: map['group'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      room: map['room'] as String? ?? '',
      building: map['building'] as String? ?? '',
      schedule: rawSchedule is List
          ? rawSchedule
                .map(ClassSchedule.tryParse)
                .whereType<ClassSchedule>()
                .toList()
          : const [],
      maxAbsences: max is int && max >= 0 ? max : null,
    );
  }

  /// "Aula 302 • Edificio 401" (omite las partes vacías).
  String get location =>
      [room, building].where((s) => s.trim().isNotEmpty).join(' • ');

  /// Horario resumido: "Lun y Mié · 6:00 PM — 8:00 PM; Vie · 8:00 AM — 10:00 AM".
  String get scheduleLabel {
    if (schedule.isEmpty) return 'Horario no registrado';
    final groups = <String, List<ClassSchedule>>{};
    for (final s in [...schedule]..sort((a, b) => a.weekday - b.weekday)) {
      groups.putIfAbsent(s.timeRange, () => []).add(s);
    }
    return groups.entries
        .map((e) {
          final days = e.value.map((s) => s.shortDay).toList();
          final dayText = days.length == 1
              ? days.first
              : '${days.sublist(0, days.length - 1).join(', ')} y ${days.last}';
          return '$dayText · ${e.key}';
        })
        .join('; ');
  }
}
