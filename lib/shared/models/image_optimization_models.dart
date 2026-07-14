/// Data models for comprehensive image optimization system

/// Enum for different image size types
enum ImageSizeType {
  thumbnail,
  medium,
  large,
  original;

  String get name {
    switch (this) {
      case ImageSizeType.thumbnail:
        return 'thumbnail';
      case ImageSizeType.medium:
        return 'medium';
      case ImageSizeType.large:
        return 'large';
      case ImageSizeType.original:
        return 'original';
    }
  }
}

/// Enum for supported image formats
enum ImageFormat {
  jpeg,
  png,
  webp,
  heic;

  String get extension {
    switch (this) {
      case ImageFormat.jpeg:
        return '.jpg';
      case ImageFormat.png:
        return '.png';
      case ImageFormat.webp:
        return '.webp';
      case ImageFormat.heic:
        return '.heic';
    }
  }

  String get name {
    switch (this) {
      case ImageFormat.jpeg:
        return 'JPEG';
      case ImageFormat.png:
        return 'PNG';
      case ImageFormat.webp:
        return 'WebP';
      case ImageFormat.heic:
        return 'HEIC';
    }
  }
}

/// Represents image dimensions
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

/// Represents a target image size for optimization
class OptimizedImageSize {
  final int width;
  final int height;

  const OptimizedImageSize({required this.width, required this.height});

  String get name => '${width}x$height';

  bool get isOriginal => width == -1 && height == -1;

  @override
  String toString() => isOriginal ? 'original' : name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OptimizedImageSize &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

/// Configuration for image optimization
class OptimizationConfig {
  final Map<ImageSizeType, OptimizedImageSize> targetSizes;
  final List<ImageFormat> formats;
  final int quality;
  final bool preserveOriginal;
  final bool enableWebP;
  final bool enableProgressiveJPEG;

  const OptimizationConfig({
    required this.targetSizes,
    this.formats = const [ImageFormat.webp, ImageFormat.jpeg],
    this.quality = 85,
    this.preserveOriginal = true,
    this.enableWebP = true,
    this.enableProgressiveJPEG = true,
  });

  /// Default configuration for general use
  static const OptimizationConfig defaultConfig = OptimizationConfig(
    targetSizes: {
      ImageSizeType.thumbnail: OptimizedImageSize(width: 150, height: 150),
      ImageSizeType.medium: OptimizedImageSize(width: 400, height: 400),
      ImageSizeType.large: OptimizedImageSize(width: 800, height: 800),
      ImageSizeType.original: OptimizedImageSize(width: -1, height: -1),
    },
  );

  /// Configuration optimized for web usage
  static const OptimizationConfig webOptimized = OptimizationConfig(
    targetSizes: {
      ImageSizeType.thumbnail: OptimizedImageSize(width: 200, height: 200),
      ImageSizeType.medium: OptimizedImageSize(width: 600, height: 600),
      ImageSizeType.large: OptimizedImageSize(width: 1200, height: 1200),
    },
    formats: [ImageFormat.webp, ImageFormat.jpeg],
    quality: 80,
    preserveOriginal: false,
  );

  /// Configuration for mobile apps with storage constraints
  static const OptimizationConfig mobileOptimized = OptimizationConfig(
    targetSizes: {
      ImageSizeType.thumbnail: OptimizedImageSize(width: 120, height: 120),
      ImageSizeType.medium: OptimizedImageSize(width: 300, height: 300),
      ImageSizeType.large: OptimizedImageSize(width: 600, height: 600),
    },
    formats: [ImageFormat.webp],
    quality: 75,
    preserveOriginal: false,
  );
}

/// Result of comprehensive image optimization
class ImageOptimizationResult {
  final String originalPath;
  final int originalSize;
  final ImageDimensions? originalDimensions;
  final Map<ImageSizeType, Map<ImageFormat, String>> optimizedPaths;
  final Map<ImageSizeType, Map<ImageFormat, int>> optimizedSizes;
  final double compressionRatio;
  final int processingTime;
  final bool success;
  final String? error;

  const ImageOptimizationResult({
    required this.originalPath,
    required this.originalSize,
    this.originalDimensions,
    required this.optimizedPaths,
    required this.optimizedSizes,
    required this.compressionRatio,
    required this.processingTime,
    required this.success,
    this.error,
  });

