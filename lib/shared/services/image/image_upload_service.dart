import 'dart:io';
import 'dart:async';

import '../background/background_processor.dart';
import '../background/image_processing_task.dart';
import 'image_optimizer.dart';

/// Service for handling optimized image uploads with progress tracking
class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final BackgroundProcessor _backgroundProcessor = BackgroundProcessor();
  final ImageOptimizer _imageOptimizer = ImageOptimizer();
  final Map<String, Completer<String>> _uploadCompleters = {};
  // Separate map for batch uploads to avoid unsafe type casts
  final Map<String, Completer<List<String>>> _batchUploadCompleters = {};

  /// Upload a single image with optimization and progress tracking
  Future<ImageUploadResult> uploadImage({
    required File imageFile,
    required String uploadPath,
    bool useBackgroundProcessing = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Validate image format
      if (!_imageOptimizer.isValidImageFormat(imageFile.path)) {
        throw Exception('Unsupported image format');
      }

      // Get image dimensions for validation
      final dimensions = await _imageOptimizer.getImageDimensions(imageFile);

      if (useBackgroundProcessing) {
        return _uploadImageInBackground(
          imageFile: imageFile,
          uploadPath: uploadPath,
          dimensions: dimensions,
          onProgress: onProgress,
        );
      } else {
        return _uploadImageSynchronously(
          imageFile: imageFile,
          uploadPath: uploadPath,
          dimensions: dimensions,
          onProgress: onProgress,
        );
      }
    } catch (e) {
      return ImageUploadResult.error(e.toString());
    }
  }

  /// Upload multiple images with batch processing
  Future<BatchImageUploadResult> uploadImages({
    required List<File> imageFiles,
    required String basePath,
    bool useBackgroundProcessing = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Validate all images
      for (final imageFile in imageFiles) {
        if (!_imageOptimizer.isValidImageFormat(imageFile.path)) {
          throw Exception('Unsupported image format: ${imageFile.path}');
        }
      }

      if (useBackgroundProcessing) {
        return _uploadImagesInBackground(
          imageFiles: imageFiles,
          basePath: basePath,
          onProgress: onProgress,
        );
      } else {
        return _uploadImagesSynchronously(
          imageFiles: imageFiles,
          basePath: basePath,
          onProgress: onProgress,
        );
      }
    } catch (e) {
      return BatchImageUploadResult.error(e.toString());
    }
  }

  /// Cancel an ongoing upload
  void cancelUpload(String uploadId) {
    _backgroundProcessor.cancelTask(uploadId);
    _uploadCompleters.remove(uploadId);
  }

  /// Get upload progress for a specific upload
  double getUploadProgress(String uploadId) {
    return _backgroundProcessor.getTaskProgress(uploadId);
  }

  /// Get stream of background task events
  Stream<BackgroundTaskEvent> get uploadEvents => _backgroundProcessor.events;

  // Private methods

  Future<ImageUploadResult> _uploadImageInBackground({
    required File imageFile,
    required String uploadPath,
    required ImageDimensions dimensions,
    Function(double progress)? onProgress,
  }) async {
    final uploadId = 'upload_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<String>();
    _uploadCompleters[uploadId] = completer;

    // Listen to progress updates
    StreamSubscription? progressSubscription;
    if (onProgress != null) {
      progressSubscription = _backgroundProcessor.events
          .where(
            (event) =>
                event.taskId == uploadId &&
                event.type == BackgroundTaskEventType.progress,
          )
          .listen((event) {
            onProgress(event.progress ?? 0.0);
          });
    }

    // Create and add background task
    final task = ImageProcessingTask(
      id: uploadId,
      imageFile: imageFile,
      uploadPath: uploadPath,
      onSuccess: (downloadUrl) {
        completer.complete(downloadUrl);
        _uploadCompleters.remove(uploadId);
        progressSubscription?.cancel();
      },
      onFailure: (error) {
        completer.completeError(error);
        _uploadCompleters.remove(uploadId);
        progressSubscription?.cancel();
      },
    );

    await _backgroundProcessor.addTask(task);

    try {
      final downloadUrl = await completer.future;
      return ImageUploadResult.success(
        downloadUrl: downloadUrl,
        originalDimensions: dimensions,
        uploadId: uploadId,
      );
    } catch (e) {
      return ImageUploadResult.error(e.toString());
    }
  }

  Future<ImageUploadResult> _uploadImageSynchronously({
    required File imageFile,
    required String uploadPath,
    required ImageDimensions dimensions,
    Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Optimize image
      final optimizedImage = await _imageOptimizer.optimizeImage(imageFile);
      onProgress?.call(0.4);

      // Generate thumbnail
      await _imageOptimizer.generateThumbnail(optimizedImage);
      onProgress?.call(0.6);

      // Use a Completer to capture the download URL from the task callback
      final urlCompleter = Completer<String>();
      final taskId = 'sync_upload_${DateTime.now().millisecondsSinceEpoch}';

      final task = ImageProcessingTask(
        id: taskId,
        imageFile: optimizedImage,
        uploadPath: uploadPath,
        onSuccess: (downloadUrl) => urlCompleter.complete(downloadUrl),
        onFailure: (error) => urlCompleter.completeError(error),
      );

      await task.execute();
      final downloadUrl = await urlCompleter.future;
      onProgress?.call(1.0);

      return ImageUploadResult.success(
        downloadUrl: downloadUrl,
        originalDimensions: dimensions,
        uploadId: taskId,
      );
    } catch (e) {
      return ImageUploadResult.error(e.toString());
    }
  }

  Future<BatchImageUploadResult> _uploadImagesInBackground({
    required List<File> imageFiles,
    required String basePath,
    Function(double progress)? onProgress,
  }) async {
    final uploadId = 'batch_upload_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<List<String>>();
    _batchUploadCompleters[uploadId] = completer;

    // Listen to progress updates
    StreamSubscription? progressSubscription;
    if (onProgress != null) {
      progressSubscription = _backgroundProcessor.events
          .where(
            (event) =>
                event.taskId == uploadId &&
                event.type == BackgroundTaskEventType.progress,
          )
          .listen((event) {
            onProgress(event.progress ?? 0.0);
          });
    }

    // Create and add batch task
    final task = BatchImageProcessingTask(
      id: uploadId,
      imageFiles: imageFiles,
      basePath: basePath,
      onSuccess: (downloadUrls) {
        completer.complete(downloadUrls);
        _batchUploadCompleters.remove(uploadId);
        progressSubscription?.cancel();
      },
      onFailure: (error) {
        completer.completeError(error);
        _batchUploadCompleters.remove(uploadId);
        progressSubscription?.cancel();
      },
    );

    await _backgroundProcessor.addTask(task);

    try {
      final downloadUrls = await completer.future;
      return BatchImageUploadResult.success(
        downloadUrls: downloadUrls,
        uploadId: uploadId,
      );
    } catch (e) {
      return BatchImageUploadResult.error(e.toString());
    }
  }

  Future<BatchImageUploadResult> _uploadImagesSynchronously({
    required List<File> imageFiles,
    required String basePath,
    Function(double progress)? onProgress,
  }) async {
    try {
      final List<String> downloadUrls = [];

      for (int i = 0; i < imageFiles.length; i++) {
        final progress = i / imageFiles.length;
        onProgress?.call(progress);

        final result = await _uploadImageSynchronously(
          imageFile: imageFiles[i],
          uploadPath: '$basePath/image_$i.jpg',
          dimensions: await _imageOptimizer.getImageDimensions(imageFiles[i]),
        );

        if (result.isSuccess) {
          downloadUrls.add(result.downloadUrl!);
        } else {
          throw Exception(result.error);
        }
      }

      onProgress?.call(1.0);

      return BatchImageUploadResult.success(
        downloadUrls: downloadUrls,
        uploadId: 'sync_batch_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      return BatchImageUploadResult.error(e.toString());
    }
  }
}

