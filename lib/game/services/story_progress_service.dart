import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Singleton service managing story chapter checkpoints, progression, and map persistence.
class StoryProgressService {
  StoryProgressService._internal();
  static final StoryProgressService instance = StoryProgressService._internal();

  /// Current active story part (1 = Warehouse, 2 = Moonlit Rooftop Cityscape)
  int _currentPart = 1;
  int get currentPart => _currentPart;

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
        if (_currentPart < 1) _currentPart = 1;
        if (_currentPart > 2) _currentPart = 2;
      }
    } catch (_) {
      // In-memory fallback
    } finally {
      _isLoaded = true;
    }
  }

  /// Sets current story part and persists
  Future<void> setPart(int part) async {
    _currentPart = part.clamp(1, 2);
    _isLoaded = true;
    try {
      final file = _getSaveFile();
      if (file != null) {
        await file.writeAsString(jsonEncode({
          'currentPart': _currentPart,
          'updatedAt': DateTime.now().toIso8601String(),
        }));
      }
    } catch (_) {}
  }

  /// Alias for setPart to save and set the active story part
  Future<void> saveProgress(int part) => setPart(part);

  /// Marks Part 1 as completed and advances to Part 2 (Moonlit Rooftop)
  Future<void> completePart1() async {
    await setPart(2);
  }

  /// Resets story progression back to Chapter 1, Part 1
  Future<void> resetStory() async {
    await setPart(1);
  }

  /// Label for current part
  String get currentPartTitle {
    switch (_currentPart) {
      case 2:
        return 'PART 2: MOONLIT ROOFTOP';
      case 1:
      default:
        return 'PART 1: ABANDONED WAREHOUSE';
    }
  }
}