  factory ImageOptimizationResult.error({
    required String originalPath,
    required String error,
  }) {
    return ImageOptimizationResult(
      originalPath: originalPath,
      originalSize: 0,
      optimizedPaths: {},
      optimizedSizes: {},
      compressionRatio: 0.0,
      processingTime: 0,
      success: false,
      error: error,
    );
  }

  /// Get the best optimized path for a specific size and preferred formats
  String? getBestPath(
    ImageSizeType sizeType, {
    List<ImageFormat> preferredFormats = const [
      ImageFormat.webp,
      ImageFormat.jpeg,
      ImageFormat.png,
    ],
  }) {
    final sizePaths = optimizedPaths[sizeType];
    if (sizePaths == null || sizePaths.isEmpty) return null;

    for (final format in preferredFormats) {
      if (sizePaths.containsKey(format)) {
        return sizePaths[format];
      }
    }

    // Return any available path if no preferred format found
    return sizePaths.values.first;
  }

  /// Get total size saved across all optimizations
  int get totalSizeSaved {
    final totalOptimizedSize = optimizedSizes.values
        .expand((formatSizes) => formatSizes.values)
        .fold<int>(0, (sum, size) => sum + size);

    final averageOptimizedSize = optimizedSizes.isNotEmpty
        ? totalOptimizedSize /
              optimizedSizes.values.expand((m) => m.values).length
        : 0;

    return (originalSize - averageOptimizedSize).round();
  }

  /// Get optimization summary
  Map<String, dynamic> get summary => {
    'originalSize': originalSize,
    'totalSizeSaved': totalSizeSaved,
    'compressionRatio': compressionRatio,
    'processingTime': processingTime,
    'sizesGenerated': optimizedPaths.length,
    'formatsGenerated': optimizedPaths.values
        .expand((formats) => formats.keys)
        .toSet()
        .length,
    'success': success,
  };
}

/// Data for progressive image loading
class ProgressiveImageData {
  final String originalPath;
  final ImageDimensions? originalDimensions;
  final Map<int, String> progressivePaths;
  final Map<int, int> progressiveSizes;
  final List<int> qualityLevels;
  final bool success;
  final String? error;

  const ProgressiveImageData({
    required this.originalPath,
    this.originalDimensions,
    required this.progressivePaths,
    required this.progressiveSizes,
    required this.qualityLevels,
    required this.success,
    this.error,
  });

  factory ProgressiveImageData.error({
    required String originalPath,
    required String error,
  }) {
    return ProgressiveImageData(
      originalPath: originalPath,
      progressivePaths: {},
      progressiveSizes: {},
      qualityLevels: [],
      success: false,
      error: error,
    );
  }

  /// Get progressive paths sorted by quality (lowest to highest)
  List<String> get sortedProgressivePaths {
    final sortedQualities = qualityLevels.toList()..sort();
    return sortedQualities
        .where((quality) => progressivePaths.containsKey(quality))
        .map((quality) => progressivePaths[quality]!)
        .toList();
  }

  /// Get the lowest quality path for initial loading
  String? get initialPath {
    if (progressivePaths.isEmpty) return null;
    final lowestQuality = qualityLevels.reduce((a, b) => a < b ? a : b);
    return progressivePaths[lowestQuality];
  }

  /// Get the highest quality path for final display
  String? get finalPath {
    if (progressivePaths.isEmpty) return null;
    final highestQuality = qualityLevels.reduce((a, b) => a > b ? a : b);
    return progressivePaths[highestQuality];
  }
}

/// Quality metrics for optimization validation
class QualityMetrics {
  final double compressionRatio;
  final double estimatedQuality;
  final int originalSize;
  final int optimizedSize;
  final ImageFormat format;
  final String? error;

  const QualityMetrics({
    required this.compressionRatio,
    required this.estimatedQuality,
    required this.originalSize,
    required this.optimizedSize,
    required this.format,
    this.error,
  });

  bool get isGoodQuality => estimatedQuality >= 0.8;
  bool get isAcceptableCompression =>
      compressionRatio >= 20 && compressionRatio <= 80;

