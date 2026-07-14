import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'enhanced_image_cache_manager.dart';

/// Cache optimization strategy
enum OptimizationStrategy {
  aggressive, // Maximum compression and cleanup
  balanced, // Balance between quality and size
  conservative, // Minimal optimization, preserve quality
  adaptive, // Adapt based on device capabilities and usage
}

/// Cache cleanup trigger
enum CleanupTrigger {
  manual, // Manually triggered
  scheduled, // Scheduled cleanup
  threshold, // Triggered by size/usage threshold
  lowMemory, // Triggered by low memory warning
  appBackground, // Triggered when app goes to background
}

/// Optimization task configuration
class OptimizationTask {
  final String id;
  final OptimizationStrategy strategy;
  final CleanupTrigger trigger;
  final DateTime scheduledTime;
  final Map<String, dynamic> parameters;
  final int priority;

  const OptimizationTask({
    required this.id,
    required this.strategy,
    required this.trigger,
    required this.scheduledTime,
    this.parameters = const {},
    this.priority = 5,
  });
}

/// Result of cache optimization operation
class CacheOptimizationResult {
  final String taskId;
  final OptimizationStrategy strategy;
  final bool success;
  final Duration executionTime;
  final int entriesProcessed;
  final int entriesOptimized;
  final int entriesRemoved;
  final int bytesFreed;
  final int bytesOptimized;
  final String? error;
  final Map<String, dynamic> details;

  const CacheOptimizationResult({
    required this.taskId,
    required this.strategy,
    required this.success,
    required this.executionTime,
    this.entriesProcessed = 0,
    this.entriesOptimized = 0,
    this.entriesRemoved = 0,
    this.bytesFreed = 0,
    this.bytesOptimized = 0,
    this.error,
    this.details = const {},
  });

  /// Get optimization summary
  Map<String, dynamic> get summary => {
    'taskId': taskId,
    'strategy': strategy.name,
    'success': success,
    'executionTime': executionTime.inMilliseconds,
    'entriesProcessed': entriesProcessed,
    'entriesOptimized': entriesOptimized,
    'entriesRemoved': entriesRemoved,
    'bytesFreed': bytesFreed,
    'bytesOptimized': bytesOptimized,
    'compressionRatio': entriesProcessed > 0
        ? (bytesOptimized / (bytesOptimized + bytesFreed)) * 100
        : 0.0,
  };
}

/// Device capability assessment for adaptive optimization
class DeviceCapabilities {
  final int totalMemoryMB;
  final int availableMemoryMB;
  final double cpuUsage;
  final bool isLowEndDevice;
  final bool hasSlowStorage;
  final bool isOnBattery;
  final bool hasLimitedData;

  const DeviceCapabilities({
    required this.totalMemoryMB,
    required this.availableMemoryMB,
    required this.cpuUsage,
    required this.isLowEndDevice,
    required this.hasSlowStorage,
    required this.isOnBattery,
    required this.hasLimitedData,
  });

  /// Get recommended optimization strategy based on capabilities
  OptimizationStrategy get recommendedStrategy {
    if (isLowEndDevice || availableMemoryMB < 512) {
      return OptimizationStrategy.aggressive;
    } else if (isOnBattery || hasLimitedData) {
      return OptimizationStrategy.balanced;
    } else if (cpuUsage > 0.8) {
      return OptimizationStrategy.conservative;
    } else {
      return OptimizationStrategy.adaptive;
    }
  }

  /// Check if device can handle intensive optimization
  bool get canHandleIntensiveOptimization {
    return !isLowEndDevice &&
        availableMemoryMB > 1024 &&
        cpuUsage < 0.6 &&
        !isOnBattery;
  }
}

/// Image cache optimizer with intelligent cleanup and optimization
class ImageCacheOptimizer {
  static final ImageCacheOptimizer _instance = ImageCacheOptimizer._internal();
  factory ImageCacheOptimizer() => _instance;
  ImageCacheOptimizer._internal();

  EnhancedImageCacheManager? _cacheManager;
  Timer? _scheduledOptimizationTimer;
  Timer? _monitoringTimer;

