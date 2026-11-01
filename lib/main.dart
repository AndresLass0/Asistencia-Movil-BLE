import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/app_colors.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart'; // generado por `flutterfire configure`
import 'screens/auth_gate.dart';

Future<void> main() async {
  // Necesario antes de usar plugins/Firebase y antes de runApp().
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Plataforma sin configuración de Firebase (p. ej. Linux/macOS) u otro
    // fallo de inicio: se muestra un aviso en lugar de cerrar la app.
    runApp(StartupErrorApp(error: e));
    return;
  }
  runApp(const BioAsistenciaApp());
}

class BioAsistenciaApp extends StatelessWidget {
  const BioAsistenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioAsistencia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // AuthGate es el único que decide: sesión activa -> Home, sin sesión ->
      // Login. Las pantallas no navegan manualmente al iniciar/cerrar sesión.
      home: const AuthGate(),
      routes: AppRoutes.table,
    );
  }
}

/// Pantalla mínima cuando Firebase no pudo inicializarse.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioAsistencia',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 56,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo iniciar BioAsistencia',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esta plataforma no está configurada o no hay conexión '
                    'con el servicio.\n\nDetalle: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
