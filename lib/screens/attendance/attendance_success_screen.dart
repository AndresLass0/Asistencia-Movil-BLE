import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/date_format.dart';
import '../../models/attendance_record.dart';
import '../../models/course.dart';
import '../../models/course_session.dart';
import '../../services/attendance_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/status_orb.dart';

/// Resultado: asistencia registrada en Firestore. Cierra con una
/// [AttendanceAction].
class AttendanceSuccessScreen extends StatelessWidget {
  const AttendanceSuccessScreen({
    super.key,
    required this.record,
    required this.course,
    required this.session,
    this.alreadyRegistered = false,
  });

  final AttendanceRecord record;
  final Course course;
  final CourseSession session;

  /// La asistencia ya existía (no se duplicó).
  final bool alreadyRegistered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Comprobante de asistencia'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        child: Column(
          children: [
            StatusOrb(
              color: AppColors.primary,
              size: 230,
              center: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 52,
              ),
              badge: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.chip,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ),
            Text(
              alreadyRegistered
                  ? 'Ya habías registrado tu asistencia'
                  : '¡Asistencia registrada!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              alreadyRegistered
                  ? 'Tu asistencia a esta sesión ya estaba guardada; no se '
                        'registró de nuevo.'
                  : 'Tu presencia ha sido confirmada en la sesión del docente.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.hint),
            ),
            const SizedBox(height: 12),
            const StatusChip(
              label: 'Registro completado sin novedades',
              showDot: true,
            ),
            const SizedBox(height: 22),
            _Receipt(record: record, course: course, session: session),
            const SizedBox(height: 16),
            const _ValidationNote(),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Volver al inicio',
              icon: Icons.home_outlined,
              iconOnLeft: true,
              onPressed: () => Navigator.pop(context, AttendanceAction.home),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Ver en mi historial',
              icon: Icons.history,
              onPressed: () => Navigator.pop(context, AttendanceAction.history),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco_outlined, size: 18, color: AppColors.hint),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Campus Sostenible • Universidad de la Amazonia',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.hint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.record,
    required this.course,
    required this.session,
  });

  final AttendanceRecord record;
  final Course course;
  final CourseSession session;

  /// "+3 min desde el inicio" (o "Antes del inicio").
  String get _offset {
    final minutes = record.registeredAt.difference(session.startsAt).inMinutes;
    if (minutes < 0) return 'Antes del inicio';
    if (minutes == 0) return 'Al inicio de la sesión';
    return '+$minutes min desde el inicio';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              height: 6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF7BD08F)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: StatusChip(
                            label: 'Comprobante ${record.code}',
                            icon: Icons.verified_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'VALIDADO POR\nSESIÓN',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SubjectTile(course: course),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Sesión de clase',
                          value: shortDate(session.startsAt),
                          detail: time12h(session.startsAt),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.access_time,
                          iconColor: AppColors.primary,
                          label: 'Hora de registro',
                          value: time12h(record.registeredAt, seconds: true),
                          detail: _offset,
                        ),
                      ),
                    ],
                  ),
                  if (course.location.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _WideTile(
                      icon: Icons.location_on_outlined,
                      label: 'Espacio físico asignado',
                      value: course.location,
                    ),
                  ],
                  const SizedBox(height: 10),
                  const _WideTile(
                    icon: Icons.sensors,
                    iconColor: AppColors.primary,
                    label: 'Método de validación',
                    value: 'Sesión abierta por el docente',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Registro guardado en BioAsistencia.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
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

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chip.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF8BE79F),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: AppColors.textDark,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASIGNATURA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  course.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (course.teacherName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 15,
                        color: AppColors.hint,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Prof. ${course.teacherName}',
                          style: const TextStyle(
                            fontSize: 12.5,
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
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.iconColor = AppColors.hint,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chip.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor == AppColors.primary
                        ? AppColors.primary
                        : AppColors.hint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          Text(
            detail,
            style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

class _WideTile extends StatelessWidget {
  const _WideTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.hint,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chip.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.hint),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationNote extends StatelessWidget {
  const _ValidationNote();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: false,
      radius: 20,
      color: AppColors.chip.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(14),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu asistencia se validó con la sesión abierta por el docente. '
              'La verificación por proximidad (Bluetooth) aún no está '
              'disponible.',
              style: TextStyle(fontSize: 13, color: AppColors.hint),
            ),
          ),
        ],
      ),
    );
  }
}
