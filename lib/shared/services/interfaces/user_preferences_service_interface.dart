import '../../models/user_preferences.dart';

/// Interface for user preferences service operations
abstract class UserPreferencesServiceInterface {
  /// Get user preferences for the current user
  Future<UserPreferences> getUserPreferences();

  /// Get user preferences for a specific user
  Future<UserPreferences> getUserPreferencesById(String userId);

  /// Update user preferences
  Future<void> updatePreferences(UserPreferences preferences);

  /// Set location radius preference
  Future<void> setLocationRadius(double radius);

  /// Set spiritual traditions preferences
  Future<void> setSpiritualTraditions(List<String> traditions);

  /// Add a spiritual tradition to preferences
  Future<void> addSpiritualTradition(String tradition);

  /// Remove a spiritual tradition from preferences
  Future<void> removeSpiritualTradition(String tradition);

  /// Set location services enabled/disabled
  Future<void> setLocationServicesEnabled(bool enabled);

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled);

  /// Set theme preference
  Future<void> setTheme(String theme);

  /// Set language preference
  Future<void> setLanguage(String language);

  /// Get user's saved location
  Future<String> getUserLocation();

  /// Set user's saved location
  Future<void> setUserLocation(String location);

  /// Set custom setting
  Future<void> setCustomSetting(String key, dynamic value);

  /// Remove custom setting
  Future<void> removeCustomSetting(String key);

  /// Get custom setting value
  Future<T?> getCustomSetting<T>(String key);

  /// Watch user preferences for real-time updates
  Stream<UserPreferences> watchPreferences();

  /// Watch user preferences for a specific user
  Stream<UserPreferences> watchPreferencesById(String userId);

  /// Reset preferences to default values
  Future<void> resetToDefaults();

  /// Export preferences as JSON
  Future<Map<String, dynamic>> exportPreferences();

  /// Import preferences from JSON
  Future<void> importPreferences(Map<String, dynamic> preferencesJson);

  /// Check if preferences are valid
  Future<bool> validatePreferences(UserPreferences preferences);

  /// Get available themes
  List<String> getAvailableThemes();

  /// Get available languages
  List<String> getAvailableLanguages();

  /// Clear cached preferences
  Future<void> clearCache();
}
