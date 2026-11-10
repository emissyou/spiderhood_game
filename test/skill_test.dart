import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/actors/civilian.dart';
import 'package:spideyhood/game/actors/enemies/thug.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/city_lamp.dart';
import 'package:spideyhood/game/components/city_weather.dart';
import 'package:spideyhood/game/components/falling_leaves.dart';
import 'package:spideyhood/game/components/taxi.dart';
import 'package:spideyhood/game/components/web_ammo.dart';
import 'package:spideyhood/game/components/web_mark.dart';
import 'package:spideyhood/game/config/game_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Spidey punch, kick, and skill1 state transitions', () {
    final spidey = Spidey(position: Vector2(100, 726));
    expect(spidey.state, equals(SpideyState.idle));

    // Punch
    spidey.punch();
    expect(spidey.state, equals(SpideyState.attacking));
    spidey.update(Spidey.punchDuration + 0.1);
    expect(spidey.state, equals(SpideyState.idle));

    // Kick
    spidey.kick();
    expect(spidey.state, equals(SpideyState.kicking));
    spidey.update(Spidey.kickDuration + 0.1);
    expect(spidey.state, equals(SpideyState.idle));

    // Skill 1
    spidey.useSkill1();
    expect(spidey.state, equals(SpideyState.skill1));
  });

  test('Double jump performs airborne acrobat leap', () {
    final spidey = Spidey(position: Vector2(100, 726));
    spidey.isGrounded = true;

    // 1st jump -> airborne jumping
    spidey.jump();
    expect(spidey.state, equals(SpideyState.jumping));
    expect(spidey.velocity.y, equals(GameConfig.jumpVelocity));

    // 2nd jump in mid-air -> acrobat double jump leap
    spidey.jump();
    expect(spidey.state, equals(SpideyState.jumping));
    expect(spidey.velocity.y, closeTo(GameConfig.jumpVelocity * 0.88, 0.01));
  });

  test('Combat damage profiles on Thug and ViperGuard', () {
    final thug = Thug(position: Vector2(200, 726));
    expect(thug.health, equals(GameConfig.thugMaxHealth));

    // Punch damage: 18
    thug.takeDamage(18, 1.0);
    expect(thug.health, equals(GameConfig.thugMaxHealth - 18));

    // Update cooldown debounce
    thug.update(0.3);

    // Kick damage: 32
    thug.takeDamage(32, 1.0);
    expect(thug.health, equals(GameConfig.thugMaxHealth - 18 - 32));

    // ViperGuard damage & sustain (7 punches to defeat, web shot deals 2 dmg)
    final guard = ViperGuard(position: Vector2(300, 726));
    expect(guard.health, equals(ViperGuard.maxHp));

    // Web ammo damage: 2
    guard.hitByWeb(1.0);
    expect(guard.health, equals(ViperGuard.maxHp - 2));
  });

  test('WebAmmo advances and expires after max distance', () {
    final ammo = WebAmmo(
      position: Vector2(100, 700),
      direction: 1.0,
      speed: 600.0,
      maxDistance: 600.0,
    );

    expect(ammo.position.x, equals(100));
    ammo.update(0.5); // moves 300px
    expect(ammo.position.x, equals(400));
  });

  test('WebMark initializes and runs down 7s dissolve timer', () {
    final mark = WebMark(position: Vector2(300, 200));
    expect(WebMark.duration, equals(7.0));

    // Update 3.5 seconds
    mark.update(3.5);
    expect(mark.isMounted, isFalse);
  });

  test('Civilian stays at player ground level and walks horizontally', () {
    final civ = Civilian(
      position: Vector2(200, GameConfig.groundY),
      direction: 1.0,
      speed: 50.0,
    );

    expect(civ.position.y, equals(GameConfig.groundY));
    civ.update(1.0);
    expect(civ.position.x, equals(250.0));
    expect(civ.position.y, equals(GameConfig.groundY));
  });

  test('Taxi stays below ground level and loops around road', () {
    final taxi = Taxi(
      position: Vector2(GameConfig.bgWidth + 100, 750.0),
      direction: 1.0,
      baseSpeed: 100.0,
    );

    expect(taxi.position.y, equals(750.0));
    expect(taxi.size.x, equals(88.0));
    expect(taxi.size.y, equals(44.0));
    // Updating moves past buffer (> bgWidth + 120), so it wraps to -120
    taxi.update(0.5);
    expect(taxi.position.x, equals(-120.0));
    expect(taxi.position.y, equals(750.0));
  });

  test('CityLamp, FallingLeavesSystem, and CityWeather update properly', () async {
    final lamp = CityLamp(position: Vector2(127, 588));
    lamp.update(0.5);

    final leaves = FallingLeavesSystem();
    await leaves.onLoad();
    leaves.update(0.5);

    final weather = CityWeather();
    await weather.onLoad();
    weather.update(0.5);
  });
}
