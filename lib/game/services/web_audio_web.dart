// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Real browser HTML5 Audio implementation for Flutter Web.
/// Bypasses all `audioplayers_web` and Web AudioContext CORS limitations,
/// playing audio directly through standard native HTMLAudioElements.
class WebAudioService {
  static final WebAudioService instance = WebAudioService._();
  WebAudioService._() {
    _setupGlobalGestureUnlock();
  }

  html.AudioElement? _bgmAudio;
  String? _currentCleanPath;
  bool _wantsBgm = false;
  bool _hasSetupGestures = false;

  void _setupGlobalGestureUnlock() {
    if (_hasSetupGestures) return;
    _hasSetupGestures = true;

    void unlock(html.Event _) {
      if (_wantsBgm && _bgmAudio != null && _bgmAudio!.paused) {
        _bgmAudio!.play().then((_) {
          debugPrint('WebAudioService: BGM unlocked via user gesture!');
        }).catchError((_) {});
      }
    }

    try {
      html.window.addEventListener('pointerdown', unlock, true);
      html.window.addEventListener('keydown', unlock, true);
      html.window.addEventListener('touchstart', unlock, true);
      html.window.addEventListener('click', unlock, true);
    } catch (e) {
      debugPrint('WebAudioService gesture setup note: $e');
    }
  }

  String _clean(String path) {
    var p = path;
    if (p.startsWith('assets/audio/')) {
      p = p.substring('assets/audio/'.length);
    } else if (p.startsWith('audio/')) {
      p = p.substring('audio/'.length);
    } else if (p.startsWith('assets/')) {
      p = p.substring('assets/'.length);
    }
    return p;
  }

  void playBgm(String relativePath, double volume) {
    _wantsBgm = true;
    try {
      final clean = _clean(relativePath);
      final primaryUrl = 'assets/assets/audio/$clean';

      if (_bgmAudio == null) {
        _bgmAudio = html.AudioElement()
          ..loop = true
          ..volume = volume.clamp(0.0, 1.0);
        html.document.body?.append(_bgmAudio!);
      }

      if (_currentCleanPath != clean) {
        _currentCleanPath = clean;
        _bgmAudio!.src = primaryUrl;
        _bgmAudio!.load();

        // Listen for error once to try alternate path if needed
        _bgmAudio!.onError.first.then((_) {
          if (_currentCleanPath == clean) {
            final fallback = 'assets/audio/$clean';
            _bgmAudio!.src = fallback;
            _bgmAudio!.load();
            if (_wantsBgm) {
              _bgmAudio!.play().catchError((_) {});
            }
          }
        });
      }

      _bgmAudio!.volume = volume.clamp(0.0, 1.0);
      _bgmAudio!.play().then((_) {
        debugPrint('WebAudioService: BGM playing successfully ($clean)');
      }).catchError((err) {
        debugPrint('WebAudioService: Autoplay pending user interaction: $err');
      });
    } catch (e) {
      debugPrint('WebAudioService playBgm error: $e');
    }
  }

  void stopBgm() {
    _wantsBgm = false;
    try {
      _bgmAudio?.pause();
      if (_bgmAudio != null) {
        _bgmAudio!.currentTime = 0;
      }
    } catch (_) {}
  }

  void pauseBgm() {
    _wantsBgm = false;
    try {
      _bgmAudio?.pause();
    } catch (_) {}
  }

  void resumeBgm() {
    _wantsBgm = true;
    try {
      _bgmAudio?.play().catchError((_) {});
    } catch (_) {}
  }

  void setBgmVolume(double volume) {
    try {
      _bgmAudio?.volume = volume.clamp(0.0, 1.0);
    } catch (_) {}
  }

  void playSfx(String relativePath, double volume) {
    try {
      final clean = _clean(relativePath);
      final primaryUrl = 'assets/assets/audio/$clean';
      final sfx = html.AudioElement(primaryUrl)..volume = volume.clamp(0.0, 1.0);
      sfx.play().catchError((_) {
        final fallback = html.AudioElement('assets/audio/$clean')
          ..volume = volume.clamp(0.0, 1.0);
        fallback.play().catchError((_) {});
      });
    } catch (_) {}
  }
}
