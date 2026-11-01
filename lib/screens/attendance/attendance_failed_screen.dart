import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/course.dart';
import '../../services/attendance_service.dart';
import '../../services/student_backend.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/incident_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/status_orb.dart';

/// Resultado: no se pudo registrar la asistencia. Cierra con una
/// [AttendanceAction].
class AttendanceFailedScreen extends StatelessWidget {
  const AttendanceFailedScreen({
    super.key,
    required this.course,
    required this.failure,
    required this.uid,
    this.backend = const FirebaseStudentBackend(),
  });

  final Course course;
  final AttendanceFailure failure;
  final String uid;
  final StudentBackend backend;

  String get _title => switch (failure) {
    AttendanceFailure.noOpenSession => 'No encontramos la señal de la clase',
    AttendanceFailure.offline => 'Sin conexión con el servidor',
    AttendanceFailure.denied => 'No pudimos registrar tu asistencia',
    AttendanceFailure.unknown => 'Ocurrió un problema',
  };

  String get _message {
    final where = course.room.isEmpty
        ? ''
        : ' en el ${course.room.toLowerCase()}';
    return switch (failure) {
      AttendanceFailure.noOpenSession =>
        'No hay una sesión abierta para ${course.name}$where. Asegúrate de '
            'que el docente ya haya iniciado la sesión.',
      AttendanceFailure.offline =>
        'Revisa tu conexión a internet e inténtalo de nuevo. Tu asistencia '
            'solo se registra cuando el servidor la confirma.',
      AttendanceFailure.denied =>
        'La sesión pudo haberse cerrado o no estás matriculado en esta '
            'asignatura. Si crees que es un error, repórtalo al docente.',
      AttendanceFailure.unknown =>
        'No se pudo completar el registro. Inténtalo de nuevo en unos '
            'segundos.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Registro de asistencia'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        child: Column(
          children: [
            StatusOrb(
              color: AppColors.danger,
              centerColor: Colors.white,
              size: 230,
              center: Icon(
                failure == AttendanceFailure.offline
                    ? Icons.wifi_off
                    : Icons.sensors_off,
                color: AppColors.danger,
                size: 40,
              ),
              badge: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            StatusChip(
              label: course.location.isEmpty ? course.name : course.location,
              showDot: true,
              background: AppColors.grayChip,
              foreground: AppColors.hint,
            ),
            const SizedBox(height: 14),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.hint),
            ),
            const SizedBox(height: 22),
            const _TipsCard(),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Intentar nuevamente',
              icon: Icons.sync,
              iconOnLeft: true,
              onPressed: () => Navigator.pop(context, AttendanceAction.retry),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Volver al inicio',
              onPressed: () => Navigator.pop(context, AttendanceAction.home),
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => showIncidentDialog(
                context,
                uid: uid,
                course: course,
                backend: backend,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_agent, size: 20, color: AppColors.hint),
                  SizedBox(width: 10),
                  Text(
                    'Reportar incidencia al docente',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.hint,
                      decoration: TextDecoration.underline,
                    ),
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

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.chip,
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Qué puedes revisar?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _TipTile(
            icon: Icons.wifi,
            title: 'Conexión activa',
            text:
                'Verifica que tienes datos móviles o Wi-Fi: la sesión se '
                'consulta en el servidor.',
          ),
          SizedBox(height: 10),
          _TipTile(
            icon: Icons.fact_check_outlined,
            title: 'Asignatura correcta',
            text: 'Confirma que estás registrando la clase que está en curso.',
          ),
          SizedBox(height: 10),
          _TipTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Confirmación docente',
            text:
                'Pregúntale amablemente al docente si la asistencia ya '
                'está abierta.',
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chip.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(fontSize: 13, color: AppColors.hint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
