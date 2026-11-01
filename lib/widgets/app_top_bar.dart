import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// Barra superior con flecha de regreso, título y (opcionalmente) el avatar.
/// En pantallas sin sesión iniciada usa `showAvatar: false`.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.backLabel,
    this.centerTitle = false,
    this.showAvatar = true,
  });

  final String title;

  /// Si se indica, se muestra "← Volver" en lugar de solo la flecha.
  final String? backLabel;
  final bool centerTitle;
  final bool showAvatar;

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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.maybePop(context),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back, size: 24),
                      if (backLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          backLabel!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: centerTitle ? 0 : 20),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: centerTitle
                          ? TextAlign.center
                          : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (showAvatar) const UserAvatar(size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
