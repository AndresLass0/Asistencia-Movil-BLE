import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/course.dart';
import '../../services/attendance_service.dart';
import '../../services/student_backend.dart';
import '../../widgets/app_card.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/status_orb.dart';
import '../attendance/attendance_failed_screen.dart';
import '../attendance/attendance_success_screen.dart';

/// Función que registra la asistencia (inyectable en pruebas).
typedef RegisterAttendance = Future<AttendanceResult> Function(Course course);

/// Pestaña "Asistencia": busca la sesión abierta de la asignatura en el
/// servidor, registra la asistencia y abre la pantalla de resultado.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({
    super.key,
    required this.uid,
    required this.course,
    required this.isLoading,
    required this.onGoToTab,
    this.error,
    this.backend = const FirebaseStudentBackend(),
    this.register,
    this.minSearchTime = const Duration(milliseconds: 1500),
  });

  final String uid;

  /// Asignatura objetivo; null = no hay una clase para registrar ahora.
  final Course? course;
  final bool isLoading;
  final Object? error;

  /// Pide al contenedor (HomeScreen) cambiar de pestaña.
  final ValueChanged<int> onGoToTab;

  final StudentBackend backend;

  /// Por defecto [StudentBackend.registerAttendance] de [backend].
  final RegisterAttendance? register;

  /// Tiempo mínimo que se muestra la animación de búsqueda (solo UX; no
  /// cambia el resultado).
  final Duration minSearchTime;

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  int _scanId = 0; // permite ignorar búsquedas canceladas

  @override
  void initState() {
    super.initState();
    if (widget.course != null) _scan();
  }

  @override
  void dispose() {
    _scanId++; // invalida cualquier búsqueda en curso
    super.dispose();
  }

  Future<void> _scan() async {
    final course = widget.course!;
    final id = ++_scanId;
    final register =
        widget.register ??
        (c) => widget.backend.registerAttendance(widget.uid, c);
    final results = await Future.wait([
      register(course),
      Future<void>.delayed(widget.minSearchTime),
    ]);
    if (!mounted || id != _scanId) return; // cancelada
    final result = results.first as AttendanceResult;

    final action = await Navigator.of(context).push<AttendanceAction>(
      MaterialPageRoute(
        builder: (_) => result.isSuccess
            ? AttendanceSuccessScreen(
                record: result.record!,
                course: course,
                session: result.session!,
                alreadyRegistered: result.alreadyRegistered,
                demo: widget.backend.isDemo,
              )
            : AttendanceFailedScreen(
                course: course,
                failure: result.failure!,
                uid: widget.uid,
                backend: widget.backend,
              ),
      ),
    );
    if (!mounted) return;

    switch (action) {
      case AttendanceAction.retry:
        _scan();
      case AttendanceAction.history:
        widget.onGoToTab(3);
      case AttendanceAction.home:
      case null:
        widget.onGoToTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const LoadingView();
    if (widget.error != null) return AcademicErrorView(error: widget.error!);
    final course = widget.course;
    if (course == null) {
      return MessageView(
        icon: Icons.sensors_off,
        title: 'No hay una clase para registrar',
        message:
            'Podrás registrar tu asistencia cuando el docente abra la '
            'sesión de una de tus asignaturas o estés en horario de clase. '
            'También puedes elegir la asignatura desde Mis Clases.',
        actionLabel: 'Ver mis clases',
        onAction: () => widget.onGoToTab(1),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DETECCIÓN ACTIVA',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registrar asistencia',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Validamos tu presencia con la sesión que abrió tu docente '
            'para esta clase.',
            style: TextStyle(fontSize: 15, color: AppColors.hint),
          ),
          const SizedBox(height: 18),
          _ClassCard(course: course),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.chip.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(56),
            ),
            child: const Center(
              child: StatusOrb(
                color: AppColors.primary,
                animate: true,
                size: 250,
                center: Icon(Icons.sensors, color: Colors.white, size: 38),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: StatusChip(
              label: course.room.isEmpty
                  ? 'Consultando la sesión de la clase'
                  : 'Consultando la sesión del ${course.room.toLowerCase()}',
              showDot: true,
              background: AppColors.chip,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Buscando la señal de la clase…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Verificando la sesión abierta por tu docente',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 18),
          const _TipCard(),
          const SizedBox(height: 18),
          SecondaryButton(
            label: 'Cancelar búsqueda',
            icon: Icons.close,
            onPressed: () => widget.onGoToTab(0),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = course.schedule.where((s) => s.weekday == now.weekday);
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Clase seleccionada',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (today.isNotEmpty)
                StatusChip(
                  label: today.first.startLabel,
                  icon: Icons.access_time,
                  background: AppColors.grayChip,
                  foreground: AppColors.textDark,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            course.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (course.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    course.location,
                    style: const TextStyle(fontSize: 13, color: AppColors.hint),
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

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: false,
      radius: 20,
      color: AppColors.chip.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.chip,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consejo de asistencia',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Mantén la app abierta y con conexión a internet. Si el '
                  'docente aún no abre la sesión, espera su indicación e '
                  'inténtalo de nuevo.',
                  style: TextStyle(fontSize: 13, color: AppColors.hint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
