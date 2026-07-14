import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../animations/app_animations.dart';
import '../../services/image/comprehensive_image_optimizer.dart';
import '../../models/image_optimization_models.dart';

/// Enhanced progressive image widget with advanced progressive JPEG support
class EnhancedProgressiveImage extends StatefulWidget {
  final String imageUrl;
  final String? localImagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration animationDuration;
  final Curve animationCurve;
  final List<int> progressiveQualityLevels;
  final Duration qualityTransitionDuration;
  final bool enableProgressiveJPEG;
  final bool showProgressIndicator;
  final bool enableRetry;
  final int maxRetryAttempts;
  final Duration retryDelay;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final void Function(String imageUrl, bool success, int? finalQuality)?
  onLoadComplete;
  final void Function(int currentQuality, int totalLevels)? onProgressUpdate;

  const EnhancedProgressiveImage({
    super.key,
    required this.imageUrl,
    this.localImagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.animationDuration = AppAnimations.normalDuration,
    this.animationCurve = AppAnimations.defaultCurve,
    this.progressiveQualityLevels = const [20, 40, 60, 80, 95],
    this.qualityTransitionDuration = AppAnimations.fastDuration,
    this.enableProgressiveJPEG = true,
    this.showProgressIndicator = true,
    this.enableRetry = true,
    this.maxRetryAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.borderRadius,
    this.placeholderColor,
    this.onLoadComplete,
    this.onProgressUpdate,
  });

  @override
  State<EnhancedProgressiveImage> createState() =>
      _EnhancedProgressiveImageState();
}

