import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/auth_messages.dart';
import '../core/ui_messages.dart';
import '../services/email_verification.dart';
import '../widgets/gate_message.dart';
import '../widgets/secondary_button.dart';

/// Exige el correo verificado antes de mostrar [child] (estudiantes y
/// docentes). Así se comprueba que quien usa la cuenta es dueño del correo
/// institucional: el enlace solo llega a su buzón.
///
/// Es la experiencia de uso; las reglas de Firestore también exigen
/// `email_verified` para leer asignaturas y registrar asistencia.
class EmailVerificationGate extends StatefulWidget {
  const EmailVerificationGate({
    super.key,
    required this.email,
    required this.verified,
    required this.child,
    this.verifier = const FirebaseEmailVerifier(),
  });

  final String email;

  /// Estado conocido al construir (p. ej. `User.emailVerified`).
  final bool verified;
  final Widget child;
  final EmailVerifier verifier;

  @override
  State<EmailVerificationGate> createState() => _EmailVerificationGateState();
}

class _EmailVerificationGateState extends State<EmailVerificationGate> {
  late bool _verified = widget.verified;
  bool _checking = false;
  bool _sending = false;

  @override
  void didUpdateWidget(EmailVerificationGate old) {
    super.didUpdateWidget(old);
    if (widget.verified && !_verified) _verified = true;
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final ok = await widget.verifier.refresh();
      if (!mounted) return;
      if (ok) {
        setState(() => _verified = true);
      } else {
        showAppMessage(
          context,
          'Tu correo aún no aparece como verificado. Abre el enlace que te '
          'enviamos (revisa también la carpeta de spam) y vuelve a intentarlo.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppMessage(context, authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'No pudimos comprobar tu correo. Revisa tu conexión e inténtalo de '
          'nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.verifier.resend();
      if (mounted) {
        showAppMessage(
          context,
          'Te enviamos un nuevo correo de verificación a ${widget.email}.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppMessage(context, authErrorMessage(e));
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
    if (_verified) return widget.child;
    return GateMessage(
      icon: Icons.mark_email_unread_outlined,
      title: 'Verifica tu correo',
      message:
          'Te enviamos un enlace a ${widget.email}. Ábrelo para confirmar que '
          'el correo es tuyo y luego pulsa "Ya lo verifiqué". Si no lo ves, '
          'revisa la carpeta de spam.',
      retryLabel: 'Ya lo verifiqué',
      retrying: _checking,
      onRetry: _check,
      onSignOut: widget.verifier.signOut,
      extra: SecondaryButton(
        label: _sending ? 'Enviando…' : 'Reenviar correo',
        icon: Icons.send_outlined,
        onPressed: _sending ? () {} : _resend,
      ),
    );
  }
}
