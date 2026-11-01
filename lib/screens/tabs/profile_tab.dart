import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/auth_messages.dart';
import '../../core/ui_messages.dart';
import '../../models/academic_snapshot.dart';
import '../../models/user_profile.dart';
import '../../services/student_backend.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/user_avatar.dart';

/// Pestaña "Perfil": identidad, información académica, proximidad,
/// alertas y cierre de sesión.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.uid,
    required this.displayName,
    required this.email,
    required this.profile,
    required this.state,
    this.backend = const FirebaseStudentBackend(),
  });

  final String uid;
  final StudentBackend backend;
  final String displayName;
  final String email;

  /// Perfil de Firestore; null si aún no carga o la cuenta no lo tiene.
  final UserProfile? profile;
  final AcademicState state;

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action().timeout(const Duration(seconds: 15));
      if (context.mounted) showAppMessage(context, done);
    } on FirebaseException catch (e) {
      if (context.mounted) showAppMessage(context, firestoreErrorMessage(e));
    } on TimeoutException {
      if (context.mounted) {
        showAppMessage(
          context,
          'Sin conexión. El cambio se guardará al recuperar la conexión.',
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a ingresar con tu correo o código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // AuthGate mostrará el Login al detectar que no hay sesión.
    await backend.signOut();
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _editAcademic(BuildContext context, UserProfile p) async {
    final result = await showModalBottomSheet<_AcademicInfo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AcademicInfoSheet(profile: p),
    );
    if (result == null || !context.mounted) return;
    await _save(
      context,
      () => backend.updateAcademicInfo(
        uid,
        program: result.program,
        semester: result.semester,
        campus: result.campus,
      ),
      'Información académica actualizada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final name = displayName.isNotEmpty
        ? displayName
        : (p?.name.isNotEmpty ?? false)
        ? p!.name
        : 'Usuario';
    final index = state.data?.overall.percent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const UserAvatar(size: 96),
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
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if (p != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusChip(label: p.role.label, showDot: true),
                      if (p.code.isNotEmpty)
                        StatusChip(
                          label: 'Cód. ${p.code}',
                          icon: Icons.badge_outlined,
                          background: AppColors.grayChip,
                          foreground: AppColors.hint,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                AppCard(
                  elevated: false,
                  color: AppColors.chip.withValues(alpha: 0.5),
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      _Metric(
                        label: 'Nivel académico',
                        value: p?.semester == null
                            ? 'Sin registrar'
                            : '${p!.semester}.º semestre',
                      ),
                      _Metric(
                        label: 'Índice presencial',
                        value: index == null ? '—' : '$index%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p == null) ...[
            const SizedBox(height: 16),
            const AppCard(
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perfil académico no disponible. Las cuentas creadas '
                      'antes de esta versión no tienen código ni facultad '
                      'registrados.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            SectionHeader(
              icon: Icons.account_balance_outlined,
              title: 'Información académica',
              trailing: TextButton.icon(
                onPressed: () => _editAcademic(context, p),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.laptop_chromebook_outlined,
                    label: 'Programa curricular',
                    value: p.program.isEmpty ? 'Sin registrar' : p.program,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.domain,
                    label: 'Facultad',
                    value: p.faculty.isEmpty ? 'Sin registrar' : p.faculty,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Sede universitaria',
                    value: p.campus.isEmpty ? 'Sin registrar' : p.campus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionHeader(
              icon: Icons.settings_input_antenna,
              title: 'Dispositivo y proximidad',
            ),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.bluetooth,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detección Bluetooth LE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            StatusChip(
                              label: 'Próximamente',
                              background: AppColors.grayChip,
                              foreground: AppColors.hint,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Aún no disponible: tu asistencia se valida con la sesión '
                    'abierta por el docente.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.hint),
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Permitir detección por proximidad',
                    subtitle:
                        'Se usará cuando la verificación Bluetooth esté '
                        'disponible.',
                    value: p.bleEnabled,
                    onChanged: (v) => _save(
                      context,
                      () => backend.updateBleEnabled(uid, v),
                      v
                          ? 'Detección por proximidad permitida.'
                          : 'Detección por proximidad desactivada.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionHeader(
              icon: Icons.tune,
              title: 'Configuración y alertas',
            ),
            AppCard(
              child: Column(
                children: [
                  _SwitchRow(
                    title: 'Sesiones de aula en vivo',
                    subtitle:
                        'Avisarme dentro de la app cuando el docente '
                        'abra una sesión de mis asignaturas.',
                    value: p.settings.liveSessionAlerts,
                    onChanged: (v) => _save(
                      context,
                      () => backend.updateSettings(
                        uid,
                        p.settings.copyWith(liveSessionAlerts: v),
                      ),
                      'Preferencia guardada.',
                    ),
                  ),
                  const Divider(height: 20),
                  _SwitchRow(
                    title: 'Alerta de riesgo presencial',
                    subtitle:
                        'Avisarme en Inicio cuando me quede 1 falta o '
                        'menos del máximo definido por la asignatura.',
                    value: p.settings.riskAlerts,
                    onChanged: (v) => _save(
                      context,
                      () => backend.updateSettings(
                        uid,
                        p.settings.copyWith(riskAlerts: v),
                      ),
                      'Preferencia guardada.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Cerrar sesión',
            icon: Icons.logout,
            iconOnLeft: true,
            onPressed: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.hint),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
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
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _AcademicInfo {
  const _AcademicInfo(this.program, this.semester, this.campus);

  final String program;
  final int? semester;
  final String campus;
}

class _AcademicInfoSheet extends StatefulWidget {
  const _AcademicInfoSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_AcademicInfoSheet> createState() => _AcademicInfoSheetState();
}

class _AcademicInfoSheetState extends State<_AcademicInfoSheet> {
  late final _program = TextEditingController(text: widget.profile.program);
  late final _semester = TextEditingController(
    text: widget.profile.semester?.toString() ?? '',
  );
  late final _campus = TextEditingController(text: widget.profile.campus);
  String? _error;

  @override
  void dispose() {
    _program.dispose();
    _semester.dispose();
    _campus.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _semester.text.trim();
    final semester = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (semester == null || semester < 1 || semester > 20)) {
      setState(() => _error = 'El semestre debe ser un número entre 1 y 20.');
      return;
    }
    Navigator.pop(
      context,
      _AcademicInfo(_program.text, semester, _campus.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Información académica',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Estos datos los registras tú; la facultad y el código no se '
            'pueden cambiar desde la app.',
            style: TextStyle(fontSize: 13, color: AppColors.hint),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _program,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Programa curricular',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _semester,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Semestre (1–20)',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _campus,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Sede universitaria',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Guardar',
            icon: Icons.check,
            iconOnLeft: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
