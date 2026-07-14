import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../../../core/services/isolate_service.dart';

/// Service for optimizing images including compression, resizing, and thumbnail generation
class ImageOptimizer {
  static const int maxWidth = 1024;
  static const int maxHeight = 1024;
  static const int quality = 85;
  static const int thumbnailSize = 200;
  static const int thumbnailQuality = 70;

  /// Optimizes an image by compressing and resizing it using isolates
  /// Returns the optimized image file
  Future<File> optimizeImage(File originalImage) async {
    try {
      final String originalPath = originalImage.path;
      final String extension = originalPath.split('.').last.toLowerCase();

      // Generate optimized filename
      final String hash = await _generateFileHash(originalImage);
      final Directory tempDir = await getTemporaryDirectory();
      final String optimizedPath = '${tempDir.path}/optimized_$hash.$extension';

      // Check if optimized version already exists
      final File optimizedFile = File(optimizedPath);
      if (await optimizedFile.exists()) {
        return optimizedFile;
      }

      // Use isolate service for processing
      final params = ImageProcessParams(
        filePath: originalPath,
        maxWidth: maxWidth,
        quality: quality,
        format: _getImageOutputFormat(extension),
        minHeight: maxHeight,
        minWidth: maxWidth,
        keepExif: false,
      );

      final String? processedPath = await IsolateService.processImageInIsolate(
        params,
      );

      if (processedPath == null) {
        throw Exception('Failed to process image in isolate');
      }

      return File(processedPath);
    } catch (e) {
      throw Exception('Image optimization failed: $e');
    }
  }

