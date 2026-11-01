import 'package:flutter/material.dart';

/// Círculo central con anillos concéntricos (búsqueda, éxito o error).
class StatusOrb extends StatefulWidget {
  const StatusOrb({
    super.key,
    required this.color,
    this.center,
    this.centerColor,
    this.badge,
    this.size = 220,
    this.animate = false,
  });

  /// Color de los anillos.
  final Color color;

  /// Contenido del círculo central (icono).
  final Widget? center;

  /// Color del círculo central (por defecto [color]).
  final Color? centerColor;

  /// Insignia pequeña arriba a la derecha.
  final Widget? badge;
  final double size;

  /// Si es true, los anillos "laten".
  final bool animate;

  @override
  State<StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<StatusOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _ring(double diameter, double alpha) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: widget.color.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(s * (0.92 + 0.08 * t), 0.08),
              _ring(s * (0.68 + 0.06 * t), 0.14),
              Container(
                width: s * 0.38,
                height: s * 0.38,
                decoration: BoxDecoration(
                  color: widget.centerColor ?? widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: widget.center,
              ),
              if (widget.badge != null)
                Positioned(top: s * 0.12, right: s * 0.2, child: widget.badge!),
            ],
          ),
        );
      },
    );
  }
}
