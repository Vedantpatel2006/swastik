import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/services/youtube_api_manager.dart';
import 'live_darshan_app_service.dart';

/// Configuration validation result
class ConfigValidationResult {
  final bool isValid;
  final String? error;
  final String? warning;
  final Map<String, dynamic>? extractedData;

  const ConfigValidationResult({
    required this.isValid,
    this.error,
    this.warning,
    this.extractedData,
  });

  ConfigValidationResult.success({this.warning, this.extractedData}) 
      : isValid = true, error = null;

  ConfigValidationResult.error(this.error) 
      : isValid = false, warning = null, extractedData = null;
}

/// Temple Configuration Manager
/// 
/// Handles temple live darshan configuration with proper validation,
/// monitoring restart, and real-time feedback for admin interfaces.
class TempleConfigManager {
  static final TempleConfigManager _instance = TempleConfigManager._internal();
  factory TempleConfigManager() => _instance;
  TempleConfigManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  /// Validate and extract YouTube channel information
  Future<ConfigValidationResult> validateYouTubeChannel(String input) async {
    if (input.trim().isEmpty) {
      return ConfigValidationResult.error('Channel URL or ID cannot be empty');
    }

    try {
      String channelId;
      String channelUrl;

      // Extract channel ID from various YouTube URL formats
      if (input.startsWith('http')) {
        channelId = _extractChannelIdFromUrl(input);
        channelUrl = input;
      } else if (input.startsWith('UC') && input.length == 24) {
        // Direct channel ID
        channelId = input;
        channelUrl = 'https://www.youtube.com/channel/$channelId';
      } else if (input.startsWith('@')) {
        // Handle format
        return ConfigValidationResult.error(
          'Handle format (@username) not supported. Please use channel URL or channel ID starting with "UC"'
        );
      } else {
        return ConfigValidationResult.error(
          'Invalid format. Please enter a YouTube channel URL or channel ID (starting with "UC")'
        );
      }

      if (channelId.isEmpty || !channelId.startsWith('UC') || channelId.length != 24) {
        return ConfigValidationResult.error(
          'Invalid channel ID format. Channel ID should start with "UC" and be 24 characters long'
        );
      }

      // Verify channel exists by making a test API call
      try {
        final youtubeApi = YouTubeApiManager();
        await youtubeApi.initialize();

        final channelExists = await youtubeApi.verifyChannelExists(channelId);
        if (!channelExists) {
          return ConfigValidationResult(
            isValid: false,
            error: 'YouTube channel not found or not accessible',
          );
        }
      } catch (e) {
        return ConfigValidationResult(
          isValid: false,
          warning: 'Could not verify channel existence: $e',
        );
      }

      return ConfigValidationResult.success(
        extractedData: {
          'channelId': channelId,
          'channelUrl': channelUrl,
        },
      );

    } catch (e) {
      return ConfigValidationResult.error('Error processing channel information: $e');
    }
  }

