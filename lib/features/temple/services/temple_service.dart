import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/services/background/background_processor.dart';
import '../../../shared/services/background/retry_task.dart';
import '../../../shared/services/image/image_upload_service.dart';
import '../../../shared/services/storage/hybrid_storage_service.dart';
import '../../../shared/services/permission_service.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../core/services/error_logger.dart';

/// Service for managing temple operations with background processing
class TempleService {
  static final TempleService _instance = TempleService._internal();
  factory TempleService() => _instance;
  TempleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackgroundProcessor _backgroundProcessor = BackgroundProcessor();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final HybridStorageService _storageService = HybridStorageService();
  final PermissionService _permissionService = PermissionService();

  /// Create a new temple with background processing and enhanced error handling
  Future<TempleOperationResult> createTemple({
    required Map<String, dynamic> templeData,
    File? imageFile,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    // Check admin permissions first
    if (!await _permissionService.canManageTemples()) {
      return TempleOperationResult.error(
        error: 'Permission denied',
        message: 'Admin privileges required to create temples',
        errorType: ErrorDisplayType.error,
      );
    }

    try {
      final operationId =
          'create_temple_${DateTime.now().millisecondsSinceEpoch}';
      onStatusUpdate?.call('Starting temple creation...');

      // Step 1: Upload image if provided (30% of progress)
      String? imageUrl;
      if (imageFile != null) {
        onStatusUpdate?.call('Optimizing and uploading image...');

        final uploadResult = await _imageUploadService.uploadImage(
          imageFile: imageFile,
          uploadPath:
              'temple_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
          useBackgroundProcessing: true,
          onProgress: (progress) => onProgress?.call(progress * 0.3),
        );

        if (!uploadResult.isSuccess) {
          return TempleOperationResult.error(
            error: uploadResult.error ?? 'Image upload failed',
            message: 'Failed to upload temple image',
            errorType: _getErrorTypeFromException(uploadResult.error),
          );
        }

        imageUrl = uploadResult.downloadUrl;
        onProgress?.call(0.3);
      }

      // Step 2: Prepare temple data (40% of progress)
      onStatusUpdate?.call('Preparing temple data...');
      final completeTempleData = {
        ...templeData,
        if (imageUrl != null) 'coverPhotoUrl': imageUrl,
        if (imageUrl != null)
          'images': [imageUrl], // Add to images array for user side
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      onProgress?.call(0.4);

      // Step 3: Create retryable data sync task (60% - 100% of progress)
      onStatusUpdate?.call('Saving temple to database...');

      String? documentId;
      final syncTask = RetryableDataSyncTask(
        id: '${operationId}_sync',
        name: 'Creating temple: ${templeData['name'] ?? 'Unknown'}',
        syncFunction: () async {
          final docRef = await _firestore
              .collection('temples')
              .add(completeTempleData);
          documentId = docRef.id;
        },
        onRetry: (error, attempt) {
          onStatusUpdate?.call('Retrying database save (attempt $attempt)...');
        },
      );

      // Listen for progress updates
      final progressSubscription = _backgroundProcessor.events
          .where((event) => event.taskId == syncTask.id)
          .listen((event) {
            if (event.type == BackgroundTaskEventType.progress) {
              final taskProgress = event.progress ?? 0.0;
              onProgress?.call(0.4 + (taskProgress * 0.6));
            }
          });

      await _backgroundProcessor.addTask(syncTask);

      // Wait for completion
      await _waitForTaskCompletion(syncTask.id);
      progressSubscription.cancel();

      onProgress?.call(1.0);
      onStatusUpdate?.call('Temple created successfully!');

      return TempleOperationResult.success(
        documentId: documentId!,
        message: 'Temple created successfully',
      );
    } on FirebaseException catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.createTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeName': templeData['name']},
      );
      return TempleOperationResult.error(
        error: _handleFirebaseException(e),
        message: 'Failed to create temple',
        errorType: _getErrorTypeFromFirebaseException(e),
      );
    } on SocketException catch (e, stackTrace) {
      ErrorLogger.log('TempleService.createTemple', e, stackTrace: stackTrace);
      return TempleOperationResult.error(
        error:
            'Network connection failed. Please check your internet connection.',
        message: 'Network error during temple creation',
        errorType: ErrorDisplayType.network,
      );
    } catch (e, stackTrace) {
      ErrorLogger.log('TempleService.createTemple', e, stackTrace: stackTrace);
      return TempleOperationResult.error(
        error: e.toString(),
        message: 'Failed to create temple',
        errorType: ErrorDisplayType.error,
      );
    }
  }

