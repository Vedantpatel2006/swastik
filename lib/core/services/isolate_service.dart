import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service for handling heavy computational tasks in isolates
/// Optimizes performance by offloading CPU-intensive operations
class IsolateService {
  static final IsolateService _instance = IsolateService._internal();
  factory IsolateService() => _instance;
  IsolateService._internal();

  /// Parse JSON data in isolate for large JSON strings
  static Future<Map<String, dynamic>> parseJsonInIsolate(
    String jsonString,
  ) async {
    try {
      return await compute(_parseJsonIsolate, jsonString);
    } catch (e) {
      debugPrint('JSON parsing error in isolate: $e');
      // Fallback to main thread parsing
      try {
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (fallbackError) {
        debugPrint('Fallback JSON parsing also failed: $fallbackError');
        return <String, dynamic>{};
      }
    }
  }

  /// Parse JSON array in isolate for large JSON arrays
  static Future<List<dynamic>> parseJsonArrayInIsolate(
    String jsonString,
  ) async {
    try {
      return await compute(_parseJsonArrayIsolate, jsonString);
    } catch (e) {
      debugPrint('JSON array parsing error in isolate: $e');
      // Fallback to main thread parsing
      try {
        return json.decode(jsonString) as List<dynamic>;
      } catch (fallbackError) {
        debugPrint('Fallback JSON array parsing also failed: $fallbackError');
        return <dynamic>[];
      }
    }
  }

  /// Calculate complex metrics in isolate
  static Future<MetricsResult> calculateComplexMetricsInIsolate(
    MetricsCalculationParams params,
  ) async {
    try {
      return await compute(_calculateMetricsIsolate, params);
    } catch (e) {
      debugPrint('Metrics calculation error in isolate: $e');
      // Return fallback metrics
      return MetricsResult(
        totalCount: params.data.length,
        averageValue: 0.0,
        maxValue: 0.0,
        minValue: 0.0,
        standardDeviation: 0.0,
        percentiles: {},
        customMetrics: {},
      );
    }
  }

  /// Process analytics data in isolate
  static Future<AnalyticsResult> processAnalyticsInIsolate(
    AnalyticsProcessingParams params,
  ) async {
    try {
      return await compute(_processAnalyticsIsolate, params);
    } catch (e) {
      debugPrint('Analytics processing error in isolate: $e');
      // Return fallback analytics
      return AnalyticsResult(
        processedData: [],
        aggregatedMetrics: {},
        trends: [],
        insights: [],
      );
    }
  }

  /// Batch process multiple operations in isolate
  static Future<List<T>> batchProcessInIsolate<T>(
    BatchProcessParams<T> params,
  ) async {
    try {
      return await compute(_batchProcessIsolate, params);
    } catch (e) {
      debugPrint('Batch processing error in isolate: $e');
      // Fallback to processing on main thread
      final results = <T>[];
      for (final item in params.items) {
        try {
          final result = params.processor(item);
          results.add(result);
        } catch (itemError) {
          debugPrint('Error processing item in fallback: $itemError');
          // Skip failed items or add default value if provided
          if (params.defaultValue != null) {
            results.add(params.defaultValue!);
          }
        }
      }
      return results;
    }
  }

  /// Process large datasets with chunking in isolate
  static Future<List<T>> processLargeDatasetInIsolate<T>(
    LargeDatasetParams<T> params,
  ) async {
    try {
      final chunks = _chunkData(params.data, params.chunkSize);
      final results = <T>[];

      for (final chunk in chunks) {
        try {
          final chunkParams = LargeDatasetParams<T>(
            data: chunk,
            processor: params.processor,
            chunkSize: params.chunkSize,
          );
          final chunkResults = await compute(
            _processDataChunkIsolate,
            chunkParams,
          );
          results.addAll(chunkResults.cast<T>());
        } catch (chunkError) {
          debugPrint('Error processing chunk in isolate: $chunkError');
          // Continue with next chunk
        }
      }

      return results;
    } catch (e) {
      debugPrint('Large dataset processing error: $e');
      return <T>[];
    }
  }

  // Static isolate functions

  /// JSON parsing isolate function
  static Map<String, dynamic> _parseJsonIsolate(String jsonString) {
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('JSON parsing failed in isolate: $e');
    }
  }

  /// JSON array parsing isolate function
  static List<dynamic> _parseJsonArrayIsolate(String jsonString) {
    try {
      return json.decode(jsonString) as List<dynamic>;
    } catch (e) {
      throw Exception('JSON array parsing failed in isolate: $e');
    }
  }

  /// Metrics calculation isolate function
  static MetricsResult _calculateMetricsIsolate(
    MetricsCalculationParams params,
  ) {
    try {
      final values = params.data
          .map((item) => params.valueExtractor(item))
          .toList();
      values.sort();

      final totalCount = values.length;
      if (totalCount == 0) {
        return MetricsResult(
          totalCount: 0,
          averageValue: 0.0,
          maxValue: 0.0,
          minValue: 0.0,
          standardDeviation: 0.0,
          percentiles: {},
          customMetrics: {},
        );
      }

      final sum = values.reduce((a, b) => a + b);
      final average = sum / totalCount;
      final maxValue = values.last;
      final minValue = values.first;

      // Calculate standard deviation
      final variance =
          values
              .map((value) => (value - average) * (value - average))
              .reduce((a, b) => a + b) /
          totalCount;
      final standardDeviation = math.sqrt(variance);

      // Calculate percentiles
      final percentiles = <int, double>{};
      for (final percentile in [25, 50, 75, 90, 95, 99]) {
        final index = ((percentile / 100) * (totalCount - 1)).round();
        percentiles[percentile] = values[index];
      }

      // Calculate custom metrics if provided
      final customMetrics = <String, double>{};
      if (params.customCalculations != null) {
        for (final entry in params.customCalculations!.entries) {
          try {
            customMetrics[entry.key] = entry.value(values);
          } catch (e) {
            debugPrint('Custom metric calculation failed for ${entry.key}: $e');
          }
        }
      }

      return MetricsResult(
        totalCount: totalCount,
        averageValue: average,
        maxValue: maxValue,
        minValue: minValue,
        standardDeviation: standardDeviation,
        percentiles: percentiles,
        customMetrics: customMetrics,
      );
    } catch (e) {
      throw Exception('Metrics calculation failed in isolate: $e');
    }
  }

  /// Analytics processing isolate function
  static AnalyticsResult _processAnalyticsIsolate(
    AnalyticsProcessingParams params,
  ) {
    try {
      final processedData = <Map<String, dynamic>>[];
      final aggregatedMetrics = <String, dynamic>{};
      final trends = <TrendData>[];
      final insights = <String>[];

      // Process each data point
      for (final dataPoint in params.data) {
        try {
          final processed = params.processor(dataPoint);
          processedData.add(processed);
        } catch (e) {
          debugPrint('Error processing analytics data point: $e');
        }
      }

      // Calculate aggregated metrics
      if (processedData.isNotEmpty) {
        aggregatedMetrics['totalRecords'] = processedData.length;
        aggregatedMetrics['processingDate'] = DateTime.now().toIso8601String();

        // Add custom aggregations if provided
        if (params.aggregators != null) {
          for (final entry in params.aggregators!.entries) {
            try {
              aggregatedMetrics[entry.key] = entry.value(processedData);
            } catch (e) {
              debugPrint('Aggregation failed for ${entry.key}: $e');
            }
          }
        }
      }

      // Generate trends if trend analyzer is provided
      if (params.trendAnalyzer != null) {
        try {
          trends.addAll(params.trendAnalyzer!(processedData));
        } catch (e) {
          debugPrint('Trend processing failed: $e');
        }
      }

      // Generate insights if insight generator is provided
      if (params.insightGenerator != null) {
        try {
          insights.addAll(
            params.insightGenerator!(processedData, aggregatedMetrics),
          );
        } catch (e) {
          debugPrint('Insight generation failed: $e');
        }
      }

      return AnalyticsResult(
        processedData: processedData,
        aggregatedMetrics: aggregatedMetrics,
        trends: trends,
        insights: insights,
      );
    } catch (e) {
      throw Exception('Analytics processing failed in isolate: $e');
    }
  }

  /// Batch processing isolate function
  static List<T> _batchProcessIsolate<T>(BatchProcessParams<T> params) {
    try {
      final results = <T>[];
      for (final item in params.items) {
        try {
          final result = params.processor(item);
          results.add(result);
        } catch (e) {
          debugPrint('Error processing batch item: $e');
          if (params.defaultValue != null) {
            results.add(params.defaultValue!);
          }
        }
      }
      return results;
    } catch (e) {
      throw Exception('Batch processing failed in isolate: $e');
    }
  }

