import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Aviso fijo del modo demostración (solo depuración): los datos son de
/// ejemplo y nada se guarda en el servidor.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.textDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo demostración: datos de ejemplo, no se guardan.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
