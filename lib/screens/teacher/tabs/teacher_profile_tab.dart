import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../models/teacher_snapshot.dart';
import '../../../models/user_profile.dart';
import '../../../services/teacher_backend.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/status_chip.dart';
import '../teacher_ui.dart';

/// Pestaña "Perfil" del docente: datos, resumen del periodo, cursos a
/// cargo, estado de la verificación por proximidad y cierre de sesión.
class TeacherProfileTab extends StatelessWidget {
  const TeacherProfileTab({
    super.key,
    required this.displayName,
    required this.email,
    required this.profile,
    required this.state,
    required this.backend,
  });

  final String displayName;
  final String email;
  final UserProfile? profile;
  final TeacherState state;
  final TeacherBackend backend;

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: '¿Cerrar sesión?',
      message: 'Tendrás que volver a ingresar con tu correo o código.',
      confirmLabel: 'Cerrar sesión',
    );
    if (!ok) return;
    // AuthGate mostrará el Login al detectar que no hay sesión.
    await backend.signOut();
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final name = displayName.isNotEmpty
        ? displayName
        : (p?.name.isNotEmpty ?? false)
        ? p!.name
        : 'Docente';
    final data = state.data;
    final period = data?.currentPeriod;
    final sum = data?.summary(period);
    final courses = data?.currentCourses ?? const [];

    String orMissing(String? v) =>
        v == null || v.trim().isEmpty ? 'Sin registrar' : v.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.chip,
                child: Icon(
                  Icons.co_present_outlined,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(email, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const StatusChip(label: 'Docente', showDot: true),
                  if (p != null && p.code.isNotEmpty)
                    StatusChip(
                      label: 'Cód. ${p.code}',
                      icon: Icons.badge_outlined,
                      background: AppColors.grayChip,
                      foreground: AppColors.hint,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.apartment_outlined,
                label: 'Facultad',
                value: orMissing(p?.faculty),
              ),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Sede',
                value: orMissing(p?.campus),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          icon: Icons.analytics_outlined,
          title: period == null ? 'Resumen' : 'Periodo $period',
        ),
        AppCard(
          child: sum == null
              ? const Text('Cargando…')
              : Column(
                  children: [
                    StatRow(
                      children: [
                        StatTile(
                          icon: Icons.class_outlined,
                          value: '${sum.courses}',
                          label: 'Asignaturas',
                        ),
                        StatTile(
                          icon: Icons.groups_outlined,
                          value: '${sum.students}',
                          label: 'Estudiantes',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StatRow(
                      children: [
                        StatTile(
                          icon: Icons.how_to_reg,
                          value: sum.percent == null ? '—' : '${sum.percent}%',
                          label: 'Asistencia promedio',
                        ),
                        StatTile(
                          icon: Icons.sensors,
                          value: '${sum.heldSessions}',
                          label: 'Sesiones realizadas',
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          icon: Icons.school_outlined,
          title: 'Cursos a cargo',
          trailing: Text(
            '${courses.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        if (courses.isEmpty)
          const AppCard(
            child: Text(
              'Aún no tienes asignaturas en el periodo actual.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        for (final c in courses) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.group.isEmpty ? '' : 'G${c.group} • '}'
                  '${data?.enrolledCount(c.id) ?? 0} estudiantes',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Horario',
                  value: c.scheduleLabel,
                ),
                if (c.location.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Lugar',
                    value: c.location,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const SectionHeader(
          icon: Icons.sensors,
          title: 'Proximidad (Bluetooth)',
        ),
        const AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.chip,
                child: Icon(Icons.bluetooth, color: AppColors.primary),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Emisión desde el aula',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusChip(
                          label: 'Próximamente',
                          background: AppColors.grayChip,
                          foreground: AppColors.hint,
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Aún no disponible: hoy la asistencia se valida con la '
                      'sesión que inicias y su tiempo de registro. La '
                      'calibración de la señal llegará con la verificación '
                      'por proximidad.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Cerrar sesión',
          icon: Icons.logout,
          iconOnLeft: true,
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
