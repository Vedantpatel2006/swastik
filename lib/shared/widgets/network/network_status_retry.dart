import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/connectivity_service.dart';
import '../animations/loading_animations.dart';

/// Network status and retry functionality widget
/// Implements requirements 7.4, 7.5
class NetworkStatusRetry {
  /// Creates a network status indicator with connection monitoring
  static Widget networkStatusIndicator({
    VoidCallback? onTap,
    bool showLabel = true,
    bool compact = false,
  }) {
    return _NetworkStatusIndicatorWidget(
      onTap: onTap,
      showLabel: showLabel,
      compact: compact,
    );
  }

  /// Creates a retry functionality widget with network-aware retry logic
  static Widget retryFunctionality({
    required VoidCallback onRetry,
    String? operationName,
    String? errorMessage,
    bool showNetworkStatus = true,
    int maxRetries = 3,
    int currentRetryCount = 0,
  }) {
    return _RetryFunctionalityWidget(
      onRetry: onRetry,
      operationName: operationName,
      errorMessage: errorMessage,
      showNetworkStatus: showNetworkStatus,
      maxRetries: maxRetries,
      currentRetryCount: currentRetryCount,
    );
  }

  /// Creates a subtle success feedback widget
  static Widget successFeedback({
    required String message,
    Duration displayDuration = const Duration(seconds: 3),
    VoidCallback? onDismiss,
  }) {
    return _SuccessFeedbackWidget(
      message: message,
      displayDuration: displayDuration,
      onDismiss: onDismiss,
    );
  }

  /// Creates a connection quality indicator
  static Widget connectionQualityIndicator({
    bool showDetails = false,
  }) {
    return _ConnectionQualityWidget(
      showDetails: showDetails,
    );
  }

  /// Creates a network-aware operation wrapper
  static Widget networkAwareOperation({
    required Widget child,
    required Future<void> Function() operation,
    String? operationName,
    bool showLoadingOverlay = true,
  }) {
    return _NetworkAwareOperationWidget(
      child: child,
      operation: operation,
      operationName: operationName,
      showLoadingOverlay: showLoadingOverlay,
    );
  }
}

/// Network status indicator widget with real-time monitoring
class _NetworkStatusIndicatorWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final bool showLabel;
  final bool compact;

  const _NetworkStatusIndicatorWidget({
    this.onTap,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  State<_NetworkStatusIndicatorWidget> createState() =>
      _NetworkStatusIndicatorWidgetState();
}

class _NetworkStatusIndicatorWidgetState
    extends State<_NetworkStatusIndicatorWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  StreamSubscription<ConnectivityStatus>? _statusSubscription;
  bool _isCheckingConnection = false;

  @override
  void initState() {
    super.initState();
    _initializeNetworkMonitoring();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeNetworkMonitoring() async {
    // Get initial status
    _currentStatus = await _connectivityService.getConnectivityStatus();
    if (mounted) setState(() {});

    // Listen to status changes
    _statusSubscription = _connectivityService.connectivityStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _currentStatus = status;
          });
        }
      },
    );
  }

  Future<void> _checkConnection() async {
    if (_isCheckingConnection) return;

    setState(() {
      _isCheckingConnection = true;
    });

    try {
      final hasConnection = await _connectivityService.hasInternetAccess();
      setState(() {
        _currentStatus = hasConnection
            ? ConnectivityStatus.connected
            : ConnectivityStatus.disconnected;
        _isCheckingConnection = false;
      });
    } catch (e) {
      setState(() {
        _currentStatus = ConnectivityStatus.unknown;
        _isCheckingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactIndicator();
    }

    return GestureDetector(
      onTap: widget.onTap ?? _checkConnection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isCheckingConnection) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                ),
              ),
            ] else ...[
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 16,
              ),
            ],
            if (widget.showLabel) ...[
              const SizedBox(width: 6),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactIndicator() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getStatusColor(),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case ConnectivityStatus.connected:
        return const Color(0xFF10B981);
      case ConnectivityStatus.disconnected:
        return const Color(0xFFEF4444);
      case ConnectivityStatus.unknown:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case ConnectivityStatus.connected:
        return Icons.cloud_done_outlined;
      case ConnectivityStatus.disconnected:
        return Icons.cloud_off_outlined;
      case ConnectivityStatus.unknown:
        return Icons.cloud_queue_outlined;
    }
  }

  String _getStatusText() {
    if (_isCheckingConnection) return 'Checking...';
    
    switch (_currentStatus) {
      case ConnectivityStatus.connected:
        return 'Online';
      case ConnectivityStatus.disconnected:
        return 'Offline';
      case ConnectivityStatus.unknown:
        return 'Unknown';
    }
  }
}