class _EnhancedProgressiveImageState extends State<EnhancedProgressiveImage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _qualityController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _qualityAnimation;

  ProgressiveImageData? _progressiveData;
  int _currentQualityIndex = 0;
  int _retryAttempts = 0;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isCompleted = false;

  final Map<int, bool> _qualityLevelsLoaded = {};
  final Map<int, String> _qualityImagePaths = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startProgressiveLoading();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _qualityController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _qualityController = AnimationController(
      duration: widget.qualityTransitionDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: widget.animationCurve),
    );

    _qualityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _qualityController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startProgressiveLoading() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentQualityIndex = 0;
      _qualityLevelsLoaded.clear();
      _qualityImagePaths.clear();
    });

    try {
      if (widget.enableProgressiveJPEG) {
        await _loadProgressiveJPEG();
      } else {
        await _loadSingleImage();
      }
    } catch (e) {
      await _handleLoadingError();
    }
  }

  Future<void> _loadProgressiveJPEG() async {
    try {
      // Create progressive image data
      final optimizer = ComprehensiveImageOptimizer();

      String sourcePath = widget.imageUrl;
      if (widget.localImagePath != null) {
        sourcePath = widget.localImagePath!;
      }

      _progressiveData = await optimizer.createProgressiveImage(
        sourcePath,
        qualityLevels: widget.progressiveQualityLevels,
      );

      if (_progressiveData?.success == true && mounted) {
        await _loadQualityLevelsSequentially();
      } else {
        throw Exception('Failed to create progressive image data');
      }
    } catch (e) {
      await _handleLoadingError();
    }
  }

  Future<void> _loadQualityLevelsSequentially() async {
    final sortedQualities = widget.progressiveQualityLevels.toList()..sort();

    for (int i = 0; i < sortedQualities.length; i++) {
      if (!mounted) break;

      final quality = sortedQualities[i];
      final imagePath = _progressiveData!.progressivePaths[quality];

      if (imagePath != null) {
        try {
          // Preload this quality level
          await precacheImage(CachedNetworkImageProvider(imagePath), context);

          if (mounted) {
            setState(() {
              _qualityLevelsLoaded[quality] = true;
              _qualityImagePaths[quality] = imagePath;
              _currentQualityIndex = i;
            });

            // Trigger animation for quality transition
            if (i == 0) {
              _fadeController.forward();
            } else {
              await _qualityController.forward();
              _qualityController.reset();
            }

            // Notify progress
            widget.onProgressUpdate?.call(i + 1, sortedQualities.length);

            // Small delay between quality levels for smooth progression
            if (i < sortedQualities.length - 1) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }
        } catch (e) {
          // Continue with next quality level on error
          continue;
        }
      }
    }

    // Mark as completed
    if (mounted) {
      setState(() {
        _isCompleted = true;
        _isLoading = false;
      });

      final finalQuality = sortedQualities.isNotEmpty
          ? sortedQualities.last
          : null;
      widget.onLoadComplete?.call(widget.imageUrl, true, finalQuality);
    }
  }

  Future<void> _loadSingleImage() async {
    try {
      await precacheImage(CachedNetworkImageProvider(widget.imageUrl), context);

      if (mounted) {
        setState(() {
          _isCompleted = true;
          _isLoading = false;
        });
        _fadeController.forward();
        widget.onLoadComplete?.call(widget.imageUrl, true, null);
      }
    } catch (e) {
      await _handleLoadingError();
    }
  }

  Future<void> _handleLoadingError() async {
    if (_retryAttempts < widget.maxRetryAttempts && widget.enableRetry) {
      _retryAttempts++;
      await Future.delayed(widget.retryDelay);

      if (mounted) {
        await _startProgressiveLoading();
      }
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        widget.onLoadComplete?.call(widget.imageUrl, false, null);
      }
    }
  }

  void _retryLoading() {
    _retryAttempts = 0;
    _startProgressiveLoading();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildImageContent();

    // Apply border radius if specified
    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: imageWidget,
    );
  }

  Widget _buildImageContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Placeholder layer
        if (!_hasError && _qualityLevelsLoaded.isEmpty && !_isCompleted)
          _buildPlaceholder(),

        // Progressive quality layers
        if (widget.enableProgressiveJPEG && _progressiveData?.success == true)
          ..._buildProgressiveQualityLayers(),

        // Single image layer (fallback)
        if (!widget.enableProgressiveJPEG && _isCompleted)
          _buildSingleImageLayer(),

        // Error layer
        if (_hasError) _buildErrorWidget(),

        // Progress indicator
        if (_isLoading && widget.showProgressIndicator)
          _buildProgressIndicator(),
      ],
    );
  }

  List<Widget> _buildProgressiveQualityLayers() {
    final layers = <Widget>[];
    final sortedQualities = widget.progressiveQualityLevels.toList()..sort();

    for (
      int i = 0;
      i <= _currentQualityIndex && i < sortedQualities.length;
      i++
    ) {
      final quality = sortedQualities[i];
      final imagePath = _qualityImagePaths[quality];
      final isCurrentLevel = i == _currentQualityIndex;

      if (imagePath != null) {
        layers.add(
          AnimatedBuilder(
            animation: isCurrentLevel ? _qualityAnimation : _fadeAnimation,
            builder: (context, child) {
              double opacity = 1.0;

              if (isCurrentLevel && i > 0) {
                opacity = _qualityAnimation.value;
              } else if (i == 0) {
                opacity = _fadeAnimation.value;
              }

              return Opacity(
                opacity: opacity,
                child: CachedNetworkImage(
                  imageUrl: imagePath,
                  fit: widget.fit,
                  width: widget.width,
                  height: widget.height,
                  placeholder: (context, url) => const SizedBox.shrink(),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              );
            },
          ),
        );
      }
    }

    return layers;
  }

  Widget _buildSingleImageLayer() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => _buildErrorWidget(),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    final placeholderColor = widget.placeholderColor ?? Colors.grey[300]!;

    return Container(
      color: placeholderColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                placeholderColor.computeLuminance() > 0.5
                    ? Colors.grey[600]!
                    : Colors.grey[400]!,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading image...',
              style: TextStyle(
                fontSize: 12,
                color: placeholderColor.computeLuminance() > 0.5
                    ? Colors.grey[600]
                    : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress =
        _currentQualityIndex / widget.progressiveQualityLevels.length;
    final currentQuality =
        _currentQualityIndex < widget.progressiveQualityLevels.length
        ? widget.progressiveQualityLevels[_currentQualityIndex]
        : widget.progressiveQualityLevels.last;

    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.white30,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${currentQuality}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load image',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (widget.enableRetry) ...[
              const SizedBox(height: 8),
              GestureDetector(
      behavior: HitTestBehavior.opaque,
                onTap: _retryLoading,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
