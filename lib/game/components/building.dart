import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Platform / Building component in comic-book cel-shaded style.
/// Contains a solid hitbox for player and enemy collisions with cached geometries.
class Building extends PositionComponent with CollisionCallbacks {
  final Color wallColor;
  final Color roofColor;

  static final Paint _windowPaint = Paint()..color = const Color(0xFFFFD166);
  static final Paint _winBorderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _outlinePaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;

  late final Paint _wallPaint;
  late final Paint _roofPaint;
  late final Rect _rect;
  late final Rect _roofRect;
  final Path _windowsPath = Path();

  Building({
    required Vector2 position,
    required Vector2 size,
    this.wallColor = const Color(0xFF1F2438),
    this.roofColor = const Color(0xFF6B728E),
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Solid rectangular hitbox for collision detection
    add(RectangleHitbox(collisionType: CollisionType.passive));

    _wallPaint = Paint()..color = wallColor;
    _roofPaint = Paint()..color = roofColor;
    _rect = Rect.fromLTWH(0, 0, size.x, size.y);
    const roofHeight = 12.0;
    _roofRect = Rect.fromLTWH(0, 0, size.x, roofHeight);

    const winW = 20.0;
    const winH = 28.0;
    const spacingX = 36.0;
    const spacingY = 48.0;

    for (double x = 24.0; x <= size.x - 30.0; x += spacingX) {
      for (double y = 30.0; y <= size.y - 30.0; y += spacingY) {
        _windowsPath.addRect(Rect.fromLTWH(x, y, winW, winH));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.drawRect(_rect, _wallPaint);
    canvas.drawPath(_windowsPath, _windowPaint);
    canvas.drawPath(_windowsPath, _winBorderPaint);
    canvas.drawRect(_roofRect, _roofPaint);
    canvas.drawRect(_rect, _outlinePaint);
    canvas.drawRect(_roofRect, _outlinePaint);
  }
}
