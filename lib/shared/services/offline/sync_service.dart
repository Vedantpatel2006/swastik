import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offline_manager.dart';
import 'conflict_resolver.dart' as resolver;
import '../cache/data_cache_manager.dart';
import '../supabase_notification_service.dart';
import '../service_container.dart';
import '../../models/notification.dart';

/// Sync operation result
class SyncResult {
  final bool success;
  final int syncedCount;
  final int conflictCount;
  final int errorCount;
  final List<String> errors;
  final List<resolver.DataConflict> conflicts;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.conflictCount,
    required this.errorCount,
    required this.errors,
    required this.conflicts,
  });

  bool get hasErrors => errorCount > 0;
  bool get hasConflicts => conflictCount > 0;
  int get totalOperations => syncedCount + conflictCount + errorCount;
}

/// Sync progress information
class SyncProgress {
  final int totalOperations;
  final int completedOperations;
  final String currentOperation;
  final double progress;

  SyncProgress({
    required this.totalOperations,
    required this.completedOperations,
    required this.currentOperation,
  }) : progress = totalOperations > 0
           ? completedOperations / totalOperations
           : 0.0;
}

/// Service for coordinating offline data synchronization
class SyncService {
  static SyncService? _instance;
  factory SyncService() => _instance ??= SyncService._internal();
  SyncService._internal();

  final OfflineManager _offlineManager = OfflineManager();
  final resolver.ConflictResolver _conflictResolver =
      resolver.ConflictResolver();
  final DataCacheManager _cacheManager = DataCacheManager();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use centralized service container for NotificationService
  SupabaseNotificationService get _notificationService =>
      services.notificationService;

  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();
  final StreamController<SyncResult> _resultController =
      StreamController<SyncResult>.broadcast();

  bool _isSyncing = false;

  /// Stream of sync progress updates
  Stream<SyncProgress> get progressStream => _progressController.stream;

  /// Stream of sync results
  Stream<SyncResult> get resultStream => _resultController.stream;

  /// Current sync status
  bool get isSyncing => _isSyncing;

  /// Initialize the sync service
  Future<void> initialize() async {
    await _offlineManager.initialize();
    await _cacheManager.initialize();
  }

