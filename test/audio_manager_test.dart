import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/services/audio_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('AudioManager Tests', () {
    test('AudioManager initializes with default track and volume', () {
      final audio = AudioManager.instance;
      expect(audio.isMuted, isFalse);
      expect(audio.volume, 0.65);
    });

    test('AudioManager toggleMute toggles mute state', () async {
      final audio = AudioManager.instance;
      expect(audio.isMuted, isFalse);

      await audio.toggleMute();
      expect(audio.isMuted, isTrue);

      await audio.toggleMute();
      expect(audio.isMuted, isFalse);
    });

    test('AudioManager SFX methods execute cleanly without throwing', () {
      final audio = AudioManager.instance;
      expect(() => audio.playWebShoot(), returnsNormally);
      expect(() => audio.playPunch(), returnsNormally);
      expect(() => audio.playJump(), returnsNormally);
      expect(() => audio.playSwing(), returnsNormally);
      expect(() => audio.playButtonClick(), returnsNormally);
    });

    test('AudioManager sound pools contain at least 3 to 4 variations each', () {
      expect(AudioManager.webShootPool.length, greaterThanOrEqualTo(4));
      expect(AudioManager.punchPool.length, greaterThanOrEqualTo(4));
      expect(AudioManager.jumpPool.length, greaterThanOrEqualTo(4));
      expect(AudioManager.swingPool.length, greaterThanOrEqualTo(4));
      expect(AudioManager.buttonClickPool.length, greaterThanOrEqualTo(3));
    });

    test('AudioManager repeated SFX calls cycle variations without error', () {
      final audio = AudioManager.instance;
      for (int i = 0; i < 8; i++) {
        expect(() => audio.playWebShoot(), returnsNormally);
        expect(() => audio.playPunch(), returnsNormally);
        expect(() => audio.playJump(), returnsNormally);
        expect(() => audio.playSwing(), returnsNormally);
      }
    });
  });
}
