import 'package:flutter/material.dart';
import '../services/localized_error_handler.dart';
import '../services/localization_service.dart';

/// User-friendly error widget with Hindi/Gujarati localization and cultural context
/// Implements requirements 6.5, 9.1 for localized error display
class LocalizedErrorWidget extends StatelessWidget {
  final String errorMessage;
  final String? suggestedAction;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool canRetry;
  final IconData? errorIcon;
  final Color? errorColor;
  final bool showCulturalContext;
  final Map<String, dynamic>? additionalContext;

  const LocalizedErrorWidget({
    Key? key,
    required this.errorMessage,
    this.suggestedAction,
    this.onRetry,
    this.onDismiss,
    this.canRetry = true,
    this.errorIcon,
    this.errorColor,
    this.showCulturalContext = true,
    this.additionalContext,
  }) : super(key: key);

  /// Create error widget from LocationErrorResult
  factory LocalizedErrorWidget.fromLocationError(
    LocationErrorResult result, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return LocalizedErrorWidget(
      errorMessage: result.localizedMessage,
      suggestedAction: result.suggestedAction,
      onRetry: onRetry,
      onDismiss: onDismiss,
      canRetry: result.canRetry,
      errorIcon: _getLocationErrorIcon(result.errorType),
      errorColor: _getLocationErrorColor(result.errorType),
    );
  }

  /// Create error widget from NetworkErrorResult
  factory LocalizedErrorWidget.fromNetworkError(
    NetworkErrorResult result, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return LocalizedErrorWidget(
      errorMessage: result.localizedMessage,
      suggestedAction: result.suggestedAction,
      onRetry: onRetry,
      onDismiss: onDismiss,
      canRetry: result.canRetry,
      errorIcon: _getNetworkErrorIcon(result.errorType),
      errorColor: _getNetworkErrorColor(result.errorType),
      additionalContext: {'hasOfflineData': result.hasOfflineData},
    );
  }

  /// Create error widget from LanguageErrorResult
  factory LocalizedErrorWidget.fromLanguageError(
    LanguageErrorResult result, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return LocalizedErrorWidget(
      errorMessage: result.localizedMessage,
      onRetry: onRetry,
      onDismiss: onDismiss,
      canRetry: result.canRetry,
      errorIcon: Icons.translate,
      errorColor: Colors.orange,
      additionalContext: {
        'requestedLanguage': result.requestedLanguage,
        'fallbackLanguage': result.fallbackLanguage,
      },
    );
  }

  /// Create error widget from GeneralErrorResult
  factory LocalizedErrorWidget.fromGeneralError(
    GeneralErrorResult result, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return LocalizedErrorWidget(
      errorMessage: result.localizedMessage,
      suggestedAction: result.suggestedAction,
      onRetry: onRetry,
      onDismiss: onDismiss,
      canRetry: result.canRetry,
      errorIcon: _getGeneralErrorIcon(result.errorType),
      errorColor: _getGeneralErrorColor(result.errorType),
      additionalContext: result.additionalContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = LocalizationService.textDirection == TextDirection.rtl;
    final fontFamily = LocalizationService.getFontFamily();

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: errorColor ?? theme.colorScheme.error,
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon and title
          Row(
            children: [
              Icon(
                errorIcon ?? Icons.error_outline,
                color: errorColor ?? theme.colorScheme.error,
                size: 32.0,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  LocalizationService.getLocalizedText('error.title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: errorColor ?? theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily,
                  ),
                  textDirection: LocalizationService.textDirection,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16.0),

          // Error message
          Text(
            errorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(fontFamily: fontFamily),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
            textDirection: LocalizationService.textDirection,
          ),

          // Suggested action
          if (suggestedAction != null) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: theme.colorScheme.primary,
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      suggestedAction!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontFamily: fontFamily,
                      ),
                      textDirection: LocalizationService.textDirection,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cultural context (for Gujarat-specific errors)
          if (showCulturalContext && _shouldShowCulturalContext()) ...[
            const SizedBox(height: 12.0),
            _buildCulturalContextWidget(theme, fontFamily),
          ],

          // Action buttons
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Dismiss button
              if (onDismiss != null)
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    LocalizationService.getLocalizedText('dismiss'),
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                ),

              const SizedBox(width: 8.0),

              // Retry button
              if (canRetry && onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    LocalizationService.getLocalizedText('retry'),
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowCulturalContext() {
    return errorMessage.contains('Gujarat') ||
        errorMessage.contains('ગુજરાત') ||
        errorMessage.contains('गुजरात');
  }

  Widget _buildCulturalContextWidget(ThemeData theme, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              LocalizationService.getLocalizedText('error.cultural_context'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontFamily: fontFamily,
                fontStyle: FontStyle.italic,
              ),
              textDirection: LocalizationService.textDirection,
            ),
          ),
        ],
      ),
    );
  }

  // Static helper methods for error icons and colors
  static IconData _getLocationErrorIcon(LocationErrorType errorType) {
    switch (errorType) {
      case LocationErrorType.serviceDisabled:
        return Icons.location_disabled;
      case LocationErrorType.permissionDenied:
        return Icons.location_off;
      case LocationErrorType.timeout:
        return Icons.access_time;
      case LocationErrorType.outsideGujarat:
        return Icons.map;
      case LocationErrorType.general:
        return Icons.location_searching;
    }
  }

  static Color _getLocationErrorColor(LocationErrorType errorType) {
    switch (errorType) {
      case LocationErrorType.serviceDisabled:
      case LocationErrorType.permissionDenied:
        return Colors.red;
      case LocationErrorType.timeout:
        return Colors.orange;
      case LocationErrorType.outsideGujarat:
        return Colors.orange;
      case LocationErrorType.general:
        return Colors.grey;
    }
  }

  static IconData _getNetworkErrorIcon(NetworkErrorType errorType) {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return Icons.wifi_off;
      case NetworkErrorType.timeout:
        return Icons.access_time;
      case NetworkErrorType.firebase:
        return Icons.cloud_off;
      case NetworkErrorType.general:
        return Icons.error_outline;
    }
  }

  static Color _getNetworkErrorColor(NetworkErrorType errorType) {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return Colors.red;
      case NetworkErrorType.timeout:
        return Colors.orange;
      case NetworkErrorType.firebase:
        return Colors.purple;
      case NetworkErrorType.general:
        return Colors.grey;
    }
  }

  static IconData _getGeneralErrorIcon(GeneralErrorType errorType) {
    switch (errorType) {
      case GeneralErrorType.templeParsing:
        return Icons.data_usage;
      case GeneralErrorType.invalidState:
        return Icons.warning;
      case GeneralErrorType.invalidArgument:
        return Icons.input;
      case GeneralErrorType.featureUnavailable:
        return Icons.construction;
      case GeneralErrorType.unexpected:
        return Icons.error;
    }
  }

  static Color _getGeneralErrorColor(GeneralErrorType errorType) {
    switch (errorType) {
      case GeneralErrorType.templeParsing:
        return Colors.orange;
      case GeneralErrorType.invalidState:
        return Colors.orange;
      case GeneralErrorType.invalidArgument:
        return Colors.amber;
      case GeneralErrorType.featureUnavailable:
        return Colors.grey;
      case GeneralErrorType.unexpected:
        return Colors.red;
    }
  }
}

