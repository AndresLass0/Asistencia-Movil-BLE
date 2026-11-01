import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/auth_messages.dart';
import '../core/ui_messages.dart';
import '../core/validators.dart';
import '../services/demo_backend.dart';
import '../services/user_profile_service.dart';
import '../widgets/app_link.dart';
import '../widgets/app_text_field.dart';
import '../widgets/brand_logo.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    showAppMessage(context, text);
  }

  /// Estudiante: modo demostración con datos de ejemplo en memoria (sin
  /// Firebase). Docente: aún no existe la vista docente.
  void _demoStudent() => DemoMode.enter();

  void _demoTeacher() {
    _showMessage('La vista docente aún no está disponible.');
  }

  Future<void> _login() async {
    if (_loading) return; // evita múltiples intentos simultáneos

    final identifier = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final type = classifyLoginIdentifier(identifier);

    if (type == LoginIdentifierType.invalid) {
      _showMessage(
        'Ingresa tu correo @$institutionalDomain o tu código institucional.',
      );
      return;
    }
    if (password.isEmpty) {
      _showMessage('Ingresa tu contraseña.');
      return;
    }

    setState(() => _loading = true);
    try {
      var email = identifier.toLowerCase();
      if (type == LoginIdentifierType.code) {
        final found = await UserProfileService.emailForCode(identifier);
        if (found == null) {
          // Mismo mensaje que una contraseña incorrecta: no revela
          // si el código existe.
          _showMessage(kInvalidCredentialsMessage);
          return;
        }
        email = found;
      }
      // Al iniciar sesión, AuthGate muestra automáticamente HomeScreen.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(authErrorMessage(e));
    } on FirebaseException catch (e) {
      _showMessage(firestoreErrorMessage(e));
    } catch (_) {
      _showMessage('Ocurrió un error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            children: [
              const _Header(),
              const SizedBox(height: 18),
              const _InfoChip(),
              const SizedBox(height: 22),
              _LoginCard(
                onForgot: () =>
                    Navigator.pushNamed(context, AppRoutes.forgotPassword),
                onLogin: _login,
                isLoading: _loading,
                emailController: _emailCtrl,
                passwordController: _passCtrl,
                onDemoTeacher: _demoTeacher,
                onDemoStudent: _demoStudent,
              ),
              const SizedBox(height: 16),
              // Acceso a la pantalla de registro.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿No tienes cuenta? ',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  AppLink(
                    label: 'Regístrate',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.register),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mismo logo que la cabecera de la app (BrandLogo) mientras no exista
        // un recurso gráfico oficial.
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const BrandLogo(size: 60),
        ),
        const SizedBox(height: 18),
        const Text(
          'BioAsistencia',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sistema de Presencia Inteligente',
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.chip.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ingresa con tu correo institucional (@udla.edu.co) o con tu '
              'código de estudiante o docente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.hint),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.onForgot,
    required this.onLogin,
    required this.onDemoTeacher,
    required this.onDemoStudent,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
  });

  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onForgot;
  final VoidCallback onLogin;
  final VoidCallback onDemoTeacher;
  final VoidCallback onDemoStudent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: emailController,
            label: 'Correo institucional o código',
            hint: 'usuario@udla.edu.co o tu código',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: passwordController,
            label: 'Contraseña',
            hint: 'Ingresa tu contraseña',
            icon: Icons.lock_outline,
            isPassword: true,
            trailingWidget: AppLink(
              label: '¿Olvidaste tu contraseña?',
              fontSize: 13,
              underline: false,
              onTap: onForgot,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Iniciar sesión',
            icon: Icons.arrow_forward,
            isLoading: isLoading,
            onPressed: onLogin,
          ),
          // Accesos de demostración: solo en compilaciones de depuración
          // (decisión del equipo; aún no existen cuentas demo).
          if (kDebugMode) ...[
            const SizedBox(height: 22),
            const _DemoDivider(),
            const SizedBox(height: 14),
            _DemoButton(
              icon: Icons.badge_outlined,
              label: 'Demostración: Entrar como Docente',
              color: AppColors.primary,
              onTap: onDemoTeacher,
            ),
            const SizedBox(height: 10),
            _DemoButton(
              icon: Icons.school_outlined,
              label: 'Demostración: Entrar como Estudiante',
              color: AppColors.textDark,
              onTap: onDemoStudent,
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoDivider extends StatelessWidget {
  const _DemoDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.barEmpty)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ACCESOS RÁPIDOS\nDEMO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.barEmpty)),
      ],
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            SizedBox(width: 14),
            Flexible(
              child: Text(
                'Portal Oficial de Autenticación Académica',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.hint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Universidad de la Amazonia',
            style: TextStyle(fontSize: 13, color: AppColors.hint),
          ),
        ),
      ],
    );
  }
}
