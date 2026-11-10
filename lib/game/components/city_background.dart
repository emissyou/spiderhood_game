import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Comic book cartoon city skyline background with precomputed static geometries
/// for rock-solid 60 FPS zero-allocation rendering.
class CityBackground extends Component {
  static const Rect _skyRect = Rect.fromLTWH(-5000, -2000, 15000, 4000);
  static final Paint _skyPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF140152),
        Color(0xFF22007C),
        Color(0xFF49117C),
        Color(0xFF8C1D74),
        Color(0xFFD64550),
        Color(0xFFEA7347),
      ],
    ).createShader(_skyRect);

  static final Paint _farSkylinePaint = Paint()..color = const Color(0xFF1B1B3A);
  static final Paint _midSkylinePaint = Paint()..color = const Color(0xFF131221);

  static final Path _farSkylinePath = _buildSkylinePath(-100, 0.7);
  static final Path _midSkylinePath = _buildSkylinePath(50, 1.0);

  static Path _buildSkylinePath(double baseHeight, double scale) {
    final path = Path();
    const double startX = -3000;
    const double endX = 10000;
    double currentX = startX;

    final buildingWidths = [120.0, 180.0, 90.0, 240.0, 150.0, 200.0];
    final buildingHeights = [350.0, 500.0, 280.0, 620.0, 410.0, 550.0];

    int i = 0;
    while (currentX < endX) {
      final w = buildingWidths[i % buildingWidths.length] * scale;
      final h = buildingHeights[i % buildingHeights.length] * scale;
      path.addRect(Rect.fromLTWH(currentX, baseHeight - h, w, h + 1000));
      currentX += w + 8;
      i++;
    }
    return path;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(_skyRect, _skyPaint);
    canvas.drawPath(_farSkylinePath, _farSkylinePaint);
    canvas.drawPath(_midSkylinePath, _midSkylinePaint);
  }
}
