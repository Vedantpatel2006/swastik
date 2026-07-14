import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../../core/services/isolate_service.dart';
import '../../models/image_optimization_models.dart';

/// Comprehensive image optimization system supporting multiple resolutions and formats
class ComprehensiveImageOptimizer {
  static final ComprehensiveImageOptimizer _instance =
      ComprehensiveImageOptimizer._internal();
  factory ComprehensiveImageOptimizer() => _instance;
  ComprehensiveImageOptimizer._internal();

  /// Default image sizes for multi-resolution optimization
  static const Map<ImageSizeType, OptimizedImageSize> defaultSizes = {
    ImageSizeType.thumbnail: OptimizedImageSize(width: 150, height: 150),
    ImageSizeType.medium: OptimizedImageSize(width: 400, height: 400),
    ImageSizeType.large: OptimizedImageSize(width: 800, height: 800),
    ImageSizeType.original: OptimizedImageSize(width: -1, height: -1),
  };

  /// Generate multiple image sizes with comprehensive optimization
  Future<ImageOptimizationResult> optimizeForAllSizes(
    String imagePath, {
    Map<ImageSizeType, OptimizedImageSize> targetSizes = defaultSizes,
    List<ImageFormat> formats = const [ImageFormat.webp, ImageFormat.jpeg],
    int quality = 85,
    bool preserveOriginal = true,
  }) async {
    try {
      final originalFile = File(imagePath);
      if (!await originalFile.exists()) {
        throw Exception('Source image file not found: $imagePath');
      }

      final originalSize = await originalFile.length();
      final originalDimensions = await _getImageDimensions(originalFile);
      final optimizedPaths = <ImageSizeType, Map<ImageFormat, String>>{};
      final optimizedSizes = <ImageSizeType, Map<ImageFormat, int>>{};
      final startTime = DateTime.now();

      // Process each target size
      for (final sizeEntry in targetSizes.entries) {
        final sizeType = sizeEntry.key;
        final targetSize = sizeEntry.value;

        optimizedPaths[sizeType] = {};
        optimizedSizes[sizeType] = {};

        // Skip original size processing if preserving original
        if (sizeType == ImageSizeType.original && preserveOriginal) {
          for (final format in formats) {
            optimizedPaths[sizeType]![format] = imagePath;
            optimizedSizes[sizeType]![format] = originalSize;
          }
          continue;
        }

        // Process each format for this size
        for (final format in formats) {
          try {
            final optimizedPath = await _optimizeSingleImage(
              originalFile,
              targetSize,
              format,
              quality,
            );

            if (optimizedPath != null) {
              final optimizedFile = File(optimizedPath);
              final optimizedFileSize = await optimizedFile.length();

              optimizedPaths[sizeType]![format] = optimizedPath;
              optimizedSizes[sizeType]![format] = optimizedFileSize;
            }
          } catch (e) {
            debugPrint(
              'Error optimizing ${sizeType.name} in ${format.name}: $e',
            );
          }
        }
      }

      final processingTime = DateTime.now()
          .difference(startTime)
          .inMilliseconds;
      final totalOptimizedSize = optimizedSizes.values
          .expand((formatSizes) => formatSizes.values)
          .fold<int>(0, (sum, size) => sum + size);

      final compressionRatio = originalSize > 0
          ? ((originalSize - (totalOptimizedSize / optimizedSizes.length)) /
                    originalSize) *
                100
          : 0.0;

      return ImageOptimizationResult(
        originalPath: imagePath,
        originalSize: originalSize,
        originalDimensions: originalDimensions,
        optimizedPaths: optimizedPaths,
        optimizedSizes: optimizedSizes,
        compressionRatio: compressionRatio,
        processingTime: processingTime,
        success: optimizedPaths.isNotEmpty,
      );
    } catch (e) {
      return ImageOptimizationResult.error(
        originalPath: imagePath,
        error: e.toString(),
      );
    }
  }

