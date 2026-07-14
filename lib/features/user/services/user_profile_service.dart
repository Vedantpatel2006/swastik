import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/services/storage/hybrid_storage_service.dart';

/// Service for managing user profile data and settings
class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HybridStorageService _storageService = HybridStorageService();

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _userPreferencesCollection =>
      _firestore.collection('user_preferences');

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;

      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting user profile: $e');
      }
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? phoneNumber,
    String? address,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        throw Exception('Unauthorized to update this profile');
      }

      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (displayName != null) {
        updateData['displayName'] = displayName;
        // Also update Firebase Auth profile
        await user.updateDisplayName(displayName);
      }

      if (bio != null) updateData['bio'] = bio;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (address != null) updateData['address'] = address;
      if (additionalInfo != null) {
        updateData['additionalInfo'] = additionalInfo;
      }

      await _usersCollection.doc(userId).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user profile: $e');
      }
      rethrow;
    }
  }

  /// Upload profile photo
  Future<String> uploadProfilePhoto({
    required String userId,
    required File photoFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        throw Exception('Unauthorized to update this profile');
      }

      // Upload to storage
      final photoUrl = await _storageService.uploadUserImage(
        imageFile: photoFile,
        userId: userId,
      );

      // Update Firestore
      await _usersCollection.doc(userId).update({
        'photoURL': photoUrl,
        'updatedAt': Timestamp.now(),
      });

      // Update Firebase Auth profile
      await user.updatePhotoURL(photoUrl);

      return photoUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading profile photo: $e');
      }
      rethrow;
    }
  }

  /// Delete profile photo
  Future<void> deleteProfilePhoto(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        throw Exception('Unauthorized to update this profile');
      }

      // Get current photo URL
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final photoUrl = data['photoURL'] as String?;

        if (photoUrl != null) {
          // Delete from storage
          await _storageService.deleteTempleImage(photoUrl);
        }
      }

      // Update Firestore
      await _usersCollection.doc(userId).update({
        'photoURL': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      });

      // Update Firebase Auth profile
      await user.updatePhotoURL(null);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting profile photo: $e');
      }
      rethrow;
    }
  }

  /// Update user preferences
  Future<void> updateUserPreferences({
    required String userId,
    String? language,
    String? theme,
    bool? notificationsEnabled,
    bool? locationEnabled,
    Map<String, dynamic>? customPreferences,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (language != null) updateData['language'] = language;
      if (theme != null) updateData['theme'] = theme;
      if (notificationsEnabled != null) {
        updateData['notificationsEnabled'] = notificationsEnabled;
      }
      if (locationEnabled != null) {
        updateData['locationEnabled'] = locationEnabled;
      }
      if (customPreferences != null) {
        updateData['customPreferences'] = customPreferences;
      }

      await _userPreferencesCollection.doc(userId).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user preferences: $e');
      }
      rethrow;
    }
  }

  /// Get user preferences
  Future<Map<String, dynamic>> getUserPreferences(String userId) async {
    try {
      final doc = await _userPreferencesCollection.doc(userId).get();

      if (!doc.exists) {
        // Return default preferences
        return {
          'language': 'en',
          'theme': 'light',
          'notificationsEnabled': true,
          'locationEnabled': true,
          'customPreferences': {},
        };
      }

      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting user preferences: $e');
      }
      rethrow;
    }
  }

  /// Watch user profile stream
  Stream<Map<String, dynamic>?> watchUserProfile(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    });
  }

  /// Delete user account
  Future<void> deleteUserAccount(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        throw Exception('Unauthorized to delete this account');
      }

      // Delete user data from Firestore
      final batch = _firestore.batch();

      // Delete user profile
      batch.delete(_usersCollection.doc(userId));

      // Delete user preferences
      batch.delete(_userPreferencesCollection.doc(userId));

      // Delete user stats
      batch.delete(_firestore.collection('user_stats').doc(userId));

      await batch.commit();

      // Delete Firebase Auth account
      await user.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting user account: $e');
      }
      rethrow;
    }
  }

  /// Export user data
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        throw Exception('Unauthorized to export this data');
      }

      final profile = await getUserProfile(userId);
      final preferences = await getUserPreferences(userId);

      // Get user stats
      final statsDoc = await _firestore.collection('user_stats').doc(userId).get();
      final stats = statsDoc.exists ? statsDoc.data() : {};

      return {
        'profile': profile,
        'preferences': preferences,
        'stats': stats,
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error exporting user data: $e');
      }
      rethrow;
    }
  }

  /// Validate profile data
  bool validateProfileData({
    String? displayName,
    String? bio,
    String? phoneNumber,
  }) {
    if (displayName != null && displayName.trim().isEmpty) {
      return false;
    }

    if (displayName != null && displayName.length > 50) {
      return false;
    }

    if (bio != null && bio.length > 500) {
      return false;
    }

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      // Basic phone number validation
      final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
      if (!phoneRegex.hasMatch(phoneNumber.replaceAll(RegExp(r'[\s-]'), ''))) {
        return false;
      }
    }

    return true;
  }
}
