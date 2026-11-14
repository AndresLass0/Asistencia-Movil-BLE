import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/date_format.dart';
import '../../../models/teacher_snapshot.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/percent_ring.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../teacher_ui.dart';

const _shortMonths = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Pestaña "Reportes" del docente: métricas por periodo, asistencia
/// mensual, resumen por asignatura, estudiantes en riesgo, incidencias y
/// exportación del consolidado.
class TeacherReportsTab extends StatefulWidget {
  const TeacherReportsTab({
    super.key,
    required this.state,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  final TeacherState state;
  final ValueChanged<String?> onExportPdf;
  final ValueChanged<String?> onExportExcel;

  @override
  State<TeacherReportsTab> createState() => _TeacherReportsTabState();
}

class _TeacherReportsTabState extends State<TeacherReportsTab> {
  /// Periodo elegido; null hasta que el usuario elija (= el actual).
  String? _period;
  bool _all = false;
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final data = widget.state.data;
    if (data == null) {
      return widget.state.error != null
          ? AcademicErrorView(error: widget.state.error!)
          : const LoadingView();
    }
    if (!data.hasCourses) {
      return const MessageView(
        icon: Icons.analytics_outlined,
        title: 'Sin datos para reportar',
        message:
            'Crea una clase y realiza sesiones de asistencia para ver '
            'los reportes.',
      );
    }
    final period = _all
        ? null
        : (_period != null && data.periods.contains(_period)
              ? _period
              : data.currentPeriod);
    final sum = data.summary(period);
    final months = data.monthly(period);
    final courses = data.coursesInPeriod(period);
    final reports = [for (final c in courses) data.reportForCourse(c)];
    final risks = [for (final r in reports) ...r.atRisk]
      ..sort((a, b) => (a.remaining ?? 0).compareTo(b.remaining ?? 0));
    final incidents = data.incidentsIn(period);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const Text(
          'Reportes de asistencia',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: period,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Periodo académico',
            prefixIcon: const Icon(Icons.calendar_month_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: [
            for (final p in data.periods)
              DropdownMenuItem(
                value: p,
                child: Text(
                  p == data.currentPeriod
                      ? 'Periodo $p (actual)'
                      : 'Periodo $p',
                ),
              ),
            const DropdownMenuItem(
              value: null,
              child: Text('Todos los periodos'),
            ),
          ],
          onChanged: (v) => setState(() {
            _all = v == null;
            _period = v;
          }),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RESUMEN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sum.percent == null ? '—' : '${sum.percent}%',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'Asistencia promedio de las sesiones realizadas',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  PercentRing(percent: sum.percent, size: 84),
                ],
              ),
              const SizedBox(height: 14),
              StatRow(
                children: [
                  StatTile(
                    icon: Icons.groups_outlined,
                    value: '${sum.students}',
                    label: 'Estudiantes en ${sum.courses} grupos',
                  ),
                  StatTile(
                    icon: Icons.sensors,
                    value: '${sum.heldSessions}',
                    label: 'Sesiones realizadas',
                  ),
                  StatTile(
                    icon: Icons.warning_amber_rounded,
                    value: '${sum.atRisk}',
                    label: 'En riesgo',
                    color: sum.atRisk > 0
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeader(
          icon: Icons.ssid_chart,
          title: 'Asistencia por mes',
        ),
        AppCard(
          child: months.isEmpty
              ? const Text(
                  'Aún no hay sesiones realizadas en este periodo.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : _MonthlyBars(months: months),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          icon: Icons.school_outlined,
          title: 'Asignaturas (${courses.length})',
        ),
        for (final r in reports) ...[
          _CourseReportCard(
            report: r,
            expanded: _expanded.contains(r.course.id),
            onToggle: () => setState(() {
              if (!_expanded.remove(r.course.id)) _expanded.add(r.course.id);
            }),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const SectionHeader(
          icon: Icons.report_problem_outlined,
          title: 'Alerta temprana',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estudiantes a los que les queda 1 falta o menos, en las '
                'asignaturas que tienen definidas las faltas permitidas.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              if (risks.isEmpty)
                const Text('No hay estudiantes en riesgo.')
              else
                for (final st in risks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: InitialsAvatar(
                      initials: st.student.initials,
                      color: AppColors.danger,
                      background: AppColors.dangerSoft,
                    ),
                    title: Text(st.student.name),
                    subtitle: Text(
                      '${st.course.name}'
                      '${st.course.group.isEmpty ? '' : ' (G${st.course.group})'}'
                      ' • ${st.absences} ${st.absences == 1 ? 'falta' : 'faltas'}'
                      ' de ${st.course.maxAbsences} permitidas',
                    ),
                    trailing: Text(
                      st.percent == null ? '—' : '${st.percent}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          icon: Icons.support_agent,
          title: 'Incidencias reportadas (${incidents.length})',
        ),
        AppCard(
          child: incidents.isEmpty
              ? const Text(
                  'Los estudiantes no han reportado incidencias.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final i in incidents.take(20))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data.studentName(i.courseId, i.email)} · '
                              '${data.courseById(i.courseId)?.name ?? 'Asignatura'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${shortDate(i.createdAt)}, ${time12h(i.createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(i.message),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        const SectionHeader(icon: Icons.download, title: 'Exportar'),
        PrimaryButton(
          label: 'Consolidado (Excel)',
          icon: Icons.table_view,
          iconOnLeft: true,
          onPressed: () => widget.onExportExcel(period),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Reporte en PDF',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: () => widget.onExportPdf(period),
        ),
        const SizedBox(height: 8),
        const Text(
          'Los reportes se generan con los registros de la app. No '
          'reemplazan las certificaciones oficiales de la universidad.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.months});

  final List<MonthlyAttendance> months;

  @override
  Widget build(BuildContext context) {
    const maxHeight = 120.0;
    final shown = months.length > 6
        ? months.sublist(months.length - 6)
        : months;
    return SizedBox(
      height: maxHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in shown)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      m.percent == null ? '—' : '${m.percent}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxHeight * (m.percent ?? 0) / 100 + 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shortMonths[m.month - 1],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseReportCard extends StatelessWidget {
  const _CourseReportCard({
    required this.report,
    required this.expanded,
    required this.onToggle,
  });

  final CourseReport report;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = report.course;
    final avg = report.averagePresent;
    final risk = report.atRisk.length;
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
                      children: [
                        if (c.group.isNotEmpty)
                          StatusChip(label: 'G${c.group}'),
                        if (c.code.isNotEmpty)
                          StatusChip(
                            label: 'Cód. ${c.code}',
                            background: AppColors.grayChip,
                            foreground: AppColors.hint,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${report.enrolled} estudiantes · ${c.scheduleLabel}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                report.percent == null ? '—' : '${report.percent}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatRow(
            children: [
              StatTile(
                icon: Icons.verified_user_outlined,
                value: avg == null
                    ? '—'
                    : '${avg.toStringAsFixed(avg % 1 == 0 ? 0 : 1)} / '
                          '${report.enrolled}',
                label: 'Presentes por sesión',
              ),
              StatTile(
                icon: Icons.notification_important_outlined,
                value: c.maxAbsences == null ? '—' : '$risk',
                label: c.maxAbsences == null
                    ? 'Sin faltas definidas'
                    : 'En riesgo',
                color: risk > 0 ? AppColors.danger : AppColors.primary,
              ),
            ],
          ),
          if (report.standings.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.expand_less : Icons.group_outlined),
              label: Text(expanded ? 'Ocultar estudiantes' : 'Ver estudiantes'),
            ),
          ],
          if (expanded)
            for (final st in report.standings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        st.student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${st.attended}/${st.held} · '
                      '${st.percent == null ? '—' : '${st.percent}%'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: st.atRisk ? AppColors.danger : AppColors.hint,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
