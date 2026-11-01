import 'package:flutter/material.dart';

import '../services/student_backend.dart';

import '../core/app_colors.dart';
import '../core/date_format.dart';
import '../models/academic_snapshot.dart';
import '../models/course.dart';
import '../models/course_session.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/incident_dialog.dart';
import '../widgets/percent_ring.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';

/// Detalle de una asignatura: datos, estadísticas y sesiones con su estado.
/// Se actualiza en vivo a partir del estado académico de HomeScreen.
class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.academic,
    required this.uid,
    required this.onRegister,
    this.backend = const FirebaseStudentBackend(),
  });

  final String courseId;
  final ValueNotifier<AcademicState> academic;
  final String uid;
  final StudentBackend backend;

  /// Registrar asistencia (HomeScreen cambia a la pestaña Asistencia).
  final ValueChanged<Course> onRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Detalle de clase'),
      body: ValueListenableBuilder<AcademicState>(
        valueListenable: academic,
        builder: (context, state, _) {
          if (state.isLoading) return const LoadingView();
          if (state.error != null) {
            return AcademicErrorView(error: state.error!);
          }
          final data = state.data!;
          final course = data.courseById(courseId);
          if (course == null) {
            return const MessageView(
              icon: Icons.search_off,
              title: 'Asignatura no disponible',
              message:
                  'Ya no estás matriculado en esta asignatura o fue '
                  'eliminada.',
            );
          }
          return _Body(
            course: course,
            data: data,
            onRegister: () {
              Navigator.pop(context);
              onRegister(course);
            },
            onReport: () => showIncidentDialog(
              context,
              uid: uid,
              course: course,
              backend: backend,
              sessionId: data.statsFor(course).openSession?.id,
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.course,
    required this.data,
    required this.onRegister,
    required this.onReport,
  });

  final Course course;
  final AcademicSnapshot data;
  final VoidCallback onRegister;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final stats = data.statsFor(course);
    final sessions = data.sessionsFor(course.id);
    final max = course.maxAbsences;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        AppCard(
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
                          [
                            if (course.period.isNotEmpty)
                              'Periodo ${course.period}',
                            if (course.group.isNotEmpty)
                              'Grupo ${course.group}',
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (course.teacherName.isNotEmpty)
                          Text(
                            'Prof. ${course.teacherName}',
                            style: const TextStyle(color: AppColors.hint),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PercentRing(percent: stats.percent, size: 72, strokeWidth: 7),
                ],
              ),
              const SizedBox(height: 14),
              _Line(
                icon: Icons.calendar_today_outlined,
                text: course.scheduleLabel,
              ),
              if (course.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Line(icon: Icons.location_on_outlined, text: course.location),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Stat(label: 'Asistidas', value: '${stats.attended}'),
            const SizedBox(width: 10),
            _Stat(label: 'Faltas', value: '${stats.absences}', danger: true),
            const SizedBox(width: 10),
            _Stat(
              label: max == null ? 'Sesiones' : 'Margen',
              value: max == null
                  ? '${stats.held}'
                  : '${(max - stats.absences).clamp(0, max)} de $max',
            ),
          ],
        ),
        if (stats.canRegister) ...[
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Registrar asistencia',
            icon: Icons.sensors,
            iconOnLeft: true,
            onPressed: onRegister,
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'Sesiones',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          const Text(
            'El docente aún no ha registrado sesiones.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final s in sessions) ...[
          _SessionTile(session: s, data: data),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.support_agent, color: AppColors.hint),
            label: const Text(
              'Reportar incidencia al docente',
              style: TextStyle(
                color: AppColors.hint,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.data});

  final CourseSession session;
  final AcademicSnapshot data;

  @override
  Widget build(BuildContext context) {
    final record = data.recordForSession(session.id);
    final Widget chip;
    if (record != null) {
      chip = StatusChip(
        label: 'Presente · ${time12h(record.registeredAt)}',
        icon: Icons.check_circle_outline,
        background: AppColors.chipStrong,
      );
    } else if (session.isOpen) {
      chip = const StatusChip(
        label: 'Abierta',
        showDot: true,
        background: AppColors.chip,
      );
    } else {
      chip = const StatusChip(
        label: 'Ausente',
        icon: Icons.cancel_outlined,
        background: AppColors.dangerSoft,
        foreground: AppColors.danger,
      );
    }
    return AppCard(
      elevated: false,
      radius: 18,
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.event_note_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortDate(session.startsAt),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Inicio: ${time12h(session.startsAt)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          chip,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.danger = false});

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.chip.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: danger ? AppColors.danger : AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
            style: const TextStyle(fontSize: 13.5, color: AppColors.hint),
          ),
        ),
      ],
    );
  }
}
