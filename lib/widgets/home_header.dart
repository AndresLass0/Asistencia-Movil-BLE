import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'brand_logo.dart';
import 'status_chip.dart';
import 'user_avatar.dart';

/// Cabecera de las pestañas principales: logo, título, sede (si el usuario
/// la registró), campana de sesiones abiertas y avatar.
class HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeader({
    super.key,
    required this.subtitle,
    this.campus = '',
    this.pendingSessions = 0,
    this.onNotifications,
  });

  final String subtitle;

  /// Sede registrada en el perfil; vacía = no se muestra el chip.
  final String campus;

  /// Sesiones abiertas en las que aún no se registró asistencia.
  final int pendingSessions;
  final VoidCallback? onNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const BrandLogo(size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BioAsistencia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Ancho limitado: el nombre de la app tiene prioridad.
                if (campus.trim().isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 104),
                    child: StatusChip(
                      label: campus.trim(),
                      background: AppColors.grayChip,
                      foreground: AppColors.hint,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: pendingSessions > 0
                      ? 'Sesiones abiertas: $pendingSessions'
                      : 'Sin sesiones abiertas',
                  onPressed: onNotifications,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none, size: 26),
                      if (pendingSessions > 0)
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const UserAvatar(size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
