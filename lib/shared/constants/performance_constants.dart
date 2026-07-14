/// Performance-related constants for the application
class PerformanceConstants {
  // Cache size limits (in bytes)
  static const int maxImageCacheSize = 100 * 1024 * 1024; // 100MB
  static const int maxDataCacheSize = 50 * 1024 * 1024; // 50MB

  // Cache TTL settings
  static const Duration defaultCacheTTL = Duration(hours: 24);
  static const Duration imageCacheTTL = Duration(days: 7);
  static const Duration dataCacheTTL = Duration(hours: 12);

  // Network timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration imageLoadTimeout = Duration(seconds: 15);

  // Image optimization settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int thumbnailSize = 150;
  static const int mediumImageSize = 400;
  static const int largeImageSize = 800;

  // Cache eviction thresholds
  static const double cacheEvictionThreshold = 0.9; // 90% full
  static const double cacheCompressionTarget = 0.7; // Compress to 70%

  // LRU cache settings
  static const int maxCacheObjects = 1000;
  static const Duration cacheCleanupInterval = Duration(hours: 6);

  // Preloading settings
  static const int maxPreloadImages = 20;
  static const int preloadDistance = 5; // Items ahead to preload

  // Memory management
  static const int maxMemoryUsage = 200 * 1024 * 1024; // 200MB
  static const Duration memoryCleanupInterval = Duration(minutes: 30);
}
