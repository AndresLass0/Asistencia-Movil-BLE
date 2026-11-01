import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/date_format.dart';
import '../../models/academic_snapshot.dart';
import '../../models/course.dart';
import '../../models/user_profile.dart';
import '../../widgets/app_card.dart';
import '../../widgets/percent_ring.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

/// Pestaña "Inicio" del estudiante, con datos reales de Firestore.
class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.firstName,
    required this.state,
    required this.onRegisterAttendance,
    required this.onOpenCourse,
    this.settings = const UserSettings(),
    this.now,
  });

  final String firstName;
  final AcademicState state;

  /// Registrar asistencia; [Course] null = elegir automáticamente.
  final ValueChanged<Course?> onRegisterAttendance;
  final ValueChanged<Course> onOpenCourse;
  final UserSettings settings;

  /// Hora de referencia (inyectable en pruebas).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final data = state.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, $firstName 👋',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            longDate(now),
            style: const TextStyle(fontSize: 14, color: AppColors.hint),
          ),
          const SizedBox(height: 18),
          _HeroCard(onRegister: () => onRegisterAttendance(null)),
          const SizedBox(height: 18),
          if (state.isLoading)
            const SizedBox(height: 200, child: LoadingView())
          else if (state.error != null)
            AcademicErrorView(error: state.error!)
          else if (!data!.hasCourses)
            const AppCard(child: NoCoursesView())
          else ...[
            if (settings.riskAlerts) ..._riskCards(data),
            _TodayClassesCard(
              data: data,
              now: now,
              onRegister: onRegisterAttendance,
              onOpenCourse: onOpenCourse,
            ),
            const SizedBox(height: 18),
            _SummaryCard(data: data),
            const SizedBox(height: 18),
            _NextClassCard(data: data, now: now, onOpenCourse: onOpenCourse),
          ],
        ],
      ),
    );
  }

  /// Alertas para asignaturas con margen de faltas definido y ≤ 1 restante.
  List<Widget> _riskCards(AcademicSnapshot data) {
    final cards = <Widget>[];
    for (final c in data.currentCourses) {
      final max = c.maxAbsences;
      if (max == null) continue;
      final remaining = max - data.statsFor(c).absences;
      if (remaining > 1) continue;
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: AppCard(
            elevated: false,
            color: AppColors.dangerSoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    remaining <= 0
                        ? '${c.name}: alcanzaste el máximo de $max faltas '
                              'definido para la asignatura.'
                        : '${c.name}: te queda 1 falta del máximo de $max.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return cards;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD7F3DD), Color(0xFFE6F7EA)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -40, top: -40, child: _circle(150, 0.08)),
            Positioned(right: 10, top: 6, child: _circle(78, 0.1)),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StatusChip(label: 'RESONANCIA DE AULA'),
                  const SizedBox(height: 14),
                  const Text(
                    '¿Estás en el aula?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Registra tu asistencia en la sesión abierta '
                    'por tu docente.',
                    style: TextStyle(fontSize: 15, color: AppColors.hint),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Registrar asistencia',
                    icon: Icons.sensors,
                    iconOnLeft: true,
                    onPressed: onRegister,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primary.withValues(alpha: alpha),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.icon, this.chip});

  final String title;
  final IconData? icon;
  final Widget? chip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        if (chip != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: chip!,
          ),
      ],
    );
  }
}

class _TodayClassesCard extends StatelessWidget {
  const _TodayClassesCard({
    required this.data,
    required this.now,
    required this.onRegister,
    required this.onOpenCourse,
  });