  final Map<String, OptimizationTask> _scheduledTasks = {};
  final List<CacheOptimizationResult> _optimizationHistory = [];

  // Configuration
  OptimizationStrategy _defaultStrategy = OptimizationStrategy.balanced;
  Duration _scheduledOptimizationInterval = const Duration(hours: 6);
  double _aggressiveCleanupThreshold = 0.95; // 95% cache full
  double _balancedCleanupThreshold = 0.85; // 85% cache full
  int _maxHistoryEntries = 50;
  bool _enableAdaptiveOptimization = true;
  bool _enableBackgroundOptimization = true;

  // Statistics
  int _totalOptimizations = 0;
  int _successfulOptimizations = 0;
  int _totalBytesFreed = 0;
  int _totalBytesOptimized = 0;

  bool _isInitialized = false;
  bool _isOptimizing = false;

  /// Initialize the cache optimizer
  Future<void> initialize({
    EnhancedImageCacheManager? cacheManager,
    OptimizationStrategy? defaultStrategy,
    Duration? scheduledInterval,
    bool? enableAdaptiveOptimization,
    bool? enableBackgroundOptimization,
  }) async {
    if (_isInitialized) return;

    try {
      _cacheManager = cacheManager ?? EnhancedImageCacheManager();

      _defaultStrategy = defaultStrategy ?? _defaultStrategy;
      _scheduledOptimizationInterval =
          scheduledInterval ?? _scheduledOptimizationInterval;
      _enableAdaptiveOptimization =
          enableAdaptiveOptimization ?? _enableAdaptiveOptimization;
      _enableBackgroundOptimization =
          enableBackgroundOptimization ?? _enableBackgroundOptimization;

      await _cacheManager!.initialize();

      if (_enableBackgroundOptimization) {
        _startScheduledOptimization();
        _startCacheMonitoring();
      }

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('ImageCacheOptimizer: Initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageCacheOptimizer: Error initializing - $e');
      }
    }
  }

  /// Perform cache optimization with specified strategy
  Future<CacheOptimizationResult> optimizeCache({
    OptimizationStrategy? strategy,
    CleanupTrigger trigger = CleanupTrigger.manual,
    Map<String, dynamic> parameters = const {},
  }) async {
    if (!_isInitialized) await initialize();

    if (_isOptimizing) {
      return CacheOptimizationResult(
        taskId: 'duplicate_${DateTime.now().millisecondsSinceEpoch}',
        strategy: strategy ?? _defaultStrategy,
        success: false,
        executionTime: Duration.zero,
        error: 'Optimization already in progress',
      );
    }

    _isOptimizing = true;
    final taskId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final stopwatch = Stopwatch()..start();

    try {
      final effectiveStrategy =
          strategy ??
          (_enableAdaptiveOptimization
              ? await _getAdaptiveStrategy()
              : _defaultStrategy);

      if (kDebugMode) {
        debugPrint(
          'ImageCacheOptimizer: Starting optimization with ${effectiveStrategy.name} strategy',
        );
      }

      final result = await _executeOptimization(
        taskId,
        effectiveStrategy,
        trigger,
        parameters,
      );

      stopwatch.stop();

      _totalOptimizations++;
      if (result.success) {
        _successfulOptimizations++;
        _totalBytesFreed += result.bytesFreed;
        _totalBytesOptimized += result.bytesOptimized;
      }

      // Store result in history
      _optimizationHistory.add(result);
      if (_optimizationHistory.length > _maxHistoryEntries) {
        _optimizationHistory.removeAt(0);
      }

      if (kDebugMode) {
        debugPrint(
          'ImageCacheOptimizer: Optimization completed - ${result.summary}',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      return CacheOptimizationResult(
        taskId: taskId,
        strategy: strategy ?? _defaultStrategy,
        success: false,
        executionTime: stopwatch.elapsed,
        error: e.toString(),
      );
    } finally {
      _isOptimizing = false;
    }
  }

  /// Execute optimization based on strategy
  Future<CacheOptimizationResult> _executeOptimization(
    String taskId,
    OptimizationStrategy strategy,
    CleanupTrigger trigger,
    Map<String, dynamic> parameters,
  ) async {
    int entriesProcessed = 0;
    int entriesOptimized = 0;
    int entriesRemoved = 0;
    int bytesOptimized = 0;

    final cacheStats = _cacheManager!.getDetailedStatistics();
    final initialSize = cacheStats['totalSize'] as int;

    switch (strategy) {
      case OptimizationStrategy.aggressive:
        final result = await _performAggressiveOptimization();
        entriesProcessed = result['entriesProcessed'] ?? 0;
        entriesOptimized = result['entriesOptimized'] ?? 0;
        entriesRemoved = result['entriesRemoved'] ?? 0;
        bytesOptimized = result['bytesOptimized'] ?? 0;
        break;

      case OptimizationStrategy.balanced:
        final result = await _performBalancedOptimization();
        entriesProcessed = result['entriesProcessed'] ?? 0;
        entriesOptimized = result['entriesOptimized'] ?? 0;
        entriesRemoved = result['entriesRemoved'] ?? 0;
        bytesOptimized = result['bytesOptimized'] ?? 0;
        break;

      case OptimizationStrategy.conservative:
        final result = await _performConservativeOptimization();
        entriesProcessed = result['entriesProcessed'] ?? 0;
        entriesOptimized = result['entriesOptimized'] ?? 0;
        entriesRemoved = result['entriesRemoved'] ?? 0;
        bytesOptimized = result['bytesOptimized'] ?? 0;
        break;

      case OptimizationStrategy.adaptive:
        final result = await _performAdaptiveOptimization();
        entriesProcessed = result['entriesProcessed'] ?? 0;
        entriesOptimized = result['entriesOptimized'] ?? 0;
        entriesRemoved = result['entriesRemoved'] ?? 0;
        bytesOptimized = result['bytesOptimized'] ?? 0;
        break;
    }

    final finalStats = _cacheManager!.getDetailedStatistics();
    final finalSize = finalStats['totalSize'] as int;
    final actualBytesFreed = math.max(0, initialSize - finalSize);

    return CacheOptimizationResult(
      taskId: taskId,
      strategy: strategy,
      success: true,
      executionTime: DateTime.now().difference(DateTime.now()),
      entriesProcessed: entriesProcessed,
      entriesOptimized: entriesOptimized,
      entriesRemoved: entriesRemoved,
      bytesFreed: actualBytesFreed,
      bytesOptimized: bytesOptimized,
      details: {
        'trigger': trigger.name,
        'initialSize': initialSize,
        'finalSize': finalSize,
        'parameters': parameters,
      },
    );
  }

  /// Perform aggressive optimization (maximum cleanup and compression)
  Future<Map<String, int>> _performAggressiveOptimization() async {
    int entriesProcessed = 0;
    int entriesOptimized = 0;
    int entriesRemoved = 0;
    int bytesFreed = 0;
    int bytesOptimized = 0;

    // Remove expired entries
    final expiredResult = await _removeExpiredEntries();
    entriesRemoved += expiredResult['removed'] ?? 0;
    bytesFreed += expiredResult['bytesFreed'] ?? 0;

    // Remove low-priority entries
    final lowPriorityResult = await _removeLowPriorityEntries(threshold: 3);
    entriesRemoved += lowPriorityResult['removed'] ?? 0;
    bytesFreed += lowPriorityResult['bytesFreed'] ?? 0;

    // Aggressive LRU eviction (remove 40% of cache)
    final lruResult = await _performLRUEviction(evictionRatio: 0.4);
    entriesRemoved += lruResult['removed'] ?? 0;
    bytesFreed += lruResult['bytesFreed'] ?? 0;

    // Re-optimize remaining images with high compression
    final optimizationResult = await _reoptimizeImages(
      qualityTarget: 60,
      maxSizeReduction: 0.7,
    );
    entriesOptimized += optimizationResult['optimized'] ?? 0;
    bytesOptimized += optimizationResult['bytesOptimized'] ?? 0;

    entriesProcessed = entriesRemoved + entriesOptimized;

    return {
      'entriesProcessed': entriesProcessed,
      'entriesOptimized': entriesOptimized,
      'entriesRemoved': entriesRemoved,
      'bytesFreed': bytesFreed,
      'bytesOptimized': bytesOptimized,
    };
  }

  /// Perform balanced optimization (moderate cleanup and compression)
  Future<Map<String, int>> _performBalancedOptimization() async {
    int entriesProcessed = 0;
    int entriesOptimized = 0;
    int entriesRemoved = 0;
    int bytesFreed = 0;
    int bytesOptimized = 0;

    // Remove expired entries
    final expiredResult = await _removeExpiredEntries();
    entriesRemoved += expiredResult['removed'] ?? 0;
    bytesFreed += expiredResult['bytesFreed'] ?? 0;

    // Remove very low-priority entries
    final lowPriorityResult = await _removeLowPriorityEntries(threshold: 1);
    entriesRemoved += lowPriorityResult['removed'] ?? 0;
    bytesFreed += lowPriorityResult['bytesFreed'] ?? 0;

    // Moderate LRU eviction if needed (remove 20% of cache)
    final cacheUsage = await _getCacheUsageRatio();
    if (cacheUsage > _balancedCleanupThreshold) {
      final lruResult = await _performLRUEviction(evictionRatio: 0.2);
      entriesRemoved += lruResult['removed'] ?? 0;
      bytesFreed += lruResult['bytesFreed'] ?? 0;
    }

    // Re-optimize old images with moderate compression
    final optimizationResult = await _reoptimizeImages(
      qualityTarget: 75,
      maxSizeReduction: 0.5,
      ageThreshold: const Duration(days: 7),
    );
    entriesOptimized += optimizationResult['optimized'] ?? 0;
    bytesOptimized += optimizationResult['bytesOptimized'] ?? 0;

    entriesProcessed = entriesRemoved + entriesOptimized;

    return {
      'entriesProcessed': entriesProcessed,
      'entriesOptimized': entriesOptimized,
      'entriesRemoved': entriesRemoved,
      'bytesFreed': bytesFreed,
      'bytesOptimized': bytesOptimized,
    };
  }

  /// Perform conservative optimization (minimal cleanup, preserve quality)
  Future<Map<String, int>> _performConservativeOptimization() async {
    int entriesProcessed = 0;
    int entriesOptimized = 0;
    int entriesRemoved = 0;
    int bytesFreed = 0;
    int bytesOptimized = 0;

    // Only remove expired entries
    final expiredResult = await _removeExpiredEntries();
    entriesRemoved += expiredResult['removed'] ?? 0;
    bytesFreed += expiredResult['bytesFreed'] ?? 0;

    // Only perform LRU eviction if critically full
    final cacheUsage = await _getCacheUsageRatio();
    if (cacheUsage > _aggressiveCleanupThreshold) {
      final lruResult = await _performLRUEviction(evictionRatio: 0.1);
      entriesRemoved += lruResult['removed'] ?? 0;
      bytesFreed += lruResult['bytesFreed'] ?? 0;
    }

    // Only re-optimize very old images with minimal compression
    final optimizationResult = await _reoptimizeImages(
      qualityTarget: 85,
      maxSizeReduction: 0.3,
      ageThreshold: const Duration(days: 30),
    );
    entriesOptimized += optimizationResult['optimized'] ?? 0;
    bytesOptimized += optimizationResult['bytesOptimized'] ?? 0;

    entriesProcessed = entriesRemoved + entriesOptimized;

    return {
      'entriesProcessed': entriesProcessed,
      'entriesOptimized': entriesOptimized,
      'entriesRemoved': entriesRemoved,
      'bytesFreed': bytesFreed,
      'bytesOptimized': bytesOptimized,
    };
  }

  /// Perform adaptive optimization based on device capabilities
  Future<Map<String, int>> _performAdaptiveOptimization() async {
    final capabilities = await _assessDeviceCapabilities();
    final recommendedStrategy = capabilities.recommendedStrategy;

    if (kDebugMode) {
      debugPrint(
        'ImageCacheOptimizer: Adaptive strategy selected: ${recommendedStrategy.name}',
      );
    }

    switch (recommendedStrategy) {
      case OptimizationStrategy.aggressive:
        return await _performAggressiveOptimization();
      case OptimizationStrategy.balanced:
        return await _performBalancedOptimization();
      case OptimizationStrategy.conservative:
        return await _performConservativeOptimization();
      case OptimizationStrategy.adaptive:
        // Fallback to balanced if adaptive is selected again
        return await _performBalancedOptimization();
    }
  }

  /// Remove expired cache entries
  Future<Map<String, int>> _removeExpiredEntries() async {
    // This would integrate with the cache manager's expiration logic
    // For now, return placeholder values
    return {'removed': 0, 'bytesFreed': 0};
  }

  /// Remove low-priority cache entries
  Future<Map<String, int>> _removeLowPriorityEntries({
    required int threshold,
  }) async {
    // This would integrate with the cache manager's priority system
    // For now, return placeholder values
    return {'removed': 0, 'bytesFreed': 0};
  }

  /// Perform LRU eviction
  Future<Map<String, int>> _performLRUEviction({
    required double evictionRatio,
  }) async {
    // This would integrate with the cache manager's LRU eviction
    // For now, return placeholder values
    return {'removed': 0, 'bytesFreed': 0};
  }

  /// Re-optimize images with new compression settings
  Future<Map<String, int>> _reoptimizeImages({
    required int qualityTarget,
    required double maxSizeReduction,
    Duration? ageThreshold,
  }) async {
    // This would re-optimize cached images with new settings
    // For now, return placeholder values
    return {'optimized': 0, 'bytesOptimized': 0};
  }

  /// Get cache usage ratio
  Future<double> _getCacheUsageRatio() async {
    final stats = _cacheManager!.getDetailedStatistics();
    final currentSize = stats['totalSize'] as int;
    final maxSize = stats['maxSize'] as int;
    return currentSize / maxSize;
  }

  /// Get adaptive optimization strategy based on current conditions
  Future<OptimizationStrategy> _getAdaptiveStrategy() async {
    final capabilities = await _assessDeviceCapabilities();
    return capabilities.recommendedStrategy;
  }

  /// Assess device capabilities for adaptive optimization
  Future<DeviceCapabilities> _assessDeviceCapabilities() async {
    // This would assess actual device capabilities
    // For now, return default values
    return const DeviceCapabilities(
      totalMemoryMB: 4096,
      availableMemoryMB: 2048,
      cpuUsage: 0.3,
      isLowEndDevice: false,
      hasSlowStorage: false,
      isOnBattery: false,
      hasLimitedData: false,
    );
  }

  /// Start scheduled optimization
  void _startScheduledOptimization() {
    _scheduledOptimizationTimer = Timer.periodic(
      _scheduledOptimizationInterval,
      (timer) async {
        if (!_isOptimizing) {
          await optimizeCache(
            strategy: _defaultStrategy,
            trigger: CleanupTrigger.scheduled,
          );
        }
      },
    );
  }

  /// Start cache monitoring
  void _startCacheMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 15), (
      timer,
    ) async {
      await _checkCacheThresholds();
    });
  }

  /// Check cache thresholds and trigger optimization if needed
  Future<void> _checkCacheThresholds() async {
    final usageRatio = await _getCacheUsageRatio();

    if (usageRatio > _aggressiveCleanupThreshold) {
      if (!_isOptimizing) {
        await optimizeCache(
          strategy: OptimizationStrategy.aggressive,
          trigger: CleanupTrigger.threshold,
        );
      }
    } else if (usageRatio > _balancedCleanupThreshold) {
      if (!_isOptimizing) {
        await optimizeCache(
          strategy: OptimizationStrategy.balanced,
          trigger: CleanupTrigger.threshold,
        );
      }
    }
  }

  /// Schedule optimization task
  void scheduleOptimization({
    required DateTime scheduledTime,
    OptimizationStrategy strategy = OptimizationStrategy.balanced,
    Map<String, dynamic> parameters = const {},
    int priority = 5,
  }) {
    final taskId = 'scheduled_${scheduledTime.millisecondsSinceEpoch}';

    final task = OptimizationTask(
      id: taskId,
      strategy: strategy,
      trigger: CleanupTrigger.scheduled,
      scheduledTime: scheduledTime,
      parameters: parameters,
      priority: priority,
    );

    _scheduledTasks[taskId] = task;

    // Schedule the task
    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) return; // Don't schedule past tasks

    Timer(delay, () async {
      _scheduledTasks.remove(taskId);

      if (!_isOptimizing) {
        await optimizeCache(
          strategy: strategy,
          trigger: CleanupTrigger.scheduled,
          parameters: parameters,
        );
      }
    });

    if (kDebugMode) {
      debugPrint(
        'ImageCacheOptimizer: Scheduled optimization task $taskId for $scheduledTime',
      );
    }
  }

  /// Cancel scheduled optimization task
  void cancelScheduledOptimization(String taskId) {
    _scheduledTasks.remove(taskId);

    if (kDebugMode) {
      debugPrint('ImageCacheOptimizer: Cancelled scheduled task $taskId');
    }
  }

  /// Get optimization statistics
  Map<String, dynamic> getStatistics() {
    final successRate = _totalOptimizations > 0
        ? (_successfulOptimizations / _totalOptimizations) * 100
        : 0.0;

    return {
      'totalOptimizations': _totalOptimizations,
      'successfulOptimizations': _successfulOptimizations,
      'successRate': successRate,
      'totalBytesFreed': _totalBytesFreed,
      'totalBytesOptimized': _totalBytesOptimized,
      'scheduledTasks': _scheduledTasks.length,
      'optimizationHistory': _optimizationHistory.length,
      'isOptimizing': _isOptimizing,
      'defaultStrategy': _defaultStrategy.name,
      'enableAdaptiveOptimization': _enableAdaptiveOptimization,
      'enableBackgroundOptimization': _enableBackgroundOptimization,
    };
  }

  /// Get optimization history
  List<CacheOptimizationResult> getOptimizationHistory({int limit = 20}) {
    return _optimizationHistory.reversed.take(limit).toList();
  }

  /// Update configuration
  void updateConfiguration({
    OptimizationStrategy? defaultStrategy,
    Duration? scheduledInterval,
    double? aggressiveThreshold,
    double? balancedThreshold,
    bool? enableAdaptiveOptimization,
    bool? enableBackgroundOptimization,
  }) {
    _defaultStrategy = defaultStrategy ?? _defaultStrategy;
    _scheduledOptimizationInterval =
        scheduledInterval ?? _scheduledOptimizationInterval;
    _aggressiveCleanupThreshold =
        aggressiveThreshold ?? _aggressiveCleanupThreshold;
    _balancedCleanupThreshold = balancedThreshold ?? _balancedCleanupThreshold;
    _enableAdaptiveOptimization =
        enableAdaptiveOptimization ?? _enableAdaptiveOptimization;
    _enableBackgroundOptimization =
        enableBackgroundOptimization ?? _enableBackgroundOptimization;

    // Restart timers if background optimization settings changed
    if (enableBackgroundOptimization != null) {
      if (enableBackgroundOptimization) {
        _startScheduledOptimization();
        _startCacheMonitoring();
      } else {
        _scheduledOptimizationTimer?.cancel();
        _monitoringTimer?.cancel();
      }
    }

    // Restart scheduled optimization timer if interval changed
    if (scheduledInterval != null && _enableBackgroundOptimization) {
      _scheduledOptimizationTimer?.cancel();
      _startScheduledOptimization();
    }

    if (kDebugMode) {
      debugPrint('ImageCacheOptimizer: Configuration updated');
    }
  }

  /// Dispose resources
  void dispose() {
    _scheduledOptimizationTimer?.cancel();
    _monitoringTimer?.cancel();
    _scheduledTasks.clear();
    _optimizationHistory.clear();
    _isInitialized = false;

    if (kDebugMode) {
      debugPrint('ImageCacheOptimizer: Disposed');
    }
  }
}
