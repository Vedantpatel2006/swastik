/// Android-specific accessibility configuration
class AndroidAccessibilityConfig {
  static const bool enableTalkBack = true;
  static const bool enableHighContrast = true;
  static const bool enableLargeText = true;
  static const double minimumTouchTargetSize = 48.0;
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// Semantic labels for common UI elements
  static const Map<String, String> semanticLabels = {
    'back_button': 'Navigate back',
    'menu_button': 'Open menu',
    'search_button': 'Search',
    'favorite_button': 'Add to favorites',
    'share_button': 'Share',
    'close_button': 'Close',
  };

  /// Screen reader announcements
  static const Map<String, String> announcements = {
    'loading': 'Loading content',
    'loaded': 'Content loaded',
    'error': 'An error occurred',
    'success': 'Action completed successfully',
  };
}
