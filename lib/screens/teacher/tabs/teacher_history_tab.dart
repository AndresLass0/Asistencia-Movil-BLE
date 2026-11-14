import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/date_format.dart';
import '../../../models/course_session.dart';
import '../../../models/teacher_snapshot.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../teacher_ui.dart';

const _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Pestaña "Historial" del docente: sesiones realizadas, con filtros por
/// mes y asignatura, planilla de cada sesión y exportación.
class TeacherHistoryTab extends StatefulWidget {
  const TeacherHistoryTab({
    super.key,
    required this.state,
    required this.onOpenSummary,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  final TeacherState state;
  final ValueChanged<CourseSession> onOpenSummary;
  final ValueChanged<SessionReport> onExportPdf;
  final ValueChanged<SessionReport> onExportExcel;

  @override
  State<TeacherHistoryTab> createState() => _TeacherHistoryTabState();
}

class _TeacherHistoryTabState extends State<TeacherHistoryTab> {
  int? _month; // yyyymm
  String? _courseId;
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final data = widget.state.data;
    if (data == null) {
      return widget.state.error != null
          ? AcademicErrorView(error: widget.state.error!)
          : const LoadingView();
    }
    final all = data.heldSessions();
    final months = {
      for (final s in all) s.startsAt.year * 100 + s.startsAt.month,
    }.toList()..sort((a, b) => b.compareTo(a));
    final byMonth = all
        .where(
          (s) =>
              _month == null ||
              s.startsAt.year * 100 + s.startsAt.month == _month,
        )
        .toList();
    final courseIds = {for (final s in byMonth) s.courseId};
    final filtered = byMonth
        .where((s) => _courseId == null || s.courseId == _courseId)
        .toList();
    final reports = [for (final s in filtered) data.reportFor(s)];
    var present = 0, possible = 0;
    final students = <String>{};
    for (final r in reports) {
      present += r.present;
      possible += r.total;
      for (final row in r.rows) {
        students.add('${r.course.id}:${row.student.email}');
      }
    }
    final pct = possible == 0 ? null : (present * 100 / possible).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const Text(
          'Historial de clases',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sesiones de asistencia realizadas, de la más reciente a la más '
          'antigua.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        if (months.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<int?>(
              initialValue: _month,
              onSelected: (m) => setState(() {
                _month = m;
                _courseId = null;
              }),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('Todos los meses'),
                ),
                for (final m in months)
                  PopupMenuItem(
                    value: m,
                    child: Text(
                      '${_monthNames[m % 100 - 1]} ${m ~/ 100} · '
                      '${all.where((s) => s.startsAt.year * 100 + s.startsAt.month == m).length} sesiones',
                    ),
                  ),
              ],
              child: StatusChip(
                label: _month == null
                    ? 'Mes: todos'
                    : 'Mes: ${_monthNames[_month! % 100 - 1]} ${_month! ~/ 100}',
                icon: Icons.calendar_month_outlined,
                background: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 12),
        StatRow(
          children: [
            StatTile(
              icon: Icons.sensors,
              value: '${filtered.length}',
              label: 'Sesiones',
            ),
            StatTile(
              icon: Icons.done_all,
              value: pct == null ? '—' : '$pct%',
              label: 'Asistencia promedio',
            ),
            StatTile(
              icon: Icons.groups_outlined,
              value: '${students.length}',
              label: 'Estudiantes',
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (courseIds.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Todas (${byMonth.length})'),
                  selected: _courseId == null,
                  onSelected: (_) => setState(() => _courseId = null),
                ),
                for (final id in courseIds) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      '${data.courseById(id)?.name ?? 'Asignatura'} '
                      '(${byMonth.where((s) => s.courseId == id).length})',
                    ),
                    selected: _courseId == id,
                    onSelected: (_) => setState(() => _courseId = id),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          const MessageView(
            icon: Icons.history_edu_outlined,
            title: 'Aún no hay sesiones realizadas',
            message:
                'Cuando finalices una sesión de asistencia (o termine su '
                'tiempo de registro) aparecerá aquí.',
          ),
        for (final r in reports) ...[
          _SessionCard(
            report: r,
            expanded: _expanded.contains(r.session.id),
            onToggle: () => setState(() {
              if (!_expanded.remove(r.session.id)) {
                _expanded.add(r.session.id);
              }
            }),
            onOpenSummary: () => widget.onOpenSummary(r.session),
            onPdf: () => widget.onExportPdf(r),
            onExcel: () => widget.onExportExcel(r),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.report,
    required this.expanded,
    required this.onToggle,
    required this.onOpenSummary,
    required this.onPdf,
    required this.onExcel,
  });

  final SessionReport report;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpenSummary;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    final s = report.session;
    final c = report.course;
    final end = s.closedAt ?? s.endsAt;
    final duration = s.duration;
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
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (c.group.isNotEmpty)
                      Text(
                        'Grupo ${c.group}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              StatusChip(
                label: s.statusOpen ? 'Sin finalizar' : 'Cerrada',
                icon: s.statusOpen ? Icons.timer_off_outlined : Icons.lock,
                background: AppColors.grayChip,
                foreground: AppColors.hint,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${shortDate(s.startsAt)} • ${time12h(s.startsAt)}'
                  '${end != null ? ' – ${time12h(end)}' : ''}'
                  '${duration != null ? ' (${minutesLabel(duration.inMinutes)})' : ''}',
                  style: const TextStyle(color: AppColors.hint),
                ),
              ),
            ],
          ),
          if (c.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.location,
                    style: const TextStyle(color: AppColors.hint),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(
                label:
                    '${report.present} / ${report.total} presentes'
                    '${report.percent == null ? '' : ' (${report.percent}%)'}',
                icon: Icons.how_to_reg,
              ),
              if (report.absent > 0)
                StatusChip(
                  label:
                      '${report.absent} ausente${report.absent == 1 ? '' : 's'}',
                  background: AppColors.dangerSoft,
                  foreground: AppColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(expanded ? Icons.expand_less : Icons.visibility),
                  label: Text(
                    expanded ? 'Ocultar planilla' : 'Ver detalle de sesión',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Revisar inasistencias',
                onPressed: onOpenSummary,
                icon: const Icon(Icons.fact_check_outlined),
              ),
            ],
          ),
          if (expanded) ...[
            const Divider(),
            Text(
              'Planilla (${report.total} estudiantes)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final r in [...report.presentRows, ...report.absentRows])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    InitialsAvatar(
                      initials: r.student.initials,
                      color: r.present ? AppColors.primary : AppColors.danger,
                      background: r.present
                          ? AppColors.chip
                          : AppColors.dangerSoft,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            r.student.code.isEmpty
                                ? 'Sin código'
                                : 'Cód. ${r.student.code}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      r.present
                          ? time12h(r.record!.registeredAt)
                          : (r.justification?.status.label ?? 'Ausente'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: r.present ? AppColors.primary : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onExcel,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Excel'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
