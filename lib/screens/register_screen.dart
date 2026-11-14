import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/auth_messages.dart';
import '../core/ui_messages.dart';
import '../core/validators.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../widgets/app_link.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _dependencias = [
    'Facultad de Ingeniería',
    'Facultad de Ciencias Agropecuarias',
    'Facultad de Ciencias Básicas',
    'Facultad de Ciencias Contables, Económicas y Administrativas',
    'Facultad de Ciencias de la Educación',
    'Facultad de Derecho',
    'Facultad de Ciencias de la Salud',
  ];

  UserRole _role = UserRole.student;
  bool _bleEnabled = true;
  bool _acceptedData = false;
  String? _dependencia;
  int _strength = 0; // 0 a 3
  bool _loading = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _documentCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    showAppMessage(context, text);
  }

  /// Devuelve el mensaje de error de validación, o null si todo está bien.
  String? _validate() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final document = _documentCtrl.text.trim();
    final pass = _passCtrl.text;

    if (name.length < 3) return 'Ingresa tu nombre completo.';
    if (!isInstitutionalEmail(email)) {
      return 'Usa tu correo institucional @$institutionalDomain.';
    }
    if (!isValidCode(document)) {
      return 'El ${_role.codeLabel.toLowerCase()} debe tener entre 5 y 15 '
          'dígitos.';
    }
    if (_dependencia == null) return 'Selecciona tu facultad.';
    if (pass.length < 8) return 'La contraseña debe tener mínimo 8 caracteres.';
    if (pass != _confirmCtrl.text) return 'Las contraseñas no coinciden.';
    if (!_acceptedData) {
      return 'Debes aceptar el tratamiento de datos personales.';
    }
    return null;
  }

  Future<void> _register() async {
    if (_loading) return; // evita múltiples envíos

    final error = _validate();
    if (error != null) {
      _showMessage(error);
      return;
    }

    final email = _emailCtrl.text.trim().toLowerCase();
    final name = _nameCtrl.text.trim();
    final code = _documentCtrl.text.trim();

    setState(() => _loading = true);
    User? created;
    try {
      // 1) El código debe estar libre (también lo garantizan las reglas).
      if (await UserProfileService.isCodeTaken(code)) {
        _showMessage('Ese código ya está registrado en otra cuenta.');
        return;
      }

      // 2) Cuenta de Firebase Auth.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _passCtrl.text,
          );
      created = credential.user;
      await created?.updateDisplayName(name);

      // 2b) Docente: la institución debe haber autorizado su correo. (Las
      // reglas también lo exigen; aquí se comprueba para dar un mensaje
      // claro y no dejar una cuenta a medias.)
      if (_role == UserRole.teacher &&
          !await UserProfileService.isAuthorizedTeacher(email)) {
        await _rollback(created);
        _showMessage(
          'Tu correo no está autorizado como docente. Solicita a la '
          'administración de BioAsistencia que lo habilite y vuelve a '
          'registrarte.',
        );
        return;
      }

      // 3) Perfil académico + reserva del código (operación atómica).
      await UserProfileService.createProfile(
        created!.uid,
        UserProfile(
          name: name,
          email: email,
          role: _role,
          code: code,
          faculty: _dependencia!,
          bleEnabled: _bleEnabled,
        ),
      );

      // Docente: correo verificado obligatorio para operar (reglas).
      if (_role == UserRole.teacher) {
        try {
          await created.sendEmailVerification();
          _showMessage(
            'Cuenta creada. Te enviamos un correo para verificar tu '
            'dirección antes de usar las funciones de docente.',
          );
        } catch (_) {
          // Se podrá reenviar desde la pantalla de verificación.
        }
      }

      // AuthGate (debajo de esta pantalla) ya muestra la vista del rol.
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      await _rollback(created);
      _showMessage(authErrorMessage(e));
    } on FirebaseException catch (e) {
      await _rollback(created);
      _showMessage(firestoreErrorMessage(e));
    } catch (_) {
      await _rollback(created);
      _showMessage('Ocurrió un error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Si la cuenta se creó pero el perfil no pudo guardarse, se elimina la
  /// cuenta para que el usuario pueda volver a intentarlo con el mismo correo.
  Future<void> _rollback(User? created) async {
    if (created == null) return;
    try {
      await created.delete();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
  }

  void _onPasswordChanged(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    setState(() => _strength = score);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Registro de usuario', showAvatar: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const _RegisterHeader(),
            const SizedBox(height: 22),
            const Text(
              'Selecciona tu rol en el campus',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _RoleSelector(
              role: _role,
              onChanged: (v) => setState(() => _role = v),
            ),
            if (_role == UserRole.teacher) ...[
              const SizedBox(height: 10),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Las cuentas docentes requieren que la institución haya '
                      'autorizado tu correo y que lo verifiques.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.hint),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            AppTextField(
              controller: _nameCtrl,
              label: 'Nombre completo',
              hint: 'ej. Juan Camilo Pérez',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _emailCtrl,
              label: 'Correo institucional',
              hint: 'ej. jcperez@udla.edu.co',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              suffix: Icon(Icons.shield_outlined, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        TextSpan(text: 'Debe pertenecer al dominio oficial '),
                        TextSpan(
                          text: '@udla.edu.co',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _documentCtrl,
              label: _role.codeLabel,
              trailingLabel: 'Numérico',
              hint: 'ej. 1020304050',
              helper: 'También podrás iniciar sesión con este código.',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            const Text(
              'Facultad',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _DependencyDropdown(
              value: _dependencia,
              items: _dependencias,
              onChanged: (v) => setState(() => _dependencia = v),
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _passCtrl,
              label: 'Contraseña de acceso',
              hint: 'Mínimo 8 caracteres',
              icon: Icons.lock_outline,
              isPassword: true,
              onChanged: _onPasswordChanged,
            ),
            const SizedBox(height: 10),
            _StrengthBar(level: _strength),
            const SizedBox(height: 14),
            AppTextField(
              controller: _confirmCtrl,
              label: 'Confirmar contraseña',
              hint: 'Repite tu contraseña',
              icon: Icons.lock_person_outlined,
              isPassword: true,
            ),
            const SizedBox(height: 24),
            _PermissionsCard(
              bleEnabled: _bleEnabled,
              acceptedData: _acceptedData,
              onBleChanged: (v) => setState(() => _bleEnabled = v),
              onAcceptedChanged: (v) =>
                  setState(() => _acceptedData = v ?? false),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Crear cuenta institucional',
              icon: Icons.how_to_reg_outlined,
              isLoading: _loading,
              onPressed: _register,
            ),
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '¿Ya tienes una cuenta registrada? ',
                    style: TextStyle(color: AppColors.hint),
                  ),
                  // Vuelve al Login existente (no apila uno nuevo).
                  AppLink(
                    label: 'Inicia sesión',
                    onTap: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 16, color: AppColors.primary),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'BioAsistencia • Conexión cifrada',
                        style: TextStyle(fontSize: 12, color: AppColors.hint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCFF2D6), Color(0xFFE9F8EC)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.primary),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'CREDENCIALES INSTITUCIONALES UDLA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Registro institucional',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vincula tu identidad oficial para habilitar la sintonía de '
            'presencia y registro automático de asistencia en aulas '
            'universitarias.',
            style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.role, required this.onChanged});

  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  Widget _option(UserRole value, IconData icon) {
    final selected = role == value;
    final label = value.label;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _option(UserRole.student, Icons.school),
          _option(UserRole.teacher, Icons.co_present_outlined),
        ],
      ),
    );
  }
}

class _DependencyDropdown extends StatelessWidget {
  const _DependencyDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down),
          hint: const Row(
            children: [
              Icon(Icons.account_balance_outlined, color: AppColors.textMuted),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Selecciona tu facultad',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: AppColors.hint),
                ),
              ),
            ],
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < level ? AppColors.primary : AppColors.barEmpty,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          'Seguridad: ${const ['baja', 'baja', 'media', 'alta'][level]}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({
    required this.bleEnabled,
    required this.acceptedData,
    required this.onBleChanged,
    required this.onAcceptedChanged,
  });

  final bool bleEnabled;
  final bool acceptedData;
  final ValueChanged<bool> onBleChanged;
  final ValueChanged<bool?> onAcceptedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Permisos de aula y proximidad',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Por ahora tu asistencia se valida con la sesión que abre tu '
            'docente. La detección por proximidad (BLE) llegará en una '
            'próxima versión.',
            style: TextStyle(fontSize: 12.5, color: AppColors.hint),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.chip.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Switch(
                  value: bleEnabled,
                  onChanged: onBleChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensor BLE y presencia en aula',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Guarda tu preferencia para cuando la detección '
                        'por proximidad esté disponible.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.hint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: acceptedData,
                onChanged: onAcceptedChanged,
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.hint, width: 1.5),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12.5, color: AppColors.hint),
                      children: [
                        TextSpan(text: 'Acepto el '),
                        TextSpan(
                          text: 'Tratamiento de Datos Personales',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' bajo la Ley 1581 de 2012 y el Estatuto '
                              'Estudiantil de la Universidad de la '
                              'Amazonia.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