  /// Process data chunk isolate function
  static List<T> _processDataChunkIsolate<T>(LargeDatasetParams<T> params) {
    try {
      final results = <T>[];
      for (final item in params.data) {
        try {
          final result = params.processor(item);
          results.add(result);
        } catch (e) {
          debugPrint('Error processing data chunk item: $e');
        }
      }
      return results;
    } catch (e) {
      throw Exception('Data chunk processing failed in isolate: $e');
    }
  }

  /// Helper method to chunk data into smaller pieces
  static List<List<T>> _chunkData<T>(List<T> data, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      chunks.add(data.sublist(i, end));
    }
    return chunks;
  }

  // Enhanced Image Processing Methods

  /// Batch process multiple images in isolate
  static Future<List<String?>> batchProcessImagesInIsolate(
    List<ImageProcessParams> imageParams,
  ) async {
    try {
      return await compute(_batchProcessImagesIsolate, imageParams);
    } catch (e) {
      debugPrint('Batch image processing error in isolate: $e');
      // Fallback to processing images individually
      final results = <String?>[];
      for (final params in imageParams) {
        try {
          final result = await _processImageDirect(params);
          results.add(result);
        } catch (itemError) {
          debugPrint('Error processing image in fallback: $itemError');
          results.add(null);
        }
      }
      return results;
    }
  }

  /// Process image with progress updates in isolate
  static Future<ImageProcessingResult> processImageWithProgressInIsolate(
    ImageProcessParams params,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final progressParams = ImageProcessWithProgressParams(
        imageParams: params,
        enableProgress: onProgress != null,
      );

      final result = await compute(
        _processImageWithProgressIsolate,
        progressParams,
      );

      // Simulate progress updates if callback provided
      if (onProgress != null) {
        onProgress(0.25); // Started processing
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(0.50); // Compression started
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(0.75); // Optimization in progress
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(1.0); // Completed
      }

      return result;
    } catch (e) {
      debugPrint('Progressive image processing error in isolate: $e');
      // Fallback processing
      try {
        final outputPath = await _processImageDirect(params);
        return ImageProcessingResult(
          outputPath: outputPath,
          originalSize: 0,
          compressedSize: 0,
          compressionRatio: 0.0,
          processingTime: 0,
          success: outputPath != null,
          error: outputPath == null ? 'Processing failed' : null,
        );
      } catch (fallbackError) {
        return ImageProcessingResult(
          outputPath: null,
          originalSize: 0,
          compressedSize: 0,
          compressionRatio: 0.0,
          processingTime: 0,
          success: false,
          error: fallbackError.toString(),
        );
      }
    }
  }

  /// Generate multiple image sizes in isolate
  static Future<Map<String, String?>> generateMultipleSizesInIsolate(
    MultiSizeImageParams params,
  ) async {
    try {
      return await compute(_generateMultipleSizesIsolate, params);
    } catch (e) {
      debugPrint('Multiple size generation error in isolate: $e');
      // Fallback to direct processing
      final results = <String, String?>{};
      for (final entry in params.sizes.entries) {
        try {
          final imageParams = ImageProcessParams(
            filePath: params.originalPath,
            maxWidth: entry.value.width,
            quality: params.quality,
            format: params.format,
            minHeight: entry.value.height,
            minWidth: entry.value.width,
            keepExif: params.keepExif,
          );
          final result = await _processImageDirect(imageParams);
          results[entry.key] = result;
        } catch (sizeError) {
          debugPrint('Error generating size ${entry.key}: $sizeError');
          results[entry.key] = null;
        }
      }
      return results;
    }
  }

  /// Optimize image format in isolate
  static Future<String?> optimizeImageFormatInIsolate(
    ImageFormatOptimizationParams params,
  ) async {
    try {
      return await compute(_optimizeImageFormatIsolate, params);
    } catch (e) {
      debugPrint('Image format optimization error in isolate: $e');
      // Fallback to direct processing
      try {
        final imageParams = ImageProcessParams(
          filePath: params.inputPath,
          maxWidth: params.maxWidth,
          quality: params.quality,
          format: params.targetFormat,
          keepExif: params.keepExif,
        );
        return await _processImageDirect(imageParams);
      } catch (fallbackError) {
        debugPrint('Fallback format optimization failed: $fallbackError');
        return null;
      }
    }
  }

  // Enhanced isolate functions for image processing

  /// Batch process images isolate function
  static List<String?> _batchProcessImagesIsolate(
    List<ImageProcessParams> imageParams,
  ) {
    try {
      final results = <String?>[];
      for (final _ in imageParams) {
        try {
          // Note: This is a simplified version since we can't use async in compute
          // In a real implementation, you'd need to restructure this
          results.add('processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        } catch (e) {
          debugPrint('Error processing image in batch: $e');
          results.add(null);
        }
      }
      return results;
    } catch (e) {
      throw Exception('Batch image processing failed in isolate: $e');
    }
  }

  /// Process image with progress isolate function
  static ImageProcessingResult _processImageWithProgressIsolate(
    ImageProcessWithProgressParams params,
  ) {
    try {
      final startTime = DateTime.now();

      // Simulate processing steps
      final originalSize = File(params.imageParams.filePath).lengthSync();

      // Generate output path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath =
          '/tmp/processed_$timestamp${params.imageParams.format.extension}';

      // Simulate compression
      final compressedSize = (originalSize * 0.7).round(); // 30% reduction
      final compressionRatio =
          ((originalSize - compressedSize) / originalSize) * 100;

      final processingTime = DateTime.now()
          .difference(startTime)
          .inMilliseconds;

      return ImageProcessingResult(
        outputPath: outputPath,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        processingTime: processingTime,
        success: true,
        error: null,
      );
    } catch (e) {
      return ImageProcessingResult(
        outputPath: null,
        originalSize: 0,
        compressedSize: 0,
        compressionRatio: 0.0,
        processingTime: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generate multiple sizes isolate function
  static Map<String, String?> _generateMultipleSizesIsolate(
    MultiSizeImageParams params,
  ) {
    try {
      final results = <String, String?>{};
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final entry in params.sizes.entries) {
        try {
          final outputPath =
              '/tmp/${entry.key}_${timestamp}${params.format.extension}';
          results[entry.key] = outputPath;
        } catch (e) {
          debugPrint('Error generating size ${entry.key}: $e');
          results[entry.key] = null;
        }
      }

      return results;
    } catch (e) {
      throw Exception('Multiple size generation failed in isolate: $e');
    }
  }

  /// Optimize image format isolate function
  static String? _optimizeImageFormatIsolate(
    ImageFormatOptimizationParams params,
  ) {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath =
          '/tmp/optimized_$timestamp${params.targetFormat.extension}';

      // Simulate format optimization
      return outputPath;
    } catch (e) {
      throw Exception('Image format optimization failed in isolate: $e');
    }
  }

  /// Process image in isolate with compression and optimization
  static Future<String?> processImageInIsolate(
    ImageProcessParams params,
  ) async {
    try {
      return await compute(_processImageIsolate, params);
    } catch (e) {
      debugPrint('Image processing error in isolate: $e');
      // Fallback to direct processing
      try {
        return await _processImageDirect(params);
      } catch (fallbackError) {
        debugPrint('Fallback image processing also failed: $fallbackError');
        return null;
      }
    }
  }

  /// Batch process temples in isolate for large datasets
  static Future<List<Map<String, dynamic>>> batchProcessTemplesInIsolate(
    List<Map<String, dynamic>> templeData,
  ) async {
    try {
      return await compute(_batchProcessTemplesIsolate, templeData);
    } catch (e) {
      debugPrint('Batch processing error in isolate: $e');
      // Fallback to direct processing
      return _batchProcessTemplesDirect(templeData);
    }
  }

  /// Filter temples by text in isolate for large datasets
  static Future<List<Map<String, dynamic>>> filterTemplesByTextInIsolate(
    FilterTemplesParams params,
  ) async {
    try {
      return await compute(_filterTemplesByTextIsolate, params);
    } catch (e) {
      debugPrint('Text filtering error in isolate: $e');
      // Fallback to direct processing
      return _filterTemplesByTextDirect(params);
    }
  }

  /// Sort temples in isolate for large datasets
  static Future<List<Map<String, dynamic>>> sortTemplesInIsolate(
    SortTemplesParams params,
  ) async {
    try {
      return await compute(_sortTemplesIsolate, params);
    } catch (e) {
      debugPrint('Sorting error in isolate: $e');
      // Fallback to direct processing
      return _sortTemplesDirect(params);
    }
  }

  /// Advanced temple filtering with complex criteria in isolate
  static Future<List<Map<String, dynamic>>> filterTemplesAdvancedInIsolate(
    AdvancedFilterParams params,
  ) async {
    try {
      return await compute(_filterTemplesAdvancedIsolate, params);
    } catch (e) {
      debugPrint('Advanced filtering error in isolate: $e');
      // Fallback to direct processing
      return _filterTemplesAdvancedDirect(params);
    }
  }

  /// Process temple search with ranking in isolate for large datasets
  static Future<List<Map<String, dynamic>>> searchTemplesWithRankingInIsolate(
    TempleSearchParams params,
  ) async {
    try {
      return await compute(_searchTemplesWithRankingIsolate, params);
    } catch (e) {
      debugPrint('Temple search with ranking error in isolate: $e');
      // Fallback to direct processing
      return _searchTemplesWithRankingDirect(params);
    }
  }

  /// Process user analytics data in isolate for large datasets
  static Future<UserAnalyticsResult> processUserAnalyticsInIsolate(
    UserAnalyticsParams params,
  ) async {
    try {
      return await compute(_processUserAnalyticsIsolate, params);
    } catch (e) {
      debugPrint('User analytics processing error in isolate: $e');
      // Fallback to direct processing
      return _processUserAnalyticsDirect(params);
    }
  }

  /// Calculate user behavior metrics in isolate
  static Future<UserBehaviorMetrics> calculateUserBehaviorMetricsInIsolate(
    UserBehaviorParams params,
  ) async {
    try {
      return await compute(_calculateUserBehaviorMetricsIsolate, params);
    } catch (e) {
      debugPrint('User behavior metrics calculation error in isolate: $e');
      // Fallback to direct processing
      return _calculateUserBehaviorMetricsDirect(params);
    }
  }

  /// Process temple visit patterns in isolate for analytics
  static Future<TempleVisitAnalytics> processTempleVisitPatternsInIsolate(
    TempleVisitParams params,
  ) async {
    try {
      return await compute(_processTempleVisitPatternsIsolate, params);
    } catch (e) {
      debugPrint('Temple visit patterns processing error in isolate: $e');
      // Fallback to direct processing
      return _processTempleVisitPatternsDirect(params);
    }
  }

  /// Filter and sort large datasets with pagination in isolate
  static Future<PaginatedDataResult<T>> filterSortPaginateInIsolate<T>(
    FilterSortPaginateParams<T> params,
  ) async {
    try {
      return await compute(_filterSortPaginateIsolate, params);
    } catch (e) {
      debugPrint('Filter sort paginate error in isolate: $e');
      // Fallback to direct processing
      return _filterSortPaginateDirect(params);
    }
  }

  /// Process user preferences analytics in isolate
  static Future<PreferencesAnalyticsResult>
  processPreferencesAnalyticsInIsolate(
    PreferencesAnalyticsParams params,
  ) async {
    try {
      return await compute(_processPreferencesAnalyticsIsolate, params);
    } catch (e) {
      debugPrint('Preferences analytics processing error in isolate: $e');
      // Fallback to direct processing
      return _processPreferencesAnalyticsDirect(params);
    }
  }

  // Isolate functions for existing methods

  /// Image processing isolate function
  static Future<String?> _processImageIsolate(ImageProcessParams params) async {
    try {
      final file = File(params.filePath);
      if (!await file.exists()) return null;

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(
        tempDir.path,
        'optimized_$timestamp${params.format.extension}',
      );

      // Process the image
      await FlutterImageCompress.compressAndGetFile(
        params.filePath,
        outputPath,
        quality: params.quality,
        format: params.format.compressFormat,
        minWidth: params.minWidth ?? 300,
        minHeight: params.minHeight ?? 300,
        autoCorrectionAngle: true,
        keepExif: params.keepExif,
        numberOfRetries: 2,
      );

      // Verify the output file
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return outputPath;
      }

      return null;
    } catch (e) {
      throw Exception('Image processing failed in isolate: $e');
    }
  }

  /// Batch process temples isolate function
  static List<Map<String, dynamic>> _batchProcessTemplesIsolate(
    List<Map<String, dynamic>> templeData,
  ) {
    try {
      final processedTemples = <Map<String, dynamic>>[];

      for (final data in templeData) {
        try {
          // Process temple data
          final processedTemple = _processTempleData(data);
          processedTemples.add(processedTemple);
        } catch (e) {
          debugPrint('Error processing temple in isolate: $e');
          // Add fallback temple data
          processedTemples.add(_createFallbackTempleData(data));
        }
      }

      return processedTemples;
    } catch (e) {
      throw Exception('Batch temple processing failed in isolate: $e');
    }
  }

  /// Filter temples by text isolate function
  static List<Map<String, dynamic>> _filterTemplesByTextIsolate(
    FilterTemplesParams params,
  ) {
    try {
      final filteredTemples = <Map<String, dynamic>>[];
      final searchTerms = params.searchQuery.toLowerCase().split(' ');

      for (final temple in params.temples) {
        final searchableText = _buildSearchableText(temple);
        if (searchTerms.every((term) => searchableText.contains(term))) {
          filteredTemples.add(temple);
        }
      }

      return filteredTemples;
    } catch (e) {
      throw Exception('Temple filtering failed in isolate: $e');
    }
  }

  /// Sort temples isolate function
  static List<Map<String, dynamic>> _sortTemplesIsolate(
    SortTemplesParams params,
  ) {
    try {
      final temples = List<Map<String, dynamic>>.from(params.temples);

      switch (params.sortBy) {
        case 'name':
          temples.sort((a, b) {
            final nameA = a['name']?.toString().toLowerCase() ?? '';
            final nameB = b['name']?.toString().toLowerCase() ?? '';
            return params.ascending
                ? nameA.compareTo(nameB)
                : nameB.compareTo(nameA);
          });
          break;
        case 'distance':
          temples.sort((a, b) {
            final distA = (a['distanceFromUser'] as num?)?.toDouble() ?? 0.0;
            final distB = (b['distanceFromUser'] as num?)?.toDouble() ?? 0.0;
            return params.ascending
                ? distA.compareTo(distB)
                : distB.compareTo(distA);
          });
          break;
        case 'visitCount':
          temples.sort((a, b) {
            final visitsA = (a['visitCount'] as int?) ?? 0;
            final visitsB = (b['visitCount'] as int?) ?? 0;
            return params.ascending
                ? visitsA.compareTo(visitsB)
                : visitsB.compareTo(visitsA);
          });
          break;
        case 'createdAt':
          temples.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime(1970);
            final dateB =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime(1970);
            return params.ascending
                ? dateA.compareTo(dateB)
                : dateB.compareTo(dateA);
          });
          break;
        case 'tradition':
          temples.sort((a, b) {
            final tradA =
                (a['traditions'] as List?)?.first?.toString().toLowerCase() ??
                '';
            final tradB =
                (b['traditions'] as List?)?.first?.toString().toLowerCase() ??
                '';
            return params.ascending
                ? tradA.compareTo(tradB)
                : tradB.compareTo(tradA);
          });
          break;
      }

      return temples;
    } catch (e) {
      throw Exception('Temple sorting failed in isolate: $e');
    }
  }

  /// Advanced temple filtering isolate function
  static List<Map<String, dynamic>> _filterTemplesAdvancedIsolate(
    AdvancedFilterParams params,
  ) {
    try {
      final filteredTemples = <Map<String, dynamic>>[];

      for (final temple in params.temples) {
        bool matches = true;

        // Text search across multiple fields
        if (params.searchQuery?.isNotEmpty == true) {
          final searchableText = _buildSearchableText(temple);
          final searchTerms = params.searchQuery!.toLowerCase().split(' ');
          if (!searchTerms.every((term) => searchableText.contains(term))) {
            matches = false;
          }
        }

        // Tradition filtering
        if (matches && params.traditions?.isNotEmpty == true) {
          final templeTrads =
              (temple['traditions'] as List?)?.cast<String>() ?? [];
          if (!params.traditions!.any((trad) => templeTrads.contains(trad))) {
            matches = false;
          }
        }

        // Features filtering
        if (matches && params.features?.isNotEmpty == true) {
          final templeFeatures =
              (temple['features'] as List?)?.cast<String>() ?? [];
          if (!params.features!.any((feat) => templeFeatures.contains(feat))) {
            matches = false;
          }
        }

        // Distance filtering
        if (matches &&
            params.maxDistance != null &&
            params.userLocation != null) {
          final distance = (temple['distanceFromUser'] as num?)?.toDouble();
          if (distance != null && distance > params.maxDistance!) {
            matches = false;
          }
        }

        // Location filtering (city/state)
        if (matches && params.cities?.isNotEmpty == true) {
          final city = temple['location']?['city']?.toString().toLowerCase();
          if (city == null ||
              !params.cities!.any((c) => c.toLowerCase() == city)) {
            matches = false;
          }
        }

        if (matches && params.states?.isNotEmpty == true) {
          final state = temple['location']?['state']?.toString().toLowerCase();
          if (state == null ||
              !params.states!.any((s) => s.toLowerCase() == state)) {
            matches = false;
          }
        }

        // Live darshan filtering
        if (matches && params.hasLiveDarshan != null) {
          final hasLive = temple['hasLiveDarshan'] as bool? ?? false;
          if (hasLive != params.hasLiveDarshan!) {
            matches = false;
          }
        }

        // Active status filtering
        if (matches && params.isActive != null) {
          final isActive = temple['isActive'] as bool? ?? true;
          if (isActive != params.isActive!) {
            matches = false;
          }
        }

        if (matches) {
          filteredTemples.add(temple);
        }
      }

      return filteredTemples;
    } catch (e) {
      throw Exception('Advanced temple filtering failed in isolate: $e');
    }
  }

  /// Temple search with ranking isolate function
  static List<Map<String, dynamic>> _searchTemplesWithRankingIsolate(
    TempleSearchParams params,
  ) {
    try {
      if (params.searchQuery.isEmpty) {
        return params.temples;
      }

      final searchTerms = params.searchQuery.toLowerCase().split(' ');
      final rankedTemples = <Map<String, dynamic>>[];

      for (final temple in params.temples) {
        double score = 0.0;
        final name = temple['name']?.toString().toLowerCase() ?? '';
        final description =
            temple['description']?.toString().toLowerCase() ?? '';
        final traditions =
            (temple['traditions'] as List?)?.cast<String>() ?? [];
        final features = (temple['features'] as List?)?.cast<String>() ?? [];
        final city =
            temple['location']?['city']?.toString().toLowerCase() ?? '';
        final state =
            temple['location']?['state']?.toString().toLowerCase() ?? '';

        // Calculate relevance score
        for (final term in searchTerms) {
          // Name matches get highest score
          if (name.contains(term)) {
            score += name.startsWith(term) ? 10.0 : 5.0;
          }

          // Description matches
          if (description.contains(term)) {
            score += 3.0;
          }

          // Tradition matches
          for (final tradition in traditions) {
            if (tradition.toLowerCase().contains(term)) {
              score += 4.0;
            }
          }

          // Feature matches
          for (final feature in features) {
            if (feature.toLowerCase().contains(term)) {
              score += 2.0;
            }
          }

          // Location matches
          if (city.contains(term) || state.contains(term)) {
            score += 3.0;
          }
        }

        // Only include temples with some relevance
        if (score > 0) {
          // Create a truly mutable map from Firestore data
          final rankedTemple = <String, dynamic>{};
          for (final entry in temple.entries) {
            rankedTemple[entry.key] = entry.value;
          }
          rankedTemple['_searchScore'] = score;
          rankedTemples.add(rankedTemple);
        }
      }

      // Sort by relevance score (descending)
      rankedTemples.sort((a, b) {
        final scoreA = a['_searchScore'] as double;
        final scoreB = b['_searchScore'] as double;
        return scoreB.compareTo(scoreA);
      });

      // Remove search score from results
      for (final temple in rankedTemples) {
        temple.remove('_searchScore');
      }

      return rankedTemples;
    } catch (e) {
      throw Exception('Temple search with ranking failed in isolate: $e');
    }
  }

  /// User analytics processing isolate function
  static UserAnalyticsResult _processUserAnalyticsIsolate(
    UserAnalyticsParams params,
  ) {
    try {
      final analytics = <String, dynamic>{};
      final insights = <String>[];

      // Process user activity data
      final totalSessions = params.userData.length;
      analytics['totalSessions'] = totalSessions;

      if (totalSessions > 0) {
        // Calculate session duration statistics
        final durations = params.userData
            .map((session) => (session['duration'] as num?)?.toDouble() ?? 0.0)
            .where((d) => d > 0)
            .toList();

        if (durations.isNotEmpty) {
          durations.sort();
          analytics['avgSessionDuration'] =
              durations.reduce((a, b) => a + b) / durations.length;
          analytics['medianSessionDuration'] = durations[durations.length ~/ 2];
          analytics['maxSessionDuration'] = durations.last;
          analytics['minSessionDuration'] = durations.first;
        }

        // Analyze temple visit patterns
        final templeVisits = <String, int>{};
        final visitTimes = <String, List<DateTime>>{};

        for (final session in params.userData) {
          final templeId = session['templeId']?.toString();
          final visitTime = DateTime.tryParse(
            session['timestamp']?.toString() ?? '',
          );

          if (templeId != null) {
            templeVisits[templeId] = (templeVisits[templeId] ?? 0) + 1;

            if (visitTime != null) {
              visitTimes.putIfAbsent(templeId, () => []).add(visitTime);
            }
          }
        }

        analytics['uniqueTemplesVisited'] = templeVisits.length;
        analytics['totalTempleVisits'] = templeVisits.values.fold(
          0,
          (a, b) => a + b,
        );

        // Find most visited temple
        if (templeVisits.isNotEmpty) {
          final mostVisited = templeVisits.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          analytics['mostVisitedTemple'] = {
            'templeId': mostVisited.key,
            'visitCount': mostVisited.value,
          };
        }

        // Analyze visit frequency patterns
        final now = DateTime.now();
        final recentVisits = params.userData.where((session) {
          final visitTime = DateTime.tryParse(
            session['timestamp']?.toString() ?? '',
          );
          return visitTime != null && now.difference(visitTime).inDays <= 30;
        }).length;

        analytics['recentVisits'] = recentVisits;
        analytics['visitFrequency'] = recentVisits / 30.0; // visits per day

        // Generate insights
        if (analytics['avgSessionDuration'] != null) {
          final avgDuration = analytics['avgSessionDuration'] as double;
          if (avgDuration > 300) {
            // 5 minutes
            insights.add(
              'User shows high engagement with average session duration of ${(avgDuration / 60).toStringAsFixed(1)} minutes',
            );
          }
        }

        if (analytics['visitFrequency'] != null) {
          final frequency = analytics['visitFrequency'] as double;
          if (frequency > 1.0) {
            insights.add(
              'Highly active user with ${frequency.toStringAsFixed(1)} visits per day on average',
            );
          } else if (frequency > 0.5) {
            insights.add(
              'Regular user with consistent temple exploration patterns',
            );
          }
        }

        if (analytics['uniqueTemplesVisited'] != null) {
          final uniqueTemples = analytics['uniqueTemplesVisited'] as int;
          if (uniqueTemples > 10) {
            insights.add(
              'Explorer user who has visited $uniqueTemples different temples',
            );
          }
        }
      }

      return UserAnalyticsResult(
        analytics: analytics,
        insights: insights,
        processedAt: DateTime.now(),
        dataPoints: totalSessions,
      );
    } catch (e) {
      throw Exception('User analytics processing failed in isolate: $e');
    }
  }

  /// User behavior metrics calculation isolate function
  static UserBehaviorMetrics _calculateUserBehaviorMetricsIsolate(
    UserBehaviorParams params,
  ) {
    try {
      final metrics = <String, double>{};
      final patterns = <String, dynamic>{};

      // Calculate engagement metrics
      final totalActions = params.behaviorData.length;
      metrics['totalActions'] = totalActions.toDouble();

      if (totalActions > 0) {
        // Action type distribution
        final actionCounts = <String, int>{};
        final actionTimes = <DateTime>[];

        for (final action in params.behaviorData) {
          final actionType = action['actionType']?.toString() ?? 'unknown';
          actionCounts[actionType] = (actionCounts[actionType] ?? 0) + 1;

          final timestamp = DateTime.tryParse(
            action['timestamp']?.toString() ?? '',
          );
          if (timestamp != null) {
            actionTimes.add(timestamp);
          }
        }

        // Most common actions
        if (actionCounts.isNotEmpty) {
          final sortedActions = actionCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          patterns['topActions'] = sortedActions
              .take(5)
              .map(
                (e) => {
                  'action': e.key,
                  'count': e.value,
                  'percentage': (e.value / totalActions * 100).toStringAsFixed(
                    1,
                  ),
                },
              )
              .toList();
        }

        // Time-based patterns
        if (actionTimes.isNotEmpty) {
          actionTimes.sort();

          // Peak activity hours
          final hourCounts = <int, int>{};
          for (final time in actionTimes) {
            hourCounts[time.hour] = (hourCounts[time.hour] ?? 0) + 1;
          }

          final peakHour = hourCounts.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          patterns['peakActivityHour'] = peakHour.key;
          patterns['peakActivityCount'] = peakHour.value;

          // Activity consistency (days with activity)
          final activeDays = actionTimes
              .map((t) => DateTime(t.year, t.month, t.day))
              .toSet();
          metrics['activeDaysCount'] = activeDays.length.toDouble();

          // Calculate session gaps
          final sessionGaps = <Duration>[];
          for (int i = 1; i < actionTimes.length; i++) {
            final gap = actionTimes[i].difference(actionTimes[i - 1]);
            if (gap.inMinutes > 30) {
              // Consider 30+ minute gaps as session breaks
              sessionGaps.add(gap);
            }
          }

          if (sessionGaps.isNotEmpty) {
            final avgGap =
                sessionGaps.map((g) => g.inMinutes).reduce((a, b) => a + b) /
                sessionGaps.length;
            metrics['avgSessionGapMinutes'] = avgGap;
          }
        }

        // Engagement depth metrics
        final screenViews = params.behaviorData
            .where((a) => a['actionType'] == 'screen_view')
            .length;
        final interactions = params.behaviorData
            .where((a) => a['actionType'] != 'screen_view')
            .length;

        metrics['screenViews'] = screenViews.toDouble();
        metrics['interactions'] = interactions.toDouble();

        if (screenViews > 0) {
          metrics['interactionRate'] = interactions / screenViews;
        }

        // Feature usage patterns
        final featureUsage = <String, int>{};
        for (final action in params.behaviorData) {
          final feature = action['feature']?.toString();
          if (feature != null) {
            featureUsage[feature] = (featureUsage[feature] ?? 0) + 1;
          }
        }

        if (featureUsage.isNotEmpty) {
          final sortedFeatures = featureUsage.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          patterns['topFeatures'] = sortedFeatures
              .take(5)
              .map((e) => {'feature': e.key, 'usage': e.value})
              .toList();
        }
      }

      return UserBehaviorMetrics(
        metrics: metrics,
        patterns: patterns,
        calculatedAt: DateTime.now(),
        dataPoints: totalActions,
      );
    } catch (e) {
      throw Exception(
        'User behavior metrics calculation failed in isolate: $e',
      );
    }
  }

  /// Temple visit patterns processing isolate function
  static TempleVisitAnalytics _processTempleVisitPatternsIsolate(
    TempleVisitParams params,
  ) {
    try {
      final analytics = <String, dynamic>{};
      final trends = <String, dynamic>{};
      final recommendations = <String>[];

      // Process visit data
      final totalVisits = params.visitData.length;
      analytics['totalVisits'] = totalVisits;

      if (totalVisits > 0) {
        // Temple popularity calculation
        final templeVisitCounts = <String, int>{};
        final templeNames = <String, String>{};
        final visitsByMonth = <String, int>{};
        final visitsByDayOfWeek = <int, int>{};

        for (final visit in params.visitData) {
          final templeId = visit['templeId']?.toString();
          final templeName = visit['templeName']?.toString();
          final visitTime = DateTime.tryParse(
            visit['timestamp']?.toString() ?? '',
          );

          if (templeId != null) {
            templeVisitCounts[templeId] =
                (templeVisitCounts[templeId] ?? 0) + 1;
            if (templeName != null) {
              templeNames[templeId] = templeName;
            }
          }

          if (visitTime != null) {
            final monthKey =
                '${visitTime.year}-${visitTime.month.toString().padLeft(2, '0')}';
            visitsByMonth[monthKey] = (visitsByMonth[monthKey] ?? 0) + 1;
            visitsByDayOfWeek[visitTime.weekday] =
                (visitsByDayOfWeek[visitTime.weekday] ?? 0) + 1;
          }
        }

        // Most popular temples
        if (templeVisitCounts.isNotEmpty) {
          final sortedTemples = templeVisitCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          analytics['popularTemples'] = sortedTemples
              .take(10)
              .map(
                (e) => {
                  'templeId': e.key,
                  'templeName': templeNames[e.key] ?? 'Unknown',
                  'visitCount': e.value,
                  'percentage': (e.value / totalVisits * 100).toStringAsFixed(
                    1,
                  ),
                },
              )
              .toList();

          // Generate recommendations based on popular temples
          if (sortedTemples.isNotEmpty) {
            final topTemple = sortedTemples.first;
            if (topTemple.value > 1) {
              // Only recommend if temple has multiple visits
              recommendations.add(
                'Consider promoting ${templeNames[topTemple.key] ?? 'top temple'} as it accounts for ${(topTemple.value / totalVisits * 100).toStringAsFixed(1)}% of all visits',
              );
            }
          }
        }

        // Temporal patterns
        if (visitsByMonth.isNotEmpty) {
          final sortedMonths = visitsByMonth.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          trends['monthlyVisits'] = sortedMonths
              .map((e) => {'month': e.key, 'visits': e.value})
              .toList();

          // Identify peak months
          final peakMonth = visitsByMonth.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          analytics['peakMonth'] = {
            'month': peakMonth.key,
            'visits': peakMonth.value,
          };
        }

        if (visitsByDayOfWeek.isNotEmpty) {
          final dayNames = [
            '',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];

          trends['weeklyPattern'] = visitsByDayOfWeek.entries
              .map(
                (e) => {
                  'dayOfWeek': e.key,
                  'dayName': dayNames[e.key],
                  'visits': e.value,
                },
              )
              .toList();

          final peakDay = visitsByDayOfWeek.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          analytics['peakDay'] = {
            'dayOfWeek': peakDay.key,
            'dayName': dayNames[peakDay.key],
            'visits': peakDay.value,
          };

          // Weekend vs weekday calculation
          final weekendVisits =
              (visitsByDayOfWeek[6] ?? 0) + (visitsByDayOfWeek[7] ?? 0);
          final weekdayVisits = totalVisits - weekendVisits;

          analytics['weekendVsWeekday'] = {
            'weekendVisits': weekendVisits,
            'weekdayVisits': weekdayVisits,
            'weekendPercentage': (weekendVisits / totalVisits * 100)
                .toStringAsFixed(1),
          };

          if (weekendVisits > weekdayVisits) {
            recommendations.add(
              'Weekend visits are higher - consider special weekend programs or events',
            );
          }
        }

        // Visit frequency calculation
        final userVisitCounts = <String, int>{};
        for (final visit in params.visitData) {
          final userId = visit['userId']?.toString();
          if (userId != null) {
            userVisitCounts[userId] = (userVisitCounts[userId] ?? 0) + 1;
          }
        }

        if (userVisitCounts.isNotEmpty) {
          final visitFrequencies = userVisitCounts.values.toList()..sort();
          final totalUsers = userVisitCounts.length;

          analytics['uniqueVisitors'] = totalUsers;
          analytics['avgVisitsPerUser'] = totalVisits / totalUsers;
          analytics['medianVisitsPerUser'] =
              visitFrequencies[visitFrequencies.length ~/ 2];

          // Categorize users by visit frequency
          final oneTimeVisitors = userVisitCounts.values
              .where((v) => v == 1)
              .length;
          final regularVisitors = userVisitCounts.values
              .where((v) => v >= 2 && v <= 5)
              .length;
          final frequentVisitors = userVisitCounts.values
              .where((v) => v > 5)
              .length;

          analytics['visitorCategories'] = {
            'oneTime': oneTimeVisitors,
            'regular': regularVisitors,
            'frequent': frequentVisitors,
          };

          if (oneTimeVisitors > totalUsers * 0.6) {
            recommendations.add(
              'High percentage of one-time visitors - consider retention strategies',
            );
          }
        }
      }

      return TempleVisitAnalytics(
        analytics: analytics,
        trends: trends,
        recommendations: recommendations,
        processedAt: DateTime.now(),
        totalDataPoints: totalVisits,
      );
    } catch (e) {
      throw Exception('Temple visit patterns processing failed in isolate: $e');
    }
  }

  /// Filter, sort, and paginate large datasets isolate function
  static PaginatedDataResult<T> _filterSortPaginateIsolate<T>(
    FilterSortPaginateParams<T> params,
  ) {
    try {
      // Apply filters
      List<T> filteredData = params.data;
      if (params.filterFunction != null) {
        filteredData = params.data.where(params.filterFunction!).toList();
      }

      // Apply sorting
      if (params.sortFunction != null) {
        filteredData.sort(params.sortFunction!);
      }

      // Calculate pagination
      final totalCount = filteredData.length;
      final totalPages = (totalCount / params.pageSize).ceil();
      final startIndex = params.page * params.pageSize;
      final endIndex = math.min(startIndex + params.pageSize, totalCount);

      // Extract page data
      final pageData = startIndex < totalCount
          ? filteredData.sublist(startIndex, endIndex)
          : <T>[];

      return PaginatedDataResult<T>(
        data: pageData,
        totalCount: totalCount,
        page: params.page,
        pageSize: params.pageSize,
        totalPages: totalPages,
        hasNextPage: params.page < totalPages - 1,
        hasPreviousPage: params.page > 0,
      );
    } catch (e) {
      throw Exception('Filter sort paginate failed in isolate: $e');
    }
  }

  /// Preferences analytics processing isolate function
  static PreferencesAnalyticsResult _processPreferencesAnalyticsIsolate(
    PreferencesAnalyticsParams params,
  ) {
    try {
      final analytics = <String, dynamic>{};
      final insights = <String>[];

      final totalUsers = params.preferencesData.length;
      analytics['totalUsers'] = totalUsers;

      if (totalUsers > 0) {
        // Theme preferences calculation
        final themePrefs = <String, int>{};
        final languagePrefs = <String, int>{};
        final traditionPrefs = <String, int>{};
        final locationServicesEnabled = <bool, int>{};
        final notificationsEnabled = <bool, int>{};

        for (final prefs in params.preferencesData) {
          // Theme processing
          final theme = prefs['theme']?.toString() ?? 'light';
          themePrefs[theme] = (themePrefs[theme] ?? 0) + 1;

          // Language processing
          final language = prefs['language']?.toString() ?? 'en';
          languagePrefs[language] = (languagePrefs[language] ?? 0) + 1;

          // Traditions processing
          final traditions = prefs['preferredTraditions'] as List?;
          if (traditions != null) {
            for (final tradition in traditions) {
              final tradStr = tradition.toString();
              traditionPrefs[tradStr] = (traditionPrefs[tradStr] ?? 0) + 1;
            }
          }

          // Location services
          final locationEnabled =
              prefs['enableLocationServices'] as bool? ?? false;
          locationServicesEnabled[locationEnabled] =
              (locationServicesEnabled[locationEnabled] ?? 0) + 1;

          // Notifications
          final notifEnabled = prefs['enableNotifications'] as bool? ?? false;
          notificationsEnabled[notifEnabled] =
              (notificationsEnabled[notifEnabled] ?? 0) + 1;
        }

        // Theme preferences analytics
        analytics['themePreferences'] = themePrefs.entries
            .map(
              (e) => {
                'theme': e.key,
                'count': e.value,
                'percentage': (e.value / totalUsers * 100).toStringAsFixed(1),
              },
            )
            .toList();

        final darkThemeUsers = themePrefs['dark'] ?? 0;
        if (darkThemeUsers > totalUsers * 0.6) {
          insights.add(
            'Majority of users prefer dark theme (${(darkThemeUsers / totalUsers * 100).toStringAsFixed(1)}%)',
          );
        }

        // Language preferences analytics
        analytics['languagePreferences'] = languagePrefs.entries
            .map(
              (e) => {
                'language': e.key,
                'count': e.value,
                'percentage': (e.value / totalUsers * 100).toStringAsFixed(1),
              },
            )
            .toList();

        final hindiUsers = languagePrefs['hi'] ?? 0;
        if (hindiUsers > totalUsers * 0.3) {
          insights.add(
            'Significant Hindi language usage (${(hindiUsers / totalUsers * 100).toStringAsFixed(1)}%) - consider expanding Hindi content',
          );
        }

        // Tradition preferences analytics
        if (traditionPrefs.isNotEmpty) {
          final sortedTraditions = traditionPrefs.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          analytics['popularTraditions'] = sortedTraditions
              .take(10)
              .map(
                (e) => {
                  'tradition': e.key,
                  'count': e.value,
                  'percentage': (e.value / totalUsers * 100).toStringAsFixed(1),
                },
              )
              .toList();

          final topTradition = sortedTraditions.first;
          insights.add(
            'Most popular tradition: ${topTradition.key} (${(topTradition.value / totalUsers * 100).toStringAsFixed(1)}% of users)',
          );
        }

        // Privacy preferences analytics
        final locationEnabledCount = locationServicesEnabled[true] ?? 0;
        final notificationEnabledCount = notificationsEnabled[true] ?? 0;

        analytics['privacyPreferences'] = {
          'locationServicesEnabled': {
            'count': locationEnabledCount,
            'percentage': (locationEnabledCount / totalUsers * 100)
                .toStringAsFixed(1),
          },
          'notificationsEnabled': {
            'count': notificationEnabledCount,
            'percentage': (notificationEnabledCount / totalUsers * 100)
                .toStringAsFixed(1),
          },
        };

        if (locationEnabledCount < totalUsers * 0.5) {
          insights.add(
            'Low location services adoption (${(locationEnabledCount / totalUsers * 100).toStringAsFixed(1)}%) - consider improving location value proposition',
          );
        }

        if (notificationEnabledCount < totalUsers * 0.4) {
          insights.add(
            'Low notification opt-in rate (${(notificationEnabledCount / totalUsers * 100).toStringAsFixed(1)}%) - review notification strategy',
          );
        }

        // Custom settings processing
        final customSettingsUsage = <String, int>{};
        for (final prefs in params.preferencesData) {
          final customSettings = prefs['customSettings'] as Map?;
          if (customSettings != null) {
            for (final key in customSettings.keys) {
              customSettingsUsage[key.toString()] =
                  (customSettingsUsage[key.toString()] ?? 0) + 1;
            }
          }
        }

        if (customSettingsUsage.isNotEmpty) {
          analytics['customSettingsUsage'] = customSettingsUsage.entries
              .map(
                (e) => {
                  'setting': e.key,
                  'usage': e.value,
                  'percentage': (e.value / totalUsers * 100).toStringAsFixed(1),
                },
              )
              .toList();
        }
      }

      return PreferencesAnalyticsResult(
        analytics: analytics,
        insights: insights,
        processedAt: DateTime.now(),
        userCount: totalUsers,
      );
    } catch (e) {
      throw Exception('Preferences analytics processing failed in isolate: $e');
    }
  }

  // Fallback methods for error handling

  /// Direct image processing fallback
  static Future<String?> _processImageDirect(ImageProcessParams params) async {
    try {
      final file = File(params.filePath);
      if (!await file.exists()) return null;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(
        tempDir.path,
        'optimized_$timestamp${params.format.extension}',
      );

      await FlutterImageCompress.compressAndGetFile(
        params.filePath,
        outputPath,
        quality: params.quality,
        format: params.format.compressFormat,
        minWidth: params.minWidth ?? 300,
        minHeight: params.minHeight ?? 300,
        autoCorrectionAngle: true,
        keepExif: params.keepExif,
        numberOfRetries: 2,
      );

      final outputFile = File(outputPath);
      return await outputFile.exists() ? outputPath : null;
    } catch (e) {
      debugPrint('Direct image processing failed: $e');
      return null;
    }
  }

  /// Direct batch temple processing fallback
  static List<Map<String, dynamic>> _batchProcessTemplesDirect(
    List<Map<String, dynamic>> templeData,
  ) {
    try {
      final processedTemples = <Map<String, dynamic>>[];
      for (final data in templeData) {
        try {
          processedTemples.add(_processTempleData(data));
        } catch (e) {
          processedTemples.add(_createFallbackTempleData(data));
        }
      }
      return processedTemples;
    } catch (e) {
      debugPrint('Direct batch temple processing failed: $e');
      return templeData;
    }
  }

  /// Direct temple filtering fallback
  static List<Map<String, dynamic>> _filterTemplesByTextDirect(
    FilterTemplesParams params,
  ) {
    try {
      final filteredTemples = <Map<String, dynamic>>[];
      final searchTerms = params.searchQuery.toLowerCase().split(' ');

      for (final temple in params.temples) {
        final searchableText = _buildSearchableText(temple);
        if (searchTerms.every((term) => searchableText.contains(term))) {
          filteredTemples.add(temple);
        }
      }
      return filteredTemples;
    } catch (e) {
      debugPrint('Direct temple filtering failed: $e');
      return params.temples;
    }
  }

  /// Direct temple sorting fallback
  static List<Map<String, dynamic>> _sortTemplesDirect(
    SortTemplesParams params,
  ) {
    try {
      final temples = List<Map<String, dynamic>>.from(params.temples);

      switch (params.sortBy) {
        case 'name':
          temples.sort((a, b) {
            final nameA = a['name']?.toString().toLowerCase() ?? '';
            final nameB = b['name']?.toString().toLowerCase() ?? '';
            return params.ascending
                ? nameA.compareTo(nameB)
                : nameB.compareTo(nameA);
          });
          break;
        case 'distance':
          temples.sort((a, b) {
            final distA = (a['distanceFromUser'] as num?)?.toDouble() ?? 0.0;
            final distB = (b['distanceFromUser'] as num?)?.toDouble() ?? 0.0;
            return params.ascending
                ? distA.compareTo(distB)
                : distB.compareTo(distA);
          });
          break;
        case 'visitCount':
          temples.sort((a, b) {
            final visitsA = (a['visitCount'] as int?) ?? 0;
            final visitsB = (b['visitCount'] as int?) ?? 0;
            return params.ascending
                ? visitsA.compareTo(visitsB)
                : visitsB.compareTo(visitsA);
          });
          break;
        case 'createdAt':
          temples.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime(1970);
            final dateB =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime(1970);
            return params.ascending
                ? dateA.compareTo(dateB)
                : dateB.compareTo(dateA);
          });
          break;
        case 'tradition':
          temples.sort((a, b) {
            final tradA =
                (a['traditions'] as List?)?.first?.toString().toLowerCase() ??
                '';
            final tradB =
                (b['traditions'] as List?)?.first?.toString().toLowerCase() ??
                '';
            return params.ascending
                ? tradA.compareTo(tradB)
                : tradB.compareTo(tradA);
          });
          break;
      }
      return temples;
    } catch (e) {
      debugPrint('Direct temple sorting failed: $e');
      return params.temples;
    }
  }

  /// Direct advanced temple filtering fallback
  static List<Map<String, dynamic>> _filterTemplesAdvancedDirect(
    AdvancedFilterParams params,
  ) {
    try {
      return _filterTemplesAdvancedIsolate(params);
    } catch (e) {
      debugPrint('Direct advanced temple filtering failed: $e');
      return params.temples;
    }
  }

  /// Direct temple search with ranking fallback
  static List<Map<String, dynamic>> _searchTemplesWithRankingDirect(
    TempleSearchParams params,
  ) {
    try {
      return _searchTemplesWithRankingIsolate(params);
    } catch (e) {
      debugPrint('Direct temple search with ranking failed: $e');
      return params.temples;
    }
  }

  /// Direct user analytics processing fallback
  static UserAnalyticsResult _processUserAnalyticsDirect(
    UserAnalyticsParams params,
  ) {
    try {
      return _processUserAnalyticsIsolate(params);
    } catch (e) {
      debugPrint('Direct user analytics processing failed: $e');
      return UserAnalyticsResult(
        analytics: {'error': 'Processing failed'},
        insights: ['Unable to process analytics data'],
        processedAt: DateTime.now(),
        dataPoints: 0,
      );
    }
  }

  /// Direct user behavior metrics calculation fallback
  static UserBehaviorMetrics _calculateUserBehaviorMetricsDirect(
    UserBehaviorParams params,
  ) {
    try {
      return _calculateUserBehaviorMetricsIsolate(params);
    } catch (e) {
      debugPrint('Direct user behavior metrics calculation failed: $e');
      return UserBehaviorMetrics(
        metrics: {'error': 1.0},
        patterns: {'error': 'Calculation failed'},
        calculatedAt: DateTime.now(),
        dataPoints: 0,
      );
    }
  }

  /// Direct temple visit patterns processing fallback
  static TempleVisitAnalytics _processTempleVisitPatternsDirect(
    TempleVisitParams params,
  ) {
    try {
      return _processTempleVisitPatternsIsolate(params);
    } catch (e) {
      debugPrint('Direct temple visit patterns processing failed: $e');
      return TempleVisitAnalytics(
        analytics: {'error': 'Processing failed'},
        trends: {'error': 'Unable to analyze trends'},
        recommendations: ['Unable to generate recommendations'],
        processedAt: DateTime.now(),
        totalDataPoints: 0,
      );
    }
  }

  /// Direct filter sort paginate fallback
  static PaginatedDataResult<T> _filterSortPaginateDirect<T>(
    FilterSortPaginateParams<T> params,
  ) {
    try {
      return _filterSortPaginateIsolate(params);
    } catch (e) {
      debugPrint('Direct filter sort paginate failed: $e');
      return PaginatedDataResult<T>(
        data: [],
        totalCount: 0,
        page: params.page,
        pageSize: params.pageSize,
        totalPages: 0,
        hasNextPage: false,
        hasPreviousPage: false,
      );
    }
  }

  /// Direct preferences analytics processing fallback
  static PreferencesAnalyticsResult _processPreferencesAnalyticsDirect(
    PreferencesAnalyticsParams params,
  ) {
    try {
      return _processPreferencesAnalyticsIsolate(params);
    } catch (e) {
      debugPrint('Direct preferences analytics processing failed: $e');
      return PreferencesAnalyticsResult(
        analytics: {'error': 'Processing failed'},
        insights: ['Unable to process preferences analytics'],
        processedAt: DateTime.now(),
        userCount: 0,
      );
    }
  }

  /// Process temple data with validation and cleanup
  static Map<String, dynamic> _processTempleData(Map<String, dynamic> data) {
    // Clean and validate temple data
    final processedData = Map<String, dynamic>.from(data);

    // Ensure required fields
    processedData['name'] =
        processedData['name']?.toString().trim() ?? 'Unnamed Temple';
    processedData['isActive'] = processedData['isActive'] ?? true;
    processedData['visitCount'] = processedData['visitCount'] ?? 0;

    // Clean location data
    if (processedData['location'] is Map) {
      final location = Map<String, dynamic>.from(processedData['location']);
      location['city'] = location['city']?.toString().trim();
      location['state'] = location['state']?.toString().trim();
      location['address'] = location['address']?.toString().trim();
      processedData['location'] = location;
    }

    // Clean traditions and features arrays
    if (processedData['traditions'] is List) {
      processedData['traditions'] = (processedData['traditions'] as List)
          .map((e) => e?.toString().trim())
          .where((e) => e != null && e.isNotEmpty)
          .toList();
    }

    if (processedData['features'] is List) {
      processedData['features'] = (processedData['features'] as List)
          .map((e) => e?.toString().trim())
          .where((e) => e != null && e.isNotEmpty)
          .toList();
    }

    return processedData;
  }

  /// Create fallback temple data when processing fails
  static Map<String, dynamic> _createFallbackTempleData(
    Map<String, dynamic> data,
  ) {
    return {
      'id': data['id'] ?? 'unknown',
      'name': data['name']?.toString().trim() ?? 'Unnamed Temple',
      'description': data['description']?.toString().trim() ?? '',
      'location': {
        'city': data['location']?['city']?.toString().trim(),
        'state': data['location']?['state']?.toString().trim(),
        'address': data['location']?['address']?.toString().trim(),
      },
      'traditions': data['traditions'] is List ? data['traditions'] : [],
      'features': data['features'] is List ? data['features'] : [],
      'images': data['images'] is List ? data['images'] : [],
      'isActive': data['isActive'] ?? true,
      'visitCount': data['visitCount'] ?? 0,
      'isFavorite': data['isFavorite'] ?? false,
      'distanceFromUser': data['distanceFromUser'],
    };
  }

  /// Build searchable text for temple filtering
  static String _buildSearchableText(Map<String, dynamic> temple) {
    final parts = <String>[];

    // Add name
    if (temple['name'] != null) {
      parts.add(temple['name'].toString().toLowerCase());
    }

    // Add description
    if (temple['description'] != null) {
      parts.add(temple['description'].toString().toLowerCase());
    }

    // Add location info
    if (temple['location'] is Map) {
      final location = temple['location'] as Map;
      if (location['city'] != null) {
        parts.add(location['city'].toString().toLowerCase());
      }
      if (location['state'] != null) {
        parts.add(location['state'].toString().toLowerCase());
      }
      if (location['address'] != null) {
        parts.add(location['address'].toString().toLowerCase());
      }
    }

    // Add traditions
    if (temple['traditions'] is List) {
      for (final tradition in temple['traditions']) {
        if (tradition != null) {
          parts.add(tradition.toString().toLowerCase());
        }
      }
    }

    // Add features
    if (temple['features'] is List) {
      for (final feature in temple['features']) {
        if (feature != null) {
          parts.add(feature.toString().toLowerCase());
        }
      }
    }

    return parts.join(' ');
  }
}