  /// Extract channel ID from various YouTube URL formats
  String _extractChannelIdFromUrl(String url) {
    // Remove any trailing parameters
    final cleanUrl = url.split('?')[0];
    
    // Handle different YouTube URL formats
    final patterns = [
      RegExp(r'youtube\.com/channel/([a-zA-Z0-9_-]{24})'),
      RegExp(r'youtube\.com/c/([a-zA-Z0-9_-]+)'),
      RegExp(r'youtube\.com/user/([a-zA-Z0-9_-]+)'),
      RegExp(r'youtu\.be/channel/([a-zA-Z0-9_-]{24})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleanUrl);
      if (match != null) {
        final extracted = match.group(1)!;
        // Only return if it looks like a proper channel ID (starts with UC)
        if (extracted.startsWith('UC') && extracted.length == 24) {
          return extracted;
        }
      }
    }

    return '';
  }

  /// Validate keywords
  ConfigValidationResult validateKeywords(List<String> keywords) {
    final cleanKeywords = keywords
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    if (cleanKeywords.isEmpty) {
      return ConfigValidationResult.success(
        warning: 'No keywords specified. Live detection will be less accurate.',
        extractedData: {'keywords': <String>[]},
      );
    }

    if (cleanKeywords.length > 10) {
      return ConfigValidationResult.error('Too many keywords. Maximum 10 keywords allowed.');
    }

    // Check for very short keywords
    final shortKeywords = cleanKeywords.where((k) => k.length < 3).toList();
    if (shortKeywords.isNotEmpty) {
      return ConfigValidationResult.error(
        'Keywords too short: ${shortKeywords.join(', ')}. Minimum 3 characters per keyword.'
      );
    }

    return ConfigValidationResult.success(
      extractedData: {'keywords': cleanKeywords},
    );
  }

  /// Save temple live darshan configuration
  Future<ConfigValidationResult> saveTempleConfiguration({
    required String templeId,
    required String channelInput,
    required List<String> keywords,
    String? streamQuality,
  }) async {
    try {
      // Validate channel
      final channelValidation = await validateYouTubeChannel(channelInput);
      if (!channelValidation.isValid) {
        return channelValidation;
      }

      // Validate keywords
      final keywordValidation = validateKeywords(keywords);
      if (!keywordValidation.isValid) {
        return keywordValidation;
      }

      final channelData = channelValidation.extractedData!;
      final keywordData = keywordValidation.extractedData!;

      // Prepare configuration data
      final configData = {
        'liveDarshan': {
          'isConfiguredByAdmin': true,
          'youtubeChannelId': channelData['channelId'],
          'youtubeChannelUrl': channelData['channelUrl'],
          'keywords': keywordData['keywords'],
          'streamQuality': streamQuality ?? '720p',
          'configuredAt': FieldValue.serverTimestamp(),
          'configuredBy': FirebaseAuth.instance.currentUser?.uid ?? 'system',
        },
        'isCurrentlyLive': false, // Reset live status
        'lastLiveCheck': null, // Reset last check
        'liveStatusSource': 'pending_configuration',
      };

      // Save to Firestore
      await _firestore.collection('temples').doc(templeId).update(configData);

      // Restart monitoring for this temple
      final appService = LiveDarshanAppService();
      if (appService.isHealthy) {
        // Wait a moment for Firestore to propagate
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Restart monitoring
        await appService.restartTempleMonitoring(templeId);
        
        debugPrint('✅ Temple configuration saved and monitoring restarted: $templeId');
      } else {
        debugPrint('⚠️ Configuration saved but monitoring system not healthy');
      }

      // Collect warnings
      final warnings = <String>[];
      if (channelValidation.warning != null) {
        warnings.add(channelValidation.warning!);
      }
      if (keywordValidation.warning != null) {
        warnings.add(keywordValidation.warning!);
      }

      return ConfigValidationResult.success(
        warning: warnings.isNotEmpty ? warnings.join(' ') : null,
        extractedData: {
          'channelId': channelData['channelId'],
          'channelUrl': channelData['channelUrl'],
          'keywords': keywordData['keywords'],
          'monitoringRestarted': appService.isHealthy,
        },
      );

    } catch (e) {
      debugPrint('❌ Error saving temple configuration: $e');
      return ConfigValidationResult.error('Failed to save configuration: $e');
    }
  }

  /// Disable live darshan for a temple
  Future<ConfigValidationResult> disableTempleConfiguration(String templeId) async {
    try {
      await _firestore.collection('temples').doc(templeId).update({
        'liveDarshan.isConfiguredByAdmin': false,
        'isCurrentlyLive': false,
        'liveStatusSource': 'disabled',
        'disabledAt': FieldValue.serverTimestamp(),
      });

      // Remove from monitoring
      final appService = LiveDarshanAppService();
      if (appService.isHealthy) {
        appService.removeTempleFromMonitoring(templeId);
      }

      return ConfigValidationResult.success(
        extractedData: {'disabled': true},
      );

    } catch (e) {
      return ConfigValidationResult.error('Failed to disable configuration: $e');
    }
  }

  /// Get current temple configuration
  Future<Map<String, dynamic>?> getTempleConfiguration(String templeId) async {
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;

      if (liveDarshan == null) return null;

      return {
        'channelId': liveDarshan['youtubeChannelId'],
        'channelUrl': liveDarshan['youtubeChannelUrl'],
        'keywords': List<String>.from(liveDarshan['keywords'] ?? []),
        'streamQuality': liveDarshan['streamQuality'],
        'isConfigured': liveDarshan['isConfiguredByAdmin'] == true,
        'isCurrentlyLive': data['isCurrentlyLive'] == true,
        'lastLiveCheck': data['lastLiveCheck'],
        'liveStatusSource': data['liveStatusSource'],
      };

    } catch (e) {
      debugPrint('❌ Error getting temple configuration: $e');
      return null;
    }
  }

  /// Test temple configuration (check if keywords match recent videos)
  Future<ConfigValidationResult> testTempleConfiguration(String templeId) async {
    try {
      final config = await getTempleConfiguration(templeId);
      if (config == null) {
        return ConfigValidationResult.error('Temple not configured');
      }

      // Force a live check for this temple
      final appService = LiveDarshanAppService();
      if (!appService.isHealthy) {
        return ConfigValidationResult.error('Monitoring system not running');
      }

      await appService.restartTempleMonitoring(templeId);
      
      // Wait for the check to complete
      await Future.delayed(const Duration(seconds: 3));

      // Get updated status
      final updatedConfig = await getTempleConfiguration(templeId);
      
      return ConfigValidationResult.success(
        extractedData: {
          'testCompleted': true,
          'isLive': updatedConfig?['isCurrentlyLive'] == true,
          'lastCheck': updatedConfig?['lastLiveCheck'],
          'source': updatedConfig?['liveStatusSource'],
        },
      );

    } catch (e) {
      return ConfigValidationResult.error('Test failed: $e');
    }
  }

  /// Get monitoring status for all temples
  Future<Map<String, dynamic>> getMonitoringStatus() async {
    try {
      final appService = LiveDarshanAppService();
      return appService.getSystemHealth();
    } catch (e) {
      return {
        'error': e.toString(),
        'isHealthy': false,
      };
    }
  }

  /// Stream temple configuration changes
  Stream<Map<String, dynamic>?> watchTempleConfiguration(String templeId) {
    return _firestore
        .collection('temples')
        .doc(templeId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          
          final data = snapshot.data() as Map<String, dynamic>;
          final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;
          
          if (liveDarshan == null) return null;
          
          return {
            'channelId': liveDarshan['youtubeChannelId'],
            'channelUrl': liveDarshan['youtubeChannelUrl'],
            'keywords': List<String>.from(liveDarshan['keywords'] ?? []),
            'streamQuality': liveDarshan['streamQuality'],
            'isConfigured': liveDarshan['isConfiguredByAdmin'] == true,
            'isCurrentlyLive': data['isCurrentlyLive'] == true,
            'lastLiveCheck': data['lastLiveCheck'],
            'liveStatusSource': data['liveStatusSource'],
          };
        });
  }
}