/// Formatos de fecha/hora en español (sin depender del paquete intl).
const _days = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _shortMonths = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "Miércoles, 21 de octubre de 2026"
String longDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]} de ${d.year}';

/// "21 oct 2026"
String shortDate(DateTime d) =>
    '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

/// "6:03 PM" o "6:03:42 PM"
String time12h(DateTime d, {bool seconds = false}) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final s = d.second.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return seconds ? '$h:$m:$s $period' : '$h:$m $period';
}
