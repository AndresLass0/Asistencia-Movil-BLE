import 'package:flutter/material.dart';

import '../../core/ui_messages.dart';
import '../../services/teacher_backend.dart';
import '../../widgets/gate_message.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/state_views.dart';
import 'teacher_home_screen.dart';

/// Comprueba que la cuenta con rol docente esté autorizada antes de mostrar
/// la vista del docente: correo en `teachers/{correo}` (lo administra la
/// institución desde la consola) y correo verificado.
///
/// Es solo la experiencia de uso: la autorización real la aplican las
/// reglas de Firestore (`isTeacher()`).
class TeacherGate extends StatefulWidget {
  const TeacherGate({
    super.key,
    required this.uid,
    required this.email,
    this.authDisplayName = '',
    this.backend = const FirebaseTeacherBackend(),
  });

  final String uid;
  final String email;
  final String authDisplayName;
  final TeacherBackend backend;

  @override
  State<TeacherGate> createState() => _TeacherGateState();
}

class _TeacherGateState extends State<TeacherGate> {
  late Future<TeacherAccess> _access = widget.backend.checkAccess();
  bool _sending = false;

  void _retry() => setState(() => _access = widget.backend.checkAccess());

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await widget.backend.sendVerificationEmail();
      if (mounted) {
        showAppMessage(
          context,
          'Te enviamos un correo de verificación a ${widget.email}.',
        );
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo enviar el correo. Espera unos minutos e inténtalo de '
          'nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherAccess>(
      future: _access,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: LoadingView(message: 'Verificando tu cuenta docente…'),
          );
        }
        if (snap.hasError) {
          return GateMessage(
            icon: Icons.cloud_off,
            title: 'No pudimos verificar tu cuenta',
            message:
                'Revisa tu conexión a internet. Si el problema continúa, '
                'es posible que las reglas de la base de datos no estén '
                'publicadas.',
            onRetry: _retry,
            onSignOut: widget.backend.signOut,
          );
        }
        switch (snap.data!) {
          case TeacherAccess.authorized:
            return TeacherHomeScreen(
              uid: widget.uid,
              email: widget.email,
              authDisplayName: widget.authDisplayName,
              backend: widget.backend,
            );
          case TeacherAccess.emailNotVerified:
            return GateMessage(
              icon: Icons.mark_email_unread_outlined,
              title: 'Verifica tu correo',
              message:
                  'Para usar las funciones de docente debes confirmar tu '
                  'correo ${widget.email}. Abre el enlace que te enviamos y '
                  'luego pulsa "Ya lo verifiqué".',
              retryLabel: 'Ya lo verifiqué',
              onRetry: _retry,
              extra: SecondaryButton(
                label: _sending ? 'Enviando…' : 'Reenviar correo',
                icon: Icons.send_outlined,
                onPressed: _sending ? () {} : _resend,
              ),
              onSignOut: widget.backend.signOut,
            );
          case TeacherAccess.notAuthorized:
            return GateMessage(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Cuenta docente pendiente de autorización',
              message:
                  'Tu correo ${widget.email} no está en la lista de docentes '
                  'autorizados de BioAsistencia. Solicita a la administración '
                  'que lo habilite y vuelve a comprobar.',
              retryLabel: 'Volver a comprobar',
              onRetry: _retry,
              onSignOut: widget.backend.signOut,
            );
        }
      },
    );
  }
}
