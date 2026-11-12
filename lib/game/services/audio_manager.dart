import 'dart:math' as math;
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'web_audio_interface.dart';

/// Central background music & audio service for Spideyhood.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final math.Random _random = math.Random();

  bool isMuted = false;
  bool _isPlaying = false;
  bool _isStartingBgm = false;
  double _volume = 0.65;
  String _currentTrack = 'bgm/background_music.mp3';

  // Dedicated AudioPlayer tracking for single-stream background music
  AudioPlayer? _bgmPlayer;

  // Last played index tracking to prevent back-to-back duplicate sounds
  int _lastWebShootIndex = -1;
  int _lastPunchIndex = -1;
  int _lastJumpIndex = -1;
  int _lastSwingIndex = -1;
  int _lastClickIndex = -1;

  // Sound variation pools (at least 3 to 4 variations per action)
  static const List<String> webShootPool = [
    'sfx/web_shoot_1.wav',
    'sfx/web_shoot_2.wav',
    'sfx/web_shoot_3.wav',
    'sfx/web_shoot_4.wav',
  ];

  static const List<String> punchPool = [
    'sfx/punch_1.wav',
    'sfx/punch_2.wav',
    'sfx/punch_3.wav',
    'sfx/punch_4.wav',
  ];

  static const List<String> jumpPool = [
    'sfx/jump_1.wav',
    'sfx/jump_2.wav',
    'sfx/jump_3.wav',
    'sfx/jump_4.wav',
  ];

  static const List<String> swingPool = [
    'sfx/swing_1.wav',
    'sfx/swing_2.wav',
    'sfx/swing_3.wav',
    'sfx/swing_4.wav',
  ];

  static const List<String> buttonClickPool = [
    'sfx/button_click_1.wav',
    'sfx/button_click_2.wav',
    'sfx/button_click_3.wav',
  ];

  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  Future<void> initialize() async {
    try {
      _bgmPlayer ??= AudioPlayer();
    } catch (e) {
      debugPrint('AudioManager initialize note: $e');
    }
  }

  /// Starts or loops the background music track as a single, non-overlapping stream.
  Future<void> playBgm({
    String track = 'bgm/background_music.mp3',
    double volume = 0.65,
    bool forceRestart = false,
  }) async {
    _volume = volume;
    _currentTrack = track;
    if (isMuted) return;

    // 1. Prevent duplicate simultaneous playback (Never overlap!)
    if (_isPlaying && !forceRestart) {
      return;
    }

    // 2. Prevent concurrent re-entry
    if (_isStartingBgm) return;
    _isStartingBgm = true;

    String cleanTrack = track;
    if (cleanTrack.startsWith('assets/audio/')) {
      cleanTrack = cleanTrack.substring('assets/audio/'.length);
    } else if (cleanTrack.startsWith('audio/')) {
      cleanTrack = cleanTrack.substring('audio/'.length);
    }

    if (kIsWeb) {
      try {
        getWebAudio().playBgm(cleanTrack, _volume);
        _isPlaying = true;
      } catch (e) {
        debugPrint('WebAudioService play error: $e');
      } finally {
        _isStartingBgm = false;
      }
      return;
    }

    try {
      // Direct single-instance AudioPlayer with streaming mediaPlayer mode
      // (Bypasses unsupported setAudioContext exceptions on web and windows)
      _bgmPlayer ??= AudioPlayer();
      try {
        await _bgmPlayer!.stop();
      } catch (_) {}
      try {
        await FlameAudio.bgm.stop();
      } catch (_) {}

      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
      await _bgmPlayer!.setVolume(_volume);

      try {
        await _bgmPlayer!.play(AssetSource('audio/$cleanTrack'), volume: _volume);
        _isPlaying = true;
        debugPrint('AudioManager: BGM playing via AssetSource(audio/$cleanTrack)');
        return;
      } catch (e1) {
        debugPrint('Direct AssetSource attempt: $e1');
      }

      // Fallback 1: FlameAudio.bgm
      try {
        await FlameAudio.bgm.play(cleanTrack, volume: _volume);
        _isPlaying = true;
        debugPrint('AudioManager: BGM playing via FlameAudio.bgm ($cleanTrack)');
        return;
      } catch (e2) {
        debugPrint('FlameAudio.bgm fallback attempt: $e2');
      }

      // Fallback 2: FlameAudio.loop
      try {
        _bgmPlayer = await FlameAudio.loop(cleanTrack, volume: _volume);
        _isPlaying = true;
        debugPrint('AudioManager: BGM playing via FlameAudio.loop ($cleanTrack)');
        return;
      } catch (e3) {
        debugPrint('FlameAudio.loop fallback attempt: $e3');
      }
    } catch (e) {
      debugPrint('AudioManager playBgm error: $e');
    } finally {
      _isStartingBgm = false;
    }
  }

  /// Wakes up any browser-suspended audio context upon any user interaction.
  void resumeBgmIfSuspended() {
    if (isMuted) return;
    if (kIsWeb) {
      getWebAudio().resumeBgm();
      if (!_isPlaying) {
        playBgm(track: _currentTrack, volume: _volume);
      }
      return;
    }
    if (!_isPlaying || _bgmPlayer == null) {
      playBgm(track: _currentTrack, volume: _volume, forceRestart: true);
    } else {
      try {
        _bgmPlayer?.resume();
      } catch (_) {
        playBgm(track: _currentTrack, volume: _volume, forceRestart: true);
      }
    }
  }

  Future<void> stopBgm() async {
    _isPlaying = false;
    if (kIsWeb) {
      getWebAudio().stopBgm();
      return;
    }
    try {
      if (_bgmPlayer != null) {
        await _bgmPlayer!.stop();
        await _bgmPlayer!.dispose();
        _bgmPlayer = null;
      }
    } catch (e) {
      debugPrint('AudioManager stopBgm note: $e');
    }
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    _isPlaying = false;
    if (kIsWeb) {
      getWebAudio().pauseBgm();
      return;
    }
    try {
      if (_bgmPlayer != null) {
        await _bgmPlayer!.pause();
      }
    } catch (e) {
      debugPrint('AudioManager pauseBgm note: $e');
    }
  }

  Future<void> resumeBgm() async {
    if (isMuted || _isPlaying) return;
    if (kIsWeb) {
      getWebAudio().resumeBgm();
      _isPlaying = true;
      return;
    }
    try {
      if (_bgmPlayer != null) {
        await _bgmPlayer!.resume();
        _isPlaying = true;
      } else {
        await playBgm(track: _currentTrack, volume: _volume);
      }
    } catch (e) {
      debugPrint('AudioManager resumeBgm note: $e');
    }
  }

  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    if (kIsWeb) {
      getWebAudio().setBgmVolume(_volume);
      return;
    }
    try {
      if (_bgmPlayer != null) {
        await _bgmPlayer!.setVolume(_volume);
      }
    } catch (_) {}
  }

  /// Plays a one-shot sound effect from assets/audio/
  Future<void> playSfx(String file, {double volume = 0.75}) async {
    if (isMuted) return;
    if (kIsWeb) {
      getWebAudio().playSfx(file, volume);
      return;
    }
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('AudioManager playSfx note ($file): $e');
    }
  }

  String _pickVariation(List<String> pool, int lastIndex, void Function(int) setLast) {
    if (pool.isEmpty) return '';
    int nextIndex = _random.nextInt(pool.length);
    if (pool.length > 1 && nextIndex == lastIndex) {
      nextIndex = (nextIndex + 1) % pool.length;
    }
    setLast(nextIndex);
    return pool[nextIndex];
  }

  /// Randomly selects from 4 distinct web shoot sounds
  void playWebShoot() {
    final track = _pickVariation(webShootPool, _lastWebShootIndex, (i) => _lastWebShootIndex = i);
    playSfx(track, volume: 0.85);
  }

  /// Randomly selects from 4 distinct punch attack sounds
  void playPunch() {
    final track = _pickVariation(punchPool, _lastPunchIndex, (i) => _lastPunchIndex = i);
    playSfx(track, volume: 0.90);
  }

  /// Randomly selects from 4 distinct jump leap sounds
  void playJump() {
    final track = _pickVariation(jumpPool, _lastJumpIndex, (i) => _lastJumpIndex = i);
    playSfx(track, volume: 0.70);
  }

  /// Randomly selects from 4 distinct swing whoosh sounds
  void playSwing() {
    final track = _pickVariation(swingPool, _lastSwingIndex, (i) => _lastSwingIndex = i);
    playSfx(track, volume: 0.75);
  }

  /// Randomly selects from 3 distinct arcade UI blip sounds
  void playButtonClick() {
    final track = _pickVariation(buttonClickPool, _lastClickIndex, (i) => _lastClickIndex = i);
    playSfx(track, volume: 0.80);
    // User interacted! Ensure background music starts if unmuted and not actively playing
    if (!isMuted && !_isPlaying) {
      playBgm(track: _currentTrack, volume: _volume);
    }
  }

  /// Toggles mute on/off across the game.
  Future<void> toggleMute() async {
    isMuted = !isMuted;
    if (isMuted) {
      await stopBgm();
    } else {
      if (_currentTrack.isNotEmpty) {
        await playBgm(track: _currentTrack, volume: _volume);
      }
    }
  }
}
