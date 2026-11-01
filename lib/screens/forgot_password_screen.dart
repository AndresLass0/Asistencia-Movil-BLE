import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/auth_messages.dart';
import '../core/ui_messages.dart';
import '../core/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_chip.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    showAppMessage(context, text);
  }

  Future<void> _sendReset() async {
    if (_loading) return;

    final email = _emailCtrl.text.trim();
    if (!isInstitutionalEmail(email)) {
      _showMessage('Ingresa tu correo institucional @$institutionalDomain.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.toLowerCase(),
      );
      _showMessage(
        'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(authErrorMessage(e));
    } catch (_) {
      _showMessage('Ocurrió un error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Recuperar contraseña', showAvatar: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        child: Column(
          children: [
            const _LockIllustration(),
            const SizedBox(height: 6),
            const _CentralIdentityChip(),
            const SizedBox(height: 4),
            const Text(
              '¿Olvidaste tu\ncontraseña?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ingresa tu correo institucional (@udla.edu.co).\n'
              'Te enviaremos un enlace seguro para\n'
              'restablecer tu contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.hint),
            ),
            const SizedBox(height: 26),
            const Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.mail_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Correo institucional',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _emailCtrl,
              label: '',
              hint: 'ej. sgonzalez@udla.edu.co',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              helper: 'Usa exclusivamente tu cuenta institucional activa',
              helperIcon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Código institucional (doble factor)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                StatusChip(
                  label: 'Próximamente',
                  background: AppColors.grayChip,
                  foreground: AppColors.hint,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Pendiente: la verificación con código aún no existe. El campo se
            // conserva deshabilitado por decisión del equipo.
            const AppTextField(
              label: '',
              hint: 'ej. 1020845920',
              icon: Icons.fingerprint,
              keyboardType: TextInputType.number,
              enabled: false,
              helper:
                  'La verificación con código estará disponible '
                  'próximamente. Por ahora basta con tu correo.',
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Enviar instrucciones de recuperación',
              icon: Icons.send_outlined,
              isLoading: _loading,
              onPressed: _sendReset,
            ),
            const SizedBox(height: 28),
            InkWell(
              onTap: () => Navigator.maybePop(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Volver a iniciar sesión',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

/// Candado con círculos concéntricos y hoja verde.
class _LockIllustration extends StatelessWidget {
  const _LockIllustration();

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primary.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _circle(140, 0.07),
          _circle(104, 0.1),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset, color: Colors.white, size: 38),
          ),
          Positioned(
            right: 20,
            bottom: 14,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.eco, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CentralIdentityChip extends StatelessWidget {
  const _CentralIdentityChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: AppColors.primary),
          SizedBox(width: 12),
          Text(
            'IDENTIDAD CENTRAL UDLA',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppColors.hint,
            ),
          ),
        ],
      ),
    );
  }
}
