import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/ui_messages.dart';
import '../../core/validators.dart';
import '../../models/course.dart';
import '../../services/report_service.dart';
import '../../services/spreadsheet.dart';
import '../../services/teacher_backend.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_chip.dart';
import 'teacher_ui.dart';

/// Crear o editar una asignatura: datos, horario, lista de estudiantes
/// (importada de Excel/CSV o añadida a mano) y reglas de registro.
///
/// Devuelve `true` con `Navigator.pop` si se guardó.
class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({
    super.key,
    required this.backend,
    required this.teacherName,
    this.course,
    this.defaultPeriod,
  });

  final TeacherBackend backend;
  final String teacherName;

  /// Asignatura a editar (null = crear).
  final Course? course;

  /// Periodo sugerido al crear (p. ej. el actual del docente).
  final String? defaultPeriod;

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  late final _name = TextEditingController(text: widget.course?.name);
  late final _code = TextEditingController(text: widget.course?.code);
  late final _group = TextEditingController(text: widget.course?.group ?? '01');
  late final _period = TextEditingController(
    text: widget.course?.period ?? widget.defaultPeriod ?? _suggestedPeriod(),
  );
  late final _room = TextEditingController(text: widget.course?.room);
  late final _building = TextEditingController(text: widget.course?.building);
  late final _maxAbsences = TextEditingController(
    text: widget.course?.maxAbsences?.toString() ?? '',
  );
  final _studentName = TextEditingController();
  final _studentCode = TextEditingController();
  final _studentEmail = TextEditingController();

  late List<ClassSchedule> _schedule = [...?widget.course?.schedule];
  late List<RosterEntry> _roster = [...?widget.course?.roster];
  late int _minutes =
      widget.course?.registrationMinutes ?? Course.defaultRegistrationMinutes;
  String? _fileName;
  bool _saving = false;

  bool get _isEdit => widget.course != null;

  static String _suggestedPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month <= 6 ? 1 : 2}';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _group,
      _period,
      _room,
      _building,
      _maxAbsences,
      _studentName,
      _studentCode,
      _studentEmail,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- horario

  Future<void> _addSlot() async {
    final slot = await showDialog<ClassSchedule>(
      context: context,
      builder: (_) => const _SlotDialog(),
    );
    if (slot == null) return;
    setState(() {
      _schedule = [..._schedule, slot]
        ..sort(
          (a, b) => a.weekday != b.weekday
              ? a.weekday - b.weekday
              : a.startMinutes - b.startMinutes,
        );
    });
  }

  // ------------------------------------------------------------ estudiantes

  void _merge(List<RosterEntry> incoming) {
    final codes = {for (final r in _roster) r.code};
    final added = [
      for (final e in incoming)
        if (codes.add(e.code)) e,
    ];
    setState(() => _roster = [..._roster, ...added]);
  }

  Future<void> _import() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
      );
    } catch (_) {
      if (mounted) showAppMessage(context, 'No se pudo abrir el selector.');
      return;
    }
    if (file == null) return;
    try {
      final rows = Spreadsheet.readRows(await file.readAsBytes(), file.name);
      final result = parseRoster(rows);
      final before = _roster.length;
      _merge(result.entries);
      final added = _roster.length - before;
      setState(() => _fileName = file!.name);
      if (!mounted) return;
      if (result.issues.isEmpty) {
        showAppMessage(
          context,
          '$added estudiantes añadidos desde el archivo.',
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$added estudiantes añadidos'),
            content: SingleChildScrollView(
              child: Text(
                'Se omitieron ${result.issues.length} filas:\n\n'
                '${result.issues.take(30).join('\n')}'
                '${result.issues.length > 30 ? '\n…' : ''}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } on FormatException catch (e) {
      if (mounted) showAppMessage(context, e.message);
    }
  }

  Future<void> _downloadTemplate() async {
    final bytes = Spreadsheet.buildXlsx('Estudiantes', const [
      ['Código', 'Nombre', 'Correo'],
    ]);
    try {
      final saved = await ReportService.saveXlsx(
        bytes,
        'plantilla_estudiantes.xlsx',
      );
      if (saved && mounted) showAppMessage(context, 'Plantilla guardada.');
    } catch (_) {
      if (mounted) showAppMessage(context, 'No se pudo guardar la plantilla.');
    }
  }

  void _addManual() {
    final name = _studentName.text.trim();
    final code = _studentCode.text.trim();
    final email = _studentEmail.text.trim().toLowerCase();
    String? error;
    if (name.isEmpty) {
      error = 'Escribe el nombre del estudiante.';
    } else if (!isValidCode(code)) {
      error = 'El código debe tener entre 5 y 15 dígitos.';
    } else if (email.isNotEmpty && !isInstitutionalEmail(email)) {
      error = 'El correo debe ser @$institutionalDomain.';
    } else if (_roster.any((r) => r.code == code)) {
      error = 'Ese código ya está en la lista.';
    }
    if (error != null) {
      showAppMessage(context, error);
      return;
    }
    _merge([RosterEntry(code: code, name: name, email: email)]);
    _studentName.clear();
    _studentCode.clear();
    _studentEmail.clear();
    FocusScope.of(context).unfocus();
  }

  // ---------------------------------------------------------------- guardar

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Escribe el nombre de la asignatura.';
    if (!RegExp(r'^\d{4}-[12]$').hasMatch(_period.text.trim())) {
      return 'El periodo debe tener el formato AAAA-1 o AAAA-2.';
    }
    final max = _maxAbsences.text.trim();
    if (max.isNotEmpty && (int.tryParse(max) == null || int.parse(max) < 0)) {
      return 'Las faltas permitidas deben ser un número entero.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = _validate();
    if (error != null) {
      showAppMessage(context, error);
      return;
    }
    setState(() => _saving = true);
    var mismatches = const <String>[];
    var linked = 0;
    final ok = await runTeacherAction(context, () async {
      final link = await widget.backend.linkRoster(_roster);
      mismatches = link.mismatches;
      linked = link.linked;
      final max = _maxAbsences.text.trim();
      final course = Course(
        id: widget.course?.id ?? '',
        name: _name.text.trim(),
        period: _period.text.trim(),
        group: _group.text.trim(),
        teacherName: widget.teacherName,
        room: _room.text.trim(),
        building: _building.text.trim(),
        code: _code.text.trim(),
        schedule: _schedule,
        maxAbsences: max.isEmpty ? null : int.parse(max),
        roster: link.entries,
        registrationMinutes: _minutes,
      );
      if (_isEdit) {
        await widget.backend.updateCourse(course);
      } else {
        await widget.backend.createCourse(course);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    final total = _roster.length;
    showAppMessage(
      context,
      '${_isEdit ? 'Clase actualizada' : 'Clase creada'}. '
      '$linked de $total estudiantes tienen cuenta en BioAsistencia'
      '${mismatches.isEmpty ? '' : '; ${mismatches.length} con correo distinto (no vinculados)'}.',
    );
    Navigator.pop(context, true);
  }

  // -------------------------------------------------------------------- UI

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  Widget build(BuildContext context) {
    final linked = _roster.where((r) => r.isLinked).length;
    return Scaffold(
      appBar: AppTopBar(title: _isEdit ? 'Editar clase' : 'Crear clase'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Text(
            _isEdit ? 'Editar clase' : 'Crear nueva clase',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ingresa los datos del curso y carga la lista de estudiantes '
            'matriculados para que puedan registrar su asistencia.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          const SectionHeader(
            icon: Icons.school_outlined,
            title: 'Información académica',
          ),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    'Nombre de la asignatura *',
                    Icons.menu_book_outlined,
                    hint: 'Ej. Algoritmos y estructuras de datos',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        decoration: _decoration('Código', Icons.tag),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _group,
                        decoration: _decoration('Grupo', Icons.groups_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _period,
                  decoration: _decoration(
                    'Periodo *',
                    Icons.calendar_month_outlined,
                    hint: 'AAAA-1 o AAAA-2',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _room,
                        decoration: _decoration(
                          'Aula',
                          Icons.meeting_room_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _building,
                        decoration: _decoration('Edificio', Icons.domain),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(
            icon: Icons.schedule,
            title: 'Horario',
            trailing: Text(
              '${_schedule.length} franjas',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_schedule.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Sin franjas. El horario permite mostrar la clase del '
                      'día y la siguiente clase.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                for (final s in _schedule)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.chip,
                      child: Text(
                        s.shortDay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Text(s.longDay),
                    subtitle: Text(
                      '${s.timeRange} · ${minutesLabel(s.durationMinutes)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar franja',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          setState(() => _schedule = [..._schedule]..remove(s)),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Agregar franja horaria'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(
            icon: Icons.groups_outlined,
            title: 'Lista de estudiantes',
            trailing: Text(
              '${_roster.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Archivo .xlsx o .csv con las columnas: código, nombre y '
                  'correo (opcional). La primera fila puede tener los '
                  'encabezados.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Cargar lista'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _downloadTemplate,
                        icon: const Icon(Icons.download),
                        label: const Text('Plantilla .xlsx'),
                      ),
                    ),
                  ],
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileName!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 28),
                const Text(
                  'Añadir estudiante manualmente',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _studentName,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    'Nombre completo',
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _studentCode,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(
                    'Código estudiantil',
                    Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _studentEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration(
                    'Correo (opcional)',
                    Icons.mail_outline,
                    hint: 'usuario@$institutionalDomain',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _addManual,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Añadir a la lista'),
                ),
                if (_roster.isNotEmpty) ...[
                  const Divider(height: 28),
                  Text(
                    '${_roster.length} estudiantes en la lista'
                    '${_isEdit ? ' · $linked con cuenta' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final r in _roster)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: InitialsAvatar(initials: r.initials),
                      title: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Cód. ${r.code}${r.email.isEmpty ? '' : ' • ${r.email}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEdit && !r.isLinked)
                            const Tooltip(
                              message: 'Sin cuenta en BioAsistencia',
                              child: Icon(
                                Icons.person_off_outlined,
                                color: AppColors.textMuted,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Quitar de la lista',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(
                              () => _roster = [..._roster]..remove(r),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(
            icon: Icons.rule_outlined,
            title: 'Reglas de registro',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Duración predeterminada del registro',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Tiempo que los estudiantes tienen para registrarse al '
                  'iniciar la asistencia. Puedes cambiarlo en cada sesión.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in Course.registrationOptions)
                      ChoiceChip(
                        label: Text('$m min'),
                        selected: _minutes == m,
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxAbsences,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(
                    'Faltas permitidas (opcional)',
                    Icons.warning_amber_outlined,
                    hint: 'Ej. 3',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Si lo defines, la app avisa al estudiante y a ti cuando '
                  'le quede 1 falta o menos.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: _isEdit
                ? 'Guardar cambios'
                : _roster.isEmpty
                ? 'Crear clase sin estudiantes'
                : 'Crear clase con ${_roster.length} estudiantes',
            icon: Icons.check_circle_outline,
            iconOnLeft: true,
            isLoading: _saving,
            onPressed: _save,
          ),
          if (widget.backend.isDemo) ...[
            const SizedBox(height: 10),
            const Center(
              child: StatusChip(
                label: 'Modo demostración: no se guarda en el servidor',
                background: AppColors.grayChip,
                foreground: AppColors.hint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Diálogo para elegir día, hora de inicio y hora de fin.
class _SlotDialog extends StatefulWidget {
  const _SlotDialog();

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  int _day = DateTime.now().weekday;
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 0);

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _min(_end) > _min(_start);
    return AlertDialog(
      title: const Text('Agregar franja horaria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  ChoiceChip(
                    label: Text(ClassSchedule.shortDayName(d)),
                    selected: _day == d,
                    onSelected: (_) => setState(() => _day = d),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'Inicio ${ClassSchedule.formatMinutes(_min(_start))}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'Fin ${ClassSchedule.formatMinutes(_min(_end))}',
                    ),
                  ),
                ),
              ],
            ),
            if (!valid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'La hora de fin debe ser posterior a la de inicio.',
                  style: TextStyle(color: AppColors.required),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  ClassSchedule(
                    weekday: _day,
                    startMinutes: _min(_start),
                    endMinutes: _min(_end),
                  ),
                )
              : null,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
