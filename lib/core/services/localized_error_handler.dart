import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/temple_error_handling.dart';
import 'localization_service.dart';

/// Comprehensive error handling service with Hindi and Gujarati localization
/// Implements requirements 6.5, 8.1, 9.1 for localized error handling
class LocalizedErrorHandler {
  static const String _loggerName = 'LocalizedErrorHandler';

  // Gujarat boundaries for location validation
  static const double _gujaratMinLat = 20.1;
  static const double _gujaratMaxLat = 24.7;
  static const double _gujaratMinLng = 68.1;
  static const double _gujaratMaxLng = 74.5;

  /// Handle location-specific errors with Gujarat boundary validation
  static Future<LocationErrorResult> handleLocationError(
    dynamic error, {
    Position? currentPosition,
    String? operationContext,
  }) async {
    final String errorKey;
    final Map<String, String> params = {};
    LocationErrorType errorType;

    if (error is LocationServiceDisabledException) {
      errorKey = 'error.location.service_disabled';
      errorType = LocationErrorType.serviceDisabled;
    } else if (error is PermissionDeniedException) {
      errorKey = 'error.location.permission_denied';
      errorType = LocationErrorType.permissionDenied;
    } else if (error.toString().contains('timeout')) {
      errorKey = 'error.location.timeout';
      errorType = LocationErrorType.timeout;
    } else if (currentPosition != null && !_isInGujarat(currentPosition)) {
      errorKey = 'error.location.outside_gujarat';
      errorType = LocationErrorType.outsideGujarat;
      params['latitude'] = currentPosition.latitude.toStringAsFixed(4);
      params['longitude'] = currentPosition.longitude.toStringAsFixed(4);
    } else {
      errorKey = 'error.location.general';
      errorType = LocationErrorType.general;
    }

    if (operationContext != null) {
      params['operation'] = operationContext;
    }

    final localizedMessage = LocalizationService.getLocalizedTextWithParams(
      errorKey,
      params,
    );

    // Log error with cultural context
    _logLocationError(error, errorType, currentPosition, operationContext);

    return LocationErrorResult(
      errorType: errorType,
      localizedMessage: localizedMessage,
      canRetry: _canRetryLocationError(errorType),
      suggestedAction: _getSuggestedLocationAction(errorType),
    );
  }

  /// Handle network errors with offline Gujarat temple data recovery
  static Future<NetworkErrorResult> handleNetworkError(
    dynamic error, {
    String? operationContext,
    bool hasOfflineData = false,
  }) async {
    final String errorKey;
    final Map<String, String> params = {};
    NetworkErrorType errorType;

    if (error is TimeoutException) {
      errorKey = 'error.network.timeout';
      errorType = NetworkErrorType.timeout;
    } else if (error is FirebaseException) {
      errorKey = _getFirebaseErrorKey(error.code);
      errorType = NetworkErrorType.firebase;
      params['errorCode'] = error.code;
    } else if (error.toString().contains('SocketException')) {
      errorKey = 'error.network.no_connection';
      errorType = NetworkErrorType.noConnection;
    } else {
      errorKey = 'error.network.general';
      errorType = NetworkErrorType.general;
    }

    if (operationContext != null) {
      params['operation'] = operationContext;
    }

    String localizedMessage = LocalizationService.getLocalizedTextWithParams(
      errorKey,
      params,
    );

    // Add offline data availability message if applicable
    if (hasOfflineData &&
        (errorType == NetworkErrorType.noConnection ||
            errorType == NetworkErrorType.timeout)) {
      final offlineMessage = LocalizationService.getLocalizedText(
        'error.network.offline_data_available',
      );
      localizedMessage = '$localizedMessage\n\n$offlineMessage';
    }

    // Log network error with context
    _logNetworkError(error, errorType, operationContext, hasOfflineData);

    return NetworkErrorResult(
      errorType: errorType,
      localizedMessage: localizedMessage,
      canRetry: _canRetryNetworkError(errorType),
      hasOfflineData: hasOfflineData,
      suggestedAction: _getSuggestedNetworkAction(errorType, hasOfflineData),
    );
  }

