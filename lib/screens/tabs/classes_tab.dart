import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/academic_snapshot.dart';
import '../../models/course.dart';
import '../../widgets/app_card.dart';
import '../../widgets/percent_ring.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

enum _ClassFilter { all, active, bySchedule }

/// Pestaña "Mis Clases": asignaturas del periodo actual.
class ClassesTab extends StatefulWidget {
  const ClassesTab({
    super.key,
    required this.state,
    required this.onRegister,
    required this.onOpenCourse,
    this.now,
  });

  final AcademicState state;
  final ValueChanged<Course> onRegister;
  final ValueChanged<Course> onOpenCourse;
  final DateTime? now;

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  final _search = TextEditingController();
  _ClassFilter _filter = _ClassFilter.all;
  final Set<String> _dismissedSessions = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Course> _visible(AcademicSnapshot data, DateTime now) {
    final q = _search.text.trim().toLowerCase();
    var list = data.currentCourses.where((c) {
      if (q.isEmpty) return true;
      return [
        c.name,
        c.teacherName,
        c.room,
        c.building,
        c.group,
      ].any((f) => f.toLowerCase().contains(q));
    }).toList();
    switch (_filter) {
      case _ClassFilter.all:
        break;
      case _ClassFilter.active:
        list = list.where((c) => data.statsFor(c).hasOpenSession).toList();
      case _ClassFilter.bySchedule:
        DateTime key(Course c) {
          final next = AcademicSnapshot(
            courses: [c],
            sessions: const [],
            attendance: const [],
          ).nextClass(now);
          return next?.startsAt ?? DateTime(9999);
        }
        list.sort((a, b) => key(a).compareTo(key(b)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.isLoading) {
      return const LoadingView(message: 'Cargando tus clases…');
    }
    if (state.error != null) return AcademicErrorView(error: state.error!);
    final data = state.data!;
    if (!data.hasCourses) return const NoCoursesView();

    final now = widget.now ?? DateTime.now();
    final current = data.currentCourses;
    final visible = _visible(data, now);
    final banner = data.pendingOpenCourses
        .where(
          (c) => !_dismissedSessions.contains(data.statsFor(c).openSession!.id),
        )
        .toList();
    final activeCount = current
        .where((c) => data.statsFor(c).hasOpenSession)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis Clases',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            StatusChip(
              label: data.isFromCache ? 'Sin conexión' : 'En línea',
              showDot: true,
              background: data.isFromCache
                  ? AppColors.grayChip
                  : AppColors.chip,
              foreground: data.isFromCache ? AppColors.hint : AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, color: AppColors.hint),
            children: [
              TextSpan(text: 'Periodo ${data.currentPeriod ?? '—'} • '),
              TextSpan(
                text: current.length == 1
                    ? '1 asignatura inscrita'
                    : '${current.length} asignaturas inscritas',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (banner.isNotEmpty) ...[
          const SizedBox(height: 16),
          _OpenSessionBanner(
            course: banner.first,
            extra: banner.length - 1,
            onRegister: () => widget.onRegister(banner.first),
            onDismiss: () => setState(
              () => _dismissedSessions.add(
                data.statsFor(banner.first).openSession!.id,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por asignatura, docente o aula…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_search.clear),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Todas (${current.length})',
                icon: Icons.apps,
                selected: _filter == _ClassFilter.all,
                onTap: () => setState(() => _filter = _ClassFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Con sesión activa ($activeCount)',
                icon: Icons.circle,
                iconSize: 9,
                selected: _filter == _ClassFilter.active,
                onTap: () => setState(() => _filter = _ClassFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Por horario',
                icon: Icons.schedule,
                selected: _filter == _ClassFilter.bySchedule,
                onTap: () => setState(() => _filter = _ClassFilter.bySchedule),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _filter == _ClassFilter.active && _search.text.isEmpty
                  ? 'Ninguna asignatura tiene una sesión abierta ahora.'
                  : 'No hay asignaturas que coincidan con la búsqueda.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        for (final c in visible) ...[
          CourseCard(
            course: c,
            data: data,
            now: now,
            onRegister: () => widget.onRegister(c),
            onOpen: () => widget.onOpenCourse(c),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.iconSize = 17,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.hint;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.chip,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: selected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenSessionBanner extends StatelessWidget {
  const _OpenSessionBanner({
    required this.course,
    required this.extra,
    required this.onRegister,
    required this.onDismiss,
  });

  final Course course;
  final int extra;
  final VoidCallback onRegister;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sensors, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const StatusChip(
                          label: 'Sesión abierta ahora',
                          showDot: true,
                          background: Color(0xFF8BE79F),
                          foreground: AppColors.textDark,
                        ),
                        if (course.room.isNotEmpty)
                          Text(
                            course.room,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      extra > 0
                          ? 'El docente abrió la sesión de asistencia '
                                '(+$extra asignatura${extra == 1 ? '' : 's'} más).'
                          : 'El docente abrió la sesión de asistencia.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRegister,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.verified_outlined, size: 20),
                  label: const Text(
                    'Registrar asistencia',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Ocultar aviso',
                onPressed: onDismiss,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una asignatura (Mis Clases).
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.data,
    required this.now,
    required this.onRegister,
    required this.onOpen,
  });

  final Course course;
  final AcademicSnapshot data;
  final DateTime now;
  final VoidCallback onRegister;
  final VoidCallback onOpen;

  Widget? _statusChip(CourseStats stats) {
    if (stats.canRegister) {
      return const StatusChip(
        label: 'Sesión activa ahora',
        showDot: true,
        background: AppColors.chipStrong,
      );
    }
    if (stats.openSessionRecord != null) {
      return const StatusChip(
        label: 'Asistencia registrada',
        icon: Icons.check_circle_outline,
        background: AppColors.chipStrong,
      );
    }
    final minutes = now.hour * 60 + now.minute;
    for (final s in course.schedule) {
      if (s.weekday == now.weekday && minutes < s.startMinutes) {
        return StatusChip(
          label: 'Hoy a las ${s.startLabel}',
          icon: Icons.alarm,
          background: AppColors.dangerSoft,
          foreground: AppColors.danger,
        );
      }
    }
    if (stats.held > 0 && stats.absences == 0) {
      return const StatusChip(label: 'Al día', icon: Icons.verified_outlined);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stats = data.statsFor(course);
    final chip = _statusChip(stats);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stats.hasOpenSession)
              Container(height: 6, color: AppColors.primary),
            Padding(
              padding: const EdgeInsets.all(18),
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
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ?chip,
                                if (course.group.isNotEmpty)
                                  Text(
                                    'Grupo ${course.group}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.hint,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              course.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (course.teacherName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    size: 16,
                                    color: AppColors.hint,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Prof. ${course.teacherName}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: AppColors.hint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      PercentRing(
                        percent: stats.percent,
                        size: 52,
                        strokeWidth: 5,
                        fontSize: 12.5,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    elevated: false,
                    radius: 16,
                    color: AppColors.chip.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoLine(
                          icon: Icons.calendar_today_outlined,
                          text: course.scheduleLabel,
                        ),
                        if (course.location.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.meeting_room_outlined,
                            text: course.location,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _InfoLine(
                          icon: Icons.task_alt,
                          text: stats.held == 0
                              ? 'Aún no hay sesiones registradas'
                              : '${stats.attended} de ${stats.held} '
                                    'asistencias registradas',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (stats.canRegister) ...[
                    FilledButton.icon(
                      onPressed: onRegister,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.how_to_reg_outlined),
                      label: const Text(
                        'Registrar asistencia',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SecondaryButton(
                    label: 'Ver detalle de clase',
                    icon: Icons.arrow_forward,
                    onPressed: onOpen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.bold = false});

  final IconData icon;
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.textDark : AppColors.hint,
            ),
          ),
        ),
      ],
    );
  }
}
