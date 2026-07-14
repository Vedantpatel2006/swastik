import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'background_processor.dart';
import '../image/image_optimizer.dart';

/// Background task for processing and uploading images
class ImageProcessingTask extends BackgroundTask {
  final File imageFile;
  final String uploadPath;
  final ImageOptimizer _imageOptimizer = ImageOptimizer();
  final Function(String downloadUrl)? onSuccess;
  final Function(dynamic error)? onFailure;

  ImageProcessingTask({
    required super.id,
    required this.imageFile,
    required this.uploadPath,
    this.onSuccess,
    this.onFailure,
  }) : super(name: 'Processing ${imageFile.path.split('/').last}');

  @override
  Future<void> execute() async {
    try {
      final backgroundProcessor = BackgroundProcessor();

      // Step 1: Optimize image using isolate (30% of progress)
      backgroundProcessor.updateTaskProgress(id, 0.1);
      final optimizationResult = await _imageOptimizer
          .optimizeImageWithProgress(imageFile, (progress) {
            // Update progress within the optimization step (10% to 30%)
            final totalProgress = 0.1 + (progress * 0.2);
            backgroundProcessor.updateTaskProgress(id, totalProgress);
          });

      if (!optimizationResult.success ||
          optimizationResult.outputPath == null) {
        throw Exception(
          'Image optimization failed: ${optimizationResult.error}',
        );
      }

      final optimizedImage = File(optimizationResult.outputPath!);
      backgroundProcessor.updateTaskProgress(id, 0.3);

      // Step 2: Generate thumbnail using isolate (50% of progress)
      final thumbnailPath = await _imageOptimizer.generateThumbnail(
        optimizedImage,
      );
      backgroundProcessor.updateTaskProgress(id, 0.5);

      // Step 3: Upload optimized image (80% of progress)
      final ref = FirebaseStorage.instance.ref().child(uploadPath);
      final uploadTask = ref.putFile(optimizedImage);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        final totalProgress = 0.5 + (uploadProgress * 0.3); // 50% to 80%
        backgroundProcessor.updateTaskProgress(id, totalProgress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Step 4: Upload thumbnail (90% of progress)
      final thumbnailRef = FirebaseStorage.instance.ref().child(
        '${uploadPath}_thumb',
      );
      await thumbnailRef.putFile(File(thumbnailPath));
      backgroundProcessor.updateTaskProgress(id, 0.9);

      // Step 5: Complete (100% of progress)
      backgroundProcessor.updateTaskProgress(id, 1.0);

      // Cleanup temporary files
      try {
        await optimizedImage.delete();
        await File(thumbnailPath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      // Notify success
      onSuccess?.call(downloadUrl);
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  void onError(dynamic error) {
    super.onError(error);
    onFailure?.call(error);
  }
}

/// Background task for batch image processing
class BatchImageProcessingTask extends BackgroundTask {
  final List<File> imageFiles;
  final String basePath;
  final ImageOptimizer _imageOptimizer = ImageOptimizer();
  final Function(List<String> downloadUrls)? onSuccess;
  final Function(dynamic error)? onFailure;

  BatchImageProcessingTask({
    required super.id,
    required this.imageFiles,
    required this.basePath,
    this.onSuccess,
    this.onFailure,
  }) : super(name: 'Processing ${imageFiles.length} images');

  @override
  Future<void> execute() async {
    try {
      final backgroundProcessor = BackgroundProcessor();
      final List<String> downloadUrls = [];

      // Use batch processing with isolates for better performance
      final optimizationResults = await _imageOptimizer.batchOptimizeImages(
        imageFiles,
        onProgress: (progress, currentIndex, total) {
          // Update progress for optimization phase (0% to 50%)
          final totalProgress = progress * 0.5;
          backgroundProcessor.updateTaskProgress(id, totalProgress);
        },
      );

      // Upload optimized images
      for (int i = 0; i < optimizationResults.length; i++) {
        final optimizedImage = optimizationResults[i];
        if (optimizedImage == null) {
          throw Exception('Failed to optimize image at index $i');
        }

        final uploadPath =
            '$basePath/image_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Update progress for upload phase (50% to 100%)
        final uploadBaseProgress = 0.5 + (i / imageFiles.length) * 0.5;
        backgroundProcessor.updateTaskProgress(id, uploadBaseProgress);

        // Upload image
        final ref = FirebaseStorage.instance.ref().child(uploadPath);
        final uploadTask = ref.putFile(optimizedImage);

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);

        // Cleanup
        try {
          await optimizedImage.delete();
        } catch (e) {
          // Ignore cleanup errors
        }

        // Update progress for completed image
        final completedProgress = 0.5 + ((i + 1) / imageFiles.length) * 0.5;
        backgroundProcessor.updateTaskProgress(id, completedProgress);
      }

      onSuccess?.call(downloadUrls);
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  void onError(dynamic error) {
    super.onError(error);
    onFailure?.call(error);
  }
}
