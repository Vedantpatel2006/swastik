/// Utility class for sanitizing and validating user input
class InputSanitizer {
  /// Sanitize string input by removing potentially harmful characters
  static String sanitize(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[<>]'), ''); // Remove angle brackets
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate phone number (basic validation)
  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 10 && cleaned.length <= 15;
  }

  /// Sanitize temple name
  static String sanitizeTempleName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[^\w\s\-.,()&]'), '');
  }

  /// Sanitize description/about text
  static String sanitizeDescription(String description) {
    return description
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[^\w\s\-.,!?()&\n]'), '');
  }

  /// Validate and sanitize YouTube URL
  static String? sanitizeYoutubeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
        return url;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if string contains only alphanumeric characters
  static bool isAlphanumeric(String input) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(input);
  }

  /// Limit string length
  static String limitLength(String input, int maxLength) {
    if (input.length <= maxLength) return input;
    return '${input.substring(0, maxLength)}...';
  }
}