  /// Update an existing temple with background processing and enhanced error handling
  Future<TempleOperationResult> updateTemple({
    required String templeId,
    required Map<String, dynamic> updates,
    File? newImageFile,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    try {
      final operationId =
          'update_temple_${DateTime.now().millisecondsSinceEpoch}';
      onStatusUpdate?.call('Starting temple update...');

      // Step 1: Upload new image if provided (30% of progress)
      String? newImageUrl;
      if (newImageFile != null) {
        onStatusUpdate?.call('Optimizing and uploading new image...');

        final uploadResult = await _imageUploadService.uploadImage(
          imageFile: newImageFile,
          uploadPath:
              'temple_images/${templeId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          useBackgroundProcessing: true,
          onProgress: (progress) => onProgress?.call(progress * 0.3),
        );

        if (!uploadResult.isSuccess) {
          return TempleOperationResult.error(
            error: uploadResult.error ?? 'Image upload failed',
            message: 'Failed to upload new temple image',
            errorType: _getErrorTypeFromException(uploadResult.error),
          );
        }

        newImageUrl = uploadResult.downloadUrl;
        onProgress?.call(0.3);
      }

      // Step 2: Prepare update data (40% of progress)
      onStatusUpdate?.call('Preparing update data...');
      final updateData = {
        ...updates,
        if (newImageUrl != null) 'coverPhotoUrl': newImageUrl,
        if (newImageUrl != null)
          'images': [newImageUrl], // Add to images array for user side
        'updatedAt': FieldValue.serverTimestamp(),
      };
      onProgress?.call(0.4);

      // Step 3: Create retryable update task (60% - 100% of progress)
      onStatusUpdate?.call('Updating temple in database...');

      final syncTask = RetryableDataSyncTask(
        id: '${operationId}_sync',
        name: 'Updating temple: ${updates['name'] ?? templeId}',
        syncFunction: () async {
          await _firestore
              .collection('temples')
              .doc(templeId)
              .update(updateData);
        },
        onRetry: (error, attempt) {
          onStatusUpdate?.call(
            'Retrying database update (attempt $attempt)...',
          );
        },
      );

      // Listen for progress updates
      final progressSubscription = _backgroundProcessor.events
          .where((event) => event.taskId == syncTask.id)
          .listen((event) {
            if (event.type == BackgroundTaskEventType.progress) {
              final taskProgress = event.progress ?? 0.0;
              onProgress?.call(0.4 + (taskProgress * 0.6));
            }
          });

      await _backgroundProcessor.addTask(syncTask);

      // Wait for completion
      await _waitForTaskCompletion(syncTask.id);
      progressSubscription.cancel();

      onProgress?.call(1.0);
      onStatusUpdate?.call('Temple updated successfully!');

      return TempleOperationResult.success(
        documentId: templeId,
        message: 'Temple updated successfully',
      );
    } on FirebaseException catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.updateTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      return TempleOperationResult.error(
        error: _handleFirebaseException(e),
        message: 'Failed to update temple',
        errorType: _getErrorTypeFromFirebaseException(e),
      );
    } on SocketException catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.updateTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      return TempleOperationResult.error(
        error:
            'Network connection failed. Please check your internet connection.',
        message: 'Network error during temple update',
        errorType: ErrorDisplayType.network,
      );
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.updateTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      return TempleOperationResult.error(
        error: e.toString(),
        message: 'Failed to update temple',
        errorType: ErrorDisplayType.error,
      );
    }
  }

  /// Delete a temple with complete cleanup (images, related data)
  Future<TempleOperationResult> deleteTemple({
    required String templeId,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    try {
      final operationId =
          'delete_temple_${DateTime.now().millisecondsSinceEpoch}';
      onStatusUpdate?.call('Starting temple deletion...');
      onProgress?.call(0.0);

      // Step 1: Get temple data to find images (10% progress)
      onStatusUpdate?.call('Fetching temple data...');
      final templeDoc = await _firestore
          .collection('temples')
          .doc(templeId)
          .get();

      if (!templeDoc.exists) {
        return TempleOperationResult.error(
          error: 'Temple not found',
          message: 'Temple does not exist',
          errorType: ErrorDisplayType.error,
        );
      }

      final templeData = templeDoc.data() as Map<String, dynamic>;
      onProgress?.call(0.1);

      // Step 2: Delete all images from Storage (40% progress)
      onStatusUpdate?.call('Deleting temple images...');
      final List<String> imageUrls = [];

      // Collect all image URLs
      if (templeData['coverPhotoUrl'] != null) {
        imageUrls.add(templeData['coverPhotoUrl'] as String);
      }
      if (templeData['images'] != null && templeData['images'] is List) {
        final images = templeData['images'] as List;
        for (var img in images) {
          if (img is String && !imageUrls.contains(img)) {
            imageUrls.add(img);
          }
        }
      }

      // Delete each image from Storage (Firebase or Supabase)
      for (int i = 0; i < imageUrls.length; i++) {
        try {
          final imageUrl = imageUrls[i];
          debugPrint('Deleting image: $imageUrl');

          // Use hybrid storage service to delete (handles both Firebase and Supabase)
          await _storageService.deleteTempleImage(imageUrl);

          debugPrint('Successfully deleted image: $imageUrl');
        } catch (e) {
          // Continue even if image deletion fails
          debugPrint('Failed to delete image: $e');
        }
        onProgress?.call(0.1 + (0.4 * (i + 1) / imageUrls.length));
      }

      // Step 3: Delete related data (30% progress)
      onStatusUpdate?.call('Cleaning up related data...');

      // Delete from user_favorites (stored per user with temple IDs in array)
      // Note: This requires reading all user_favorites docs and updating them
      try {
        final userFavoritesSnapshot = await _firestore
            .collection('user_favorites')
            .get();

        for (var doc in userFavoritesSnapshot.docs) {
          final data = doc.data();
          if (data['favorites'] != null && data['favorites'] is List) {
            final favorites = List<String>.from(data['favorites']);
            if (favorites.contains(templeId)) {
              favorites.remove(templeId);
              await doc.reference.update({'favorites': favorites});
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to clean favorites: $e');
      }
      onProgress?.call(0.6);

      // Delete donations for this temple
      try {
        final donationsQuery = await _firestore
            .collection('donations')
            .where('templeId', isEqualTo: templeId)
            .get();

        for (var doc in donationsQuery.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete donations: $e');
      }
      onProgress?.call(0.7);

      // Delete reviews for this temple
      try {
        final reviewsQuery = await _firestore
            .collection('reviews')
            .where('templeId', isEqualTo: templeId)
            .get();

        for (var doc in reviewsQuery.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete reviews: $e');
      }
      onProgress?.call(0.8);

      // Step 4: Delete the temple document (20% progress)
      onStatusUpdate?.call('Deleting temple record...');
      final syncTask = RetryableDataSyncTask(
        id: '${operationId}_sync',
        name: 'Deleting temple: $templeId',
        syncFunction: () async {
          await _firestore.collection('temples').doc(templeId).delete();
        },
        onRetry: (error, attempt) {
          onStatusUpdate?.call('Retrying deletion (attempt $attempt)...');
        },
      );

      await _backgroundProcessor.addTask(syncTask);
      await _waitForTaskCompletion(syncTask.id);

      onProgress?.call(1.0);
      onStatusUpdate?.call('Temple and all related data deleted successfully!');

      return TempleOperationResult.success(
        documentId: templeId,
        message: 'Temple and all related data deleted successfully',
      );
    } on FirebaseException catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.deleteTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      return TempleOperationResult.error(
        error: _handleFirebaseException(e),
        message: 'Failed to delete temple',
        errorType: _getErrorTypeFromFirebaseException(e),
      );
    } on SocketException catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.deleteTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      return TempleOperationResult.error(
        error:
            'Network connection failed. Please check your internet connection.',
        message: 'Network error during temple deletion',
        errorType: ErrorDisplayType.network,
      );
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'TempleService.deleteTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      return TempleOperationResult.error(
        error: e.toString(),
        message: 'Failed to delete temple',
        errorType: ErrorDisplayType.error,
      );
    }
  }

  /// Batch create multiple temples
  Future<BatchTempleOperationResult> createMultipleTemples({
    required List<TempleCreationData> templesData,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    try {
      final results = <String>[];
      final errors = <String>[];

      for (int i = 0; i < templesData.length; i++) {
        final templeData = templesData[i];
        final baseProgress = i / templesData.length;

        onStatusUpdate?.call(
          'Creating temple ${i + 1} of ${templesData.length}...',
        );

        try {
          final result = await createTemple(
            templeData: templeData.data,
            imageFile: templeData.imageFile,
            onProgress: (progress) {
              final totalProgress =
                  baseProgress + (progress / templesData.length);
              onProgress?.call(totalProgress);
            },
            onStatusUpdate: onStatusUpdate,
          );

          if (result.isSuccess) {
            results.add(result.documentId!);
          } else {
            errors.add('Temple ${i + 1}: ${result.error}');
          }
        } catch (e) {
          errors.add('Temple ${i + 1}: $e');
        }
      }

      onProgress?.call(1.0);

      return BatchTempleOperationResult(
        successCount: results.length,
        errorCount: errors.length,
        documentIds: results,
        errors: errors,
      );
    } catch (e) {
      return BatchTempleOperationResult(
        successCount: 0,
        errorCount: templesData.length,
        documentIds: [],
        errors: [e.toString()],
      );
    }
  }

  /// Wait for a background task to complete
  Future<void> _waitForTaskCompletion(String taskId) async {
    final completer = Completer<void>();

    final subscription = _backgroundProcessor.events
        .where((event) => event.taskId == taskId)
        .listen((event) {
          if (event.type == BackgroundTaskEventType.completed) {
            completer.complete();
          } else if (event.type == BackgroundTaskEventType.error) {
            completer.completeError(event.error ?? 'Unknown error');
          }
        });

    try {
      await completer.future;
    } finally {
      subscription.cancel();
    }
  }

  /// Get active temple operations
  List<String> getActiveOperations() {
    return _backgroundProcessor.activeTaskIds
        .where((id) => id.contains('temple'))
        .toList();
  }

  /// Cancel a temple operation
  void cancelOperation(String operationId) {
    _backgroundProcessor.cancelTask(operationId);
  }

  /// Get real-time stream for a single temple document
  Stream<Temple?> getTempleStream(String templeId) {
    return _firestore
        .collection('temples')
        .doc(templeId)
        .snapshots()
        .map((doc) => doc.exists ? Temple.fromFirestore(doc) : null);
  }

  /// Handle Firebase exceptions with user-friendly messages
  String _handleFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please check your connection and try again.';
      case 'resource-exhausted':
        return 'Service quota exceeded. Please try again later.';
      case 'not-found':
        return 'The requested temple was not found.';
      case 'already-exists':
        return 'A temple with this information already exists.';
      case 'invalid-argument':
        return 'Invalid temple data provided.';
      case 'failed-precondition':
        return 'Operation failed due to system constraints.';
      case 'aborted':
        return 'Operation was aborted due to a conflict.';
      case 'out-of-range':
        return 'Request parameters are out of valid range.';
      case 'unimplemented':
        return 'This feature is not yet implemented.';
      case 'internal':
        return 'Internal server error. Please try again later.';
      case 'data-loss':
        return 'Data corruption detected. Please contact support.';
      case 'unauthenticated':
        return 'Authentication required. Please sign in again.';
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get error display type from Firebase exception
  ErrorDisplayType _getErrorTypeFromFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
        return ErrorDisplayType.network;
      case 'permission-denied':
      case 'unauthenticated':
        return ErrorDisplayType.warning;
      case 'not-found':
      case 'already-exists':
        return ErrorDisplayType.info;
      default:
        return ErrorDisplayType.error;
    }
  }

  /// Get error display type from general exception
  ErrorDisplayType _getErrorTypeFromException(String? error) {
    if (error == null) return ErrorDisplayType.error;

    final lowerError = error.toLowerCase();
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout') ||
        lowerError.contains('internet')) {
      return ErrorDisplayType.network;
    }

    if (lowerError.contains('permission') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('forbidden')) {
      return ErrorDisplayType.warning;
    }

    return ErrorDisplayType.error;
  }
}