/// Snackbar extension for showing localized errors
extension LocalizedErrorSnackBar on ScaffoldMessengerState {
  void showLocalizedError(
    String errorMessage, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final fontFamily = LocalizationService.getFontFamily();

    showSnackBar(
      SnackBar(
        content: Text(
          errorMessage,
          style: TextStyle(fontFamily: fontFamily),
          textDirection: LocalizationService.textDirection,
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: Colors.white,
              )
            : null,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Dialog extension for showing localized error dialogs
class LocalizedErrorDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    bool barrierDismissible = true,
  }) async {
    final fontFamily = LocalizationService.getFontFamily();

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(fontFamily: fontFamily),
            textDirection: LocalizationService.textDirection,
          ),
          content: Text(
            message,
            style: TextStyle(fontFamily: fontFamily),
            textDirection: LocalizationService.textDirection,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                LocalizationService.getLocalizedText('ok'),
                style: TextStyle(fontFamily: fontFamily),
              ),
            ),
            if (actionText != null && onAction != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAction();
                },
                child: Text(
                  actionText,
                  style: TextStyle(fontFamily: fontFamily),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet extension for showing detailed error information
class LocalizedErrorBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required String errorMessage,
    String? suggestedAction,
    Map<String, dynamic>? technicalDetails,
    VoidCallback? onRetry,
  }) async {
    final fontFamily = LocalizationService.getFontFamily();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    LocalizationService.getLocalizedText('error.details'),
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontFamily: fontFamily),
                    textDirection: LocalizationService.textDirection,
                  ),

                  const SizedBox(height: 16),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error message
                          Text(
                            errorMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontFamily: fontFamily),
                            textDirection: LocalizationService.textDirection,
                          ),

                          // Suggested action
                          if (suggestedAction != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              LocalizationService.getLocalizedText(
                                'error.suggested_action',
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontFamily: fontFamily,
                                    fontWeight: FontWeight.bold,
                                  ),
                              textDirection: LocalizationService.textDirection,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              suggestedAction,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontFamily: fontFamily),
                              textDirection: LocalizationService.textDirection,
                            ),
                          ],

                          // Technical details (if available)
                          if (technicalDetails != null &&
                              technicalDetails.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ExpansionTile(
                              title: Text(
                                LocalizationService.getLocalizedText(
                                  'error.technical_details',
                                ),
                                style: TextStyle(fontFamily: fontFamily),
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    technicalDetails.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join('\n'),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          LocalizationService.getLocalizedText('close'),
                          style: TextStyle(fontFamily: fontFamily),
                        ),
                      ),
                      if (onRetry != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onRetry();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            LocalizationService.getLocalizedText('retry'),
                            style: TextStyle(fontFamily: fontFamily),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
