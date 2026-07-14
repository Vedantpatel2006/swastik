import 'package:flutter/foundation.dart';

/// Conflict resolution result
class ConflictResolutionResult {
  final Map<String, dynamic> resolvedData;
  final ConflictResolutionStrategy strategy;
  final String? reason;

  ConflictResolutionResult({
    required this.resolvedData,
    required this.strategy,
    this.reason,
  });
}

/// Conflict resolution strategies
enum ConflictResolutionStrategy { clientWins, serverWins, merge, manual }

/// Field-level conflict information
class FieldConflict {
  final String fieldName;
  final dynamic serverValue;
  final dynamic clientValue;
  final DateTime serverTimestamp;
  final DateTime clientTimestamp;

  FieldConflict({
    required this.fieldName,
    required this.serverValue,
    required this.clientValue,
    required this.serverTimestamp,
    required this.clientTimestamp,
  });

  /// Check if values are different
  bool get hasConflict => serverValue != clientValue;

  /// Get the more recent value based on timestamps
  dynamic get newerValue {
    return serverTimestamp.isAfter(clientTimestamp) ? serverValue : clientValue;
  }
}

/// Data conflict between server and client
class DataConflict {
  final String id;
  final String collection;
  final Map<String, dynamic> serverData;
  final Map<String, dynamic> clientData;
  final DateTime serverTimestamp;
  final DateTime clientTimestamp;
  final List<FieldConflict> fieldConflicts;

  DataConflict({
    required this.id,
    required this.collection,
    required this.serverData,
    required this.clientData,
    required this.serverTimestamp,
    required this.clientTimestamp,
    required this.fieldConflicts,
  });

  /// Check if there are any actual conflicts
  bool get hasConflicts => fieldConflicts.any((c) => c.hasConflict);

  /// Get conflicted field names
  List<String> get conflictedFields => fieldConflicts
      .where((c) => c.hasConflict)
      .map((c) => c.fieldName)
      .toList();
}

/// Conflict resolver for handling data synchronization conflicts
class ConflictResolver {
  static ConflictResolver? _instance;
  factory ConflictResolver() => _instance ??= ConflictResolver._internal();
  ConflictResolver._internal();

  /// System fields that should not be merged
  static const Set<String> systemFields = {
    'createdAt',
    'updatedAt',
    'version',
    'id',
    'documentId',
  };

  /// Fields that should prefer server values
  static const Set<String> serverPreferredFields = {
    'createdAt',
    'updatedAt',
    'version',
  };

  /// Fields that should prefer client values
  static const Set<String> clientPreferredFields = {
    'name',
    'title',
    'description',
    'aboutTemple',
  };

  /// Analyze conflicts between server and client data
  DataConflict analyzeConflict({
    required String id,
    required String collection,
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> clientData,
  }) {
    final serverTimestamp =
        _extractTimestamp(serverData, 'updatedAt') ??
        _extractTimestamp(serverData, 'createdAt') ??
        DateTime.now();

    final clientTimestamp =
        _extractTimestamp(clientData, 'updatedAt') ??
        _extractTimestamp(clientData, 'createdAt') ??
        DateTime.now();

    final fieldConflicts = <FieldConflict>[];
    final allFields = <String>{...serverData.keys, ...clientData.keys};

    for (final field in allFields) {
      if (systemFields.contains(field)) continue;

      final serverValue = serverData[field];
      final clientValue = clientData[field];

      fieldConflicts.add(
        FieldConflict(
          fieldName: field,
          serverValue: serverValue,
          clientValue: clientValue,
          serverTimestamp: serverTimestamp,
          clientTimestamp: clientTimestamp,
        ),
      );
    }

    return DataConflict(
      id: id,
      collection: collection,
      serverData: serverData,
      clientData: clientData,
      serverTimestamp: serverTimestamp,
      clientTimestamp: clientTimestamp,
      fieldConflicts: fieldConflicts,
    );
  }

  /// Resolve conflict using specified strategy
  ConflictResolutionResult resolveConflict({
    required DataConflict conflict,
    required ConflictResolutionStrategy strategy,
    Map<String, dynamic>? manualResolution,
  }) {
    switch (strategy) {
      case ConflictResolutionStrategy.clientWins:
        return _resolveClientWins(conflict);

      case ConflictResolutionStrategy.serverWins:
        return _resolveServerWins(conflict);

      case ConflictResolutionStrategy.merge:
        return _resolveMerge(conflict);

      case ConflictResolutionStrategy.manual:
        if (manualResolution == null) {
          throw ArgumentError(
            'Manual resolution data required for manual strategy',
          );
        }
        return _resolveManual(conflict, manualResolution);
    }
  }

