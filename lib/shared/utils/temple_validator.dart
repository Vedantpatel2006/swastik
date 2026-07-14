import 'package:flutter/foundation.dart';
import '../models/temple.dart';

/// Comprehensive temple data validator
/// ✅ Prevents invalid data from being saved
class TempleValidator {
  /// Validate complete temple data before saving
  static ValidationResult validate(Temple temple) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. Basic Info Validation
    _validateBasicInfo(temple, errors, warnings);

    // 2. Location Validation
    _validateLocation(temple, errors, warnings);

    // 3. Timings Validation
    _validateTimings(temple, errors, warnings);

    // 4. Media Validation
    _validateMedia(temple, errors, warnings);

    // 5. Booking Validation
    _validateBooking(temple, errors, warnings);

    // 6. Donation Validation
    _validateDonation(temple, errors, warnings);

    // 7. Live Darshan Validation
    _validateLiveDarshan(temple, errors, warnings);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate basic temple information
  static void _validateBasicInfo(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    // Name
    if (temple.name.trim().isEmpty) {
      errors.add('Temple name is required');
    } else if (temple.name.length < 3) {
      warnings.add('Temple name is very short (< 3 characters)');
    }

    // Description
    if (temple.description.trim().isEmpty) {
      errors.add('Temple description is required');
    } else if (temple.description.length < 50) {
      warnings.add('Temple description is short (< 50 characters)');
    }

    // Main Deity
    if (temple.mainDeity == null || temple.mainDeity!.trim().isEmpty) {
      warnings.add('Main deity should be specified');
    }

    // Traditions
    if (temple.traditions.isEmpty) {
      warnings.add('At least one tradition should be specified');
    }
  }

  /// Validate location data
  static void _validateLocation(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    final location = temple.location;

    // Check for valid coordinates
    if (!location.isValid()) {
      if (location.latitude == 0.0 && location.longitude == 0.0) {
        errors.add('Location coordinates are invalid (0,0)');
      } else {
        errors.add('Location coordinates are out of valid range');
      }
    }

    // Check for address
    if (!location.hasAddress()) {
      warnings.add('Temple address should be provided');
    }

    // Check for city and state
    if (location.city == null || location.city!.isEmpty) {
      warnings.add('City should be specified');
    }

    if (location.state == null || location.state!.isEmpty) {
      warnings.add('State should be specified');
    }
  }

  /// Validate temple timings
  static void _validateTimings(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    if (temple.timings.isEmpty) {
      warnings.add('Temple timings should be specified');
      return;
    }

    // Validate timing format
    final timeRegex = RegExp(
      r'^\d{1,2}:\d{2}\s*(AM|PM)?\s*-\s*\d{1,2}:\d{2}\s*(AM|PM)?$',
      caseSensitive: false,
    );

    for (final entry in temple.timings.entries) {
      if (!timeRegex.hasMatch(entry.value)) {
        warnings.add(
          'Invalid timing format for ${entry.key}: "${entry.value}". '
          'Expected format: "6:00 AM - 8:00 PM"',
        );
      }
    }

    // Check if at least one day has timings
    if (temple.timings.values.every((t) => t.isEmpty)) {
      errors.add('At least one day must have timings');
    }
  }

  /// Validate media (images)
  static void _validateMedia(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    if (temple.images.isEmpty) {
      warnings.add('At least one image should be uploaded');
    }

    // Validate image URLs
    for (final imageUrl in temple.images) {
      if (!imageUrl.startsWith('http://') &&
          !imageUrl.startsWith('https://')) {
        errors.add('Invalid image URL: $imageUrl');
      }
    }
  }

  /// Validate booking configuration
  static void _validateBooking(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!temple.acceptsBookings) return;

    // Check booking types
    if (temple.availableBookingTypes.isEmpty) {
      errors.add(
        'At least one booking type must be specified when bookings are enabled',
      );
    }

    // Validate booking types
    const validTypes = ['visit', 'event', 'special_service'];
    for (final type in temple.availableBookingTypes) {
      if (!validTypes.contains(type)) {
        warnings.add('Unknown booking type: $type');
      }
    }

    // Check booking settings
    if (temple.bookingSettings == null) {
      warnings.add('Booking settings should be configured');
    }
  }

  /// Validate donation configuration
  static void _validateDonation(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!temple.acceptsDonations) return;

    // Check donation purposes
    if (temple.donationPurposes.isEmpty) {
      warnings.add(
        'At least one donation purpose should be specified when donations are enabled',
      );
    }

    // Validate amounts
    if (temple.minimumDonationAmount != null) {
      if (temple.minimumDonationAmount! <= 0) {
        errors.add('Minimum donation amount must be greater than 0');
      }
    }

    if (temple.suggestedDonationAmount != null &&
        temple.minimumDonationAmount != null) {
      if (temple.suggestedDonationAmount! < temple.minimumDonationAmount!) {
        errors.add(
          'Suggested donation amount (${temple.suggestedDonationAmount}) '
          'must be >= minimum amount (${temple.minimumDonationAmount})',
        );
      }
    }
  }

  /// Validate live darshan configuration
  static void _validateLiveDarshan(
    Temple temple,
    List<String> errors,
    List<String> warnings,
  ) {
    final liveDarshan = temple.liveDarshan;
    if (liveDarshan == null || !liveDarshan.isConfiguredByAdmin) return;

    // Check YouTube channel URL
    if (liveDarshan.youtubeChannelUrl == null ||
        liveDarshan.youtubeChannelUrl!.isEmpty) {
      errors.add('YouTube channel URL is required for live darshan');
    } else if (!liveDarshan.youtubeChannelUrl!.contains('youtube.com')) {
      errors.add('Invalid YouTube channel URL');
    }

    // Check YouTube channel ID
    if (liveDarshan.youtubeChannelId == null ||
        liveDarshan.youtubeChannelId!.isEmpty) {
      warnings.add('YouTube channel ID should be specified');
    } else if (!liveDarshan.youtubeChannelId!.startsWith('UC')) {
      warnings.add(
        'YouTube channel ID should start with "UC" (got: ${liveDarshan.youtubeChannelId})',
      );
    }

    // Validate schedules
    for (final schedule in liveDarshan.schedule) {
      if (!schedule.isValid()) {
        warnings.add('Invalid schedule: ${schedule.name}');
      }
    }
  }

  /// Quick validation for critical fields only
  static bool quickValidate(Temple temple) {
    return temple.name.trim().isNotEmpty &&
        temple.description.trim().isNotEmpty &&
        temple.location.isValid();
  }

  /// Get validation summary as string
  static String getValidationSummary(ValidationResult result) {
    final buffer = StringBuffer();

    if (result.isValid) {
      buffer.writeln('✅ Validation passed');
    } else {
      buffer.writeln('❌ Validation failed');
    }

    if (result.errors.isNotEmpty) {
      buffer.writeln('\nErrors (${result.errors.length}):');
      for (final error in result.errors) {
        buffer.writeln('  • $error');
      }
    }

    if (result.warnings.isNotEmpty) {
      buffer.writeln('\nWarnings (${result.warnings.length}):');
      for (final warning in result.warnings) {
        buffer.writeln('  • $warning');
      }
    }

    return buffer.toString();
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  /// Print validation result to console
  void printResult() {
    if (kDebugMode) {
      print(TempleValidator.getValidationSummary(this));
    }
  }
}
