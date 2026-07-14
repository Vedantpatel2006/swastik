import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/isolate_service.dart';

/// Service for handling image processing tasks in a separate isolate
/// Optimized with centralized isolate management
class ImageProcessingService {
  static final ImageProcessingService _instance =
      ImageProcessingService._internal();

  factory ImageProcessingService() => _instance;

  ImageProcessingService._internal();

  /// Compresses and optimizes an image file
  /// Returns the path to the optimized image
  Future<String> processImage(
    String filePath, {
    int maxWidth = 1200,
    int quality = 80,
    ImageOutputFormat format = ImageOutputFormat.webp,
    int? minHeight,
    int? minWidth,
    bool keepExif = false,
  }) async {
    try {
      // Use centralized isolate service for better performance
      final result = await compute(
        IsolateService.processImageInIsolate,
        ImageProcessParams(
          filePath: filePath,
          maxWidth: maxWidth,
          quality: quality,
          format: format,
          minHeight: minHeight,
          minWidth: minWidth,
          keepExif: keepExif,
        ),
      );

      return result ?? filePath; // Return original if processing fails
    } catch (e) {
      debugPrint('Error processing image: $e');
      return filePath; // Return original path on error
    }
  }

  /// Batch process multiple images efficiently
  Future<List<String>> batchProcessImages(
    List<String> filePaths, {
    int maxWidth = 1200,
    int quality = 80,
    ImageOutputFormat format = ImageOutputFormat.webp,
    int? minHeight,
    int? minWidth,
    bool keepExif = false,
  }) async {
    try {
      final results = <String>[];

      // Process images in batches to avoid overwhelming the system
      const batchSize = 3;
      for (int i = 0; i < filePaths.length; i += batchSize) {
        final batch = filePaths.skip(i).take(batchSize);
        final batchFutures = batch.map(
          (filePath) => processImage(
            filePath,
            maxWidth: maxWidth,
            quality: quality,
            format: format,
            minHeight: minHeight,
            minWidth: minWidth,
            keepExif: keepExif,
          ),
        );

        final batchResults = await Future.wait(batchFutures);
        results.addAll(batchResults);

        // Small delay between batches to prevent UI blocking
        if (i + batchSize < filePaths.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error batch processing images: $e');
      return filePaths; // Return original paths on error
    }
  }
}
