import 'package:firebase_auth/firebase_auth.dart';

const kInvalidCredentialsMessage = 'Correo/código o contraseña incorrectos.';

/// Traduce los códigos de error de FirebaseAuth a mensajes para el usuario.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'El correo no tiene un formato válido.';
    case 'user-disabled':
      return 'Esta cuenta ha sido deshabilitada.';
    // Las versiones recientes devuelven invalid-credential tanto para
    // correo inexistente como para contraseña incorrecta.
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return kInvalidCredentialsMessage;
    case 'email-already-in-use':
      // Si el correo es tuyo y no creaste esa cuenta, "¿Olvidaste tu
      // contraseña?" envía el enlace a tu buzón y la recuperas.
      return 'Ya existe una cuenta registrada con ese correo. Si es tuyo, '
          'usa "¿Olvidaste tu contraseña?" en el inicio de sesión para '
          'recuperarla.';
    case 'weak-password':
      return 'La contraseña es muy débil. Usa al menos 8 caracteres.';
    case 'operation-not-allowed':
      return 'El acceso con correo y contraseña no está habilitado.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
    default:
      return 'No se pudo completar la operación (${e.code}).';
  }
}

/// Mensajes para errores de Cloud Firestore (perfiles y códigos).
String firestoreErrorMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'No tienes permiso para esta operación. Si el problema '
          'continúa, contacta al administrador.';
    case 'unavailable':
      return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
    default:
      return 'No se pudo completar la operación (${e.code}).';
  }
}
