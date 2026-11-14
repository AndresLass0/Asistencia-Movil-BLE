import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/date_format.dart';
import '../../models/attendance_record.dart';
import '../../models/course_session.dart';
import '../../models/teacher_snapshot.dart';
import '../../services/teacher_backend.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import 'teacher_ui.dart';

/// Sesión de asistencia en curso: cuenta atrás, presentes y pendientes en
/// vivo, registro manual de excepciones y botón para finalizar.
///
/// Se actualiza con el [state] compartido por TeacherHomeScreen. Al
/// finalizar llama a [onFinished] (que muestra el resumen).
class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.state,
    required this.backend,
    required this.onFinished,
  });

  final String sessionId;
  final ValueNotifier<TeacherState> state;
  final TeacherBackend backend;
  final ValueChanged<CourseSession> onFinished;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  Timer? _ticker;
  String _query = '';
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Refresca la cuenta atrás cada segundo.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _finish(SessionReport report) async {
    final ok = await confirmAction(
      context,
      title: '¿Finalizar asistencia?',
      message:
          'Se cerrará el registro con ${report.present} de ${report.total} '
          'estudiantes presentes. Después podrás revisar las inasistencias.',
      confirmLabel: 'Finalizar',
    );
    if (!ok || !mounted) return;
    setState(() => _closing = true);
    final done = await runTeacherAction(
      context,
      () => widget.backend.closeSession(report.session.id),
    );
    if (!mounted) return;
    setState(() => _closing = false);
    if (done) widget.onFinished(report.session);
  }

  Future<void> _markPresent(CourseSession session, AttendanceRow row) async {
    final ok = await confirmAction(
      context,
      title: 'Registrar asistencia manual',
      message:
          '¿Registrar a ${row.student.name} como presente? Quedará marcada '
          'como excepción del docente.',
      confirmLabel: 'Registrar',
    );
    if (!ok || !mounted) return;
    await runTeacherAction(
      context,
      () => widget.backend.markManualAttendance(session, row.student.uid!),
      done: '${row.student.name} registrado como presente.',
    );
  }

  bool _matches(AttendanceRow r) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return r.student.name.toLowerCase().contains(q) ||
        r.student.code.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Asistencia activa'),
      body: ValueListenableBuilder<TeacherState>(
        valueListenable: widget.state,
        builder: (context, state, _) {
          final data = state.data;
          if (data == null) {
            return state.error != null
                ? AcademicErrorView(error: state.error!)
                : const LoadingView();
          }
          final session = data.sessionById(widget.sessionId);
          if (session == null) {
            return const MessageView(
              icon: Icons.search_off,
              title: 'Sesión no encontrada',
              message: 'Es posible que se haya eliminado la asignatura.',
            );
          }
          return _body(data.reportFor(session));
        },
      ),
    );
  }

  Widget _body(SessionReport report) {
    final s = report.session;
    final now = DateTime.now();
    final open = s.isOpenAt(now);
    final remaining = s.endsAt?.difference(now);
    final present = report.presentRows.where(_matches).toList();
    final pending = report.absentRows.where(_matches).toList();
    final course = report.course;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        AppCard(
          color: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                !s.statusOpen
                    ? 'SESIÓN FINALIZADA'
                    : open
                    ? 'REGISTRO ABIERTO'
                    : 'TIEMPO DE REGISTRO CUMPLIDO',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${course.name}${course.group.isEmpty ? '' : ' (G${course.group})'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (remaining != null && s.statusOpen)
                    StatusChip(
                      label: open
                          ? '${countdownLabel(remaining)} restantes'
                          : 'Registro cerrado',
                      icon: open ? Icons.timer_outlined : Icons.timer_off,
                      background: Colors.white,
                    ),
                  StatusChip(
                    label: 'Inició ${time12h(s.startsAt)}',
                    icon: Icons.schedule,
                    background: Colors.white24,
                    foreground: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course.location.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(course.location)),
                  ],
                ),
              if (course.location.isNotEmpty) const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sensors, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los estudiantes matriculados registran su asistencia '
                        'desde la app mientras el registro esté abierto. La '
                        'verificación por proximidad (Bluetooth) aún no está '
                        'disponible.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.hint),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.how_to_reg, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Asistencia registrada: ${report.present} / '
                      '${report.total}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    report.percent == null ? '—' : '${report.percent}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: report.total == 0 ? 0 : report.present / report.total,
                  minHeight: 8,
                  backgroundColor: AppColors.barEmpty,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Listado de estudiantes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            StatusChip(label: '${report.total} en total'),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o código…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _GroupTitle(
          icon: Icons.check_circle,
          label: 'Presentes (${report.present})',
          color: AppColors.primary,
        ),
        if (present.isEmpty)
          const _Empty(text: 'Aún no hay asistencias registradas.'),
        for (final r in present)
          _StudentTile(
            row: r,
            subtitle:
                '${time12h(r.record!.registeredAt)}'
                '${r.record!.method == AttendanceMethod.manual ? ' • Registro manual' : ' • Desde la app'}',
            trailing: const StatusChip(label: 'Presente', icon: Icons.verified),
          ),
        const SizedBox(height: 12),
        _GroupTitle(
          icon: Icons.schedule,
          label: 'Pendientes (${report.absent})',
          color: AppColors.hint,
        ),
        if (pending.isEmpty)
          const _Empty(text: 'No hay estudiantes pendientes.'),
        for (final r in pending)
          _StudentTile(
            row: r,
            muted: true,
            subtitle: r.linked
                ? 'Aún no registra su asistencia'
                : 'Sin cuenta en BioAsistencia',
            trailing: r.linked && s.statusOpen
                ? TextButton(
                    onPressed: () => _markPresent(s, r),
                    child: const Text('Marcar presente'),
                  )
                : null,
          ),
        const SizedBox(height: 20),
        if (s.statusOpen)
          PrimaryButton(
            label: 'Finalizar asistencia',
            icon: Icons.stop_circle_outlined,
            iconOnLeft: true,
            isLoading: _closing,
            onPressed: () => _finish(report),
          )
        else
          PrimaryButton(
            label: 'Ver resumen de la sesión',
            icon: Icons.fact_check_outlined,
            iconOnLeft: true,
            onPressed: () => widget.onFinished(s),
          ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.row,
    required this.subtitle,
    this.trailing,
    this.muted = false,
  });

  final AttendanceRow row;
  final String subtitle;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        radius: 16,
        elevated: false,
        child: Row(
          children: [
            InitialsAvatar(
              initials: row.student.initials,
              color: muted ? AppColors.hint : AppColors.primary,
              background: muted ? AppColors.grayChip : AppColors.chip,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ),
    );
  }
}