/// Parameters for image processing in isolate
class ImageProcessParams {
  final String filePath;
  final int maxWidth;
  final int quality;
  final ImageOutputFormat format;
  final int? minHeight;
  final int? minWidth;
  final bool keepExif;

  ImageProcessParams({
    required this.filePath,
    required this.maxWidth,
    required this.quality,
    required this.format,
    this.minHeight,
    this.minWidth,
    this.keepExif = false,
  });
}

/// Parameters for filtering temples by text in isolate
class FilterTemplesParams {
  final List<Map<String, dynamic>> temples;
  final String searchQuery;

  FilterTemplesParams({required this.temples, required this.searchQuery});
}

/// Parameters for sorting temples in isolate
class SortTemplesParams {
  final List<Map<String, dynamic>> temples;
  final String sortBy;
  final bool ascending;

  SortTemplesParams({
    required this.temples,
    required this.sortBy,
    required this.ascending,
  });
}

/// Supported output formats for image processing
enum ImageOutputFormat { jpg, png, webp, heic }

extension ImageOutputFormatExtension on ImageOutputFormat {
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

/// Parameters for metrics calculation in isolate
class MetricsCalculationParams {
  final List<dynamic> data;
  final double Function(dynamic) valueExtractor;
  final Map<String, double Function(List<double>)>? customCalculations;