/// Retry functionality widget with network-aware logic
class _RetryFunctionalityWidget extends StatefulWidget {
  final VoidCallback onRetry;
  final String? operationName;
  final String? errorMessage;
  final bool showNetworkStatus;
  final int maxRetries;
  final int currentRetryCount;

  const _RetryFunctionalityWidget({
    required this.onRetry,
    this.operationName,
    this.errorMessage,
    this.showNetworkStatus = true,
    this.maxRetries = 3,
    this.currentRetryCount = 0,
  });

  @override
  State<_RetryFunctionalityWidget> createState() =>
      _RetryFunctionalityWidgetState();
}

class _RetryFunctionalityWidgetState extends State<_RetryFunctionalityWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isRetrying = false;
  bool _isCheckingNetwork = false;
  ConnectivityStatus _networkStatus = ConnectivityStatus.unknown;

  @override
  void initState() {
    super.initState();
    if (widget.showNetworkStatus) {
      _checkNetworkStatus();
    }
  }

  Future<void> _checkNetworkStatus() async {
    setState(() {
      _isCheckingNetwork = true;
    });

    try {
      _networkStatus = await _connectivityService.getConnectivityStatus();
    } catch (e) {
      _networkStatus = ConnectivityStatus.unknown;
    }

    if (mounted) {
      setState(() {
        _isCheckingNetwork = false;
      });
    }
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      // Check network first if enabled
      if (widget.showNetworkStatus) {
        await _checkNetworkStatus();
        
        if (_networkStatus == ConnectivityStatus.disconnected) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No internet connection. Please check your network settings.',
                ),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
          setState(() {
            _isRetrying = false;
          });
          return;
        }
      }

      // Small delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));

      // Execute retry
      widget.onRetry();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
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
  Widget build(BuildContext context) {
    final canRetry = widget.currentRetryCount < widget.maxRetries;
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error header
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.operationName != null
                      ? '${widget.operationName} Failed'
                      : 'Operation Failed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          
          // Error message
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
          
          // Network status
          if (widget.showNetworkStatus) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Network Status: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (_isCheckingNetwork) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Checking...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ] else ...[
                  NetworkStatusRetry.networkStatusIndicator(
                    compact: false,
                    showLabel: true,
                    onTap: _checkNetworkStatus,
                  ),
                ],
              ],
            ),
          ],
          
          // Retry count
          if (widget.maxRetries > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Retry attempts: ${widget.currentRetryCount}/${widget.maxRetries}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              // Check network button
              if (widget.showNetworkStatus) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingNetwork ? null : _checkNetworkStatus,
                    icon: _isCheckingNetwork
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check, size: 16),
                    label: Text(_isCheckingNetwork ? 'Checking...' : 'Check Network'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Retry button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isRetrying || !canRetry) ? null : _handleRetry,
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(_getRetryButtonText()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canRetry
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey[400],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          // Max retries reached message
          if (!canRetry) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maximum retry attempts reached. Please check your connection and try again later.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRetryButtonText() {
    if (_isRetrying) return 'Retrying...';
    if (widget.currentRetryCount >= widget.maxRetries) return 'Max Retries Reached';
    return 'Try Again';
  }
}

/// Success feedback widget with subtle animations
class _SuccessFeedbackWidget extends StatefulWidget {
  final String message;
  final Duration displayDuration;
  final VoidCallback? onDismiss;

  const _SuccessFeedbackWidget({
    required this.message,
    this.displayDuration = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<_SuccessFeedbackWidget> createState() => _SuccessFeedbackWidgetState();
}

class _SuccessFeedbackWidgetState extends State<_SuccessFeedbackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    // Start animation
    _controller.forward();
    
    // Auto dismiss
    _dismissTimer = Timer(widget.displayDuration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 50),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close,
                      color: const Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Connection quality indicator widget
class _ConnectionQualityWidget extends StatefulWidget {
  final bool showDetails;

  const _ConnectionQualityWidget({
    this.showDetails = false,
  });

  @override
  State<_ConnectionQualityWidget> createState() =>
      _ConnectionQualityWidgetState();
}

class _ConnectionQualityWidgetState extends State<_ConnectionQualityWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  ConnectionQuality _quality = ConnectionQuality.unknown;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionQuality();
  }

