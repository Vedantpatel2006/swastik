import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../core/themes/app_colors.dart';
import '../widgets/error/index.dart';

/// Network error recovery widget with automatic retry and connectivity monitoring
class NetworkErrorRecoveryWidget extends StatefulWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onOfflineMode;
  final bool showOfflineOption;
  final bool autoRetryOnConnection;
  final Duration retryDelay;

  const NetworkErrorRecoveryWidget({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onOfflineMode,
    this.showOfflineOption = true,
    this.autoRetryOnConnection = true,
    this.retryDelay = const Duration(seconds: 2),
  });

  @override
  State<NetworkErrorRecoveryWidget> createState() =>
      _NetworkErrorRecoveryWidgetState();
}

class _NetworkErrorRecoveryWidgetState extends State<NetworkErrorRecoveryWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isConnected = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeConnectivityMonitoring();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      final isConnected = result != ConnectivityResult.none;

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });

        // Auto-retry when connection is restored
        if (isConnected &&
            widget.autoRetryOnConnection &&
            !_isRetrying &&
            widget.onRetry != null) {
          _handleAutoRetry();
        }
      }
    });

    // Check initial connectivity
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final isConnected = result != ConnectivityResult.none;

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      // Handle connectivity check error
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _handleAutoRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    // Wait for the retry delay
    await Future.delayed(widget.retryDelay);

    if (mounted && widget.onRetry != null) {
      widget.onRetry!();
    }

    if (mounted) {
      setState(() {
        _isRetrying = false;
      });
    }
  }

  Future<void> _handleManualRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      if (widget.onRetry != null) {
        widget.onRetry!();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated network icon
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? AppColors.successGreen.withValues(alpha: 0.1)
                        : AppColors.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 48,
                    color: _isConnected
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                widget.title ??
                    (_isConnected
                        ? 'Connection Restored'
                        : 'Connection Problem'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Message
              Text(
                widget.message ??
                    (_isConnected
                        ? 'Your internet connection has been restored. Retrying...'
                        : 'Please check your internet connection and try again.'),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Connection status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? AppColors.successGreen.withValues(alpha: 0.1)
                      : AppColors.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected
                        ? AppColors.successGreen.withValues(alpha: 0.3)
                        : AppColors.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: _isConnected
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Column(
                children: [
                  // Retry button
                  if (widget.onRetry != null)
                    AnimatedRetryButton(
                      onPressed: _isRetrying ? null : _handleManualRetry,
                      text: _isRetrying ? 'Retrying...' : 'Try Again',
                      isLoading: _isRetrying,
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      style: RetryButtonStyle.filled,
                      width: double.infinity,
                    ),

                  // Offline mode button
                  if (widget.showOfflineOption &&
                      widget.onOfflineMode != null) ...[
                    const SizedBox(height: 12),
                    AnimatedRetryButton(
                      onPressed: widget.onOfflineMode,
                      text: 'Continue Offline',
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.secondaryText,
                      style: RetryButtonStyle.outlined,
                      width: double.infinity,
                    ),
                  ],
                ],
              ),

              // Auto-retry indicator
              if (_isRetrying && widget.autoRetryOnConnection) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Auto-retrying...',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Compact network error recovery for smaller spaces
class CompactNetworkErrorRecovery extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool showRetryButton;

  const CompactNetworkErrorRecovery({
    super.key,
    this.message,
    this.onRetry,
    this.showRetryButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? 'Network connection failed',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(width: 12),
            AnimatedRetryButton(
              onPressed: onRetry,
              text: 'Retry',
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              style: RetryButtonStyle.filled,
              height: 32,
            ),
          ],
        ],
      ),
    );
  }
}