  /// Compresses image bytes and returns compressed bytes
  Future<Uint8List> compressImage(Uint8List imageBytes) async {
    try {
      // Decode the image
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if necessary
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resizedImage = _resizeImage(image, maxWidth, maxHeight);
      }

      // Encode with compression
      final List<int> compressedBytes = img.encodeJpg(
        resizedImage,
        quality: quality,
      );
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      throw Exception('Image compression failed: $e');
    }
  }

  /// Generates a thumbnail for the given image using isolates
  /// Returns the path to the generated thumbnail
  Future<String> generateThumbnail(File image) async {
    try {
      final String originalPath = image.path;
      final String extension = originalPath.split('.').last.toLowerCase();

      // Generate thumbnail filename
      final String hash = await _generateFileHash(image);
      final Directory tempDir = await getTemporaryDirectory();
      final String thumbnailPath = '${tempDir.path}/thumb_$hash.$extension';

      // Check if thumbnail already exists
      final File thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        return thumbnailPath;
      }

      // Use isolate service for thumbnail generation
      final params = ImageProcessParams(
        filePath: originalPath,
        maxWidth: thumbnailSize,
        quality: thumbnailQuality,
        format: _getImageOutputFormat(extension),
        minHeight: thumbnailSize,
        minWidth: thumbnailSize,
        keepExif: false,
      );

      final String? thumbnailPath2 = await IsolateService.processImageInIsolate(
        params,
      );

      if (thumbnailPath2 == null) {
        throw Exception('Failed to generate thumbnail in isolate');
      }

      return thumbnailPath2;
    } catch (e) {
      throw Exception('Thumbnail generation failed: $e');
    }
  }

  /// Resizes an image while maintaining aspect ratio
  Future<File> resizeImage(
    File originalImage,
    int targetWidth,
    int targetHeight,
  ) async {
    try {
      final Uint8List imageBytes = await originalImage.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image for resizing');
      }

      final img.Image resizedImage = _resizeImage(
        image,
        targetWidth,
        targetHeight,
      );

      // Save resized image
      final String hash = await _generateFileHash(originalImage);
      final Directory tempDir = await getTemporaryDirectory();
      final String resizedPath =
          '${tempDir.path}/resized_${targetWidth}x${targetHeight}_$hash.jpg';

      final File resizedFile = File(resizedPath);
      final List<int> encodedBytes = img.encodeJpg(
        resizedImage,
        quality: quality,
      );
      await resizedFile.writeAsBytes(encodedBytes);

      return resizedFile;
    } catch (e) {
      throw Exception('Image resizing failed: $e');
    }
  }

  /// Gets image dimensions without loading the full image
  Future<ImageDimensions> getImageDimensions(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image for dimensions');
      }

      return ImageDimensions(width: image.width, height: image.height);
    } catch (e) {
      throw Exception('Failed to get image dimensions: $e');
    }
  }

  /// Calculates the file size reduction percentage
  Future<double> calculateCompressionRatio(
    File originalFile,
    File compressedFile,
  ) async {
    try {
      final int originalSize = await originalFile.length();
      final int compressedSize = await compressedFile.length();

      if (originalSize == 0) return 0.0;

      return ((originalSize - compressedSize) / originalSize) * 100;
    } catch (e) {
      return 0.0;
    }
  }

  /// Validates if the file is a supported image format
  bool isValidImageFormat(String filePath) {
    final String extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension);
  }

  /// Batch optimize multiple images using isolates with progress updates
  Future<List<File?>> batchOptimizeImages(
    List<File> images, {
    Function(double progress, int currentIndex, int total)? onProgress,
  }) async {
    try {
      final results = <File?>[];

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final extension = image.path.split('.').last.toLowerCase();

        // Update progress
        onProgress?.call(i / images.length, i, images.length);

        final params = ImageProcessParams(
          filePath: image.path,
          maxWidth: maxWidth,
          quality: quality,
          format: _getImageOutputFormat(extension),
          minHeight: maxHeight,
          minWidth: maxWidth,
          keepExif: false,
        );

        final result = await IsolateService.processImageInIsolate(params);
        results.add(result != null ? File(result) : null);

        // Small delay to prevent overwhelming the system
        if (i < images.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Final progress update
      onProgress?.call(1.0, images.length, images.length);

      return results;
    } catch (e) {
      throw Exception('Batch image optimization failed: $e');
    }
  }

  /// Batch optimize multiple images simultaneously using isolates
  Future<List<File?>> batchOptimizeImagesParallel(
    List<File> images, {
    int maxConcurrency = 3,
    Function(double progress, int completed, int total)? onProgress,
  }) async {
    try {
      final imageParams = <ImageProcessParams>[];

      for (final image in images) {
        final extension = image.path.split('.').last.toLowerCase();
        final params = ImageProcessParams(
          filePath: image.path,
          maxWidth: maxWidth,
          quality: quality,
          format: _getImageOutputFormat(extension),
          minHeight: maxHeight,
          minWidth: maxWidth,
          keepExif: false,
        );
        imageParams.add(params);
      }

      final results = await IsolateService.batchProcessImagesInIsolate(
        imageParams,
      );

      return results.map((path) => path != null ? File(path) : null).toList();
    } catch (e) {
      throw Exception('Batch image optimization failed: $e');
    }
  }

  /// Generate multiple sizes for an image using isolates
  Future<Map<String, File?>> generateMultipleSizes(
    File originalImage,
    Map<String, ImageSize> sizes,
  ) async {
    try {
      final extension = originalImage.path.split('.').last.toLowerCase();
      final params = MultiSizeImageParams(
        originalPath: originalImage.path,
        sizes: sizes,
        quality: quality,
        format: _getImageOutputFormat(extension),
        keepExif: false,
      );

      final results = await IsolateService.generateMultipleSizesInIsolate(
        params,
      );

      return results.map(
        (key, path) => MapEntry(key, path != null ? File(path) : null),
      );
    } catch (e) {
      throw Exception('Multiple size generation failed: $e');
    }
  }

  /// Optimize image with progress updates using isolates
  Future<ImageProcessingResult> optimizeImageWithProgress(
    File originalImage,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final extension = originalImage.path.split('.').last.toLowerCase();
      final params = ImageProcessParams(
        filePath: originalImage.path,
        maxWidth: maxWidth,
        quality: quality,
        format: _getImageOutputFormat(extension),
        minHeight: maxHeight,
        minWidth: maxWidth,
        keepExif: false,
      );

      return await IsolateService.processImageWithProgressInIsolate(
        params,
        onProgress,
      );
    } catch (e) {
      throw Exception('Progressive image optimization failed: $e');
    }
  }

  /// Convert image to different format using isolates
  Future<File?> convertImageFormat(
    File originalImage,
    ImageOutputFormat targetFormat,
  ) async {
    try {
      final params = ImageFormatOptimizationParams(
        inputPath: originalImage.path,
        targetFormat: targetFormat,
        quality: quality,
        maxWidth: maxWidth,
        keepExif: false,
      );

      final outputPath = await IsolateService.optimizeImageFormatInIsolate(
        params,
      );

      return outputPath != null ? File(outputPath) : null;
    } catch (e) {
      throw Exception('Image format conversion failed: $e');
    }
  }

  /// Process multiple images with different sizes simultaneously
  Future<Map<String, List<File?>>> batchGenerateMultipleSizes(
    List<File> originalImages,
    Map<String, ImageSize> sizes, {
    Function(double progress, int currentImage, int totalImages)? onProgress,
  }) async {
    try {
      final results = <String, List<File?>>{};

      for (int i = 0; i < originalImages.length; i++) {
        final image = originalImages[i];
        onProgress?.call(i / originalImages.length, i, originalImages.length);

        final sizeResults = await generateMultipleSizes(image, sizes);
        final imageKey = 'image_$i';
        results[imageKey] = sizes.keys
            .map((sizeKey) => sizeResults[sizeKey])
            .toList();

        // Small delay between images
        if (i < originalImages.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      onProgress?.call(1.0, originalImages.length, originalImages.length);
      return results;
    } catch (e) {
      throw Exception('Batch multiple size generation failed: $e');
    }
  }

  /// Compress images to target file size using isolates
  Future<File?> compressToTargetSize(
    File originalImage,
    int targetSizeKB, {
    int maxIterations = 5,
    Function(double progress, int iteration)? onProgress,
  }) async {
    try {
      int currentQuality = quality;
      File? result;

      for (int iteration = 0; iteration < maxIterations; iteration++) {
        onProgress?.call(iteration / maxIterations, iteration);

        final extension = originalImage.path.split('.').last.toLowerCase();
        final params = ImageProcessParams(
          filePath: originalImage.path,
          maxWidth: maxWidth,
          quality: currentQuality,
          format: _getImageOutputFormat(extension),
          minHeight: maxHeight,
          minWidth: maxWidth,
          keepExif: false,
        );

        final processedPath = await IsolateService.processImageInIsolate(
          params,
        );
        if (processedPath == null) break;

        result = File(processedPath);
        final fileSize = await result.length();
        final fileSizeKB = fileSize ~/ 1024;

        if (fileSizeKB <= targetSizeKB) {
          onProgress?.call(1.0, maxIterations);
          return result;
        }

        // Reduce quality for next iteration
        currentQuality = (currentQuality * 0.8).round().clamp(10, 100);

        if (currentQuality <= 10) break;
      }

      onProgress?.call(1.0, maxIterations);
      return result;
    } catch (e) {
      throw Exception('Target size compression failed: $e');
    }
  }

  /// Create progressive JPEG with multiple quality levels
  Future<List<File?>> createProgressiveJPEG(
    File originalImage, {
    List<int> qualityLevels = const [20, 40, 60, 80],
    Function(double progress, int currentLevel)? onProgress,
  }) async {
    try {
      final results = <File?>[];

      for (int i = 0; i < qualityLevels.length; i++) {
        final qualityLevel = qualityLevels[i];
        onProgress?.call(i / qualityLevels.length, i);

        final params = ImageProcessParams(
          filePath: originalImage.path,
          maxWidth: maxWidth,
          quality: qualityLevel,
          format: ImageOutputFormat.jpg,
          minHeight: maxHeight,
          minWidth: maxWidth,
          keepExif: false,
        );

        final processedPath = await IsolateService.processImageInIsolate(
          params,
        );
        results.add(processedPath != null ? File(processedPath) : null);

        // Small delay between quality levels
        if (i < qualityLevels.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      onProgress?.call(1.0, qualityLevels.length);
      return results;
    } catch (e) {
      throw Exception('Progressive JPEG creation failed: $e');
    }
  }

  // Private helper methods

  /// Resizes image while maintaining aspect ratio
  img.Image _resizeImage(img.Image image, int maxWidth, int maxHeight) {
    final double aspectRatio = image.width / image.height;

    int newWidth = maxWidth;
    int newHeight = maxHeight;

    if (aspectRatio > 1) {
      // Landscape
      newHeight = (maxWidth / aspectRatio).round();
      if (newHeight > maxHeight) {
        newHeight = maxHeight;
        newWidth = (maxHeight * aspectRatio).round();
      }
    } else {
      // Portrait or square
      newWidth = (maxHeight * aspectRatio).round();
      if (newWidth > maxWidth) {
        newWidth = maxWidth;
        newHeight = (maxWidth / aspectRatio).round();
      }
    }

    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  /// Gets the appropriate ImageOutputFormat based on file extension
  ImageOutputFormat _getImageOutputFormat(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return ImageOutputFormat.png;
      case 'webp':
        return ImageOutputFormat.webp;
      case 'heic':
        return ImageOutputFormat.heic;
      default:
        return ImageOutputFormat.jpg;
    }
  }

  /// Generates a hash for the file to create unique filenames
  Future<String> _generateFileHash(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final Digest digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}

/// Data class for image dimensions
class ImageDimensions {
  final int width;
  final int height;

  const ImageDimensions({required this.width, required this.height});

  double get aspectRatio => width / height;

  @override
  String toString() => '${width}x$height';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageDimensions &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}
