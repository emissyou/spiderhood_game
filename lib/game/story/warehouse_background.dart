import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders the wide Abandoned Warehouse environment scaled proportionally to character size (2048 x 508).
class WarehouseBackground extends PositionComponent {
  static const double warehouseWidth = 2048.0;
  static const double warehouseHeight = 508.0;

  Sprite? _bgSprite;
  late final Paint _ambientVignette;
  static const Rect _boundsRect = Rect.fromLTWH(0, 0, warehouseWidth, warehouseHeight);

  WarehouseBackground()
      : super(
          position: Vector2.zero(),
          size: Vector2(warehouseWidth, warehouseHeight),
        ) {
    _ambientVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.45),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(_boundsRect);
  }

  static final Paint _fallbackDarkPaint = Paint()..color = const Color(0xFF13151D);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _bgSprite = await Sprite.load('environment/abandon_warehouse.jpg');
    } catch (_) {
      try {
        _bgSprite = await Sprite.load('environment/abandon_warehouse.png');
      } catch (_) {}
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_bgSprite != null) {
      _bgSprite!.render(
        canvas,
        size: Vector2(warehouseWidth, warehouseHeight),
      );
    } else {
      // Fallback industrial dark background
      canvas.drawRect(_boundsRect, _fallbackDarkPaint);
    }

    // Atmospheric industrial vignette & subtle dark shadows (cached)
    canvas.drawRect(_boundsRect, _ambientVignette);
  }
}
