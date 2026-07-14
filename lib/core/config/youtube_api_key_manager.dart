import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Manages multiple YouTube API keys for quota distribution
class YouTubeApiKeyManager {
  static final YouTubeApiKeyManager _instance =
      YouTubeApiKeyManager._internal();
  factory YouTubeApiKeyManager() => _instance;
  YouTubeApiKeyManager._internal();

  // Keys loaded from .env at runtime
  static List<String> get _apiKeys {
    final key = dotenv.env['YOUTUBE_API_KEY'] ?? '';
    return key.isNotEmpty ? [key] : [];
  }

  final Map<String, int> _keyUsageCount = {};
  final Map<String, DateTime> _keyLastReset = {};
  int _currentKeyIndex = 0;

  /// Get the current active API key
  String getCurrentApiKey() {
    if (_apiKeys.isEmpty) {
      throw StateError('No API keys configured');
    }

    // Check if current key needs rotation due to quota
    final currentKey = _apiKeys[_currentKeyIndex];
    final usage = _keyUsageCount[currentKey] ?? 0;
    final lastReset = _keyLastReset[currentKey] ?? DateTime.now();

    // Reset daily usage counter
    if (DateTime.now().difference(lastReset).inDays >= 1) {
      _keyUsageCount[currentKey] = 0;
      _keyLastReset[currentKey] = DateTime.now();
    }

    // Rotate if current key is near quota limit (8000 requests per day)
    if (usage >= 7500) {
      _rotateToNextKey();
      return getCurrentApiKey();
    }

    return currentKey;
  }

  /// Record API usage for current key
  void recordUsage({int cost = 1}) {
    final currentKey = getCurrentApiKey();
    _keyUsageCount[currentKey] = (_keyUsageCount[currentKey] ?? 0) + cost;

    if (kDebugMode) {
      debugPrint(
        'API Key Usage: ${_keyUsageCount[currentKey]}/8000 for key ${_currentKeyIndex + 1}',
      );
    }
  }

  /// Rotate to next available API key
  void _rotateToNextKey() {
    if (_apiKeys.length <= 1) {
      if (kDebugMode) {
        debugPrint('Cannot rotate: Only one API key available');
      }
      return;
    }

    final originalIndex = _currentKeyIndex;

    // Find next key with available quota
    for (int i = 0; i < _apiKeys.length; i++) {
      _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
      final key = _apiKeys[_currentKeyIndex];
      final lastReset = _keyLastReset[key] ?? DateTime.now();

      // Reset if it's a new day
      if (DateTime.now().difference(lastReset).inDays >= 1) {
        _keyUsageCount[key] = 0;
        _keyLastReset[key] = DateTime.now();
      }

      // Use this key if it has quota available
      if ((_keyUsageCount[key] ?? 0) < 7500) {
        if (kDebugMode) {
          debugPrint('Rotated to API key ${_currentKeyIndex + 1}');
        }
        return;
      }
    }

    // If no keys have quota, use the original (will hit quota limit)
    _currentKeyIndex = originalIndex;
    if (kDebugMode) {
      debugPrint('Warning: All API keys near quota limit');
    }
  }

  /// Get usage statistics for all keys
  Map<String, dynamic> getUsageStats() {
    final stats = <String, dynamic>{};

    for (int i = 0; i < _apiKeys.length; i++) {
      final key = _apiKeys[i];
      final usage = _keyUsageCount[key] ?? 0;
      final lastReset = _keyLastReset[key] ?? DateTime.now();

      stats['key_${i + 1}'] = {
        'usage': usage,
        'remaining': 8000 - usage,
        'lastReset': lastReset.toIso8601String(),
        'isActive': i == _currentKeyIndex,
      };
    }

    return {
      'totalKeys': _apiKeys.length,
      'currentKeyIndex': _currentKeyIndex + 1,
      'keyStats': stats,
    };
  }

  /// Force rotation to specific key index
  void forceRotateToKey(int keyIndex) {
    if (keyIndex >= 0 && keyIndex < _apiKeys.length) {
      _currentKeyIndex = keyIndex;
      if (kDebugMode) {
        debugPrint('Forced rotation to API key ${keyIndex + 1}');
      }
    }
  }

  /// Add new API key at runtime
  void addApiKey(String apiKey) {
    // Note: This would require modifying the const list to a regular list
    // For now, keys should be added to the _apiKeys const list above
    if (kDebugMode) {
      debugPrint(
        'To add API keys, modify the _apiKeys list in the source code',
      );
    }
  }
}
