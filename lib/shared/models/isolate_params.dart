import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Parameters for image processing in isolates
class ImageProcessParams {
  final String filePath;
  final int? maxWidth;
  final int? minWidth;
  final int? minHeight;
  final int quality;
  final ImageOutputFormat format;
  final bool keepExif;

  const ImageProcessParams({
    required this.filePath,
    this.maxWidth,
    this.minWidth,
    this.minHeight,
    required this.quality,
    required this.format,
    this.keepExif = false,
  });
}

/// Enum for image output formats
enum ImageOutputFormat {
  jpg,
  png,
  webp,
  heic;

  String get extension {
    switch (this) {
      case ImageOutputFormat.jpg:
        return '.jpg';
      case ImageOutputFormat.png:
        return '.png';
      case ImageOutputFormat.webp:
        return '.webp';
      case ImageOutputFormat.heic:
        return '.heic';
    }
  }

  CompressFormat get compressFormat {
    switch (this) {
      case ImageOutputFormat.jpg:
        return CompressFormat.jpeg;
      case ImageOutputFormat.png:
        return CompressFormat.png;
      case ImageOutputFormat.webp:
        return CompressFormat.webp;
      case ImageOutputFormat.heic:
        return CompressFormat.heic;
    }
  }
}

/// Parameters for image format optimization
class ImageFormatOptimizationParams {
  final String inputPath;
  final ImageOutputFormat targetFormat;
  final int quality;
  final int maxWidth;
  final int? maxHeight;
  final bool keepExif;

  const ImageFormatOptimizationParams({
    required this.inputPath,
    required this.targetFormat,
    required this.quality,
    required this.maxWidth,
    this.maxHeight,
    this.keepExif = false,
  });
}

/// Parameters for processing image with progress tracking
class ImageProcessWithProgressParams {
  final ImageProcessParams imageParams;
  final bool enableProgress;

  const ImageProcessWithProgressParams({
    required this.imageParams,
    this.enableProgress = true,
  });
}

/// Result of image processing with detailed information
class ImageProcessingResult {
  final String? outputPath;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final int processingTime;
  final bool success;
  final String? error;

  const ImageProcessingResult({
    this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.processingTime,
    required this.success,
    this.error,
  });
}

/// Parameters for generating multiple image sizes
class MultiSizeImageParams {
  final String originalPath;
  final Map<String, ImageSize> sizes;
  final int quality;
  final ImageOutputFormat format;
  final bool keepExif;

  const MultiSizeImageParams({
    required this.originalPath,
    required this.sizes,
    required this.quality,
    required this.format,
    this.keepExif = false,
  });
}

/// Represents an image size specification
class ImageSize {
  final int width;
  final int height;

  const ImageSize({required this.width, required this.height});

  @override
  String toString() => '${width}x$height';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageSize &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

/// Parameters for metrics calculation
class MetricsCalculationParams<T> {
  final List<T> data;
  final double Function(T) valueExtractor;
  final Map<String, double Function(List<double>)>? customCalculations;

  const MetricsCalculationParams({
    required this.data,
    required this.valueExtractor,
    this.customCalculations,
  });
}

/// Result of metrics calculation
class MetricsResult {
  final int totalCount;
  final double averageValue;
  final double maxValue;
  final double minValue;
  final double standardDeviation;
  final Map<int, double> percentiles;
  final Map<String, double> customMetrics;

  const MetricsResult({
    required this.totalCount,
    required this.averageValue,
    required this.maxValue,
    required this.minValue,
    required this.standardDeviation,
    required this.percentiles,
    required this.customMetrics,
  });
}


/// Parameters for batch processing
class BatchProcessParams<T> {
  final List<dynamic> items;
  final T Function(dynamic) processor;
  final T? defaultValue;

  const BatchProcessParams({
    required this.items,
    required this.processor,
    this.defaultValue,
  });
}

/// Parameters for large dataset processing
class LargeDatasetParams<T> {
  final List<dynamic> data;
  final T Function(dynamic) processor;
  final int chunkSize;

  const LargeDatasetParams({
    required this.data,
    required this.processor,
    this.chunkSize = 1000,
  });
}

/// Parameters for filtering temples
class FilterTemplesParams {
  final List<Map<String, dynamic>> temples;
  final String searchQuery;

  const FilterTemplesParams({required this.temples, required this.searchQuery});
}

/// Parameters for sorting temples
class SortTemplesParams {
  final List<Map<String, dynamic>> temples;
  final String sortBy;
  final bool ascending;

  const SortTemplesParams({
    required this.temples,
    required this.sortBy,
    this.ascending = true,
  });
}

/// Parameters for advanced temple filtering
class AdvancedFilterParams {
  final List<Map<String, dynamic>> temples;
  final String? searchQuery;
  final List<String>? traditions;
  final double? maxDistance;
  final String? state;
  final String? city;
  final bool? isVerified;

  const AdvancedFilterParams({
    required this.temples,
    this.searchQuery,
    this.traditions,
    this.maxDistance,
    this.state,
    this.city,
    this.isVerified,
  });
}

/// Parameters for temple search with ranking
class TempleSearchParams {
  final List<Map<String, dynamic>> temples;
  final String searchQuery;
  final double? userLatitude;
  final double? userLongitude;
  final Map<String, double> rankingWeights;

  const TempleSearchParams({
    required this.temples,
    required this.searchQuery,
    this.userLatitude,
    this.userLongitude,
    this.rankingWeights = const {
      'nameMatch': 0.4,
      'descriptionMatch': 0.3,
      'distance': 0.2,
      'popularity': 0.1,
    },
  });
}



/// Parameters for user behavior processing
class UserBehaviorParams {
  final List<Map<String, dynamic>> behaviorData;
  final List<String> behaviorTypes;
  final int timeWindowDays;

  const UserBehaviorParams({
    required this.behaviorData,
    required this.behaviorTypes,
    this.timeWindowDays = 30,
  });
}

/// Result of user behavior metrics calculation
class UserBehaviorMetrics {
  final Map<String, double> behaviorFrequency;
  final Map<String, double> behaviorTrends;
  final List<String> behaviorPatterns;
  final double engagementScore;

  const UserBehaviorMetrics({
    required this.behaviorFrequency,
    required this.behaviorTrends,
    required this.behaviorPatterns,
    required this.engagementScore,
  });
}

/// Parameters for temple visit pattern processing
class TempleVisitParams {
  final List<Map<String, dynamic>> visitData;
  final DateTime startDate;
  final DateTime endDate;

  const TempleVisitParams({
    required this.visitData,
    required this.startDate,
    required this.endDate,
  });
}



/// Parameters for filter, sort, and paginate operations
class FilterSortPaginateParams<T> {
  final List<T> data;
  final bool Function(T)? filter;
  final int Function(T, T)? comparator;
  final int page;
  final int pageSize;

  const FilterSortPaginateParams({
    required this.data,
    this.filter,
    this.comparator,
    required this.page,
    required this.pageSize,
  });
}

/// Result of paginated data processing
class PaginatedDataResult<T> {
  final List<T> data;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedDataResult({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}


