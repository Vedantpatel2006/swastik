import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity and internet access
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<ConnectivityStatus>? _statusController;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  DateTime? _lastConnectivityCheck;
  static const Duration _connectivityCacheTimeout = Duration(seconds: 30);

  /// Initialize the connectivity service
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('ConnectivityService: Initializing connectivity monitoring');
    }

    // Get initial connectivity status
    await _updateConnectivityStatus();

    // Start monitoring connectivity changes
    _startConnectivityMonitoring();
  }

  /// Get current connectivity status
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Check if device is connected to internet
  bool get isConnected => _currentStatus == ConnectivityStatus.connected;

  /// Check if device has no connectivity
  bool get isDisconnected => _currentStatus == ConnectivityStatus.disconnected;

  /// Check if connectivity status is unknown
  bool get isUnknown => _currentStatus == ConnectivityStatus.unknown;

  /// Get connectivity status with cache timeout
  Future<ConnectivityStatus> getConnectivityStatus() async {
    // Return cached status if recent
    if (_lastConnectivityCheck != null &&
        DateTime.now().difference(_lastConnectivityCheck!) <
            _connectivityCacheTimeout) {
      return _currentStatus;
    }

    await _updateConnectivityStatus();
    return _currentStatus;
  }

  /// Check internet connectivity by attempting to reach a reliable host
  Future<bool> hasInternetAccess() async {
    try {
      // First check basic connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Test actual internet access
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 10));

      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (kDebugMode) {
        debugPrint('ConnectivityService: Internet access check: $hasInternet');
      }

      return hasInternet;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ConnectivityService: Internet access check failed: $e');
      }
      return false;
    }
  }

  /// Stream of connectivity status changes
  Stream<ConnectivityStatus> get statusStream {
    _statusController ??= StreamController<ConnectivityStatus>.broadcast();
    return _statusController!.stream;
  }

  /// Stream of connectivity status changes (alias for compatibility)
  Stream<ConnectivityStatus> get connectivityStream => statusStream;

  /// Get human-readable connectivity status message
  String getStatusMessage(ConnectivityStatus status) {
    switch (status) {
      case ConnectivityStatus.connected:
        return 'Connected to internet';
      case ConnectivityStatus.disconnected:
        return 'No internet connection';
      case ConnectivityStatus.unknown:
        return 'Checking connection...';
    }
  }

  /// Get connectivity error message with retry suggestion
  String getConnectivityErrorMessage() {
    switch (_currentStatus) {
      case ConnectivityStatus.disconnected:
        return 'No internet connection. Please check your network settings and try again.';
      case ConnectivityStatus.unknown:
        return 'Unable to determine connection status. Please try again.';
      case ConnectivityStatus.connected:
        return 'Connection issue occurred. Please try again.';
    }
  }

  /// Wait for internet connection with timeout
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    late StreamSubscription<ConnectivityStatus> subscription;

    // Set up timeout
    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    // Listen for connectivity changes
    subscription = statusStream.listen((status) {
      if (status == ConnectivityStatus.connected && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    final result = await completer.future;

    // Cleanup
    timeoutTimer.cancel();
    await subscription.cancel();

    return result;
  }

  /// Retry operation with connectivity check
  Future<T> retryWithConnectivity<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    Duration connectivityTimeout = const Duration(seconds: 10),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        // Check connectivity before attempting operation
        if (!isConnected) {
          final hasConnection = await waitForConnection(
            timeout: connectivityTimeout,
          );
          if (!hasConnection) {
            throw ConnectivityException('No internet connection available');
          }
        }

        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= maxRetries) {
          rethrow;
        }

        if (kDebugMode) {
          debugPrint('ConnectivityService: Retry attempt $attempts failed: $e');
        }

        // Wait before retrying
        await Future.delayed(delay);

        // Update connectivity status
        await _updateConnectivityStatus();
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        await _updateConnectivityStatus();
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
            'ConnectivityService: Connectivity monitoring error: $error',
          );
        }
      },
    );
  }

  /// Update connectivity status and notify listeners
  Future<void> _updateConnectivityStatus() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasBasicConnectivity =
          connectivityResult != ConnectivityResult.none;

      final ConnectivityStatus newStatus;

      if (!hasBasicConnectivity) {
        newStatus = ConnectivityStatus.disconnected;
      } else {
        // For basic connectivity, assume connected.
        // Real internet check can be done separately when needed.
        newStatus = ConnectivityStatus.connected;
      }

      if (newStatus != _currentStatus) {
        _currentStatus = newStatus;
        _lastConnectivityCheck = DateTime.now();

        if (kDebugMode) {
          debugPrint('ConnectivityService: Status changed to $_currentStatus');
        }

        // Notify listeners
        _statusController?.add(_currentStatus);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ConnectivityService: Error updating connectivity status: $e',
        );
      }

      _currentStatus = ConnectivityStatus.unknown;
      _lastConnectivityCheck = DateTime.now();
      _statusController?.add(_currentStatus);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    await _statusController?.close();
    _statusController = null;

    if (kDebugMode) {
      debugPrint('ConnectivityService: Disposed');
    }
  }
}

/// Connectivity status enumeration
enum ConnectivityStatus { connected, disconnected, unknown }

/// Exception thrown when connectivity issues occur
class ConnectivityException implements Exception {
  final String message;
  final ConnectivityStatus? status;

  const ConnectivityException(this.message, [this.status]);

  @override
  String toString() => 'ConnectivityException: $message';
}
