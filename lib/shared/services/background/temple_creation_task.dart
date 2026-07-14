import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'background_processor.dart';
import 'retry_task.dart';
import '../image/image_upload_service.dart';

/// Comprehensive background task for temple creation with retry logic
class TempleCreationTask extends RetryableBackgroundTask {
  final Map<String, dynamic> templeData;
  final File? imageFile;
  final Function(String downloadUrl)? onImageUploaded;
  final Function(String documentId)? onTempleCreated;
  final Function(String status)? onStatusUpdate;
  final Function(dynamic error)? onFailure;

  TempleCreationTask({
    required super.id,
    required this.templeData,
    this.imageFile,
    this.onImageUploaded,
    this.onTempleCreated,
    this.onStatusUpdate,
    this.onFailure,
    super.maxRetries = 3,
    super.baseDelay = const Duration(seconds: 2),
  }) : super(name: 'Creating temple: ${templeData['name'] ?? 'Unknown'}');

  @override
  Future<void> performWork() async {
    final backgroundProcessor = BackgroundProcessor();
    final imageUploadService = ImageUploadService();

    try {
      // Phase 1: Image upload (0% - 40%)
      String? imageUrl;
      if (imageFile != null) {
        onStatusUpdate?.call('Optimizing and uploading image...');
        backgroundProcessor.updateTaskProgress(id, 0.1);

        final uploadResult = await imageUploadService.uploadImage(
          imageFile: imageFile!,
          uploadPath:
              'temple_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
          useBackgroundProcessing: false, // Already in background
          onProgress: (progress) {
            // Map image upload progress to 0.1 - 0.4 range
            backgroundProcessor.updateTaskProgress(id, 0.1 + (progress * 0.3));
          },
        );

        if (!uploadResult.isSuccess) {
          throw Exception('Image upload failed: ${uploadResult.error}');
        }

        imageUrl = uploadResult.downloadUrl;
        onImageUploaded?.call(imageUrl!);
        backgroundProcessor.updateTaskProgress(id, 0.4);
      } else {
        backgroundProcessor.updateTaskProgress(id, 0.4);
      }

      // Phase 2: Data preparation (40% - 50%)
      onStatusUpdate?.call('Preparing temple data...');
      final completeTempleData = {
        ...templeData,
        if (imageUrl != null) 'coverPhotoUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      backgroundProcessor.updateTaskProgress(id, 0.5);

      // Phase 3: Database save (50% - 100%)
      onStatusUpdate?.call('Saving temple to database...');
      backgroundProcessor.updateTaskProgress(id, 0.6);

      final docRef = await FirebaseFirestore.instance
          .collection('temples')
          .add(completeTempleData);

      backgroundProcessor.updateTaskProgress(id, 0.9);
      onTempleCreated?.call(docRef.id);
      onStatusUpdate?.call('Temple created successfully!');
      backgroundProcessor.updateTaskProgress(id, 1.0);
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Retry network and server errors
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('server error') ||
        errorString.contains('firestore') ||
        errorString.contains('unavailable')) {
      return true;
    }

    // Don't retry validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('permission denied')) {
      return false;
    }

    return super.isRetryableError(error);
  }

  @override
  void onError(dynamic error) {
    super.onError(error);
    onStatusUpdate?.call(
      'Error occurred, retrying... (${currentAttempt}/${maxRetries})',
    );
  }
}

/// Background task for temple updates with retry logic
class TempleUpdateTask extends RetryableBackgroundTask {
  final String templeId;
  final Map<String, dynamic> updates;
  final File? newImageFile;
  final Function(String downloadUrl)? onImageUploaded;
  final Function()? onTempleUpdated;
  final Function(String status)? onStatusUpdate;
  final Function(dynamic error)? onFailure;

  TempleUpdateTask({
    required super.id,
    required this.templeId,
    required this.updates,
    this.newImageFile,
    this.onImageUploaded,
    this.onTempleUpdated,
    this.onStatusUpdate,
    this.onFailure,
    super.maxRetries = 3,
    super.baseDelay = const Duration(seconds: 2),
  }) : super(name: 'Updating temple: ${updates['name'] ?? templeId}');

  @override
  Future<void> performWork() async {
    final backgroundProcessor = BackgroundProcessor();
    final imageUploadService = ImageUploadService();

    try {
      // Phase 1: Image upload (0% - 40%)
      String? newImageUrl;
      if (newImageFile != null) {
        onStatusUpdate?.call('Optimizing and uploading new image...');
        backgroundProcessor.updateTaskProgress(id, 0.1);

        final uploadResult = await imageUploadService.uploadImage(
          imageFile: newImageFile!,
          uploadPath:
              'temple_images/${templeId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          useBackgroundProcessing: false, // Already in background
          onProgress: (progress) {
            // Map image upload progress to 0.1 - 0.4 range
            backgroundProcessor.updateTaskProgress(id, 0.1 + (progress * 0.3));
          },
        );

        if (!uploadResult.isSuccess) {
          throw Exception('Image upload failed: ${uploadResult.error}');
        }

        newImageUrl = uploadResult.downloadUrl;
        onImageUploaded?.call(newImageUrl!);
        backgroundProcessor.updateTaskProgress(id, 0.4);
      } else {
        backgroundProcessor.updateTaskProgress(id, 0.4);
      }

      // Phase 2: Data preparation (40% - 50%)
      onStatusUpdate?.call('Preparing update data...');
      final updateData = {
        ...updates,
        if (newImageUrl != null) 'coverPhotoUrl': newImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      backgroundProcessor.updateTaskProgress(id, 0.5);

      // Phase 3: Database update (50% - 100%)
      onStatusUpdate?.call('Updating temple in database...');
      backgroundProcessor.updateTaskProgress(id, 0.6);

      await FirebaseFirestore.instance
          .collection('temples')
          .doc(templeId)
          .update(updateData);

      backgroundProcessor.updateTaskProgress(id, 0.9);
      onTempleUpdated?.call();
      onStatusUpdate?.call('Temple updated successfully!');
      backgroundProcessor.updateTaskProgress(id, 1.0);
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Retry network and server errors
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('server error') ||
        errorString.contains('firestore') ||
        errorString.contains('unavailable')) {
      return true;
    }

    // Don't retry validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('permission denied')) {
      return false;
    }

    return super.isRetryableError(error);
  }

  @override
  void onError(dynamic error) {
    super.onError(error);
    onStatusUpdate?.call(
      'Error occurred, retrying... (${currentAttempt}/${maxRetries})',
    );
  }
}
