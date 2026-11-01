import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Campo de texto con etiqueta, icono, ayuda opcional y botón "ver contraseña".
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.trailingLabel,
    this.trailingLabelColor = AppColors.textMuted,
    this.trailingWidget,
    this.helper,
    this.helperIcon,
    this.isPassword = false,
    this.keyboardType,
    this.suffix,
    this.onChanged,
    this.enabled = true,
  });

  /// Si está vacío, no se dibuja la fila de etiqueta.
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;

  /// Texto pequeño a la derecha de la etiqueta (ej. "Requerido").
  final String? trailingLabel;
  final Color trailingLabelColor;

  /// Widget a la derecha de la etiqueta (ej. enlace "¿Olvidaste...?").
  final Widget? trailingWidget;

  final String? helper;
  final IconData? helperIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  /// Si es false, el campo se muestra atenuado y no admite edición.
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.trailingWidget != null) widget.trailingWidget!,
              if (widget.trailingLabel != null)
                Text(
                  widget.trailingLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.trailingLabelColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: widget.enabled ? Colors.white : AppColors.grayChip,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            obscureText: widget.isPassword && _obscure,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 15,
                color: AppColors.hint.withValues(alpha: 0.85),
              ),
              prefixIcon: Icon(widget.icon, color: AppColors.textMuted),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : widget.suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.helperIcon != null) ...[
                Icon(widget.helperIcon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.helper!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
