import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/auth_messages.dart';
import '../core/ui_messages.dart';
import '../models/academic_snapshot.dart';
import '../models/course.dart';
import '../models/enrollment.dart';
import '../models/user_profile.dart';
import '../services/report_service.dart';
import '../services/student_backend.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/home_header.dart';
import 'course_detail_screen.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/classes_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';

/// Contenedor de la vista del estudiante: cabecera + pestaña + barra inferior.
/// Lo muestra AuthGate cuando hay sesión (no es una ruta con nombre).
///
/// Mantiene las suscripciones a Firestore (perfil y datos académicos) y las
/// comparte con las pestañas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.uid,
    required this.email,
    this.authDisplayName = '',
    this.backend = const FirebaseStudentBackend(),
  });

  final String uid;
  final String email;

  /// Nombre de Firebase Auth (si lo tiene); si no, el del perfil.
  final String authDisplayName;

  /// Firebase en la app; en memoria en las pruebas.
  final StudentBackend backend;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _subtitles = [
    'Portal Estudiantil',
    'Mis Clases',
    'Asistencia',
    'Historial',
    'Perfil',
  ];

  int _index = 0;

  final _academic = ValueNotifier<AcademicState>(const AcademicState.loading());
  UserProfile? _profile;
  StreamSubscription<AcademicSnapshot>? _academicSub;
  StreamSubscription<UserProfile?>? _profileSub;

  /// Asignatura fijada al entrar en la pestaña Asistencia (null = ninguna).
  Course? _attendanceCourse;
  bool _attendanceResolved = false;
  int _attendanceRun = 0;

  /// Sesiones abiertas ya conocidas (para avisar solo de las nuevas).
  Set<String>? _knownOpenSessions;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.backend != widget.backend) {
      _unsubscribe();
      _academic.value = const AcademicState.loading();
      _profile = null;
      _knownOpenSessions = null;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    _academic.dispose();
    super.dispose();
  }

  void _subscribe() {
    final uid = widget.uid;
    _profileSub = widget.backend
        .watchProfile(uid)
        .listen(
          (p) => setState(() => _profile = p),
          // Sin perfil (reglas o red): la app sigue funcionando sin él.
          onError: (_) => setState(() => _profile = null),
        );
    _academicSub = widget.backend
        .watchAcademic(widget.email)
        .listen(
          _onAcademic,
          onError: (Object e) => _setAcademic(AcademicState.error(e)),
        );
  }

  void _unsubscribe() {
    _academicSub?.cancel();
    _profileSub?.cancel();
  }

  void _setAcademic(AcademicState state) {
    _academic.value = state;
    if (mounted) setState(() {});
  }

  void _onAcademic(AcademicSnapshot data) {
    final pending = {
      for (final c in data.pendingOpenCourses) data.statsFor(c).openSession!.id,
    };
    final known = _knownOpenSessions;
    final alerts = _profile?.settings.liveSessionAlerts ?? true;
    if (known != null && alerts && mounted) {
      final fresh = data.pendingOpenCourses.where(
        (c) => !known.contains(data.statsFor(c).openSession!.id),
      );
      if (fresh.isNotEmpty) _announceSession(fresh.first);
    }
    _knownOpenSessions = pending;
    _setAcademic(AcademicState.data(data));

    // Si se entró a Asistencia antes de tener datos, se elige ahora (una vez).
    if (_index == AppBottomNav.attendanceIndex && !_attendanceResolved) {
      _resolveAttendance(null);
    }
  }

  void _announceSession(Course course) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('El docente abrió la sesión de ${course.name}.'),
          action: SnackBarAction(
            label: 'Registrar',
            onPressed: () => _registerAttendance(course),
          ),
        ),
      );
  }

  /// Fija la asignatura objetivo al entrar a Asistencia, para que los
  /// cambios posteriores de los datos no reinicien la búsqueda.
  void _resolveAttendance(Course? explicit) {
    final data = _academic.value.data;
    if (explicit == null && data == null) {
      _attendanceCourse = null;
      _attendanceResolved = false;
    } else {
      _attendanceCourse =
          explicit ?? data!.suggestedAttendanceCourse(DateTime.now());
      _attendanceResolved = true;
    }
    _attendanceRun++;
    if (mounted) setState(() {});
  }

  void _goTo(int index) {
    if (index == AppBottomNav.attendanceIndex) {
      _index = index;
      _resolveAttendance(null);
      return;
    }
    setState(() {
      _index = index;
      _attendanceResolved = false;
    });
  }

  void _registerAttendance(Course? course) {
    _index = AppBottomNav.attendanceIndex;
    _resolveAttendance(course);
  }

  void _openCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(
          courseId: course.id,
          academic: _academic,
          uid: widget.uid,
          backend: widget.backend,
          onRegister: _registerAttendance,
          onWithdraw: _withdraw,
        ),
      ),
    );
  }

  /// Cambia el estado de la propia matrícula y avisa del resultado.
  Future<bool> _setStatus(
    Enrollment enrollment,
    EnrollmentStatus status,
    String done,
  ) async {
    try {
      await widget.backend.setEnrollmentStatus(enrollment, status);
      if (mounted) showAppMessage(context, done);
      return true;
    } on FirebaseException catch (e) {
      if (mounted) showAppMessage(context, firestoreErrorMessage(e));
    } on TimeoutException {
      if (mounted) {
        showAppMessage(context, 'Sin conexión. Inténtalo de nuevo.');
      }
    }
    return false;
  }

  Future<void> _respondInvitation(CourseInvitation inv, bool accept) =>
      _setStatus(
        inv.enrollment,
        accept ? EnrollmentStatus.active : EnrollmentStatus.declined,
        accept
            ? 'Te uniste a ${inv.course.name}.'
            : 'Rechazaste la invitación a ${inv.course.name}.',
      );

  /// Cancelar la asignatura (con confirmación). El docente recibe el aviso.
  Future<bool> _withdraw(Course course) async {
    final enrollment = _academic.value.data?.enrollmentFor(course.id);
    if (enrollment == null || !enrollment.isActive) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Cancelar ${course.name}?'),
        content: const Text(
          'Dejarás de aparecer en la lista de la clase y no podrás registrar '
          'asistencia. Tu historial se conserva y el docente recibirá un '
          'aviso. Para volver, el docente tendrá que invitarte de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.required),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar asignatura'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    return _setStatus(
      enrollment,
      EnrollmentStatus.withdrawn,
      'Cancelaste ${course.name}.',
    );
  }

  void _showOpenSessions() {
    final data = _academic.value.data;
    final pending = data?.pendingOpenCourses ?? const <Course>[];
    final invitations = data?.invitations ?? const <CourseInvitation>[];
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
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No hay sesiones abiertas pendientes de registro en tus '
                    'asignaturas.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              for (final c in pending)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sensors, color: AppColors.primary),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    c.location.isEmpty
                        ? 'El docente abrió la sesión'
                        : c.location,
                  ),
                  trailing: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _registerAttendance(c);
                    },
                    child: const Text('Registrar'),
                  ),
                ),
              if (invitations.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Invitaciones',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                for (final inv in invitations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.mail_outline,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      inv.course.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      inv.course.teacherName.isEmpty
                          ? 'Te invitaron a esta clase'
                          : 'Prof. ${inv.course.teacherName} te invitó',
                    ),
                    trailing: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _respondInvitation(inv, true);
                      },
                      child: const Text('Aceptar'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportHistory() async {
    final data = _academic.value.data;
    if (data == null) return;
    final now = DateTime.now();
    final bytes = await ReportService.buildHistoryPdf(
      studentName: _displayName,
      email: widget.email,
      code: _profile?.code ?? '',
      data: data,
      generatedAt: now,
    );
    await ReportService.share(bytes, now);
    if (mounted) showAppMessage(context, 'Historial generado.');
  }

  String get _displayName {
    final auth = widget.authDisplayName.trim();
    if (auth.isNotEmpty) return auth;
    return _profile?.name ?? '';
  }

  /// Primer nombre del usuario; si no tiene, el nombre de su rol.
  String get _firstName {
    final name = _displayName;
    if (name.isNotEmpty) return name.split(' ').first;
    return _profile?.role.label ?? 'Estudiante';
  }

  Widget _buildTab(AcademicState state) {
    switch (_index) {
      case 0:
        return DashboardTab(
          firstName: _firstName,
          state: state,
          settings: _profile?.settings ?? const UserSettings(),
          onRegisterAttendance: _registerAttendance,
          onOpenCourse: _openCourse,
          onRespondInvitation: _respondInvitation,
        );
      case 1:
        return ClassesTab(
          state: state,
          onRegister: _registerAttendance,
          onOpenCourse: _openCourse,
        );
      case 2:
        // Clave por "entrada": cada vez que se entra se busca de nuevo, pero
        // las actualizaciones de datos no reinician la búsqueda.
        return AttendanceTab(
          key: ValueKey(_attendanceRun),
          uid: widget.uid,
          backend: widget.backend,
          course: _attendanceCourse,
          isLoading: !_attendanceResolved && state.isLoading,
          error: _attendanceResolved ? null : state.error,
          onGoToTab: _goTo,
        );
      case 3:
        return HistoryTab(
          state: state,
          onOpenCourse: _openCourse,
          onExport: state.data == null ? null : _exportHistory,
        );
      default:
        return ProfileTab(
          uid: widget.uid,
          backend: widget.backend,
          displayName: _displayName,
          email: widget.email,
          profile: _profile,
          state: state,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _academic.value;
    final subtitle = _index == 0 && _profile?.role == UserRole.teacher
        ? 'Portal Docente'
        : _subtitles[_index];
    return Scaffold(
      appBar: HomeHeader(
        subtitle: subtitle,
        campus: _profile?.campus ?? '',
        pendingSessions:
            (state.data?.pendingOpenCourses.length ?? 0) +
            (state.data?.invitations.length ?? 0),
        onNotifications: _showOpenSessions,
      ),
      body: _buildTab(state),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
