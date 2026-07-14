import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Service for handling image uploads to Supabase Storage
/// Used as alternative to Firebase Storage for temple images
class SupabaseStorageService {
  static final SupabaseStorageService _instance = SupabaseStorageService._internal();
  factory SupabaseStorageService() => _instance;
  SupabaseStorageService._internal();

  final _uuid = const Uuid();
  
  // Bucket names
  static const String templeImagesBucket = 'temple-images';
  static const String userImagesBucket = 'user-images';
  
  /// Initialize Supabase Storage buckets
  /// Call this once during app initialization
  Future<void> initialize() async {
    try {
      final storage = Supabase.instance.client.storage;
      
      // Check if buckets exist, create if they don't
      try {
        final buckets = await storage.listBuckets();
        
        if (!buckets.any((b) => b.name == templeImagesBucket)) {
          await storage.createBucket(
            templeImagesBucket,
            const BucketOptions(
              public: true,
              fileSizeLimit: '5MB', // 5MB limit
            ),
          );
          debugPrint('Created Supabase bucket: $templeImagesBucket');
        }
        
        if (!buckets.any((b) => b.name == userImagesBucket)) {
          await storage.createBucket(
            userImagesBucket,
            const BucketOptions(
              public: true,
              fileSizeLimit: '2MB', // 2MB limit
            ),
          );
          debugPrint('Created Supabase bucket: $userImagesBucket');
        }
      } catch (bucketError) {
        // Buckets might already exist or RLS policy prevents creation
        // This is okay - buckets can be created manually in Supabase Dashboard
        debugPrint('Note: Could not auto-create buckets (may already exist): $bucketError');
        debugPrint('If buckets don\'t exist, create them manually in Supabase Dashboard');
      }
      
      debugPrint('Supabase Storage initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase Storage: $e');
      rethrow;
    }
  }
  
  /// Upload temple image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadTempleImage({
    required File imageFile,
    required String templeId,
  }) async {
    try {
      final extension = path.extension(imageFile.path);
      final fileName = '${templeId}_${_uuid.v4()}$extension';
      final filePath = 'temples/$fileName';
      
      debugPrint('Uploading temple image: $filePath');
      
      // Upload file
      await Supabase.instance.client.storage
          .from(templeImagesBucket)
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      
      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from(templeImagesBucket)
          .getPublicUrl(filePath);
      
      debugPrint('Temple image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading temple image: $e');
      rethrow;
    }
  }
  
  /// Upload multiple temple images
  Future<List<String>> uploadTempleImages({
    required List<File> imageFiles,
    required String templeId,
  }) async {
    final urls = <String>[];
    
    for (final imageFile in imageFiles) {
      try {
        final url = await uploadTempleImage(
          imageFile: imageFile,
          templeId: templeId,
        );
        urls.add(url);
      } catch (e) {
        debugPrint('Failed to upload image: $e');
        // Continue with other images
      }
    }
    
    return urls;
  }
  
  /// Upload user profile image
  Future<String> uploadUserImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final extension = path.extension(imageFile.path);
      final fileName = '${userId}_profile$extension';
      final filePath = 'profiles/$fileName';
      
      // Upload file (upsert to replace existing)
      await Supabase.instance.client.storage
          .from(userImagesBucket)
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Replace existing profile image
            ),
          );
      
      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from(userImagesBucket)
          .getPublicUrl(filePath);
      
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading user image: $e');
      rethrow;
    }
  }
  
  /// Delete temple image from Supabase Storage
  Future<void> deleteTempleImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // URL format: .../storage/v1/object/public/{bucket}/{file-path...}
      // Find 'public' segment and extract bucket + file path after it
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex < 0 || publicIndex + 2 >= pathSegments.length) {
        throw Exception(
          'Cannot parse Supabase Storage URL — unexpected format: $imageUrl',
        );
      }

      final bucket = pathSegments[publicIndex + 1];
      final filePath = pathSegments.sublist(publicIndex + 2).join('/');

      if (bucket.isEmpty || filePath.isEmpty) {
        throw Exception(
          'Extracted empty bucket or file path from URL: $imageUrl',
        );
      }

      await Supabase.instance.client.storage.from(bucket).remove([filePath]);

      if (kDebugMode) {
        debugPrint('SupabaseStorage: Deleted $filePath from $bucket');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseStorage: Error deleting image: $e');
      }
      rethrow;
    }
  }
  
  /// Delete multiple temple images
  Future<void> deleteTempleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        await deleteTempleImage(url);
      } catch (e) {
        debugPrint('Failed to delete image: $url - $e');
        // Continue with other images
      }
    }
  }
  
  /// Get public URL for a file (if you already know the path)
  String getPublicUrl({
    required String bucket,
    required String filePath,
  }) {
    return Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(filePath);
  }
  
  /// Get the base storage URL for the Supabase project
  String getStorageUrl() {
    // Construct storage URL from the Supabase project URL
    // Format: https://[project-id].supabase.co/storage/v1
    final storageClient = Supabase.instance.client.storage;
    // Get a public URL and extract the base storage URL from it
    final sampleUrl = storageClient.from(templeImagesBucket).getPublicUrl('sample');
    final uri = Uri.parse(sampleUrl);
    return '${uri.scheme}://${uri.host}/storage/v1';
  }
  
  /// Check if Supabase is configured
  bool isConfigured() {
    try {
      // Check if Supabase client is initialized
      final client = Supabase.instance.client;
      return client.auth.currentUser != null || true; // Always return true if client exists
    } catch (e) {
      return false;
    }
  }
}
