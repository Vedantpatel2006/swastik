import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'realtime_live_controller.dart';
import 'realtime_live_provider.dart';

/// Live Darshan Application Service
/// 
/// This service manages the entire real-time live detection system.
/// It should be initialized once at app startup and handles:
/// 1. Starting/stopping the background controller
/// 2. Managing app lifecycle (foreground/background)
/// 3. Providing clean access to live status for UI
/// 
/// Usage:
/// - Initialize once in main()
/// - UI components use RealtimeLiveProvider for streams
/// - Background monitoring runs automatically
class LiveDarshanAppService {
  static final LiveDarshanAppService _instance = LiveDarshanAppService._internal();
  factory LiveDarshanAppService() => _instance;
  LiveDarshanAppService._internal();

  final RealtimeLiveController _controller = RealtimeLiveController();
  final RealtimeLiveProvider _provider = RealtimeLiveProvider();
  
  bool _isInitialized = false;
  bool _isRunning = false;
  Timer? _statusTimer;

  /// Initialize the live darshan system
  /// Call this once at app startup
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ LiveDarshanAppService already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing LiveDarshanAppService...');
      
      // Initialize the controller
      await _controller.initialize();
      
      // Start real-time monitoring
      await startRealtimeMonitoring();
      
      // Setup app lifecycle handling
      _setupAppLifecycleHandling();
      
      // Start status monitoring
      _startStatusMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ LiveDarshanAppService initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize LiveDarshanAppService: $e');
      rethrow;
    }
  }

  /// Start real-time monitoring
  Future<void> startRealtimeMonitoring() async {
    if (_isRunning) {
      debugPrint('⚠️ Real-time monitoring already running');
      return;
    }

    try {
      await _controller.startRealtimeMonitoring();
      _isRunning = true;
      debugPrint('✅ Real-time monitoring started');
    } catch (e) {
      debugPrint('❌ Failed to start real-time monitoring: $e');
      rethrow;
    }
  }

  /// Stop real-time monitoring
  Future<void> stopRealtimeMonitoring() async {
    if (!_isRunning) return;

    try {
      await _controller.stopRealtimeMonitoring();
      _isRunning = false;
      debugPrint('✅ Real-time monitoring stopped');
    } catch (e) {
      debugPrint('❌ Failed to stop real-time monitoring: $e');
    }
  }

  /// Setup app lifecycle handling
  void _setupAppLifecycleHandling() {
    // Listen to app lifecycle changes
    SystemChannels.lifecycle.setMessageHandler((message) async {
      debugPrint('📱 App lifecycle: $message');
      
      switch (message) {
        case 'AppLifecycleState.resumed':
          // App came to foreground - ensure monitoring is running
          if (!_isRunning) {
            await startRealtimeMonitoring();
          }
          // Force refresh to get latest status
          await _controller.forceRefreshAll();
          break;
          
        case 'AppLifecycleState.paused':
          // App went to background - keep monitoring running
          // (Real-time system should work even when app is backgrounded)
          debugPrint('📱 App backgrounded - keeping monitoring active');
          break;
          
        case 'AppLifecycleState.detached':
          // App is being terminated
          await stopRealtimeMonitoring();
          break;
      }
      
      return null;
    });
  }

  /// Start status monitoring (for debugging and health checks)
  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      final controllerStats = _controller.getMonitoringStats();
      final providerStats = _provider.getStats();
      
      debugPrint('📊 Live System Status:');
      debugPrint('   Controller: ${controllerStats['isRunning'] ? 'RUNNING' : 'STOPPED'}');
      debugPrint('   Monitoring: ${controllerStats['monitoringCount']} temples');
      debugPrint('   Live: ${controllerStats['liveTemples']} temples');
      debugPrint('   Failures: ${controllerStats['totalFailures']}');
      debugPrint('   Provider Streams: ${providerStats['activeStreams']}');
    });
  }

  /// Get the live provider (for UI components)
  RealtimeLiveProvider get liveProvider => _provider;

  /// Get the controller (for admin/debug purposes)
  RealtimeLiveController get controller => _controller;

  /// Add a temple to monitoring (when admin configures new temple)
  Future<void> addTempleToMonitoring(String templeId) async {
    if (!_isRunning) {
      debugPrint('⚠️ Cannot add temple - monitoring not running');
      return;
    }

    await _controller.addTempleToMonitoring(templeId);
    debugPrint('✅ Added temple to monitoring: $templeId');
  }

  /// Remove a temple from monitoring (when admin disables temple)
  void removeTempleFromMonitoring(String templeId) {
    _controller.removeTempleFromMonitoring(templeId);
    debugPrint('✅ Removed temple from monitoring: $templeId');
  }

  /// Force refresh all temples (manual trigger)
  Future<void> forceRefreshAll() async {
    if (!_isRunning) {
      debugPrint('⚠️ Cannot refresh - monitoring not running');
      return;
    }

    await _controller.forceRefreshAll();
    debugPrint('✅ Force refresh completed');
  }

  /// Restart monitoring for a specific temple (for admin interface)
  Future<void> restartTempleMonitoring(String templeId) async {
    if (!_isRunning) {
      debugPrint('⚠️ Cannot restart temple monitoring - system not running');
      return;
    }

    await _controller.restartTempleMonitoring(templeId);
    debugPrint('✅ Temple monitoring restarted: $templeId');
  }

  /// Get system health status
  Map<String, dynamic> getSystemHealth() {
    final controllerStats = _controller.getMonitoringStats();
    final providerStats = _provider.getStats();
    
    return {
      'isInitialized': _isInitialized,
      'isRunning': _isRunning,
      'controller': controllerStats,
      'provider': providerStats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Restart the entire system (for error recovery)
  Future<void> restartSystem() async {
    debugPrint('🔄 Restarting live darshan system...');
    
    try {
      // Stop everything
      await stopRealtimeMonitoring();
      _provider.dispose();
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));
      
      // Restart
      await startRealtimeMonitoring();
      
      debugPrint('✅ Live darshan system restarted');
    } catch (e) {
      debugPrint('❌ Failed to restart system: $e');
      rethrow;
    }
  }

  /// Dispose the service (call on app termination)
  Future<void> dispose() async {
    debugPrint('🧹 Disposing LiveDarshanAppService...');
    
    _statusTimer?.cancel();
    _statusTimer = null;
    
    await stopRealtimeMonitoring();
    _provider.dispose();
    
    _isInitialized = false;
    debugPrint('✅ LiveDarshanAppService disposed');
  }

  /// Check if system is healthy
  bool get isHealthy {
    return _isInitialized && _isRunning;
  }

  /// Get current system status
  String get systemStatus {
    if (!_isInitialized) return 'NOT_INITIALIZED';
    if (!_isRunning) return 'STOPPED';
    return 'RUNNING';
  }
}