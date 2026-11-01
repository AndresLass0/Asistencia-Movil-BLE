import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/demo_backend.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Decide la pantalla según el estado de la sesión.
/// Firebase restaura la sesión guardada en el dispositivo automáticamente,
/// por eso el usuario no tiene que iniciar sesión cada vez que abre la app.
///
/// Usa `userChanges()` (y no solo `authStateChanges()`) para reconstruir
/// también cuando cambia el perfil, p. ej. el nombre recién registrado.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(
            uid: user.uid,
            email: user.email ?? '',
            authDisplayName: user.displayName ?? '',
          );
        }
        // Modo demostración (solo depuración): vistas reales con datos de
        // ejemplo en memoria; "Cerrar sesión" vuelve al Login.
        return ValueListenableBuilder<bool>(
          valueListenable: DemoMode.active,
          builder: (context, demo, _) =>
              kDebugMode && demo && DemoMode.backend != null
              ? HomeScreen(
                  key: const ValueKey('demo'),
                  uid: DemoStudentBackend.uid,
                  email: DemoStudentBackend.email,
                  authDisplayName: DemoStudentBackend.name,
                  backend: DemoMode.backend!,
                )
              : const LoginScreen(),
        );
      },
    );
  }
}