  /// Sync all pending offline data
  Future<SyncResult> syncAll({
    resolver.ConflictResolutionStrategy defaultStrategy =
        resolver.ConflictResolutionStrategy.merge,
    String? userId,
  }) async {
    if (_isSyncing) {
      throw StateError('Sync already in progress');
    }

    if (!_offlineManager.isOnline) {
      throw StateError('Cannot sync while offline');
    }

    _isSyncing = true;

    // Send sync started notification
    if (userId != null) {
      await _sendSyncStartedNotification(userId);
    }

    try {
      final pendingEntries = <OfflineDataEntry>[];

      // Collect all pending entries
      for (final collection in ['temples', 'users']) {
        final entries = await _offlineManager.getOfflineDataByCollection(
          collection,
        );
        pendingEntries.addAll(entries.where((e) => e.needsSync));
      }

      if (pendingEntries.isEmpty) {
        final result = SyncResult(
          success: true,
          syncedCount: 0,
          conflictCount: 0,
          errorCount: 0,
          errors: [],
          conflicts: [],
        );

        // Send sync completed notification
        if (userId != null) {
          await _sendSyncCompletedNotification(userId, result);
        }

        return result;
      }

      final totalOperations = pendingEntries.length;
      int completedOperations = 0;
      int syncedCount = 0;
      int conflictCount = 0;
      int errorCount = 0;
      final errors = <String>[];
      final conflicts = <resolver.DataConflict>[];

      // Process each entry
      for (final entry in pendingEntries) {
        _progressController.add(
          SyncProgress(
            totalOperations: totalOperations,
            completedOperations: completedOperations,
            currentOperation: 'Syncing ${entry.collection}:${entry.id}',
          ),
        );

        try {
          final result = await _syncEntry(entry, defaultStrategy);

          if (result.hasConflicts) {
            conflictCount++;
            conflicts.addAll(result.conflicts);
          } else if (result.hasErrors) {
            errorCount++;
            errors.addAll(result.errors);
          } else {
            syncedCount++;
          }
        } catch (e) {
          errorCount++;
          errors.add('${entry.collection}:${entry.id} - $e');

          if (kDebugMode) {
            debugPrint('SyncService: Error syncing ${entry.id} - $e');
          }
        }

        completedOperations++;
      }

      final result = SyncResult(
        success: errorCount == 0 && conflictCount == 0,
        syncedCount: syncedCount,
        conflictCount: conflictCount,
        errorCount: errorCount,
        errors: errors,
        conflicts: conflicts,
      );

      _resultController.add(result);

      // Send sync completed notification
      if (userId != null) {
        if (result.success) {
          await _sendSyncCompletedNotification(userId, result);
        } else {
          await _sendSyncErrorNotification(userId, result);
        }
      }

      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a specific collection
  Future<SyncResult> syncCollection(
    String collection, {
    resolver.ConflictResolutionStrategy defaultStrategy =
        resolver.ConflictResolutionStrategy.merge,
  }) async {
    if (_isSyncing) {
      throw StateError('Sync already in progress');
    }

    if (!_offlineManager.isOnline) {
      throw StateError('Cannot sync while offline');
    }

    _isSyncing = true;

    try {
      final entries = await _offlineManager.getOfflineDataByCollection(
        collection,
      );
      final pendingEntries = entries.where((e) => e.needsSync).toList();

      if (pendingEntries.isEmpty) {
        return SyncResult(
          success: true,
          syncedCount: 0,
          conflictCount: 0,
          errorCount: 0,
          errors: [],
          conflicts: [],
        );
      }

      final totalOperations = pendingEntries.length;
      int completedOperations = 0;
      int syncedCount = 0;
      int conflictCount = 0;
      int errorCount = 0;
      final errors = <String>[];
      final conflicts = <resolver.DataConflict>[];

      for (final entry in pendingEntries) {
        _progressController.add(
          SyncProgress(
            totalOperations: totalOperations,
            completedOperations: completedOperations,
            currentOperation: 'Syncing ${entry.id}',
          ),
        );

        try {
          final result = await _syncEntry(entry, defaultStrategy);

          if (result.hasConflicts) {
            conflictCount++;
            conflicts.addAll(result.conflicts);
          } else if (result.hasErrors) {
            errorCount++;
            errors.addAll(result.errors);
          } else {
            syncedCount++;
          }
        } catch (e) {
          errorCount++;
          errors.add('${entry.id} - $e');
        }

        completedOperations++;
      }

      final result = SyncResult(
        success: errorCount == 0 && conflictCount == 0,
        syncedCount: syncedCount,
        conflictCount: conflictCount,
        errorCount: errorCount,
        errors: errors,
        conflicts: conflicts,
      );

      _resultController.add(result);
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single entry
  Future<SyncResult> _syncEntry(
    OfflineDataEntry entry,
    resolver.ConflictResolutionStrategy defaultStrategy,
  ) async {
    try {
      final docRef = _firestore.collection(entry.collection).doc(entry.id);

      switch (entry.operation) {
        case OfflineOperationType.create:
          return await _syncCreate(entry, docRef);

        case OfflineOperationType.update:
          return await _syncUpdate(entry, docRef, defaultStrategy);

        case OfflineOperationType.delete:
          return await _syncDelete(entry, docRef);
      }
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        errorCount: 1,
        errors: [e.toString()],
        conflicts: [],
      );
    }
  }

  /// Sync create operation
  Future<SyncResult> _syncCreate(
    OfflineDataEntry entry,
    DocumentReference docRef,
  ) async {
    try {
      // Check if document already exists
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        // Document was created elsewhere, treat as update
        return await _syncUpdate(
          entry,
          docRef,
          resolver.ConflictResolutionStrategy.merge,
        );
      }

      await docRef.set({
        ...entry.data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
      });

      // Update cache with server data
      final updatedDoc = await docRef.get();
      if (updatedDoc.exists) {
        await _cacheManager.cacheData(
          '${entry.collection}:${entry.id}',
          updatedDoc.data()! as Map<String, dynamic>,
        );
      }

      // Remove from offline storage
      await _offlineManager.deleteOfflineData(
        id: entry.id,
        collection: entry.collection,
      );

      return SyncResult(
        success: true,
        syncedCount: 1,
        conflictCount: 0,
        errorCount: 0,
        errors: [],
        conflicts: [],
      );
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        errorCount: 1,
        errors: [e.toString()],
        conflicts: [],
      );
    }
  }

  /// Sync update operation
  Future<SyncResult> _syncUpdate(
    OfflineDataEntry entry,
    DocumentReference docRef,
    resolver.ConflictResolutionStrategy defaultStrategy,
  ) async {
    try {
      final serverDoc = await docRef.get();

      if (!serverDoc.exists) {
        // Document was deleted on server, treat as create
        return await _syncCreate(entry, docRef);
      }

      final serverData = serverDoc.data()! as Map<String, dynamic>;

      // Check for conflicts
      final conflict = _conflictResolver.analyzeConflict(
        id: entry.id,
        collection: entry.collection,
        serverData: serverData,
        clientData: entry.data,
      );

      if (!conflict.hasConflicts) {
        // No conflicts, proceed with update
        await docRef.update({
          ...entry.data,
          'updatedAt': FieldValue.serverTimestamp(),
          'version': FieldValue.increment(1),
        });

        // Update cache
        final updatedDoc = await docRef.get();
        if (updatedDoc.exists) {
          await _cacheManager.cacheData(
            '${entry.collection}:${entry.id}',
            updatedDoc.data()! as Map<String, dynamic>,
          );
        }

        // Remove from offline storage
        await _offlineManager.deleteOfflineData(
          id: entry.id,
          collection: entry.collection,
        );

        return SyncResult(
          success: true,
          syncedCount: 1,
          conflictCount: 0,
          errorCount: 0,
          errors: [],
          conflicts: [],
        );
      }

      // Handle conflict
      final strategy = entry.conflictResolution != null
          ? resolver.ConflictResolutionStrategy.values.firstWhere(
              (e) => e.toString() == entry.conflictResolution,
            )
          : defaultStrategy;

      if (strategy == resolver.ConflictResolutionStrategy.manual ||
          _conflictResolver.requiresManualResolution(conflict)) {
        // Store conflict for manual resolution
        return SyncResult(
          success: false,
          syncedCount: 0,
          conflictCount: 1,
          errorCount: 0,
          errors: [],
          conflicts: [conflict],
        );
      }

      // Auto-resolve conflict
      final resolution = _conflictResolver.resolveConflict(
        conflict: conflict,
        strategy: strategy,
      );

      await docRef.update({
        ...resolution.resolvedData,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });

      // Update cache
      final updatedDoc = await docRef.get();
      if (updatedDoc.exists) {
        await _cacheManager.cacheData(
          '${entry.collection}:${entry.id}',
          updatedDoc.data()! as Map<String, dynamic>,
        );
      }

      // Remove from offline storage
      await _offlineManager.deleteOfflineData(
        id: entry.id,
        collection: entry.collection,
      );

      if (kDebugMode) {
        debugPrint(
          'SyncService: Auto-resolved conflict for ${entry.id} using ${strategy.name}',
        );
      }

      return SyncResult(
        success: true,
        syncedCount: 1,
        conflictCount: 0,
        errorCount: 0,
        errors: [],
        conflicts: [],
      );
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        errorCount: 1,
        errors: [e.toString()],
        conflicts: [],
      );
    }
  }

