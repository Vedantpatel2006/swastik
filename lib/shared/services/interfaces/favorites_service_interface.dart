/// Interface for favorites service operations
abstract class FavoritesServiceInterface {
  /// Add a temple to user's favorites
  Future<void> addToFavorites(String templeId);

  /// Remove a temple from user's favorites
  Future<void> removeFromFavorites(String templeId);

  /// Get list of favorite temple IDs
  Future<List<String>> getFavoriteTempleIds();

  /// Check if a temple is in favorites
  Future<bool> isFavorite(String templeId);

  /// Clear all favorites
  Future<void> clearAllFavorites();

  /// Export user data for backup
  Future<Map<String, dynamic>> exportUserData();

  /// Import user data from backup
  Future<void> importUserData(Map<String, dynamic> userData);

  /// Force sync all data with server
  Future<void> forceSyncAll();

  /// Stream of favorite temple IDs
  Stream<List<String>> watchFavorites();
}
