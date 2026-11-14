import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/ui_messages.dart';
import '../../models/course.dart';
import '../../models/course_session.dart';
import '../../models/enrollment.dart';
import '../../models/teacher_snapshot.dart';
import '../../models/user_profile.dart';
import '../../services/report_service.dart';
import '../../services/teacher_backend.dart';
import '../../widgets/home_header.dart';
import '../../widgets/teacher_bottom_nav.dart';
import 'active_session_screen.dart';
import 'course_form_screen.dart';
import 'session_summary_screen.dart';
import 'tabs/teacher_classes_tab.dart';
import 'tabs/teacher_history_tab.dart';
import 'tabs/teacher_profile_tab.dart';
import 'tabs/teacher_reports_tab.dart';
import 'teacher_ui.dart';

/// Contenedor de la vista del docente: cabecera, pestaña y barra inferior.
/// Lo muestra TeacherGate cuando la cuenta está autorizada (no es una ruta
/// con nombre).
///
/// Mantiene las suscripciones (perfil y datos del docente) y las comparte
/// con las pestañas y las pantallas de sesión mediante un [ValueNotifier].
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.backend,
    this.authDisplayName = '',
  });

  final String uid;
  final String email;
  final String authDisplayName;
  final TeacherBackend backend;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  static const _subtitles = [
    'Portal Docente',
    'Historial de clases',
    'Reportes',
    'Perfil',
  ];

  int _index = TeacherBottomNav.classesIndex;
  final _state = ValueNotifier<TeacherState>(const TeacherState.loading());
  UserProfile? _profile;
  StreamSubscription<TeacherSnapshot>? _dataSub;
  StreamSubscription<UserProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(TeacherHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.backend != widget.backend) {
      _unsubscribe();
      _state.value = const TeacherState.loading();
      _profile = null;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    _state.dispose();
    super.dispose();
  }

  void _subscribe() {
    _profileSub = widget.backend
        .watchProfile(widget.uid)
        .listen(
          (p) => setState(() => _profile = p),
          onError: (_) => setState(() => _profile = null),
        );
    _dataSub = widget.backend
        .watch(widget.uid)
        .listen(
          (d) => _setState(TeacherState.data(d)),
          onError: (Object e) => _setState(TeacherState.error(e)),
        );
  }

  void _unsubscribe() {
    _dataSub?.cancel();
    _profileSub?.cancel();
  }

  void _setState(TeacherState s) {
    _state.value = s;
    if (mounted) setState(() {});
  }

  String get _name {
    final auth = widget.authDisplayName.trim();
    if (auth.isNotEmpty) return auth;
    return _profile?.name ?? '';
  }

  void _goTo(int index) => setState(() => _index = index);

  // ------------------------------------------------------------ asignaturas

  Future<void> _openForm([Course? course]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CourseFormScreen(
          backend: widget.backend,
          teacherName: _name,
          course: course,
          defaultPeriod: _state.value.data?.currentPeriod,
          enrollments: course == null
              ? const []
              : _state.value.data?.enrollmentsOf(course.id) ?? const [],
        ),
      ),
    );
  }

  Future<void> _delete(Course course) async {
    final data = _state.value.data;
    if (data != null && data.sessionsFor(course.id).isNotEmpty) {
      showAppMessage(
        context,
        'No se puede eliminar: la clase ya tiene sesiones de asistencia y '
        'se perdería su historial.',
      );
      return;
    }
    final ok = await confirmAction(
      context,
      title: '¿Eliminar ${course.name}?',
      message:
          'Se eliminará la asignatura y su lista de estudiantes. Esta acción '
          'no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await runTeacherAction(
      context,
      () => widget.backend.deleteCourse(
        course,
        data?.enrollmentsOf(course.id) ?? const [],
      ),
      done: 'Asignatura eliminada.',
    );
  }

  // -------------------------------------------------------------- sesiones

  Future<void> _start(Course course) async {
    final active = _state.value.data?.activeSessionFor(course.id);
    if (active != null) {
      _openSession(active);
      return;
    }
    final minutes = await showSessionDurationSheet(
      context,
      course,
      enrolled: _state.value.data?.enrolledCount(course.id) ?? 0,
    );
    if (minutes == null || !mounted) return;
    CourseSession? created;
    final ok = await runTeacherAction(context, () async {
      created = await widget.backend.startSession(course, minutes);
    });
    if (ok && created != null && mounted) _openSession(created!);
  }

  void _openSession(CourseSession session) {
    if (!session.statusOpen) {
      _openSummary(session);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => ActiveSessionScreen(
          sessionId: session.id,
          state: _state,
          backend: widget.backend,
          onFinished: (s) => _openSummary(s, replace: true, justFinished: true),
        ),
      ),
    );
  }

  Future<void> _openSummary(
    CourseSession session, {
    bool replace = false,
    bool justFinished = false,
  }) async {
    final route = MaterialPageRoute<bool>(
      builder: (_) => SessionSummaryScreen(
        sessionId: session.id,
        state: _state,
        backend: widget.backend,
        teacherName: _name,
        justFinished: justFinished,
      ),
    );
    final nav = Navigator.of(context);
    final goToHistory = replace
        ? await nav.pushReplacement<bool, void>(route)
        : await nav.push(route);
    if (goToHistory == true && mounted) _goTo(TeacherBottomNav.historyIndex);
  }

  void _showActiveSessions() {
    final data = _state.value.data;
    final active = data?.activeSessions ?? const <CourseSession>[];
    final alerts = data?.alerts ?? const <Enrollment>[];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Avisos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No tienes sesiones de asistencia abiertas.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              for (final s in active)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sensors, color: AppColors.primary),
                  title: Text(
                    data!.courseById(s.courseId)?.name ?? 'Asignatura',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${data.reportFor(s).present} presentes'
                    '${s.isOpen ? '' : ' · registro cerrado'}',
                  ),
                  trailing: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openSession(s);
                    },
                    child: const Text('Abrir'),
                  ),
                ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Avisos de estudiantes',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                for (final e in alerts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      e.status == EnrollmentStatus.withdrawn
                          ? Icons.person_remove_outlined
                          : Icons.cancel_schedule_send_outlined,
                      color: AppColors.required,
                    ),
                    title: Text(
                      e.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${e.status == EnrollmentStatus.withdrawn ? 'Canceló' : 'Rechazó la invitación a'} '
                      '${data!.courseById(e.courseId)?.name ?? 'la asignatura'}',
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        runTeacherAction(
                          context,
                          () => widget.backend.markAlertSeen(e),
                        );
                      },
                      child: const Text('Visto'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ exportar

  Future<void> _sessionPdf(SessionReport report) =>
      runTeacherAction(context, () async {
        final bytes = await ReportService.buildSessionPdf(
          report: report,
          teacherName: _name,
        );
        await ReportService.sharePdf(
          bytes,
          ReportService.sessionFileName(report, 'pdf'),
        );
      });

  Future<void> _saveXlsx(Uint8List Function() build, String name) async {
    try {
      final saved = await ReportService.saveXlsx(build(), name);
      if (saved && mounted) showAppMessage(context, 'Archivo guardado.');
    } catch (_) {
      if (mounted) showAppMessage(context, 'No se pudo guardar el archivo.');
    }
  }

  Future<void> _reportPdf(String? period) async {
    final data = _state.value.data;
    if (data == null) return;
    await runTeacherAction(context, () async {
      final now = DateTime.now();
      final bytes = await ReportService.buildTeacherPdf(
        data: data,
        period: period,
        teacherName: _name,
        generatedAt: now,
      );
      await ReportService.sharePdf(
        bytes,
        ReportService.consolidatedFileName(period, now, 'pdf'),
      );
    });
  }

  Future<void> _reportExcel(String? period) async {
    final data = _state.value.data;
    if (data == null) return;
    await _saveXlsx(
      () => ReportService.buildConsolidatedXlsx(data, period),
      ReportService.consolidatedFileName(period, DateTime.now(), 'xlsx'),
    );
  }

  Widget _buildTab(TeacherState state) {
    switch (_index) {
      case TeacherBottomNav.classesIndex:
        return TeacherClassesTab(
          state: state,
          teacherName: _name,
          faculty: _profile?.faculty ?? '',
          onCreate: _openForm,
          onEdit: _openForm,
          onDelete: _delete,
          onStart: _start,
          onOpenSession: _openSession,
        );
      case TeacherBottomNav.historyIndex:
        return TeacherHistoryTab(
          state: state,
          onOpenSummary: (s) => _openSummary(s),
          onExportPdf: _sessionPdf,
          onExportExcel: (r) => _saveXlsx(
            () => ReportService.buildSessionXlsx(r),
            ReportService.sessionFileName(r, 'xlsx'),
          ),
        );
      case TeacherBottomNav.reportsIndex:
        return TeacherReportsTab(
          state: state,
          onExportPdf: _reportPdf,
          onExportExcel: _reportExcel,
        );
      default:
        return TeacherProfileTab(
          displayName: _name,
          email: widget.email,
          profile: _profile,
          state: state,
          backend: widget.backend,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state.value;
    final body = _buildTab(state);
    return Scaffold(
      appBar: HomeHeader(
        subtitle: _subtitles[_index],
        campus: _profile?.campus ?? '',
        pendingSessions:
            (state.data?.activeSessions.length ?? 0) +
            (state.data?.alerts.length ?? 0),
        onNotifications: _showActiveSessions,
      ),
      body: body,
      bottomNavigationBar: TeacherBottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
