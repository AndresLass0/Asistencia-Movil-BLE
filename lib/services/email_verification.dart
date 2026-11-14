import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Verificación del correo de la cuenta actual. Separada en una interfaz
/// para poder probar [EmailVerificationGate] sin Firebase.
abstract class EmailVerifier {
  const EmailVerifier();

  /// Vuelve a consultar el estado en el servidor. Devuelve true si el correo
  /// ya está verificado (y deja el token actualizado para las reglas).
  Future<bool> refresh();

  /// Reenvía el correo con el enlace de verificación.
  Future<void> resend();

  Future<void> signOut();
}

class FirebaseEmailVerifier extends EmailVerifier {
  const FirebaseEmailVerifier();

  static const _timeout = Duration(seconds: 15);

  @override
  Future<bool> refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await user.reload().timeout(_timeout);
    final fresh = FirebaseAuth.instance.currentUser;
    if (fresh == null || !fresh.emailVerified) return false;
    // Las reglas leen `email_verified` del token: hay que renovarlo.
    await fresh.getIdToken(true).timeout(_timeout);
    return true;
  }

  @override
  Future<void> resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.sendEmailVerification().timeout(_timeout);
  }

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
