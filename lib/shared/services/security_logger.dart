import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Security logging service for audit trails and monitoring
class SecurityLogger {
  static final SecurityLogger _instance = SecurityLogger._internal();
  factory SecurityLogger() => _instance;
  SecurityLogger._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _securityLogsCollection = 'security_logs';

  /// Log security event
  static Future<void> log(Map<String, dynamic> logEntry) async {
    try {
      final instance = SecurityLogger();
      final currentUser = instance._auth.currentUser;
      
      final enhancedLogEntry = {
        ...logEntry,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser?.uid,
        'userEmail': currentUser?.email,
        'sessionId': _generateSessionId(),
        'severity': logEntry['severity'] ?? 'info',
        'source': 'mobile_app',
        'platform': defaultTargetPlatform.name,
      };

      await instance._firestore
          .collection(_securityLogsCollection)
          .add(enhancedLogEntry);

      if (kDebugMode) {
        debugPrint('SecurityLogger: Logged event - ${logEntry['event']}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityLogger: Failed to log security event - $e');
      }
      // Don't throw error to avoid breaking app functionality
    }
  }

  /// Log access event (for map permissions, etc.)
  static Future<void> logAccess({
    required String resource,
    required String action,
    required bool granted,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    await log({
      'event': 'access_request',
      'resource': resource,
      'action': action,
      'granted': granted,
      'reason': reason,
      'metadata': metadata,
      'severity': granted ? 'info' : 'warning',
    });
  }

  /// Log authentication event
  static Future<void> logAuth({
    required String event,
    required bool success,
    String? method,
    String? error,
  }) async {
    await log({
      'event': 'authentication',
      'auth_event': event,
      'success': success,
      'method': method,
      'error': error,
      'severity': success ? 'info' : 'error',
    });
  }

  /// Log payment security event
  static Future<void> logPayment({
    required String event,
    required String transactionId,
    required double amount,
    required String currency,
    bool? success,
    String? error,
  }) async {
    await log({
      'event': 'payment_security',
      'payment_event': event,
      'transaction_id': transactionId,
      'amount': amount,
      'currency': currency,
      'success': success,
      'error': error,
      'severity': (success == false) ? 'error' : 'info',
    });
  }

  /// Log data access event
  static Future<void> logDataAccess({
    required String collection,
    required String action,
    required String documentId,
    bool? success,
    String? error,
  }) async {
    await log({
      'event': 'data_access',
      'collection': collection,
      'action': action,
      'document_id': documentId,
      'success': success,
      'error': error,
      'severity': (success == false) ? 'error' : 'info',
    });
  }

  /// Generate session ID for tracking
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'session_${timestamp}_$random';
  }

  /// Get security logs for admin review
  static Future<List<Map<String, dynamic>>> getSecurityLogs({
    int limit = 100,
    String? severity,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final instance = SecurityLogger();
      var query = instance._firestore
          .collection(_securityLogsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (severity != null) {
        query = query.where('severity', isEqualTo: severity);
      }

      if (startDate != null) {
        query = query.where('timestamp', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', 
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityLogger: Failed to get security logs - $e');
      }
      return [];
    }
  }

  /// Clear old logs (for maintenance)
  static Future<void> clearOldLogs({int daysToKeep = 90}) async {
    try {
      final instance = SecurityLogger();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final oldLogs = await instance._firestore
          .collection(_securityLogsCollection)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = instance._firestore.batch();
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();

      if (kDebugMode) {
        debugPrint('SecurityLogger: Cleared ${oldLogs.docs.length} old logs');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityLogger: Failed to clear old logs - $e');
      }
    }
  }
}