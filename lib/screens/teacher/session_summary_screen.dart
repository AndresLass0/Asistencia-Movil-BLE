import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/date_format.dart';
import '../../core/ui_messages.dart';
import '../../models/course_session.dart';
import '../../models/justification.dart';
import '../../models/teacher_snapshot.dart';
import '../../services/report_service.dart';
import '../../services/teacher_backend.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import 'teacher_ui.dart';

/// Resumen de una sesión: totales, revisión de inasistencias (justificar o
/// confirmar) y descarga de la planilla. Sirve al finalizar la sesión y
/// desde el historial.
///
/// Devuelve `true` con `Navigator.pop` si el docente pide ver el historial.
class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({
    super.key,
    required this.sessionId,
    required this.state,
    required this.backend,
    required this.teacherName,
    this.justFinished = false,
  });

  final String sessionId;
  final ValueNotifier<TeacherState> state;
  final TeacherBackend backend;
  final String teacherName;

  /// Se abrió justo después de finalizar la sesión.
  final bool justFinished;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Resumen de asistencia'),
      body: ValueListenableBuilder<TeacherState>(
        valueListenable: state,
        builder: (context, state, _) {
          final data = state.data;
          if (data == null) {
            return state.error != null
                ? AcademicErrorView(error: state.error!)
                : const LoadingView();
          }
          final session = data.sessionById(sessionId);
          if (session == null) {
            return const MessageView(
              icon: Icons.search_off,
              title: 'Sesión no encontrada',
              message: 'Es posible que se haya eliminado la asignatura.',
            );
          }
          return _SummaryBody(
            report: data.reportFor(session),
            backend: backend,
            teacherName: teacherName,
            justFinished: justFinished,
          );
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.report,
    required this.backend,
    required this.teacherName,
    required this.justFinished,
  });

  final SessionReport report;
  final TeacherBackend backend;
  final String teacherName;
  final bool justFinished;

  Future<void> _pdf(BuildContext context) async {
    await runTeacherAction(context, () async {
      final bytes = await ReportService.buildSessionPdf(
        report: report,
        teacherName: teacherName,
      );
      await ReportService.sharePdf(
        bytes,
        ReportService.sessionFileName(report, 'pdf'),
      );
    });
  }

  Future<void> _excel(BuildContext context) async {
    try {
      final saved = await ReportService.saveXlsx(
        ReportService.buildSessionXlsx(report),
        ReportService.sessionFileName(report, 'xlsx'),
      );
      if (saved && context.mounted) {
        showAppMessage(context, 'Planilla guardada.');
      }
    } catch (_) {
      if (context.mounted) {
        showAppMessage(context, 'No se pudo guardar la planilla.');
      }
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    CourseSession session,
    AttendanceRow row,
    AbsenceStatus status,
  ) => runTeacherAction(
    context,
    () => backend.setAbsenceStatus(session, row.student.email, status),
    done: status == AbsenceStatus.justified
        ? 'Inasistencia de ${row.student.name} justificada.'
        : 'Falta de ${row.student.name} confirmada.',
  );

  @override
  Widget build(BuildContext context) {
    final s = report.session;
    final c = report.course;
    final closed = !s.statusOpen;
    final end = s.closedAt ?? s.endsAt;
    final absent = report.absentRows;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Center(
          child: StatusChip(
            label: closed
                ? (justFinished
                      ? 'Sesión finalizada con éxito'
                      : 'Sesión finalizada')
                : 'Sesión en curso',
            icon: closed ? Icons.task_alt : Icons.sensors,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Resumen de asistencia',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          closed
              ? 'El registro está cerrado. Los datos se guardaron en '
                    'BioAsistencia.'
              : 'El registro sigue abierto; los totales pueden cambiar.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                [
                  if (c.group.isNotEmpty) 'Grupo ${c.group}',
                  if (c.period.isNotEmpty) 'Periodo ${c.period}',
                ].join(' • '),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${shortDate(s.startsAt)}, ${time12h(s.startsAt)}'
                      '${end != null ? ' – ${time12h(end)}' : ''}',
                    ),
                  ),
                ],
              ),
              if (c.location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.location)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              StatRow(
                children: [
                  StatTile(
                    icon: Icons.how_to_reg,
                    value: '${report.present}',
                    label:
                        'Presentes${report.percent == null ? '' : ' (${report.percent}%)'}',
                  ),
                  StatTile(
                    icon: Icons.person_off_outlined,
                    value: '${report.absent}',
                    label: 'Ausentes',
                    color: AppColors.danger,
                  ),
                  StatTile(
                    icon: Icons.groups_outlined,
                    value: '${report.total}',
                    label: 'Total',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Estudiantes ausentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            StatusChip(
              label: '${absent.length}',
              background: AppColors.dangerSoft,
              foreground: AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Revisa cada inasistencia. La justificación queda anotada; la '
          'inasistencia sigue contando en los porcentajes.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        if (absent.isEmpty)
          const AppCard(
            child: Row(
              children: [
                Icon(Icons.celebration_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(child: Text('No hubo inasistencias en esta sesión.')),
              ],
            ),
          ),
        for (final r in absent)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AbsentCard(
              row: r,
              canReview: closed,
              onJustify: () =>
                  _setStatus(context, s, r, AbsenceStatus.justified),
              onConfirm: () =>
                  _setStatus(context, s, r, AbsenceStatus.confirmed),
            ),
          ),
        if (report.presentRows.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Ver presentes (${report.present})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [
                for (final r in report.presentRows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: InitialsAvatar(initials: r.student.initials),
                    title: Text(r.student.name),
                    subtitle: Text(
                      'Cód. ${r.student.code.isEmpty ? '—' : r.student.code}'
                      ' • ${time12h(r.record!.registeredAt)}',
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Descargar planilla PDF',
          icon: Icons.picture_as_pdf_outlined,
          iconOnLeft: true,
          onPressed: () => _pdf(context),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Planilla Excel',
          icon: Icons.table_chart_outlined,
          onPressed: () => _excel(context),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Consultar historial de clases',
          icon: Icons.history_edu_outlined,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

class _AbsentCard extends StatelessWidget {
  const _AbsentCard({
    required this.row,
    required this.canReview,
    required this.onJustify,
    required this.onConfirm,
  });

  final AttendanceRow row;
  final bool canReview;
  final VoidCallback onJustify;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final status = row.justification?.status;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                initials: row.student.initials,
                color: AppColors.danger,
                background: AppColors.dangerSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.student.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        if (row.student.code.isNotEmpty)
                          'Cód. ${row.student.code}',
                        row.enrolled
                            ? 'No registró asistencia'
                            : 'No registró · ${row.student.status.label}',
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatusChip(
                    label: status.label,
                    icon: status == AbsenceStatus.justified
                        ? Icons.verified
                        : Icons.gavel,
                    background: status == AbsenceStatus.justified
                        ? AppColors.chip
                        : AppColors.dangerSoft,
                    foreground: status == AbsenceStatus.justified
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                ),
                if (canReview)
                  TextButton(
                    onPressed: status == AbsenceStatus.justified
                        ? onConfirm
                        : onJustify,
                    child: Text(
                      status == AbsenceStatus.justified
                          ? 'Confirmar falta'
                          : 'Justificar',
                    ),
                  ),
              ],
            ),
          ] else if (canReview) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onJustify,
                    child: const Text('Justificar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: onConfirm,
                    child: const Text(
                      'Confirmar falta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