  /// Handle language resource errors with graceful degradation
  static Future<LanguageErrorResult> handleLanguageError(
    dynamic error, {
    String? requestedLanguage,
    String? fallbackLanguage,
  }) async {
    final String errorKey;
    final Map<String, String> params = {};
    LanguageErrorType errorType;

    if (error.toString().contains('Unable to load asset')) {
      errorKey = 'error.language.resource_not_found';
      errorType = LanguageErrorType.resourceNotFound;
      if (requestedLanguage != null) {
        params['language'] = _getLanguageDisplayName(requestedLanguage);
      }
    } else if (error is FormatException) {
      errorKey = 'error.language.invalid_format';
      errorType = LanguageErrorType.invalidFormat;
    } else {
      errorKey = 'error.language.general';
      errorType = LanguageErrorType.general;
    }

    // Try to get localized message, fall back to English if needed
    String localizedMessage;
    try {
      localizedMessage = LocalizationService.getLocalizedTextWithParams(
        errorKey,
        params,
      );
    } catch (e) {
      // Ultimate fallback to hardcoded English messages
      localizedMessage = _getHardcodedErrorMessage(errorType, params);
    }

    // Add fallback language information if available
    if (fallbackLanguage != null && fallbackLanguage != requestedLanguage) {
      final fallbackMessage = LocalizationService.getLocalizedText(
        'error.language.using_fallback',
      );
      final fallbackParams = {
        'fallbackLanguage': _getLanguageDisplayName(fallbackLanguage),
      };
      final fallbackText = LocalizationService.getLocalizedTextWithParams(
        fallbackMessage,
        fallbackParams,
      );
      localizedMessage = '$localizedMessage\n\n$fallbackText';
    }

    // Log language error
    _logLanguageError(error, errorType, requestedLanguage, fallbackLanguage);

    return LanguageErrorResult(
      errorType: errorType,
      localizedMessage: localizedMessage,
      requestedLanguage: requestedLanguage,
      fallbackLanguage: fallbackLanguage,
      canRetry: _canRetryLanguageError(errorType),
    );
  }

