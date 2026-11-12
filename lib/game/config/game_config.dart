import 'package:flame/extensions.dart';

/// Central game configuration constants for Spideyhood.
class GameConfig {
  GameConfig._();

  // World physics
  static final Vector2 gravity = Vector2(0, 1400);

  // Exact bounds matching new_york_morning.png (no infinite loop)
  static const double bgWidth = 2086.0;
  static const double bgHeight = 754.0;

  // Exact sidewalk pavement level (where trees and lamps are rooted)
  // Completely grounded: Spidey walks firmly on the sidewalk (no floating)
  static const double groundY = 726.0;

  // Camera zoom & responsive viewport settings
  // Base visible world height captured from the reference screenshot (531px / 3.3 = 160.91).
  // Locking this visible height guarantees 100% identical frame height & visible area on PC and mobile.
  static const double targetVisibleHeight = 160.91;
  static const double streetZoom = 3.3; // Default baseline close-up street view
  static const double swingZoom = 1.65; // Smooth zoom-out when web-swinging
  static const double maxSwingZoomOut = 1.65; // Maximum wide zoom-out limit when web-swinging

  /// Calculates responsive zoom that guarantees exact same visible world height across any screen size.
  static double responsiveStreetZoom(double screenHeight) {
    if (screenHeight <= 0) return streetZoom;
    return screenHeight / targetVisibleHeight;
  }

  /// Calculates responsive swing zoom proportional to screen height.
  static double responsiveSwingZoom(double screenHeight) {
    if (screenHeight <= 0) return maxSwingZoomOut;
    return (screenHeight / targetVisibleHeight) * 0.5;
  }

  // Player dimensions: scaled smaller
  static final Vector2 playerSize = Vector2(22, 38);
  static const double walkSpeed = 115.0; // Comfortable, grounded sidewalk walk speed (less sensitive)
  static const double runSpeed = 115.0;  // Kept for backwards compatibility
  static const double jumpVelocity = -470.0;
  static const double wallSlideSpeed = 120.0;

  // Web-swinging mechanics (weighty, snappy pendulum physics)
  static const double maxWebDistance = 650.0;
  static const double swingGravity = 2800.0;
  static const double swingDamping = 0.9985;
  static const double swingBoostImpulse = 460.0;

  // Combat
  static const double attackRange = 55.0;
  static const int playerMaxHealth = 100;
  static const int thugMaxHealth = 30;

  // Testing & Developer cheats
  // Godmode enabled for user testing: Spidey takes 0 damage, infinite web fluid, instant skill cooldown
  static bool godMode = true;

  // Visuals & Comic FX
  static const double comicFxDuration = 0.65;
}
