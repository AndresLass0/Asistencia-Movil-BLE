import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Barra inferior del docente: Clases · Historial · Reportes · Perfil.
///
/// Índices: 0 Clases, 1 Historial, 2 Reportes, 3 Perfil. (La sesión activa
/// se abre desde Clases; no es una pestaña.)
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const classesIndex = 0;
  static const historyIndex = 1;
  static const reportsIndex = 2;
  static const profileIndex = 3;

  static const _items = [
    (Icons.school_outlined, Icons.school, 'Clases'),
    (Icons.history_edu_outlined, Icons.history_edu, 'Historial'),
    (Icons.analytics_outlined, Icons.analytics, 'Reportes'),
    (Icons.badge_outlined, Icons.badge, 'Perfil'),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == currentIndex,
                    button: true,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == currentIndex ? _items[i].$2 : _items[i].$1,
                            size: 25,
                            color: i == currentIndex
                                ? AppColors.primary
                                : AppColors.hint,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _items[i].$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: i == currentIndex
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == currentIndex
                                  ? AppColors.primary
                                  : AppColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
