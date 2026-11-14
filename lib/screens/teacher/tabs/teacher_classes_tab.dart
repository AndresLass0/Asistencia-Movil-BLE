import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/date_format.dart';
import '../../../models/academic_snapshot.dart';
import '../../../models/course.dart';
import '../../../models/course_session.dart';
import '../../../models/enrollment.dart';
import '../../../models/teacher_snapshot.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/percent_ring.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../teacher_ui.dart';

/// Pestaña "Clases" del docente: clase actual o próxima con el botón para
/// iniciar la asistencia, resumen del periodo y gestión de asignaturas.
class TeacherClassesTab extends StatelessWidget {
  const TeacherClassesTab({
    super.key,
    required this.state,
    required this.teacherName,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onOpenSession,
    this.faculty = '',
    this.now,
  });

  final TeacherState state;
  final String teacherName;
  final String faculty;
  final VoidCallback onCreate;
  final ValueChanged<Course> onEdit;
  final ValueChanged<Course> onDelete;
  final ValueChanged<Course> onStart;
  final ValueChanged<CourseSession> onOpenSession;

  /// Hora de referencia (inyectable en pruebas).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    if (data == null) {
      return state.error != null
          ? AcademicErrorView(error: state.error!)
          : const LoadingView(message: 'Cargando tus clases…');
    }
    final now = this.now ?? DateTime.now();
    final period = data.currentPeriod;
    final courses = [
      ...data.currentCourses,
      for (final p in data.periods.skip(1)) ...data.coursesInPeriod(p),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis clases',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Crear clase'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TeacherCard(name: teacherName, faculty: faculty, period: period),
        const SizedBox(height: 16),
        if (!data.hasCourses)
          MessageView(
            icon: Icons.class_outlined,
            title: 'Aún no tienes asignaturas',
            message:
                'Crea tu primera clase y carga la lista de estudiantes para '
                'empezar a tomar asistencia.',
            actionLabel: 'Crear clase',
            onAction: onCreate,
          )
        else ...[
          _FeaturedCard(
            data: data,
            now: now,
            onStart: onStart,
            onOpenSession: onOpenSession,
          ),
          const SizedBox(height: 16),
          _PeriodSummary(data: data, period: period),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mis asignaturas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${courses.length} en total',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in courses) ...[
            _CourseCard(
              course: c,
              report: data.reportForCourse(c),
              enrolled: data.enrolledCount(c.id),
              invited: data
                  .currentListOf(c.id)
                  .where((e) => e.status == EnrollmentStatus.invited)
                  .length,
              active: data.activeSessionFor(c.id),
              isPast: c.period != period,
              onEdit: () => onEdit(c),
              onDelete: () => onDelete(c),
              onStart: () => onStart(c),
              onOpenSession: onOpenSession,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({
    required this.name,
    required this.faculty,
    required this.period,
  });

  final String name;
  final String faculty;
  final String? period;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.chip,
            child: Icon(Icons.co_present_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Docente' : 'Prof. $name',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (faculty.isNotEmpty)
                  Text(
                    faculty,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          if (period != null) ...[
            const SizedBox(width: 8),
            StatusChip(label: 'Periodo $period'),
          ],
        ],
      ),
    );
  }
}