/// Result of a temple operation
class TempleOperationResult {
  final bool isSuccess;
  final String? documentId;
  final String message;
  final String? error;
  final ErrorDisplayType? errorType;

  TempleOperationResult._({
    required this.isSuccess,
    this.documentId,
    required this.message,
    this.error,
    this.errorType,
  });

  factory TempleOperationResult.success({
    required String documentId,
    required String message,
  }) {
    return TempleOperationResult._(
      isSuccess: true,
      documentId: documentId,
      message: message,
    );
  }

  factory TempleOperationResult.error({
    required String error,
    required String message,
    ErrorDisplayType? errorType,
  }) {
    return TempleOperationResult._(
      isSuccess: false,
      message: message,
      error: error,
      errorType: errorType ?? ErrorDisplayType.error,
    );
  }
}

/// Result of a batch temple operation
class BatchTempleOperationResult {
  final int successCount;
  final int errorCount;
  final List<String> documentIds;
  final List<String> errors;

  BatchTempleOperationResult({
    required this.successCount,
    required this.errorCount,
    required this.documentIds,
    required this.errors,
  });

  bool get hasErrors => errorCount > 0;
  bool get allSucceeded => errorCount == 0;
  int get totalCount => successCount + errorCount;
}

/// Data for creating a temple
class TempleCreationData {
  final Map<String, dynamic> data;
  final File? imageFile;

  TempleCreationData({required this.data, this.imageFile});
}
