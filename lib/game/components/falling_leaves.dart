import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/config/game_config.dart';

class _LeafParticle {
  Vector2 pos;
  double vx;
  double vy;
  double size;
  Color color;
  double flutterPhase;
  double flutterSpeed;
  double flutterAmp;
  double rotSpeed;
  double lifetime;
  double maxLifetime;
  int treeIndex;

  _LeafParticle({
    required this.pos,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.flutterPhase,
    required this.flutterSpeed,
    required this.flutterAmp,
    required this.rotSpeed,
    required this.lifetime,
    required this.maxLifetime,
    required this.treeIndex,
  });
}

/// Particle system for delicate leaves that spawn ONLY directly at the sidewalk trees.
class FallingLeavesSystem extends Component with HasGameReference {
  // Verified exact tree foliage canopy positions on the sidewalk in new_york_morning.png
  static final List<Vector2> treeCanopies = [
    Vector2(232, 580),
    Vector2(378, 580),
    Vector2(1414, 580),
    Vector2(1542, 580),
    Vector2(1698, 580),
    Vector2(1848, 580),
    Vector2(2060, 575),
  ];

  static const List<Color> leafColors = [
    Color(0xFFF59E0B), // Golden amber
    Color(0xFFD97706), // Warm orange
    Color(0xFF10B981), // Fresh green
    Color(0xFF059669), // Deep green
    Color(0xFFEF4444), // Maple red
    Color(0xFFEAB308), // Yellow
  ];

  final math.Random _random = math.Random();
  final List<_LeafParticle> _leaves = [];
  static const int totalLeaves = 24;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize small delicate leaves distributed across the 7 verified trees
    for (int i = 0; i < totalLeaves; i++) {
      final treeIdx = i % treeCanopies.length;
      final leaf = _createLeaf(treeIdx, randomInitialProgress: true);
      _leaves.add(leaf);
    }
  }

  _LeafParticle _createLeaf(int treeIdx, {bool randomInitialProgress = false}) {
    final canopy = treeCanopies[treeIdx];
    // Spawn strictly within the tree canopy cluster (tight ±10px spread)
    final startX = canopy.x + (_random.nextDouble() - 0.5) * 18.0;
    final startY = randomInitialProgress
        ? canopy.y + _random.nextDouble() * (GameConfig.groundY - canopy.y)
        : canopy.y + (_random.nextDouble() - 0.5) * 15.0;

    return _LeafParticle(
      pos: Vector2(startX, startY),
      vx: 8.0 + _random.nextDouble() * 8.0, // gentle breeze
      vy: 14.0 + _random.nextDouble() * 10.0, // gentle fall
      size: 1.6 + _random.nextDouble() * 0.9, // small, delicate leaf scale
      color: leafColors[_random.nextInt(leafColors.length)],
      flutterPhase: _random.nextDouble() * math.pi * 2,
      flutterSpeed: 2.2 + _random.nextDouble() * 1.5,
      flutterAmp: 10.0 + _random.nextDouble() * 8.0,
      rotSpeed: 1.5 + _random.nextDouble() * 1.8,
      lifetime: randomInitialProgress ? _random.nextDouble() * 5.0 : 0.0,
      maxLifetime: 6.0 + _random.nextDouble() * 2.5,
      treeIndex: treeIdx,
    );
  }

  void _resetLeaf(_LeafParticle leaf, int treeIdx) {
    final canopy = treeCanopies[treeIdx];
    final startX = canopy.x + (_random.nextDouble() - 0.5) * 18.0;
    final startY = canopy.y + (_random.nextDouble() - 0.5) * 15.0;
    leaf.pos.setValues(startX, startY);
    leaf.vx = 8.0 + _random.nextDouble() * 8.0;
    leaf.vy = 14.0 + _random.nextDouble() * 10.0;
    leaf.lifetime = 0.0;
    leaf.maxLifetime = 6.0 + _random.nextDouble() * 2.5;
    leaf.treeIndex = treeIdx;
  }

  @override
  void update(double dt) {
    super.update(dt);

    for (int i = 0; i < _leaves.length; i++) {
      final leaf = _leaves[i];
      leaf.lifetime += dt;

      // Sinusoidal wind flutter
      final flutterX = math.sin(leaf.lifetime * leaf.flutterSpeed + leaf.flutterPhase) * leaf.flutterAmp;
      leaf.pos.x += (leaf.vx + flutterX) * dt;
      leaf.pos.y += leaf.vy * dt;

      // Respawn in place strictly at the next tree when reaching the sidewalk or expiring
      if (leaf.pos.y >= GameConfig.groundY || leaf.lifetime >= leaf.maxLifetime) {
        _resetLeaf(leaf, (leaf.treeIndex + 1) % treeCanopies.length);
      }
    }
  }

  final Paint _leafPaint = Paint()..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final visible = game.camera.visibleWorldRect;

    for (final leaf in _leaves) {
      // Viewport culling: only render leaves within the active camera view
      if (leaf.pos.x < visible.left - 20 || leaf.pos.x > visible.right + 20) {
        continue;
      }

      final distToGround = GameConfig.groundY - leaf.pos.y;
      final alpha = (distToGround / 25.0).clamp(0.0, 1.0);

      _leafPaint.color = leaf.color.withValues(alpha: alpha);

      final rw = leaf.size * 0.8;
      final rh = leaf.size * 1.4;
      canvas.drawOval(
        Rect.fromLTRB(leaf.pos.x - rw, leaf.pos.y - rh, leaf.pos.x + rw, leaf.pos.y + rh),
        _leafPaint,
      );
    }
  }
}
