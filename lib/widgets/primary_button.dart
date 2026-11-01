import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Botón verde ancho con texto e icono (a la derecha, o a la izquierda
/// con [iconOnLeft]). Con [isLoading] muestra un indicador y se deshabilita.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.iconOnLeft = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool iconOnLeft;

  @override
  Widget build(BuildContext context) {
    final iconWidget = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Icon(icon, size: 20, color: Colors.white);
    final text = Flexible(
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FilledButton(
        // Deshabilitado mientras carga: evita múltiples envíos.
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: iconOnLeft
              ? [iconWidget, const SizedBox(width: 10), text]
              : [text, const SizedBox(width: 10), iconWidget],
        ),
      ),
    );
  }
}
