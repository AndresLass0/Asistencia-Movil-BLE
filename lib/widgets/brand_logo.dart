import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Logo de BioAsistencia (huella dentro de un cuadro redondeado).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.fingerprint,
        color: AppColors.primary,
        size: size * 0.65,
      ),
    );
  }
}
