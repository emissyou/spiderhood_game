import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/config/game_config.dart';

/// Weather & Sky Environment component:
/// - Morning atmospheric sunbeams
/// - Floating ambient light motes
class CityWeather extends Component {
  double _time = 0.0;

  static final Paint _motePaint = Paint();

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Light sparkling motes only (0 heavy screen-wide shader overdraw)
    _renderDustMotes(canvas);
  }

  void _renderDustMotes(Canvas canvas) {
    // 15 floating sparkling motes in the morning air
    for (int i = 0; i < 16; i++) {
      final moteX = (i * 137.0 + _time * 16.0) % GameConfig.bgWidth;
      final moteY = 80.0 + (i * 41.0 + math.sin(_time * 1.4 + i) * 25.0) % 520.0;
      final moteAlpha = 0.25 + (math.sin(_time * 2.5 + i) + 1.0) * 0.2;

      _motePaint.color = const Color(0xFFFEF08A).withValues(alpha: moteAlpha.clamp(0.0, 0.7));
      canvas.drawCircle(Offset(moteX, moteY), 1.2, _motePaint);
    }
  }
}