  String get qualityGrade {
    if (estimatedQuality >= 0.9) return 'Excellent';
    if (estimatedQuality >= 0.8) return 'Good';
    if (estimatedQuality >= 0.7) return 'Acceptable';
    if (estimatedQuality >= 0.6) return 'Poor';
    return 'Very Poor';
  }
}

/// Report for optimization quality validation
class OptimizationQualityReport {
  final String originalPath;
  final Map<ImageSizeType, QualityMetrics> qualityMetrics;
  final double overallQuality;
  final double compressionEfficiency;
  final List<String> recommendations;
  final String? error;

  const OptimizationQualityReport({
    required this.originalPath,
    required this.qualityMetrics,
    required this.overallQuality,
    required this.compressionEfficiency,
    required this.recommendations,
    this.error,
  });

  factory OptimizationQualityReport.error({
    required String originalPath,
    required String error,
  }) {
    return OptimizationQualityReport(
      originalPath: originalPath,
      qualityMetrics: {},
      overallQuality: 0.0,
      compressionEfficiency: 0.0,
      recommendations: [],
      error: error,
    );
  }

  bool get isOptimizationSuccessful => overallQuality >= 0.7;

  String get overallGrade {
    if (overallQuality >= 0.9) return 'Excellent';
    if (overallQuality >= 0.8) return 'Good';
    if (overallQuality >= 0.7) return 'Acceptable';
    if (overallQuality >= 0.6) return 'Poor';
    return 'Very Poor';
  }

  /// Get summary of the optimization report
  Map<String, dynamic> get summary => {
    'overallQuality': overallQuality,
    'overallGrade': overallGrade,
    'compressionEfficiency': compressionEfficiency,
    'isSuccessful': isOptimizationSuccessful,
    'recommendationsCount': recommendations.length,
    'sizesAnalyzed': qualityMetrics.length,
  };
}

/// Parameters for batch optimization
class BatchOptimizationParams {
  final List<String> imagePaths;
  final OptimizationConfig config;
  final bool enableProgressTracking;
  final int maxConcurrency;

  const BatchOptimizationParams({
    required this.imagePaths,
    required this.config,
    this.enableProgressTracking = true,
    this.maxConcurrency = 3,
  });
}

/// Result of batch optimization
class BatchOptimizationResult {
  final List<ImageOptimizationResult> results;
  final int totalProcessed;
  final int successfulOptimizations;
  final int failedOptimizations;
  final int totalProcessingTime;
  final double averageCompressionRatio;

  const BatchOptimizationResult({
    required this.results,
    required this.totalProcessed,
    required this.successfulOptimizations,
    required this.failedOptimizations,
    required this.totalProcessingTime,
    required this.averageCompressionRatio,
  });

  factory BatchOptimizationResult.fromResults(
    List<ImageOptimizationResult> results,
  ) {
    final totalProcessed = results.length;
    final successfulOptimizations = results.where((r) => r.success).length;
    final failedOptimizations = totalProcessed - successfulOptimizations;
    final totalProcessingTime = results.fold<int>(
      0,
      (sum, result) => sum + result.processingTime,
    );
    final averageCompressionRatio = successfulOptimizations > 0
        ? results
                  .where((r) => r.success)
                  .map((r) => r.compressionRatio)
                  .fold<double>(0.0, (sum, ratio) => sum + ratio) /
              successfulOptimizations
        : 0.0;

    return BatchOptimizationResult(
      results: results,
      totalProcessed: totalProcessed,
      successfulOptimizations: successfulOptimizations,
      failedOptimizations: failedOptimizations,
      totalProcessingTime: totalProcessingTime,
      averageCompressionRatio: averageCompressionRatio,
    );
  }

  double get successRate => totalProcessed > 0
      ? (successfulOptimizations / totalProcessed) * 100
      : 0.0;

  /// Get summary of batch optimization
  Map<String, dynamic> get summary => {
    'totalProcessed': totalProcessed,
    'successfulOptimizations': successfulOptimizations,
    'failedOptimizations': failedOptimizations,
    'successRate': successRate,
    'totalProcessingTime': totalProcessingTime,
    'averageCompressionRatio': averageCompressionRatio,
  };
}