  final AcademicSnapshot data;
  final DateTime now;
  final ValueChanged<Course?> onRegister;
  final ValueChanged<Course> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    final today = data.todayClasses(now);
    final count = today.map((t) => t.course.id).toSet().length;
    return AppCard(
      child: Column(
        children: [
          _SectionTitle(
            title: 'Mis clases de hoy',
            icon: Icons.calendar_today_outlined,
            chip: StatusChip(
              label: count == 1 ? '1 asignatura' : '$count asignaturas',
              background: AppColors.grayChip,
            ),
          ),
          const SizedBox(height: 14),
          if (today.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tienes clases programadas para hoy.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final t in today) ...[
            _TodayClassTile(
              item: t,
              data: data,
              now: now,
              onRegister: onRegister,
              onOpen: () => onOpenCourse(t.course),
            ),
            if (t != today.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TodayClassTile extends StatelessWidget {
  const _TodayClassTile({
    required this.item,
    required this.data,
    required this.now,
    required this.onRegister,
    required this.onOpen,
  });

  final TodayClass item;
  final AcademicSnapshot data;
  final DateTime now;
  final ValueChanged<Course?> onRegister;
  final VoidCallback onOpen;

  /// Asistencia de una sesión de esta asignatura que empezó hoy.
  ({bool hasSession, bool attended}) _todayAttendance() {
    for (final s in data.sessionsFor(item.course.id)) {
      final d = s.startsAt;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        return (
          hasSession: true,
          attended: data.recordForSession(s.id) != null,
        );
      }
    }
    return (hasSession: false, attended: false);
  }

  @override
  Widget build(BuildContext context) {
    final course = item.course;
    final stats = data.statsFor(course);
    final active = stats.hasOpenSession;
    final today = _todayAttendance();

    final Widget chip;
    if (active && stats.canRegister) {
      chip = const StatusChip(
        label: 'Sesión abierta',
        showDot: true,
        background: AppColors.chipStrong,
      );
    } else if (today.attended) {
      chip = const StatusChip(
        label: 'Presente',
        icon: Icons.check_circle_outline,
        background: AppColors.chipStrong,
      );
    } else if (item.status == ClassTimeStatus.inProgress) {
      chip = const StatusChip(
        label: 'En horario',
        showDot: true,
        background: AppColors.chip,
      );
    } else if (item.status == ClassTimeStatus.upcoming) {
      chip = StatusChip(
        label: 'Hoy a las ${item.schedule.startLabel}',
        icon: Icons.schedule,
        background: AppColors.grayChip,
        foreground: AppColors.hint,
      );
    } else {
      chip = StatusChip(
        label: today.hasSession ? 'Sin registro' : 'Finalizada',
        background: AppColors.grayChip,
        foreground: AppColors.hint,
      );
    }

    final highlighted = active || item.status == ClassTimeStatus.inProgress;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: AppCard(
          elevated: false,
          radius: 18,
          color: AppColors.chip.withValues(alpha: highlighted ? 0.5 : 0.35),
          borderColor: highlighted
              ? AppColors.primary.withValues(alpha: 0.25)
              : null,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 17,
                        color: AppColors.hint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.schedule.timeRange,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  chip,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: highlighted ? 21 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (course.teacherName.isNotEmpty)
                    'Prof. ${course.teacherName}',
                  if (course.location.isNotEmpty) course.location,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.hint),
              ),
              if (stats.canRegister) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.sensors,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'El docente abrió la sesión',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => onRegister(course),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.sensors, size: 18),
                      label: const Text(
                        'Registrar\nasistencia',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final AcademicSnapshot data;

  @override
  Widget build(BuildContext context) {
    final period = data.currentPeriod;
    final summary = data.summaryFor(data.currentCourses);
    return AppCard(
      child: Column(
        children: [
          _SectionTitle(
            title: 'Resumen de asistencia',
            chip: period == null
                ? null
                : StatusChip(
                    label: 'Periodo $period',
                    background: AppColors.grayChip,
                  ),
          ),
          const SizedBox(height: 14),
          AppCard(
            elevated: false,
            radius: 20,
            color: AppColors.chip.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                PercentRing(percent: summary.percent, caption: 'GLOBAL'),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Asistencia del periodo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.held == 0
                            ? 'Aún no hay sesiones registradas en este periodo.'
                            : 'Has asistido a ${summary.attended} de '
                                  '${summary.held} clases del periodo.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.hint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                icon: Icons.check_circle_outline,
                color: AppColors.primary,
                value: summary.attended,
                label: 'Asistencias',
              ),
              const SizedBox(width: 10),
              _StatTile(
                icon: Icons.cancel_outlined,
                color: AppColors.danger,
                value: summary.absences,
                label: 'Ausencias',
              ),
              const SizedBox(width: 10),
              _StatTile(
                icon: Icons.event_available_outlined,
                color: AppColors.hint,
                value: summary.held,
                label: 'Total clases',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.chip.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({
    required this.data,
    required this.now,
    required this.onOpenCourse,
  });

  final AcademicSnapshot data;
  final DateTime now;
  final ValueChanged<Course> onOpenCourse;

  String _dayLabel(DateTime start) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return longDate(start).split(',').first;
  }

  @override
  Widget build(BuildContext context) {
    final next = data.nextClass(now);
    return AppCard(
      child: Column(
        children: [
          _SectionTitle(
            title: 'Siguiente clase',
            chip: next == null
                ? null
                : StatusChip(
                    label: _dayLabel(next.startsAt),
                    background: AppColors.grayChip,
                    foreground: AppColors.hint,
                  ),
          ),
          const SizedBox(height: 14),
          if (next == null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tus asignaturas no tienen horario registrado.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            Material(
              color: AppColors.chip.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onOpenCourse(next.course),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              next.course.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 15,
                                  color: AppColors.hint,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    [
                                      next.schedule.startLabel,
                                      if (next.course.room.isNotEmpty)
                                        next.course.room,
                                    ].join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.hint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Ver detalle de la asignatura',
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AppColors.grayChip,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
