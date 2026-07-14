import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../image/image_optimizer.dart';

/// Service for handling file uploads to Firebase Storage with optimizations
class FirebaseStorageService {
  static final Logger _logger = Logger('FirebaseStorageService');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImageOptimizer _imageOptimizer = ImageOptimizer();
  static const String _imagesFolder = 'images';
  static const String _videosFolder = 'videos';
  static const String _documentsFolder = 'documents';

  /// Uploads an image file with optimization
  Future<String> uploadImage({
    required File file,
    String? folder,
    String? fileName,
    int maxWidth = 1200,
    int quality = 80,
    bool convertToWebP = false, // Changed default to false for compatibility
  }) async {
    try {
      // Optimize the image file
      final optimizedFile = await _imageOptimizer.optimizeImage(file);
      final optimizedBytes = await optimizedFile.readAsBytes();

      final storagePath = _buildStoragePath(
        file: file,
        folder: folder ?? _imagesFolder,
        fileName: fileName,
      );

      final ref = _storage.ref().child(storagePath);
      await ref.putData(optimizedBytes);
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      _logger.severe('Failed to upload image', e, stackTrace);
      rethrow;
    }
  }

  /// Uploads image from bytes with optimization
  Future<String> uploadImageFromBytes({
    required Uint8List bytes,
    String? folder,
    String? fileName,
    int maxWidth = 1200,
    int quality = 80,
    bool convertToWebP = false,
  }) async {
    try {
      // Optimize the image bytes before upload
      final optimizedBytes = await _imageOptimizer.compressImage(bytes);

      final storagePath = _buildStoragePath(
        fileName: fileName ?? '${const Uuid().v4()}.jpg',
        folder: folder ?? _imagesFolder,
      );

      final ref = _storage.ref().child(storagePath);
      await ref.putData(optimizedBytes);
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      _logger.severe('Failed to upload image from bytes', e, stackTrace);
      rethrow;
    }
  }

  /// Uploads a video file with thumbnail generation
  Future<Map<String, String>> uploadVideoWithThumbnail({
    required File videoFile,
    String? folder,
    String? fileName,
    int thumbnailQuality = 60,
  }) async {
    try {
      // Upload video
      final videoPath = _buildStoragePath(
        file: videoFile,
        folder: '${folder ?? _videosFolder}/videos',
        fileName: fileName,
      );

      final videoRef = _storage.ref().child(videoPath);
      await videoRef.putFile(videoFile);
      final videoUrl = await videoRef.getDownloadURL();

      // Generate and upload video thumbnail
      final thumbnailUrl = await _uploadVideoThumbnail(
        videoFile,
        'thumbnails/${DateTime.now().millisecondsSinceEpoch}_thumb.jpg',
      );
      //   videoFile: videoFile,
      //   folder: folder,
      //   quality: thumbnailQuality,
      // );

      return {'videoUrl': videoUrl, 'thumbnailUrl': thumbnailUrl};
    } catch (e, stackTrace) {
      _logger.severe('Failed to upload video', e, stackTrace);
      rethrow;
    }
  }

  /// Uploads a document file
  Future<String> uploadDocument({
    required File file,
    String? folder,
    String? fileName,
  }) async {
    try {
      final storagePath = _buildStoragePath(
        file: file,
        folder: folder ?? _documentsFolder,
        fileName: fileName,
      );

      final ref = _storage.ref().child(storagePath);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      _logger.severe('Failed to upload document', e, stackTrace);
      rethrow;
    }
  }

  /// Deletes a file from Firebase Storage
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e, stackTrace) {
      _logger.severe('Failed to delete file', e, stackTrace);
      rethrow;
    }
  }

  /// Generate and upload video thumbnail
  Future<String> _uploadVideoThumbnail(
    File videoFile,
    String thumbnailPath,
  ) async {
    try {
      // For now, create a placeholder thumbnail
      // In production, use video_thumbnail package to generate actual thumbnail
      final placeholderBytes = await _generatePlaceholderThumbnail();

      final thumbnailRef = _storage.ref().child(thumbnailPath);
      final uploadTask = thumbnailRef.putData(
        placeholderBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'generated_from': 'video_thumbnail',
            'created_at': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Failed to generate video thumbnail: $e');
      // Return a default thumbnail URL or throw error
      throw Exception('Failed to generate video thumbnail: $e');
    }
  }

  /// Generate placeholder thumbnail (replace with actual video thumbnail generation)
  Future<Uint8List> _generatePlaceholderThumbnail() async {
    // Create a simple colored rectangle as placeholder
    // In production, use video_thumbnail package
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.grey[300]!;

    canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 180), paint);

    // Add play icon
    final playPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(160, 90), 30, playPaint);

    final playIconPaint = Paint()..color = Colors.grey[600]!;
    final path = Path();
    path.moveTo(150, 75);
    path.lineTo(150, 105);
    path.lineTo(175, 90);
    path.close();
    canvas.drawPath(path, playIconPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(320, 180);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // Builds the storage path for a file
  String _buildStoragePath({
    File? file,
    required String folder,
    String? fileName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = file != null
        ? path.extension(file.path).toLowerCase().replaceAll('.', '')
        : path.extension(fileName ?? '').toLowerCase().replaceAll('.', '');

    final name = fileName ?? '${const Uuid().v4()}.$ext';
    return '$folder/${timestamp}_$name';
  }

  /// Upload temple image (wrapper for uploadImage)
  Future<String> uploadTempleImage({
    required File imageFile,
    required String templeId,
  }) async {
    return await uploadImage(
      file: imageFile,
      folder: 'temple_images',
      fileName: '${templeId}_${DateTime.now().millisecondsSinceEpoch}',
    );
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
        debugPrint('Failed to upload temple image: $e');
      }
    }
    return urls;
  }

  /// Delete temple image (wrapper for deleteFile)
  Future<void> deleteTempleImage(String imageUrl) async {
    return await deleteFile(imageUrl);
  }
}