  /// Sync delete operation
  Future<SyncResult> _syncDelete(
    OfflineDataEntry entry,
    DocumentReference docRef,
  ) async {
    try {
      await docRef.delete();

      // Remove from cache
      await _cacheManager.remove('${entry.collection}:${entry.id}');

      // Remove from offline storage
      await _offlineManager.deleteOfflineData(
        id: entry.id,
        collection: entry.collection,
      );

      return SyncResult(
        success: true,
        syncedCount: 1,
        conflictCount: 0,
        errorCount: 0,
        errors: [],
        conflicts: [],
      );
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        errorCount: 1,
        errors: [e.toString()],
        conflicts: [],
      );
    }
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStatistics() async {
    final pendingCount = _offlineManager.pendingSyncCount;
    final lastSyncTime = await _offlineManager.getLastSyncTime();
    final conflicts = await _offlineManager.getPendingConflicts();

    return {
      'pendingSyncCount': pendingCount,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'pendingConflicts': conflicts.length,
      'isOnline': _offlineManager.isOnline,
      'isSyncing': _isSyncing,
    };
  }

  /// Cancel current sync operation
  void cancelSync() {
    if (_isSyncing) {
      _isSyncing = false;

      _resultController.add(
        SyncResult(
          success: false,
          syncedCount: 0,
          conflictCount: 0,
          errorCount: 1,
          errors: ['Sync cancelled by user'],
          conflicts: [],
        ),
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
    _resultController.close();
    _offlineManager.dispose();
  }

  /// Send sync started notification
  Future<void> _sendSyncStartedNotification(String userId) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        title: 'Sync Started',
        message: 'Synchronizing your offline data with the server...',
        type: NotificationType.systemUpdate,
        priority: NotificationPriority.low,
        category: 'sync',
        actionData: {
          'syncType': 'started',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (kDebugMode) {
        debugPrint(
          'SyncService: Sent sync started notification for user $userId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SyncService: Failed to send sync started notification: $e');
      }
    }
  }

  /// Send sync completed notification
  Future<void> _sendSyncCompletedNotification(
    String userId,
    SyncResult result,
  ) async {
    try {
      final message = result.syncedCount > 0
          ? 'Successfully synchronized ${result.syncedCount} items'
          : 'All data is up to date';

      await _notificationService.createNotification(
        userId: userId,
        title: 'Sync Completed ✅',
        message: message,
        type: NotificationType.systemUpdate,
        priority: NotificationPriority.normal,
        category: 'sync',
        actionData: {
          'syncType': 'completed',
          'syncedCount': result.syncedCount,
          'totalOperations': result.totalOperations,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (kDebugMode) {
        debugPrint(
          'SyncService: Sent sync completed notification for user $userId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SyncService: Failed to send sync completed notification: $e',
        );
      }
    }
  }

  /// Send sync error notification
  Future<void> _sendSyncErrorNotification(
    String userId,
    SyncResult result,
  ) async {
    try {
      final message = result.hasConflicts
          ? 'Sync completed with ${result.conflictCount} conflicts that need resolution'
          : 'Sync failed with ${result.errorCount} errors';

      await _notificationService.createNotification(
        userId: userId,
        title: 'Sync Issues ⚠️',
        message: message,
        type: NotificationType.systemUpdate,
        priority: NotificationPriority.high,
        category: 'sync',
        actionData: {
          'syncType': 'error',
          'errorCount': result.errorCount,
          'conflictCount': result.conflictCount,
          'errors': result.errors,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (kDebugMode) {
        debugPrint(
          'SyncService: Sent sync error notification for user $userId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SyncService: Failed to send sync error notification: $e');
      }
    }
  }
}