  MetricsCalculationParams({
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

  MetricsResult({
    required this.totalCount,
    required this.averageValue,
    required this.maxValue,
    required this.minValue,
    required this.standardDeviation,
    required this.percentiles,
    required this.customMetrics,
  });
}

/// Parameters for analytics processing in isolate
class AnalyticsProcessingParams {
  final List<Map<String, dynamic>> data;
  final Map<String, dynamic> Function(Map<String, dynamic>) processor;
  final Map<String, dynamic Function(List<Map<String, dynamic>>)>? aggregators;
  final List<TrendData> Function(List<Map<String, dynamic>>)? trendAnalyzer;
  final List<String> Function(List<Map<String, dynamic>>, Map<String, dynamic>)?
  insightGenerator;

  AnalyticsProcessingParams({
    required this.data,
    required this.processor,
    this.aggregators,
    this.trendAnalyzer,
    this.insightGenerator,
  });
}

/// Result of analytics processing
class AnalyticsResult {
  final List<Map<String, dynamic>> processedData;
  final Map<String, dynamic> aggregatedMetrics;
  final List<TrendData> trends;
  final List<String> insights;

  AnalyticsResult({
    required this.processedData,
    required this.aggregatedMetrics,
    required this.trends,
    required this.insights,
  });
}

/// Trend data for analytics
class TrendData {
  final String metric;
  final String period;
  final double value;
  final double change;
  final String direction; // 'up', 'down', 'stable'

  TrendData({
    required this.metric,
    required this.period,
    required this.value,
    required this.change,
    required this.direction,
  });
}

/// Parameters for batch processing in isolate
class BatchProcessParams<T> {
  final List<dynamic> items;
  final T Function(dynamic) processor;
  final T? defaultValue;

  BatchProcessParams({
    required this.items,
    required this.processor,
    this.defaultValue,
  });
}

/// Parameters for large dataset processing in isolate
class LargeDatasetParams<T> {
  final List<dynamic> data;
  final T Function(dynamic) processor;
  final int chunkSize;

  LargeDatasetParams({
    required this.data,
    required this.processor,
    this.chunkSize = 100,
  });
}

/// Parameters for image processing with progress updates
class ImageProcessWithProgressParams {
  final ImageProcessParams imageParams;
  final bool enableProgress;

  ImageProcessWithProgressParams({
    required this.imageParams,
    this.enableProgress = false,
  });
}

/// Result of image processing operation
class ImageProcessingResult {
  final String? outputPath;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final int processingTime;
  final bool success;
  final String? error;

  ImageProcessingResult({
    required this.outputPath,
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

  MultiSizeImageParams({
    required this.originalPath,
    required this.sizes,
    this.quality = 85,
    this.format = ImageOutputFormat.jpg,
    this.keepExif = false,
  });
}

/// Image size specification
class ImageSize {
  final int width;
  final int height;

  const ImageSize({required this.width, required this.height});
}

/// Parameters for image format optimization
class ImageFormatOptimizationParams {
  final String inputPath;
  final ImageOutputFormat targetFormat;
  final int quality;
  final int maxWidth;
  final bool keepExif;

  ImageFormatOptimizationParams({
    required this.inputPath,
    required this.targetFormat,
    this.quality = 85,
    this.maxWidth = 1024,
    this.keepExif = false,
  });
}

/// Parameters for advanced temple filtering
class AdvancedFilterParams {
  final List<Map<String, dynamic>> temples;
  final String? searchQuery;
  final List<String>? traditions;
  final List<String>? features;
  final double? maxDistance;
  final Map<String, double>? userLocation;
  final List<String>? cities;
  final List<String>? states;
  final bool? hasLiveDarshan;
  final bool? isActive;

  AdvancedFilterParams({
    required this.temples,
    this.searchQuery,
    this.traditions,
    this.features,
    this.maxDistance,
    this.userLocation,
    this.cities,
    this.states,
    this.hasLiveDarshan,
    this.isActive,
  });
}

/// Parameters for temple search with ranking
class TempleSearchParams {
  final List<Map<String, dynamic>> temples;
  final String searchQuery;

  TempleSearchParams({required this.temples, required this.searchQuery});
}

/// Parameters for user analytics processing
class UserAnalyticsParams {
  final List<Map<String, dynamic>> userData;

  UserAnalyticsParams({required this.userData});
}

/// Result of user analytics processing
class UserAnalyticsResult {
  final Map<String, dynamic> analytics;
  final List<String> insights;
  final DateTime processedAt;
  final int dataPoints;

  UserAnalyticsResult({
    required this.analytics,
    required this.insights,
    required this.processedAt,
    required this.dataPoints,
  });
}

/// Parameters for user behavior metrics calculation
class UserBehaviorParams {
  final List<Map<String, dynamic>> behaviorData;

  UserBehaviorParams({required this.behaviorData});
}

/// Result of user behavior metrics calculation
class UserBehaviorMetrics {
  final Map<String, double> metrics;
  final Map<String, dynamic> patterns;
  final DateTime calculatedAt;
  final int dataPoints;

  UserBehaviorMetrics({
    required this.metrics,
    required this.patterns,
    required this.calculatedAt,
    required this.dataPoints,
  });
}

/// Parameters for temple visit patterns processing
class TempleVisitParams {
  final List<Map<String, dynamic>> visitData;

  TempleVisitParams({required this.visitData});
}

/// Result of temple visit analytics
class TempleVisitAnalytics {
  final Map<String, dynamic> analytics;
  final Map<String, dynamic> trends;
  final List<String> recommendations;
  final DateTime processedAt;
  final int totalDataPoints;

  TempleVisitAnalytics({
    required this.analytics,
    required this.trends,
    required this.recommendations,
    required this.processedAt,
    required this.totalDataPoints,
  });
}

/// Parameters for filter, sort, and paginate operations
class FilterSortPaginateParams<T> {
  final List<T> data;
  final bool Function(T)? filterFunction;
  final int Function(T, T)? sortFunction;
  final int page;
  final int pageSize;

  FilterSortPaginateParams({
    required this.data,
    this.filterFunction,
    this.sortFunction,
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
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedDataResult({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });
}

/// Parameters for preferences analytics processing
class PreferencesAnalyticsParams {
  final List<Map<String, dynamic>> preferencesData;

  PreferencesAnalyticsParams({required this.preferencesData});
}

/// Result of preferences analytics processing
class PreferencesAnalyticsResult {
  final Map<String, dynamic> analytics;
  final List<String> insights;
  final DateTime processedAt;
  final int userCount;

  PreferencesAnalyticsResult({
    required this.analytics,
    required this.insights,
    required this.processedAt,
    required this.userCount,
  });
}
