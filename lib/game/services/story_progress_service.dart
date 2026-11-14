import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Singleton service managing story chapter checkpoints, progression, and map persistence.
class StoryProgressService {
  StoryProgressService._internal();
  static final StoryProgressService instance = StoryProgressService._internal();

  /// Current active story part (1 = Warehouse, 2 = Moonlit Rooftop Cityscape, 3 = Manhattan Harbor)
  int _currentPart = 1;
  int get currentPart => _currentPart;

  /// Highest part cleared / reached so far
  int _maxPartReached = 1;
  int get maxPartReached => _maxPartReached;

  /// Whether a part is unlocked for manual selection
  bool isPartUnlocked(int part) => part <= _maxPartReached;

  /// Whether a part has been completed
  bool isPartCleared(int part) => _maxPartReached > part;

  /// Whether progress has been loaded from storage
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Returns storage file path when running on desktop/mobile
  File? _getSaveFile() {
    if (kIsWeb) return null;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    try {
      final tempDir = Directory.systemTemp;
      return File('${tempDir.path}/spideyhood_story_checkpoint.json');
    } catch (_) {
      return null;
    }
  }

  /// Loads saved story part from storage
  Future<void> loadProgress() async {
    if (_isLoaded) return;
    try {
      final file = _getSaveFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        _currentPart = (data['currentPart'] as num?)?.toInt() ?? 1;
        _maxPartReached = (data['maxPartReached'] as num?)?.toInt() ?? _currentPart;
        if (_currentPart < 1) _currentPart = 1;
        if (_currentPart > 3) _currentPart = 3;
        if (_maxPartReached < _currentPart) _maxPartReached = _currentPart;
      }
    } catch (_) {
      // In-memory fallback
    } finally {
      _isLoaded = true;
    }
  }

  /// Sets current story part and persists
  Future<void> setPart(int part) async {
    _currentPart = part.clamp(1, 3);
    if (_currentPart > _maxPartReached) {
      _maxPartReached = _currentPart;
    }
    _isLoaded = true;
    try {
      final file = _getSaveFile();
      if (file != null) {
        await file.writeAsString(jsonEncode({
          'currentPart': _currentPart,
          'maxPartReached': _maxPartReached,
          'updatedAt': DateTime.now().toIso8601String(),
        }));
      }
    } catch (_) {}
  }

  /// Alias for setPart to save and set the active story part
  Future<void> saveProgress(int part) => setPart(part);

  /// Marks Part 1 as completed and advances to Part 2 (Moonlit Rooftop)
  Future<void> completePart1() async {
    _maxPartReached = 2;
    await setPart(2);
  }

  /// Marks Part 2 as completed and advances to Part 3 (Manhattan Harbor)
  Future<void> completePart2() async {
    _maxPartReached = 3;
    await setPart(3);
  }

  /// Resets story progression back to Chapter 1, Part 1
  Future<void> resetStory({bool resetAllUnlocked = false}) async {
    if (resetAllUnlocked) {
      _maxPartReached = 1;
    }
    await setPart(1);
  }

  /// Label for current part
  String get currentPartTitle {
    switch (_currentPart) {
      case 3:
        return 'PART 3: MANHATTAN HARBOR';
      case 2:
        return 'PART 2: MOONLIT ROOFTOP';
      case 1:
      default:
        return 'PART 1: ABANDONED WAREHOUSE';
    }
  }
}