/// Result of a single image upload
class ImageUploadResult {
  final bool isSuccess;
  final String? downloadUrl;
  final ImageDimensions? originalDimensions;
  final String? uploadId;
  final String? error;

  ImageUploadResult._({
    required this.isSuccess,
    this.downloadUrl,
    this.originalDimensions,
    this.uploadId,
    this.error,
  });

  factory ImageUploadResult.success({
    required String downloadUrl,
    required ImageDimensions originalDimensions,
    required String uploadId,
  }) {
    return ImageUploadResult._(
      isSuccess: true,
      downloadUrl: downloadUrl,
      originalDimensions: originalDimensions,
      uploadId: uploadId,
    );
  }

  factory ImageUploadResult.error(String error) {
    return ImageUploadResult._(isSuccess: false, error: error);
  }
}

/// Result of a batch image upload
class BatchImageUploadResult {
  final bool isSuccess;
  final List<String>? downloadUrls;
  final String? uploadId;
  final String? error;

  BatchImageUploadResult._({
    required this.isSuccess,
    this.downloadUrls,
    this.uploadId,
    this.error,
  });

  factory BatchImageUploadResult.success({
    required List<String> downloadUrls,
    required String uploadId,
  }) {
    return BatchImageUploadResult._(
      isSuccess: true,
      downloadUrls: downloadUrls,
      uploadId: uploadId,
    );
  }

  factory BatchImageUploadResult.error(String error) {
    return BatchImageUploadResult._(isSuccess: false, error: error);
  }
}
