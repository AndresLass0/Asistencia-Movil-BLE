import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/ui_messages.dart';
import '../../models/academic_snapshot.dart';
import '../../models/course.dart';
import '../../widgets/app_card.dart';
import '../../widgets/percent_ring.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

/// Genera y comparte el PDF del historial (inyectable en pruebas).
typedef ExportHistory = Future<void> Function();

/// Pestaña "Historial": progreso académico por periodo, con datos reales.
class HistoryTab extends StatefulWidget {
  const HistoryTab({
    super.key,
    required this.state,
    required this.onOpenCourse,
    this.onExport,
  });

  final AcademicState state;
  final ValueChanged<Course> onOpenCourse;

  /// null = botón de PDF deshabilitado.
  final ExportHistory? onExport;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _period;
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await widget.onExport!();
    } catch (_) {
      if (mounted) showAppMessage(context, 'No se pudo generar el PDF.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.isLoading) {
      return const LoadingView(message: 'Cargando tu historial…');
    }
    if (state.error != null) return AcademicErrorView(error: state.error!);
    final data = state.data!;
    if (!data.hasCourses) return const NoCoursesView();

    final periods = data.periods;
    final period = periods.contains(_period) ? _period! : periods.first;
    final isCurrent = period == data.currentPeriod;
    final courses = data.coursesInPeriod(period);
    final periodSummary = data.summaryFor(courses);
    final overall = data.overall;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            label: 'Historial y progreso académico',
            icon: Icons.school,
            background: AppColors.chip,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mi progreso académico',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Estadísticas acumuladas organizadas por periodo académico.',
          style: TextStyle(fontSize: 15, color: AppColors.hint),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(20),
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
                          'PROMEDIO GENERAL HISTÓRICO',
                          style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.6,
                            color: AppColors.hint,
                          ),
                        ),
                        Text(
                          overall.percent == null ? '—' : '${overall.percent}%',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PercentRing(
                    percent: overall.percent,
                    size: 84,
                    strokeWidth: 10,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatusChip(
                label: periods.length == 1
                    ? '1 periodo registrado'
                    : '${periods.length} periodos registrados',
                showDot: true,
                background: AppColors.chip,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Tile(
                    icon: Icons.calendar_month_outlined,
                    value: overall.held,
                    label: 'Clases totales',
                  ),
                  const SizedBox(width: 10),
                  _Tile(
                    icon: Icons.how_to_reg_outlined,
                    value: overall.attended,
                    label: 'Asistidas',
                  ),
                  const SizedBox(width: 10),
                  _Tile(
                    icon: Icons.event_busy_outlined,
                    value: overall.absences,
                    label: 'Inasistencias',
                    danger: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Icon(Icons.tune, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Periodo académico',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            if (isCurrent)
              const StatusChip(
                label: 'En curso',
                background: Color(0xFF8BE79F),
                foreground: AppColors.textDark,
              ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in periods) ...[
                ChoiceChip(
                  label: Text(p == data.currentPeriod ? '$p (actual)' : p),
                  selected: p == period,
                  onSelected: (_) => setState(() => _period = p),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p == period ? Colors.white : AppColors.hint,
                  ),
                  showCheckmark: false,
                  backgroundColor: AppColors.chip,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.circle, size: 10, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PERIODO $period${isCurrent ? ' (EN CURSO)' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.primary,
                ),
              ),
            ),
            Text(
              periodSummary.percent == null
                  ? 'Promedio: —'
                  : 'Promedio: ${periodSummary.percent}%',
              style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final c in courses) ...[
          _CourseProgressCard(
            course: c,
            stats: data.statsFor(c),
            onTap: () => widget.onOpenCourse(c),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'Descargar historial académico (PDF)',
          icon: Icons.download,
          iconOnLeft: true,
          isLoading: _exporting,
          onPressed: widget.onExport == null ? null : _export,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.value,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.chip.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: danger ? AppColors.danger : AppColors.textDark,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({
    required this.course,
    required this.stats,
    required this.onTap,
  });

  final Course course;
  final CourseStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = stats.percent;
    final max = course.maxAbsences;
    final remaining = max == null ? null : max - stats.absences;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (course.location.isNotEmpty)
                          Text(
                            course.location,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.hint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        percent == null ? '—' : '$percent%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${stats.attended} / ${stats.held}\nasistidas',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.hint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (percent ?? 0) / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.barEmpty,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats.absences == 0
                            ? Icons.check_circle
                            : Icons.cancel_outlined,
                        size: 18,
                        color: stats.absences == 0
                            ? AppColors.primary
                            : (remaining != null && remaining <= 0
                                  ? AppColors.danger
                                  : AppColors.hint),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stats.absences == 0
                            ? 'Sin inasistencias'
                            : stats.absences == 1
                            ? '1 falta registrada'
                            : '${stats.absences} faltas registradas',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  if (remaining != null)
                    StatusChip(
                      label: remaining <= 0
                          ? 'Sin margen de faltas'
                          : remaining == 1
                          ? 'Margen: 1 restante'
                          : 'Margen: $remaining permitidas',
                      icon: remaining <= 1
                          ? Icons.warning_amber_rounded
                          : Icons.shield_outlined,
                      background: remaining <= 1
                          ? AppColors.dangerSoft
                          : AppColors.grayChip,
                      foreground: remaining <= 1
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