  Future<void> _checkConnectionQuality() async {
    setState(() {
      _isChecking = true;
    });

    try {
      _quality = await _connectivityService.getConnectionQuality();
    } catch (e) {
      _quality = ConnectionQuality.unknown;
    }

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Checking connection quality...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _checkConnectionQuality,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getQualityColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getQualityColor().withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSignalBars(),
            if (widget.showDetails) ...[
              const SizedBox(width: 6),
              Text(
                _getQualityText(),
                style: TextStyle(
                  color: _getQualityColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalBars() {
    final barCount = _getBarCount();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = index < barCount;
        return Container(
          width: 3,
          height: 8 + (index * 2),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? _getQualityColor() : Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Color _getQualityColor() {
    switch (_quality) {
      case ConnectionQuality.excellent:
        return const Color(0xFF10B981);
      case ConnectionQuality.good:
        return const Color(0xFF10B981);
      case ConnectionQuality.fair:
        return const Color(0xFFF59E0B);
      case ConnectionQuality.poor:
        return const Color(0xFFEF4444);
      case ConnectionQuality.unknown:
        return Colors.grey;
    }
  }

  String _getQualityText() {
    switch (_quality) {
      case ConnectionQuality.excellent:
        return 'Excellent';
      case ConnectionQuality.good:
        return 'Good';
      case ConnectionQuality.fair:
        return 'Fair';
      case ConnectionQuality.poor:
        return 'Poor';
      case ConnectionQuality.unknown:
        return 'Unknown';
    }
  }

  int _getBarCount() {
    switch (_quality) {
      case ConnectionQuality.excellent:
        return 4;
      case ConnectionQuality.good:
        return 3;
      case ConnectionQuality.fair:
        return 2;
      case ConnectionQuality.poor:
        return 1;
      case ConnectionQuality.unknown:
        return 0;
    }
  }
}

/// Network-aware operation wrapper widget
class _NetworkAwareOperationWidget extends StatefulWidget {
  final Widget child;
  final Future<void> Function() operation;
  final String? operationName;
  final bool showLoadingOverlay;

  const _NetworkAwareOperationWidget({
    required this.child,
    required this.operation,
    this.operationName,
    this.showLoadingOverlay = true,
  });

  @override
  State<_NetworkAwareOperationWidget> createState() =>
      _NetworkAwareOperationWidgetState();
}

class _NetworkAwareOperationWidgetState
    extends State<_NetworkAwareOperationWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isExecuting = false;
  String? _errorMessage;

  Future<void> _executeOperation() async {
    setState(() {
      _isExecuting = true;
      _errorMessage = null;
    });

    try {
      // Check network connectivity first
      final hasConnection = await _connectivityService.hasInternetAccess();
      
      if (!hasConnection) {
        throw Exception('No internet connection available');
      }

      // Execute the operation
      await widget.operation();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.operationName != null
                  ? '${widget.operationName} completed successfully'
                  : 'Operation completed successfully',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Loading overlay
        if (_isExecuting && widget.showLoadingOverlay)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingAnimations.templeLoadingAnimation(
                      size: 60,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.operationName ?? 'Processing...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Error overlay
        if (_errorMessage != null)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: NetworkStatusRetry.retryFunctionality(
                onRetry: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _executeOperation();
                },
                operationName: widget.operationName,
                errorMessage: _errorMessage,
              ),
            ),
          ),
      ],
    );
  }
}

/// Connection quality enumeration
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
  unknown,
}

/// Extension to add connection quality checking to ConnectivityService
extension ConnectivityServiceExtension on ConnectivityService {
  Future<ConnectionQuality> getConnectionQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      final hasConnection = await hasInternetAccess();
      stopwatch.stop();
      
      if (!hasConnection) {
        return ConnectionQuality.poor;
      }
      
      final responseTime = stopwatch.elapsedMilliseconds;
      
      if (responseTime < 500) {
        return ConnectionQuality.excellent;
      } else if (responseTime < 1000) {
        return ConnectionQuality.good;
      } else if (responseTime < 2000) {
        return ConnectionQuality.fair;
      } else {
        return ConnectionQuality.poor;
      }
    } catch (e) {
      return ConnectionQuality.unknown;
    }
  }
}