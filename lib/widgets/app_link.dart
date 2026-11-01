import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Enlace de texto pulsable con semántica de botón y área táctil ampliada.
class AppLink extends StatelessWidget {
  const AppLink({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 14,
    this.underline = true,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
