import 'dart:io';
import 'package:flutter/foundation.dart';
import 'supabase_storage_service.dart';
import 'firebase_storage_service.dart';
import '../../../core/config/supabase_config.dart';

/// Hybrid storage service that uses Supabase for images (if configured)
/// Falls back to Firebase Storage if Supabase is not configured
class HybridStorageService {
  static final HybridStorageService _instance = HybridStorageService._internal();
  factory HybridStorageService() => _instance;
  HybridStorageService._internal();

  final _supabaseStorage = SupabaseStorageService();
  final _firebaseStorage = FirebaseStorageService();
  
  bool _useSupabase = false;
  bool _initialized = false;

  /// Initialize storage service
  /// Checks if Supabase is configured and available
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Check if Supabase is configured
      if (SupabaseConfig.isConfigured()) {
        await _supabaseStorage.initialize();
        _useSupabase = true;
        debugPrint('✓ Using Supabase Storage for images');
      } else {
        debugPrint('⚠ Supabase not configured, using Firebase Storage');
        _useSupabase = false;
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing Supabase Storage, falling back to Firebase: $e');
      _useSupabase = false;
      _initialized = true;
    }
  }

  /// Upload temple image
  Future<String> uploadTempleImage({
    required File imageFile,
    required String templeId,
  }) async {
    await initialize();
    
    if (_useSupabase) {
      return await _supabaseStorage.uploadTempleImage(
        imageFile: imageFile,
        templeId: templeId,
      );
    } else {
      return await _firebaseStorage.uploadTempleImage(
        imageFile: imageFile,
        templeId: templeId,
      );
    }
  }

  /// Upload multiple temple images
  Future<List<String>> uploadTempleImages({
    required List<File> imageFiles,
    required String templeId,
  }) async {
    await initialize();
    
    if (_useSupabase) {
      return await _supabaseStorage.uploadTempleImages(
        imageFiles: imageFiles,
        templeId: templeId,
      );
    } else {
      return await _firebaseStorage.uploadTempleImages(
        imageFiles: imageFiles,
        templeId: templeId,
      );
    }
  }

  /// Delete temple image
  Future<void> deleteTempleImage(String imageUrl) async {
    await initialize();
    
    // Detect which storage service based on URL
    if (imageUrl.contains('supabase.co')) {
      await _supabaseStorage.deleteTempleImage(imageUrl);
    } else if (imageUrl.contains('firebase')) {
      await _firebaseStorage.deleteTempleImage(imageUrl);
    } else {
      debugPrint('Unknown storage URL format: $imageUrl');
    }
  }

  /// Delete multiple temple images
  Future<void> deleteTempleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        await deleteTempleImage(url);
      } catch (e) {
        debugPrint('Failed to delete image: $url - $e');
      }
    }
  }

  /// Upload user profile/community image
  Future<String> uploadUserImage({
    required File imageFile,
    required String userId,
  }) async {
    await initialize();
    
    if (_useSupabase) {
      return await _supabaseStorage.uploadUserImage(
        imageFile: imageFile,
        userId: userId,
      );
    } else {
      // Firebase doesn't have a specific user image method, use generic upload
      return await _firebaseStorage.uploadImage(
        file: imageFile,
        folder: 'user_images/$userId',
      );
    }
  }

  /// Get storage provider being used
  String getStorageProvider() {
    return _useSupabase ? 'Supabase' : 'Firebase';
  }

  /// Check if using Supabase
  bool isUsingSupabase() => _useSupabase;
}
