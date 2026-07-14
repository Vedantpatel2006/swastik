import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

/// Service for handling permission checks and role validation
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if current user has admin privileges
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      if (userData == null) return false;

      final role = userData['role'] as String?;
      return role == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Validate temple operation permissions
  Future<bool> canManageTemples() async {
    return await isCurrentUserAdmin();
  }

  /// Validate specific temple edit permissions
  Future<bool> canEditTemple(String templeId) async {
    if (!await isCurrentUserAdmin()) return false;

    try {
      // Additional checks can be added here
      // For example, checking if temple exists and is editable
      final templeDoc = await _firestore
          .collection('temples')
          .doc(templeId)
          .get();
      return templeDoc.exists;
    } catch (e) {
      print('Error checking temple edit permissions: $e');
      return false;
    }
  }

  /// Validate temple deletion permissions
  Future<bool> canDeleteTemple(String templeId) async {
    if (!await isCurrentUserAdmin()) return false;

    try {
      // Check if temple exists and can be deleted
      final templeDoc = await _firestore
          .collection('temples')
          .doc(templeId)
          .get();
      if (!templeDoc.exists) return false;

      // Add any business logic for deletion restrictions
      // For example, don't allow deletion of temples with active bookings
      return true;
    } catch (e) {
      print('Error checking temple deletion permissions: $e');
      return false;
    }
  }

  /// Get user role for current user
  Future<UserRole> getCurrentUserRole() async {
    final isAdmin = await isCurrentUserAdmin();
    return isAdmin ? UserRole.admin : UserRole.user;
  }

  /// Throw permission denied exception
  void throwPermissionDenied(String operation) {
    throw Exception('Permission denied: $operation requires admin privileges');
  }
}
