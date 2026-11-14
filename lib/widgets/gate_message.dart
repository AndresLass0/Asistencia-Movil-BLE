import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'primary_button.dart';

/// Pantalla completa de aviso que bloquea el acceso hasta que el usuario
/// resuelva algo (verificar su correo, esperar autorización, reintentar).
/// Siempre ofrece "Cerrar sesión" para volver al Login.
class GateMessage extends StatelessWidget {
  const GateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
    this.retryLabel = 'Reintentar',
    this.retrying = false,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;
  final String retryLabel;

  /// Muestra el indicador de carga en el botón principal.
  final bool retrying;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.chip,
                  child: Icon(icon, size: 38, color: AppColors.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: retryLabel,
                  icon: Icons.refresh,
                  iconOnLeft: true,
                  isLoading: retrying,
                  onPressed: onRetry,
                ),
                if (extra != null) ...[const SizedBox(height: 10), extra!],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
