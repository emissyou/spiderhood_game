import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Small floating damage number (e.g. "18", "32", or custom label like "SHIELDED").
class DamageNumber extends PositionComponent {
  final int amount;
  final String? label;
  final Color color;
  final double maxDuration;

  double _elapsed = 0.0;

  DamageNumber({
    required this.amount,
    this.label,
    required Vector2 position,
    this.color = const Color(0xFFFDE047),
    this.maxDuration = 0.55,
  }) : super(
          position: position,
          size: Vector2(36, 14),
          anchor: Anchor.center,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y -= dt * 30.0; // Floats upward gently

    if (_elapsed >= maxDuration) {
      Future.microtask(() {
        if (isMounted) removeFromParent();
      });
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final opacity = (1.0 - (_elapsed / maxDuration)).clamp(0.0, 1.0);

    final text = label ?? '$amount';
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: label != null ? 8.5 : 10.0,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: opacity),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