  /// Optimize image for specific format with WebP conversion support
  Future<String?> optimizeForFormat(
    String imagePath,
    ImageFormat targetFormat, {
    int quality = 85,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final originalFile = File(imagePath);
      if (!await originalFile.exists()) {
        throw Exception('Source image file not found: $imagePath');
      }

      // Generate output path
      final hash = await _generateFileHash(originalFile);
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'format_optimized_$hash${targetFormat.extension}',
      );

      // Check if already optimized
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return outputPath;
      }

      // Use isolate for processing
      final params = ImageFormatOptimizationParams(
        inputPath: imagePath,
        targetFormat: _mapToImageOutputFormat(targetFormat),
        quality: quality,
        maxWidth: maxWidth ?? 1920,
        keepExif: false,
      );

      return await IsolateService.optimizeImageFormatInIsolate(params);
    } catch (e) {
      debugPrint('Format optimization failed: $e');
      return null;
    }
  }

  /// Batch optimize multiple images with progress tracking
  Future<List<ImageOptimizationResult>> batchOptimize(
    List<String> imagePaths,
    OptimizationConfig config, {
    Function(double progress, int currentIndex, int total)? onProgress,
  }) async {
    try {
      final results = <ImageOptimizationResult>[];

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        onProgress?.call(i / imagePaths.length, i, imagePaths.length);

        try {
          final result = await optimizeForAllSizes(
            imagePath,
            targetSizes: config.targetSizes,
            formats: config.formats,
            quality: config.quality,
            preserveOriginal: config.preserveOriginal,
          );
          results.add(result);
        } catch (e) {
          results.add(
            ImageOptimizationResult.error(
              originalPath: imagePath,
              error: e.toString(),
            ),
          );
        }

        // Small delay to prevent overwhelming the system
        if (i < imagePaths.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      onProgress?.call(1.0, imagePaths.length, imagePaths.length);
      return results;
    } catch (e) {
      throw Exception('Batch optimization failed: $e');
    }
  }

  /// Create progressive image data for better loading experience
  Future<ProgressiveImageData> createProgressiveImage(
    String imagePath, {
    List<int> qualityLevels = const [20, 40, 60, 80, 95],
  }) async {
    try {
      final originalFile = File(imagePath);
      if (!await originalFile.exists()) {
        throw Exception('Source image file not found: $imagePath');
      }

      final progressivePaths = <int, String>{};
      final progressiveSizes = <int, int>{};
      final originalDimensions = await _getImageDimensions(originalFile);

      for (final quality in qualityLevels) {
        try {
          final progressivePath = await _createProgressiveLevel(
            originalFile,
            quality,
          );

          if (progressivePath != null) {
            final progressiveFile = File(progressivePath);
            final fileSize = await progressiveFile.length();

            progressivePaths[quality] = progressivePath;
            progressiveSizes[quality] = fileSize;
          }
        } catch (e) {
          debugPrint('Error creating progressive level $quality: $e');
        }
      }

      return ProgressiveImageData(
        originalPath: imagePath,
        originalDimensions: originalDimensions,
        progressivePaths: progressivePaths,
        progressiveSizes: progressiveSizes,
        qualityLevels: qualityLevels,
        success: progressivePaths.isNotEmpty,
      );
    } catch (e) {
      return ProgressiveImageData.error(
        originalPath: imagePath,
        error: e.toString(),
      );
    }
  }

  /// Get optimal image format based on content type
  Future<ImageFormat> getOptimalFormat(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return ImageFormat.jpeg; // Default fallback
      }

      // Analyze image characteristics
      final hasTransparency = _hasTransparency(image);
      final colorComplexity = _analyzeColorComplexity(image);
      final isPhotographic = _isPhotographic(image);

      // Decision logic for optimal format
      if (hasTransparency) {
        return ImageFormat
            .webp; // WebP supports transparency with better compression
      } else if (isPhotographic && colorComplexity > 0.7) {
        return ImageFormat.jpeg; // JPEG better for complex photographic content
      } else {
        return ImageFormat.webp; // WebP generally better for most other cases
      }
    } catch (e) {
      debugPrint('Error analyzing image format: $e');
      return ImageFormat.jpeg; // Safe fallback
    }
  }

  /// Validate optimization quality and compression ratio
  Future<OptimizationQualityReport> validateOptimization(
    ImageOptimizationResult result,
  ) async {
    try {
      final qualityMetrics = <ImageSizeType, QualityMetrics>{};

      for (final sizeEntry in result.optimizedPaths.entries) {
        final sizeType = sizeEntry.key;
        final formatPaths = sizeEntry.value;

        for (final formatEntry in formatPaths.entries) {
          final format = formatEntry.key;
          final optimizedPath = formatEntry.value;

          final metrics = await _calculateQualityMetrics(
            result.originalPath,
            optimizedPath,
            format,
          );

          qualityMetrics[sizeType] = metrics;
        }
      }

      final overallQuality = _calculateOverallQuality(qualityMetrics);
      final compressionEfficiency = _calculateCompressionEfficiency(result);

      return OptimizationQualityReport(
        originalPath: result.originalPath,
        qualityMetrics: qualityMetrics,
        overallQuality: overallQuality,
        compressionEfficiency: compressionEfficiency,
        recommendations: _generateOptimizationRecommendations(
          result,
          qualityMetrics,
        ),
      );
    } catch (e) {
      return OptimizationQualityReport.error(
        originalPath: result.originalPath,
        error: e.toString(),
      );
    }
  }

  // Private helper methods

  Future<String?> _optimizeSingleImage(
    File originalFile,
    OptimizedImageSize targetSize,
    ImageFormat format,
    int quality,
  ) async {
    try {
      final hash = await _generateFileHash(originalFile);
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        '${targetSize.name}_$hash${format.extension}',
      );

      // Check if already exists
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return outputPath;
      }

      // Use isolate for processing
      final params = ImageProcessParams(
        filePath: originalFile.path,
        maxWidth: targetSize.width > 0 ? targetSize.width : 1920,
        quality: quality,
        format: _mapToImageOutputFormat(format),
        minHeight: targetSize.height > 0 ? targetSize.height : 1080,
        minWidth: targetSize.width > 0 ? targetSize.width : 1920,
        keepExif: false,
      );

      return await IsolateService.processImageInIsolate(params);
    } catch (e) {
      debugPrint('Single image optimization failed: $e');
      return null;
    }
  }

  Future<String?> _createProgressiveLevel(
    File originalFile,
    int quality,
  ) async {
    try {
      final hash = await _generateFileHash(originalFile);
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'progressive_${quality}_$hash.jpg',
      );

      // Check if already exists
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return outputPath;
      }

      // Use isolate for processing
      final params = ImageProcessParams(
        filePath: originalFile.path,
        maxWidth: 800, // Standard size for progressive loading
        quality: quality,
        format: ImageOutputFormat.jpg,
        keepExif: false,
      );

      return await IsolateService.processImageInIsolate(params);
    } catch (e) {
      debugPrint('Progressive level creation failed: $e');
      return null;
    }
  }

  Future<ImageDimensions> _getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image for dimensions');
      }

      return ImageDimensions(width: image.width, height: image.height);
    } catch (e) {
      throw Exception('Failed to get image dimensions: $e');
    }
  }

  bool _hasTransparency(img.Image image) {
    try {
      return image.hasAlpha;
    } catch (e) {
      return false;
    }
  }

  double _analyzeColorComplexity(img.Image image) {
    try {
      final colors = <int>{};
      final sampleSize = math.min(10000, image.width * image.height);
      final step = math.max(1, (image.width * image.height) ~/ sampleSize);

      for (int y = 0; y < image.height; y += step) {
        for (int x = 0; x < image.width; x += step) {
          final pixel = image.getPixel(x, y);
          colors.add(
            pixel.r.toInt() << 16 | pixel.g.toInt() << 8 | pixel.b.toInt(),
          );
          if (colors.length > 1000) break; // Limit for performance
        }
        if (colors.length > 1000) break;
      }

      return math.min(1.0, colors.length / 1000.0);
    } catch (e) {
      return 0.5; // Default complexity
    }
  }

  bool _isPhotographic(img.Image image) {
    try {
      // Simple heuristic: photographic images tend to have more color variation
      // and gradients compared to graphics/illustrations
      final complexity = _analyzeColorComplexity(image);
      return complexity > 0.6;
    } catch (e) {
      return true; // Default to photographic
    }
  }

  Future<QualityMetrics> _calculateQualityMetrics(
    String originalPath,
    String optimizedPath,
    ImageFormat format,
  ) async {
    try {
      final originalFile = File(originalPath);
      final optimizedFile = File(optimizedPath);

      final originalSize = await originalFile.length();
      final optimizedSize = await optimizedFile.length();

      final compressionRatio = originalSize > 0
          ? ((originalSize - optimizedSize) / originalSize) * 100
          : 0.0;

      // Simple quality estimation based on compression ratio and format
      double estimatedQuality;
      if (compressionRatio < 30) {
        estimatedQuality = 0.95; // High quality
      } else if (compressionRatio < 60) {
        estimatedQuality = 0.85; // Good quality
      } else if (compressionRatio < 80) {
        estimatedQuality = 0.75; // Acceptable quality
      } else {
        estimatedQuality = 0.65; // Lower quality
      }

      return QualityMetrics(
        compressionRatio: compressionRatio,
        estimatedQuality: estimatedQuality,
        originalSize: originalSize,
        optimizedSize: optimizedSize,
        format: format,
      );
    } catch (e) {
      return QualityMetrics(
        compressionRatio: 0.0,
        estimatedQuality: 0.0,
        originalSize: 0,
        optimizedSize: 0,
        format: format,
        error: e.toString(),
      );
    }
  }

  double _calculateOverallQuality(Map<ImageSizeType, QualityMetrics> metrics) {
    if (metrics.isEmpty) return 0.0;

    final qualitySum = metrics.values
        .map((m) => m.estimatedQuality)
        .fold<double>(0.0, (sum, quality) => sum + quality);

    return qualitySum / metrics.length;
  }

  double _calculateCompressionEfficiency(ImageOptimizationResult result) {
    if (result.originalSize == 0) return 0.0;

    final totalOptimizedSize = result.optimizedSizes.values
        .expand((formatSizes) => formatSizes.values)
        .fold<int>(0, (sum, size) => sum + size);

    final averageOptimizedSize =
        totalOptimizedSize /
        result.optimizedSizes.values.expand((m) => m.values).length;

    return ((result.originalSize - averageOptimizedSize) /
            result.originalSize) *
        100;
  }

  List<String> _generateOptimizationRecommendations(
    ImageOptimizationResult result,
    Map<ImageSizeType, QualityMetrics> metrics,
  ) {
    final recommendations = <String>[];

    final avgQuality = _calculateOverallQuality(metrics);
    if (avgQuality < 0.7) {
      recommendations.add(
        'Consider increasing quality settings for better visual results',
      );
    }

    if (result.compressionRatio < 30) {
      recommendations.add(
        'Compression ratio is low - consider more aggressive optimization',
      );
    } else if (result.compressionRatio > 80) {
      recommendations.add(
        'High compression detected - verify image quality is acceptable',
      );
    }

    final hasWebP = result.optimizedPaths.values.any(
      (formats) => formats.containsKey(ImageFormat.webp),
    );
    if (!hasWebP) {
      recommendations.add('Consider using WebP format for better compression');
    }

    return recommendations;
  }

  ImageOutputFormat _mapToImageOutputFormat(ImageFormat format) {
    switch (format) {
      case ImageFormat.jpeg:
        return ImageOutputFormat.jpg;
      case ImageFormat.png:
        return ImageOutputFormat.png;
      case ImageFormat.webp:
        return ImageOutputFormat.webp;
      case ImageFormat.heic:
        return ImageOutputFormat.heic;
    }
  }

  Future<String> _generateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