  /// Resolve using client wins strategy
  ConflictResolutionResult _resolveClientWins(DataConflict conflict) {
    final resolvedData = Map<String, dynamic>.from(conflict.clientData);

    // Keep server system fields
    for (final field in serverPreferredFields) {
      if (conflict.serverData.containsKey(field)) {
        resolvedData[field] = conflict.serverData[field];
      }
    }

    return ConflictResolutionResult(
      resolvedData: resolvedData,
      strategy: ConflictResolutionStrategy.clientWins,
      reason: 'Client data takes precedence',
    );
  }

  /// Resolve using server wins strategy
  ConflictResolutionResult _resolveServerWins(DataConflict conflict) {
    final resolvedData = Map<String, dynamic>.from(conflict.serverData);

    return ConflictResolutionResult(
      resolvedData: resolvedData,
      strategy: ConflictResolutionStrategy.serverWins,
      reason: 'Server data takes precedence',
    );
  }

  /// Resolve using intelligent merge strategy
  ConflictResolutionResult _resolveMerge(DataConflict conflict) {
    final resolvedData = Map<String, dynamic>.from(conflict.serverData);
    final mergeReasons = <String>[];

    for (final fieldConflict in conflict.fieldConflicts) {
      if (!fieldConflict.hasConflict) continue;

      final fieldName = fieldConflict.fieldName;
      dynamic resolvedValue;
      String reason;

      if (serverPreferredFields.contains(fieldName)) {
        resolvedValue = fieldConflict.serverValue;
        reason = 'Server preferred field';
      } else if (clientPreferredFields.contains(fieldName)) {
        resolvedValue = fieldConflict.clientValue;
        reason = 'Client preferred field';
      } else {
        // Use timestamp-based resolution
        resolvedValue = fieldConflict.newerValue;
        reason = 'Newer timestamp wins';
      }

      resolvedData[fieldName] = resolvedValue;
      mergeReasons.add('$fieldName: $reason');
    }

    return ConflictResolutionResult(
      resolvedData: resolvedData,
      strategy: ConflictResolutionStrategy.merge,
      reason: 'Intelligent merge: ${mergeReasons.join(', ')}',
    );
  }

  /// Resolve using manual resolution
  ConflictResolutionResult _resolveManual(
    DataConflict conflict,
    Map<String, dynamic> manualResolution,
  ) {
    final resolvedData = Map<String, dynamic>.from(conflict.serverData);

    // Apply manual resolution
    for (final entry in manualResolution.entries) {
      if (!systemFields.contains(entry.key)) {
        resolvedData[entry.key] = entry.value;
      }
    }

    return ConflictResolutionResult(
      resolvedData: resolvedData,
      strategy: ConflictResolutionStrategy.manual,
      reason: 'Manual resolution applied',
    );
  }

  /// Extract timestamp from data
  DateTime? _extractTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) return null;

    try {
      if (value is DateTime) {
        return value;
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ConflictResolver: Error parsing timestamp - $e');
      }
    }

    return null;
  }

  /// Get recommended strategy for a conflict
  ConflictResolutionStrategy getRecommendedStrategy(DataConflict conflict) {
    // If no actual conflicts, use server wins
    if (!conflict.hasConflicts) {
      return ConflictResolutionStrategy.serverWins;
    }

    // If only system fields conflict, use server wins
    final nonSystemConflicts = conflict.fieldConflicts.where(
      (c) => c.hasConflict && !systemFields.contains(c.fieldName),
    );

    if (nonSystemConflicts.isEmpty) {
      return ConflictResolutionStrategy.serverWins;
    }

    // If client data is newer, prefer client
    if (conflict.clientTimestamp.isAfter(conflict.serverTimestamp)) {
      return ConflictResolutionStrategy.clientWins;
    }

    // Default to intelligent merge
    return ConflictResolutionStrategy.merge;
  }

  /// Check if conflict requires manual resolution
  bool requiresManualResolution(DataConflict conflict) {
    // Check for critical field conflicts
    final criticalFields = {'name', 'title', 'location'};

    return conflict.fieldConflicts.any(
      (c) => c.hasConflict && criticalFields.contains(c.fieldName),
    );
  }

  /// Generate conflict summary for UI display
  Map<String, dynamic> generateConflictSummary(DataConflict conflict) {
    return {
      'id': conflict.id,
      'collection': conflict.collection,
      'hasConflicts': conflict.hasConflicts,
      'conflictedFields': conflict.conflictedFields,
      'serverTimestamp': conflict.serverTimestamp.toIso8601String(),
      'clientTimestamp': conflict.clientTimestamp.toIso8601String(),
      'recommendedStrategy': getRecommendedStrategy(conflict).name,
      'requiresManualResolution': requiresManualResolution(conflict),
      'fieldDetails': conflict.fieldConflicts
          .where((c) => c.hasConflict)
          .map(
            (c) => {
              'field': c.fieldName,
              'serverValue': c.serverValue,
              'clientValue': c.clientValue,
              'newerValue': c.newerValue,
            },
          )
          .toList(),
    };
  }
}
