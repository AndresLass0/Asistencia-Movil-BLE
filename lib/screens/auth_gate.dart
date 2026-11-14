import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import 'email_verification_gate.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'teacher/teacher_gate.dart';

/// Decide la pantalla según el estado de la sesión.
/// Firebase restaura la sesión guardada en el dispositivo automáticamente,
/// por eso el usuario no tiene que iniciar sesión cada vez que abre la app.
///
/// Usa `userChanges()` (y no solo `authStateChanges()`) para reconstruir
/// también cuando cambia el perfil, p. ej. el nombre recién registrado.
///
/// Es el **único** que alterna entre Login y la vista principal. Con sesión,
/// [EmailVerificationGate] exige el correo verificado y después [RoleGate]
/// elige la vista del estudiante o la del docente.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return EmailVerificationGate(
          key: ValueKey('verify-${user.uid}'),
          email: user.email ?? '',
          verified: user.emailVerified,
          child: RoleGate(user: user),
        );
      },
    );
  }
}

/// Elige la vista según el rol guardado en `users/{uid}`.
///
/// El rol del perfil solo decide qué pantalla mostrar; los permisos de
/// docente los concede la institución (`teachers/{correo}`) y los aplican
/// las reglas. Sin perfil (o si no se puede leer) se muestra la vista del
/// estudiante, como antes.
class RoleGate extends StatelessWidget {
  const RoleGate({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      key: ValueKey(user.uid),
      stream: UserProfileService.watch(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (!snap.hasError && snap.data?.role == UserRole.teacher) {
          return TeacherGate(
            key: ValueKey('teacher-${user.uid}'),
            uid: user.uid,
            email: user.email ?? '',
            authDisplayName: user.displayName ?? '',
          );
        }
        return HomeScreen(
          uid: user.uid,
          email: user.email ?? '',
          authDisplayName: user.displayName ?? '',
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