  /// Handle general application errors with cultural context
  static Future<GeneralErrorResult> handleGeneralError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operationContext,
    Map<String, dynamic>? additionalContext,
  }) async {
    final String errorKey;
    final Map<String, String> params = {};
    GeneralErrorType errorType;

    if (error is TempleParsingError) {
      errorKey = 'error.temple.parsing_failed';
      errorType = GeneralErrorType.templeParsing;
      params['field'] = error.field;
    } else if (error is StateError) {
      errorKey = 'error.general.invalid_state';
      errorType = GeneralErrorType.invalidState;
    } else if (error is ArgumentError) {
      errorKey = 'error.general.invalid_argument';
      errorType = GeneralErrorType.invalidArgument;
    } else if (error is UnimplementedError) {
      errorKey = 'error.general.feature_unavailable';
      errorType = GeneralErrorType.featureUnavailable;
    } else {
      errorKey = 'error.general.unexpected';
      errorType = GeneralErrorType.unexpected;
    }

    if (operationContext != null) {
      params['operation'] = operationContext;
    }

    final localizedMessage = LocalizationService.getLocalizedTextWithParams(
      errorKey,
      params,
    );

    // Log general error with full context
    _logGeneralError(
      error,
      stackTrace,
      errorType,
      operationContext,
      additionalContext,
    );

    return GeneralErrorResult(
      errorType: errorType,
      localizedMessage: localizedMessage,
      canRetry: _canRetryGeneralError(errorType),
      suggestedAction: _getSuggestedGeneralAction(errorType),
      additionalContext: additionalContext,
    );
  }

  /// Check if position is within Gujarat boundaries
  static bool _isInGujarat(Position position) {
    return position.latitude >= _gujaratMinLat &&
        position.latitude <= _gujaratMaxLat &&
        position.longitude >= _gujaratMinLng &&
        position.longitude <= _gujaratMaxLng;
  }

  /// Get Firebase error key for localization
  static String _getFirebaseErrorKey(String errorCode) {
    switch (errorCode) {
      case 'permission-denied':
        return 'error.firebase.permission_denied';
      case 'not-found':
        return 'error.firebase.not_found';
      case 'unavailable':
        return 'error.firebase.unavailable';
      case 'deadline-exceeded':
        return 'error.firebase.timeout';
      case 'unauthenticated':
        return 'error.firebase.unauthenticated';
      default:
        return 'error.firebase.general';
    }
  }

  /// Get display name for language code
  static String _getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'हिन्दी';
      case 'gu':
        return 'ગુજરાતી';
      case 'en':
        return 'English';
      default:
        return languageCode;
    }
  }

  /// Get hardcoded error message as ultimate fallback
  static String _getHardcodedErrorMessage(
    LanguageErrorType errorType,
    Map<String, String> params,
  ) {
    switch (errorType) {
      case LanguageErrorType.resourceNotFound:
        return 'Language resources not found. Using default language.';
      case LanguageErrorType.invalidFormat:
        return 'Language file format is invalid.';
      case LanguageErrorType.general:
        return 'Language error occurred.';
    }
  }

  /// Determine if location error can be retried
  static bool _canRetryLocationError(LocationErrorType errorType) {
    switch (errorType) {
      case LocationErrorType.timeout:
      case LocationErrorType.general:
        return true;
      case LocationErrorType.serviceDisabled:
      case LocationErrorType.permissionDenied:
      case LocationErrorType.outsideGujarat:
        return false;
    }
  }

  /// Get suggested action for location errors
  static String _getSuggestedLocationAction(LocationErrorType errorType) {
    switch (errorType) {
      case LocationErrorType.serviceDisabled:
        return LocalizationService.getLocalizedText(
          'error.action.enable_location',
        );
      case LocationErrorType.permissionDenied:
        return LocalizationService.getLocalizedText(
          'error.action.grant_permission',
        );
      case LocationErrorType.timeout:
        return LocalizationService.getLocalizedText('error.action.try_again');
      case LocationErrorType.outsideGujarat:
        return LocalizationService.getLocalizedText(
          'error.action.move_to_gujarat',
        );
      case LocationErrorType.general:
        return LocalizationService.getLocalizedText(
          'error.action.check_location',
        );
    }
  }

  /// Determine if network error can be retried
  static bool _canRetryNetworkError(NetworkErrorType errorType) {
    switch (errorType) {
      case NetworkErrorType.timeout:
      case NetworkErrorType.noConnection:
      case NetworkErrorType.general:
        return true;
      case NetworkErrorType.firebase:
        return false; // Firebase errors usually need specific handling
    }
  }

  /// Get suggested action for network errors
  static String _getSuggestedNetworkAction(
    NetworkErrorType errorType,
    bool hasOfflineData,
  ) {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return hasOfflineData
            ? LocalizationService.getLocalizedText('error.action.use_offline')
            : LocalizationService.getLocalizedText(
                'error.action.check_connection',
              );
      case NetworkErrorType.timeout:
        return LocalizationService.getLocalizedText('error.action.try_again');
      case NetworkErrorType.firebase:
        return LocalizationService.getLocalizedText(
          'error.action.contact_support',
        );
      case NetworkErrorType.general:
        return LocalizationService.getLocalizedText('error.action.try_again');
    }
  }

  /// Determine if language error can be retried
  static bool _canRetryLanguageError(LanguageErrorType errorType) {
    switch (errorType) {
      case LanguageErrorType.resourceNotFound:
        return false; // Resource doesn't exist
      case LanguageErrorType.invalidFormat:
        return false; // Format issue needs fixing
      case LanguageErrorType.general:
        return true;
    }
  }

  /// Determine if general error can be retried
  static bool _canRetryGeneralError(GeneralErrorType errorType) {
    switch (errorType) {
      case GeneralErrorType.templeParsing:
      case GeneralErrorType.unexpected:
        return true;
      case GeneralErrorType.invalidState:
      case GeneralErrorType.invalidArgument:
      case GeneralErrorType.featureUnavailable:
        return false;
    }
  }

  /// Get suggested action for general errors
  static String _getSuggestedGeneralAction(GeneralErrorType errorType) {
    switch (errorType) {
      case GeneralErrorType.templeParsing:
        return LocalizationService.getLocalizedText(
          'error.action.refresh_data',
        );
      case GeneralErrorType.invalidState:
        return LocalizationService.getLocalizedText('error.action.restart_app');
      case GeneralErrorType.invalidArgument:
        return LocalizationService.getLocalizedText('error.action.check_input');
      case GeneralErrorType.featureUnavailable:
        return LocalizationService.getLocalizedText('error.action.update_app');
      case GeneralErrorType.unexpected:
        return LocalizationService.getLocalizedText('error.action.try_again');
    }
  }

  // Logging methods
  static void _logLocationError(
    dynamic error,
    LocationErrorType errorType,
    Position? position,
    String? context,
  ) {
    final logData = {
      'error_type': 'location_error',
      'location_error_type': errorType.toString(),
      'position': position != null
          ? '${position.latitude},${position.longitude}'
          : null,
      'in_gujarat': position != null ? _isInGujarat(position) : null,
      'context': context,
      'language': LocalizationService.currentLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Location Error: $errorType - $error',
        name: _loggerName,
        error: error,
      );
    }

    _sendToAnalytics('location_error', logData);
  }

  static void _logNetworkError(
    dynamic error,
    NetworkErrorType errorType,
    String? context,
    bool hasOfflineData,
  ) {
    final logData = {
      'error_type': 'network_error',
      'network_error_type': errorType.toString(),
      'context': context,
      'has_offline_data': hasOfflineData,
      'language': LocalizationService.currentLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Network Error: $errorType - $error',
        name: _loggerName,
        error: error,
      );
    }

    _sendToAnalytics('network_error', logData);
  }

  static void _logLanguageError(
    dynamic error,
    LanguageErrorType errorType,
    String? requestedLanguage,
    String? fallbackLanguage,
  ) {
    final logData = {
      'error_type': 'language_error',
      'language_error_type': errorType.toString(),
      'requested_language': requestedLanguage,
      'fallback_language': fallbackLanguage,
      'current_language': LocalizationService.currentLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Language Error: $errorType - $error',
        name: _loggerName,
        error: error,
      );
    }

    _sendToAnalytics('language_error', logData);
  }

  static void _logGeneralError(
    dynamic error,
    StackTrace? stackTrace,
    GeneralErrorType errorType,
    String? context,
    Map<String, dynamic>? additionalContext,
  ) {
    final logData = {
      'error_type': 'general_error',
      'general_error_type': errorType.toString(),
      'context': context,
      'additional_context': additionalContext,
      'language': LocalizationService.currentLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'General Error: $errorType - $error',
        name: _loggerName,
        error: error,
        stackTrace: stackTrace,
      );
    }

    _sendToAnalytics('general_error', logData);
  }

  /// Send analytics data (placeholder for actual implementation)
  static void _sendToAnalytics(String eventName, Map<String, dynamic> data) {
    // In a real implementation, this would send data to Firebase Analytics,
    // Crashlytics, or another analytics service
    if (kDebugMode) {
      developer.log('Analytics Event: $eventName - $data', name: 'Analytics');
    }
  }

  /// Show user-friendly error dialog with cultural context
  static Future<void> showLocalizedErrorDialog({
    required dynamic context,
    required dynamic error,
    String? operationContext,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) async {
    // Determine error type and get appropriate result
    dynamic errorResult;

    if (error is LocationServiceDisabledException ||
        error is PermissionDeniedException ||
        error.toString().contains('timeout')) {
      errorResult = await handleLocationError(
        error,
        operationContext: operationContext,
      );
    } else if (error is TimeoutException ||
        error is FirebaseException ||
        error.toString().contains('SocketException')) {
      errorResult = await handleNetworkError(
        error,
        operationContext: operationContext,
      );
    } else if (error.toString().contains('Unable to load asset') ||
        error is FormatException) {
      errorResult = await handleLanguageError(error);
    } else {
      errorResult = await handleGeneralError(
        error,
        operationContext: operationContext,
      );
    }

    // Show dialog with cultural context
    await _showErrorDialogWithCulturalContext(
      context: context,
      errorResult: errorResult,
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }

  /// Show error dialog with cultural context
  static Future<void> _showErrorDialogWithCulturalContext({
    required dynamic context,
    required dynamic errorResult,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) async {
    final title = LocalizationService.getLocalizedText('error.title');
    final culturalContext = LocalizationService.getLocalizedText(
      'error.cultural_context',
    );

    // This would be implemented with actual Flutter dialog
    // For now, we'll log the error details
    if (kDebugMode) {
      developer.log(
        'Error Dialog: $title\n'
        'Message: ${errorResult.localizedMessage}\n'
        'Cultural Context: $culturalContext\n'
        'Can Retry: ${errorResult.canRetry}\n'
        'Suggested Action: ${errorResult.suggestedAction}',
        name: _loggerName,
      );
    }
  }

  /// Create error report with cultural context for support
  static Map<String, dynamic> createErrorReport({
    required dynamic error,
    StackTrace? stackTrace,
    String? operationContext,
    Map<String, dynamic>? userContext,
  }) {
    return {
      'error_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      'stack_trace': stackTrace?.toString(),
      'operation_context': operationContext,
      'user_context': userContext,
      'app_context': {
        'language': LocalizationService.currentLanguage,
        'locale': LocalizationService.currentLocale.toString(),
        'is_gujarati_script': LocalizationService.isGujaratiScript,
        'is_devanagari_script': LocalizationService.isDevanagariScript,
        'cultural_region': 'Gujarat',
      },
      'device_context': {'platform': 'flutter', 'debug_mode': kDebugMode},
    };
  }

  /// Handle offline data recovery for Gujarat temples
  static Future<OfflineRecoveryResult> handleOfflineRecovery({
    required String operationContext,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Check if offline Gujarat temple data is available
      final hasOfflineData = await _checkOfflineGujaratData();

      final message = hasOfflineData
          ? LocalizationService.getLocalizedText(
              'error.network.offline_data_available',
            )
          : LocalizationService.getLocalizedText('error.network.no_connection');

      return OfflineRecoveryResult(
        hasOfflineData: hasOfflineData,
        localizedMessage: message,
        operationContext: operationContext,
        additionalData: additionalData,
      );
    } catch (e) {
      return OfflineRecoveryResult(
        hasOfflineData: false,
        localizedMessage: LocalizationService.getLocalizedText(
          'error.network.general',
        ),
        operationContext: operationContext,
        additionalData: additionalData,
      );
    }
  }

  /// Check if offline Gujarat temple data is available
  static Future<bool> _checkOfflineGujaratData() async {
    try {
      // This would check actual offline data availability
      // For now, we'll simulate the check
      await Future.delayed(const Duration(milliseconds: 100));
      return true; // Assume offline data is available
    } catch (e) {
      return false;
    }
  }

  /// Validate Gujarat location boundaries
  static LocationValidationResult validateGujaratLocation(Position position) {
    final isInGujarat = _isInGujarat(position);

    return LocationValidationResult(
      isValid: isInGujarat,
      position: position,
      localizedMessage: isInGujarat
          ? LocalizationService.getLocalizedText('location.within_gujarat')
          : LocalizationService.getLocalizedTextWithParams(
              'error.location.outside_gujarat',
              {
                'latitude': position.latitude.toStringAsFixed(4),
                'longitude': position.longitude.toStringAsFixed(4),
              },
            ),
    );
  }
}

// Error result classes
class LocationErrorResult {
  final LocationErrorType errorType;
  final String localizedMessage;
  final bool canRetry;
  final String suggestedAction;

  LocationErrorResult({
    required this.errorType,
    required this.localizedMessage,
    required this.canRetry,
    required this.suggestedAction,
  });
}

class NetworkErrorResult {
  final NetworkErrorType errorType;
  final String localizedMessage;
  final bool canRetry;
  final bool hasOfflineData;
  final String suggestedAction;

  NetworkErrorResult({
    required this.errorType,
    required this.localizedMessage,
    required this.canRetry,
    required this.hasOfflineData,
    required this.suggestedAction,
  });
}

class LanguageErrorResult {
  final LanguageErrorType errorType;
  final String localizedMessage;
  final String? requestedLanguage;
  final String? fallbackLanguage;
  final bool canRetry;

  LanguageErrorResult({
    required this.errorType,
    required this.localizedMessage,
    this.requestedLanguage,
    this.fallbackLanguage,
    required this.canRetry,
  });
}

class GeneralErrorResult {
  final GeneralErrorType errorType;
  final String localizedMessage;
  final bool canRetry;
  final String suggestedAction;
  final Map<String, dynamic>? additionalContext;

  GeneralErrorResult({
    required this.errorType,
    required this.localizedMessage,
    required this.canRetry,
    required this.suggestedAction,
    this.additionalContext,
  });
}

// Error type enums
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  timeout,
  outsideGujarat,
  general,
}

enum NetworkErrorType { noConnection, timeout, firebase, general }

enum LanguageErrorType { resourceNotFound, invalidFormat, general }

enum GeneralErrorType {
  templeParsing,
  invalidState,
  invalidArgument,
  featureUnavailable,
  unexpected,
}

// Additional result classes for enhanced error handling
class OfflineRecoveryResult {
  final bool hasOfflineData;
  final String localizedMessage;
  final String operationContext;
  final Map<String, dynamic>? additionalData;

  OfflineRecoveryResult({
    required this.hasOfflineData,
    required this.localizedMessage,
    required this.operationContext,
    this.additionalData,
  });
}

class LocationValidationResult {
  final bool isValid;
  final Position position;
  final String localizedMessage;

  LocationValidationResult({
    required this.isValid,
    required this.position,
    required this.localizedMessage,
  });
}
