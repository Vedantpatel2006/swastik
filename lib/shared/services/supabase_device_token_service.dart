import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fcm_service.dart';
import 'dart:io';

/// Helper service to save FCM device tokens to Supabase
/// This enables push notifications via Supabase Edge Functions
class SupabaseDeviceTokenService {
  static final SupabaseDeviceTokenService _instance =
      SupabaseDeviceTokenService._internal();
  factory SupabaseDeviceTokenService() => _instance;
  SupabaseDeviceTokenService._internal();

  /// Save or update FCM device token for current user
  Future<void> saveDeviceToken(String userId, {String? appVersion}) async {
    try {
      final fcmService = FCMService();
      await fcmService.initialize();

      final deviceToken = fcmService.deviceToken;
      if (deviceToken == null) {
        if (kDebugMode) {
          debugPrint('SupabaseDeviceTokenService: No FCM token available');
        }
        return;
      }

      final supabase = Supabase.instance.client;

      // Upsert device token
      await supabase.from('user_device_tokens').upsert({
        'user_id': userId,
        'device_token': deviceToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'app_version': appVersion ?? 'unknown',
        'device_model': Platform.isAndroid ? 'Android' : 'iOS',
        'is_active': true,
        'last_used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_token');

      if (kDebugMode) {
        debugPrint('SupabaseDeviceTokenService: Device token saved');
        debugPrint('  User ID: $userId');
        debugPrint('  Platform: ${Platform.isAndroid ? "android" : "ios"}');
        debugPrint('  Token: ${deviceToken.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseDeviceTokenService: Error saving token - $e');
      }
      // Don't rethrow - this is non-critical
    }
  }

  /// Mark all old tokens for this user as inactive (when user logs out)
  Future<void> deactivateOldTokens(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('user_device_tokens')
          .update({'is_active': false})
          .eq('user_id', userId);

      if (kDebugMode) {
        debugPrint('SupabaseDeviceTokenService: Deactivated old tokens');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseDeviceTokenService: Error deactivating tokens - $e',
        );
      }
    }
  }

  /// Remove device token (when user uninstalls app)
  Future<void> removeDeviceToken(String userId, String deviceToken) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('user_device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('device_token', deviceToken);

      if (kDebugMode) {
        debugPrint('SupabaseDeviceTokenService: Removed device token');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseDeviceTokenService: Error removing token - $e');
      }
    }
  }

  /// Get all active tokens for a user
  Future<List<String>> getActiveTokens(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('user_device_tokens')
          .select('device_token')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_used_at', ascending: false);

      return (response as List)
          .map((row) => row['device_token'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseDeviceTokenService: Error getting tokens - $e');
      }
      return [];
    }
  }
}
