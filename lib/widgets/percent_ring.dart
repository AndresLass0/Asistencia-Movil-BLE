import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Anillo de porcentaje con el valor en el centro. [percent] null = "—".
class PercentRing extends StatelessWidget {
  const PercentRing({
    super.key,
    required this.percent,
    this.size = 88,
    this.strokeWidth = 9,
    this.caption,
    this.fontSize = 21,
  });

  final int? percent;
  final double size;
  final double strokeWidth;
  final String? caption;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: percent == null
          ? 'Sin datos de asistencia'
          : 'Asistencia del $percent por ciento',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: (percent ?? 0) / 100,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.barEmpty,
                color: AppColors.primary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  percent == null ? '—' : '$percent%',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: const TextStyle(fontSize: 10, color: AppColors.hint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