/// Sesión en curso o, si no hay, la clase en horario / próxima.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.data,
    required this.now,
    required this.onStart,
    required this.onOpenSession,
  });

  final TeacherSnapshot data;
  final DateTime now;
  final ValueChanged<Course> onStart;
  final ValueChanged<CourseSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final active = data.activeSessions;
    if (active.isNotEmpty) {
      final s = active.first;
      final report = data.reportFor(s);
      final expired = s.isExpiredAt(now);
      return AppCard(
        color: AppColors.chip,
        borderColor: AppColors.primary.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(
              label: expired
                  ? 'Registro cerrado · sin finalizar'
                  : 'Sesión en curso',
              showDot: !expired,
              icon: expired ? Icons.timer_off_outlined : null,
              background: Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              report.course.name,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${report.present} de ${report.total} estudiantes registrados'
              '${s.endsAt != null && !expired ? ' · cierra a las ${time12h(s.endsAt!)}' : ''}',
              style: const TextStyle(color: AppColors.hint),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: expired
                  ? 'Finalizar y ver resumen'
                  : 'Ver sesión en curso',
              icon: Icons.sensors,
              iconOnLeft: true,
              onPressed: () => onOpenSession(s),
            ),
          ],
        ),
      );
    }

    final inProgress = data
        .todayClasses(now)
        .where((t) => t.status == ClassTimeStatus.inProgress)
        .toList();
    final next = data.nextClass(now);
    final Course? course = inProgress.isNotEmpty
        ? inProgress.first.course
        : next?.course;
    if (course == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sin clases programadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Agrega el horario a tus asignaturas para ver aquí la próxima '
              'clase. También puedes iniciar la asistencia desde cada '
              'asignatura.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    final ClassSchedule schedule = inProgress.isNotEmpty
        ? inProgress.first.schedule
        : next!.schedule;
    final when = inProgress.isNotEmpty
        ? 'En horario ahora'
        : _relative(next!.startsAt, now);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: StatusChip(
                  label: inProgress.isNotEmpty
                      ? 'Clase en curso'
                      : 'Próxima clase',
                  icon: Icons.sensors,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: StatusChip(
                  label: when,
                  icon: Icons.schedule,
                  background: AppColors.grayChip,
                  foreground: AppColors.hint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            course.name,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          if (course.group.isNotEmpty)
            Text(
              'Grupo ${course.group}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.timer_outlined,
            text: '${schedule.longDay}, ${schedule.timeRange}',
          ),
          if (course.location.isNotEmpty)
            _InfoLine(icon: Icons.domain, text: course.location),
          _InfoLine(
            icon: Icons.groups_outlined,
            text: '${data.enrolledCount(course.id)} estudiantes matriculados',
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Iniciar asistencia',
            icon: Icons.sensors,
            iconOnLeft: true,
            onPressed: () => onStart(course),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los estudiantes registran su asistencia desde la app mientras '
            'la sesión esté abierta.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime start, DateTime now) {
    final mins = start.difference(now).inMinutes;
    if (mins < 60) return 'En $mins min';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    final hour = time12h(start);
    if (diff == 0) return 'Hoy, $hour';
    if (diff == 1) return 'Mañana, $hour';
    return '${ClassSchedule.dayName(start.weekday)}, $hour';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.hint)),
          ),
        ],
      ),
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({required this.data, required this.period});

  final TeacherSnapshot data;
  final String? period;

  @override
  Widget build(BuildContext context) {
    final s = data.summary(period);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period == null ? 'Resumen' : 'Resumen del periodo $period',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          StatRow(
            children: [
              StatTile(
                icon: Icons.school_outlined,
                value: '${s.students}',
                label: 'Estudiantes en ${s.courses} asignaturas',
              ),
              StatTile(
                icon: Icons.trending_up,
                value: s.percent == null ? '—' : '${s.percent}%',
                label: 'Asistencia promedio',
              ),
              StatTile(
                icon: Icons.sensors,
                value: '${s.heldSessions}',
                label: 'Sesiones realizadas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.report,
    required this.active,
    required this.isPast,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onOpenSession,
    this.enrolled = 0,
    this.invited = 0,
  });

  final Course course;
  final CourseReport report;

  /// Matriculados e invitaciones pendientes.
  final int enrolled;
  final int invited;
  final CourseSession? active;
  final bool isPast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStart;
  final ValueChanged<CourseSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (course.group.isNotEmpty)
                          StatusChip(label: 'Grupo ${course.group}'),
                        if (course.room.isNotEmpty)
                          StatusChip(
                            label: course.room,
                            background: AppColors.grayChip,
                            foreground: AppColors.hint,
                          ),
                        if (isPast)
                          StatusChip(
                            label: 'Periodo ${course.period}',
                            background: AppColors.grayChip,
                            foreground: AppColors.hint,
                          ),
                        if (active != null)
                          const StatusChip(
                            label: 'Sesión activa',
                            showDot: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.scheduleLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PercentRing(
                percent: report.percent,
                size: 58,
                strokeWidth: 6,
                fontSize: 14,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 18, color: AppColors.hint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  enrolled == 0 && invited == 0
                      ? 'Sin estudiantes en la lista'
                      : '$enrolled ${enrolled == 1 ? 'estudiante' : 'estudiantes'}'
                            '${invited > 0 ? ' · $invited ${invited == 1 ? 'invitación' : 'invitaciones'}' : ''}'
                            ' · ${report.heldSessions.length} sesiones',
                  style: const TextStyle(color: AppColors.hint),
                ),
              ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta clase tiene una sesión de asistencia activa. '
                      'Podrás editarla cuando la sesión termine.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.hint),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: active != null
                    ? FilledButton.icon(
                        onPressed: () => onOpenSession(active!),
                        icon: const Icon(Icons.sensors, size: 18),
                        label: const Text('Ver sesión'),
                      )
                    : FilledButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.sensors, size: 18),
                        label: const Text('Iniciar asistencia'),
                      ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Editar',
                onPressed: active == null ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton.filledTonal(
                tooltip: 'Eliminar',
                onPressed: active == null ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir la duración de la ventana de registro.
/// Devuelve los minutos elegidos o null si se cancela.
Future<int?> showSessionDurationSheet(
  BuildContext context,
  Course course, {
  int enrolled = 0,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DurationSheet(course: course, enrolled: enrolled),
  );
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({required this.course, required this.enrolled});

  final Course course;

  /// Estudiantes matriculados (si es 0 se avisa).
  final int enrolled;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late int _minutes =
      Course.registrationOptions.contains(widget.course.registrationMinutes)
      ? widget.course.registrationMinutes
      : Course.defaultRegistrationMinutes;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configurar duración',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Elige cuánto tiempo podrán registrar su asistencia los '
              'estudiantes de ${widget.course.name}. Al terminar, el registro '
              'se cierra automáticamente.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Duración del registro',
              style: TextStyle(fontWeight: FontWeight.w700),
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
            const SizedBox(height: 14),
            StatRow(
              children: [
                StatTile(
                  icon: Icons.play_circle_outline,
                  value: time12h(now),
                  label: 'Inicio',
                ),
                StatTile(
                  icon: Icons.stop_circle_outlined,
                  value: time12h(now.add(Duration(minutes: _minutes))),
                  label: 'Cierre del registro',
                ),
              ],
            ),
            if (widget.enrolled == 0) ...[
              const SizedBox(height: 12),
              const Text(
                'La clase no tiene estudiantes matriculados, así que nadie '
                'podrá registrarse. Edita la clase para cargar la lista.',
                style: TextStyle(fontSize: 12.5, color: AppColors.required),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Iniciar sesión de asistencia',
              icon: Icons.sensors,
              iconOnLeft: true,
              onPressed: () => Navigator.pop(context, _minutes),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
