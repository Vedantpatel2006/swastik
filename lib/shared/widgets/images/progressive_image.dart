import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../animations/app_animations.dart';
import '../../services/image/comprehensive_image_optimizer.dart';
import '../../models/image_optimization_models.dart';

/// Progressive image loading widget with blur-to-sharp transition and progressive JPEG support
class ProgressiveImage extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration animationDuration;
  final Curve animationCurve;
  final double blurRadius;
  final bool enableHeroAnimation;
  final String? heroTag;
  final BorderRadius? borderRadius;
  final bool preloadFullImage;
  final bool enableProgressiveJPEG;
  final List<int> progressiveQualityLevels;
  final Duration progressiveTransitionDuration;
  final bool enableSmartPlaceholder;
  final Color? placeholderColor;
  final void Function(String imageUrl, bool success)? onLoadComplete;

  const ProgressiveImage({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.animationDuration = AppAnimations.normalDuration,
    this.animationCurve = AppAnimations.defaultCurve,
    this.blurRadius = 10.0,
    this.enableHeroAnimation = false,
    this.heroTag,
    this.borderRadius,
    this.preloadFullImage = true,
    this.enableProgressiveJPEG = true,
    this.progressiveQualityLevels = const [20, 40, 60, 80, 95],
    this.progressiveTransitionDuration = AppAnimations.fastDuration,
    this.enableSmartPlaceholder = true,
    this.placeholderColor,
    this.onLoadComplete,
  });

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _blurController;
  late AnimationController _progressiveController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;
  late Animation<double> _progressiveAnimation;

  bool _thumbnailLoaded = false;
  bool _fullImageLoaded = false;
  bool _hasError = false;
  bool _isLoadingProgressive = false;

  // Progressive JPEG support
  ProgressiveImageData? _progressiveData;
  int _currentProgressiveLevel = 0;
  final Map<int, bool> _progressiveLevelsLoaded = {};

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _blurController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _progressiveController = AnimationController(
      duration: widget.progressiveTransitionDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: widget.animationCurve),
    );

    _blurAnimation = Tween<double>(begin: widget.blurRadius, end: 0.0).animate(
      CurvedAnimation(parent: _blurController, curve: widget.animationCurve),
    );

    _progressiveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressiveController, curve: Curves.easeInOut),
    );

    _preloadImages();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _blurController.dispose();
    _progressiveController.dispose();
    super.dispose();
  }

  /// Preload images for progressive loading
  Future<void> _preloadImages() async {
    try {
      // Initialize progressive levels tracking
      for (final quality in widget.progressiveQualityLevels) {
        _progressiveLevelsLoaded[quality] = false;
      }

      // First, try progressive JPEG loading if enabled
      if (widget.enableProgressiveJPEG) {
        await _loadProgressiveJPEG();
      } else {
        // Fallback to traditional progressive loading
        await _loadTraditionalProgressive();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        widget.onLoadComplete?.call(widget.imageUrl, false);
      }
    }
  }

  /// Load progressive JPEG with multiple quality levels
  Future<void> _loadProgressiveJPEG() async {
    try {
      setState(() {
        _isLoadingProgressive = true;
      });

      // Create progressive image data
      final optimizer = ComprehensiveImageOptimizer();
      _progressiveData = await optimizer.createProgressiveImage(
        widget.imageUrl,
        qualityLevels: widget.progressiveQualityLevels,
      );

      if (_progressiveData?.success == true && mounted) {
        await _loadProgressiveLevels();
      } else {
        // Fallback to traditional loading
        await _loadTraditionalProgressive();
      }
    } catch (e) {
      // Fallback to traditional loading on error
      await _loadTraditionalProgressive();
    }
  }

  /// Load progressive levels sequentially
  Future<void> _loadProgressiveLevels() async {
    if (_progressiveData?.progressivePaths.isEmpty == true) return;

    final sortedQualities = widget.progressiveQualityLevels.toList()..sort();

    for (int i = 0; i < sortedQualities.length; i++) {
      final quality = sortedQualities[i];
      final imagePath = _progressiveData!.progressivePaths[quality];

      if (imagePath != null && mounted) {
        try {
          // Preload this quality level
          await precacheImage(CachedNetworkImageProvider(imagePath), context);

          if (mounted) {
            setState(() {
              _progressiveLevelsLoaded[quality] = true;
              _currentProgressiveLevel = quality;

              if (i == 0) {
                // First level loaded - show with fade
                _thumbnailLoaded = true;
                _fadeController.forward();
              } else {
                // Subsequent levels - smooth transition
                _progressiveController.forward().then((_) {
                  if (mounted) {
                    _progressiveController.reset();
                  }
                });
              }
            });

            // Small delay between levels for smooth progression
            if (i < sortedQualities.length - 1) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
        } catch (e) {
          // Continue with next quality level on error
          continue;
        }
      }
    }

    // Mark as fully loaded when highest quality is reached
    if (mounted) {
      setState(() {
        _fullImageLoaded = true;
        _isLoadingProgressive = false;
      });
      _blurController.forward();
      widget.onLoadComplete?.call(widget.imageUrl, true);
    }
  }

  /// Traditional progressive loading fallback
  Future<void> _loadTraditionalProgressive() async {
    // First, try to load thumbnail if available
    if (widget.thumbnailUrl != null) {
      await _preloadThumbnail();
    } else {
      // If no thumbnail, start with a blurred version of the full image
      await _preloadBlurredVersion();
    }

    // Then preload full image if enabled
    if (widget.preloadFullImage) {
      await _preloadFullImage();
    }
  }

  /// Preload a blurred version of the full image as placeholder
  Future<void> _preloadBlurredVersion() async {
    try {
      // Create a low-quality version URL if possible
      String blurredUrl = widget.imageUrl;

      // For common image services, append quality parameters
      if (widget.imageUrl.contains('firebase') ||
          widget.imageUrl.contains('cloudinary')) {
        final uri = Uri.parse(widget.imageUrl);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams['w'] = '50'; // Very small width for blur effect
        queryParams['q'] = '30'; // Low quality
        blurredUrl = uri.replace(queryParameters: queryParams).toString();
      }

      await precacheImage(CachedNetworkImageProvider(blurredUrl), context);

      if (mounted) {
        setState(() {
          _thumbnailLoaded = true;
        });
        _fadeController.forward();
      }
    } catch (e) {
      // Blurred version failed, continue with full image
    }
  }

  /// Preload thumbnail image
  Future<void> _preloadThumbnail() async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(widget.thumbnailUrl!),
        context,
      );

      if (mounted) {
        setState(() {
          _thumbnailLoaded = true;
        });
        _fadeController.forward();
      }
    } catch (e) {
      // Thumbnail failed, continue with full image
    }
  }

  /// Preload full resolution image
  Future<void> _preloadFullImage() async {
    try {
      await precacheImage(CachedNetworkImageProvider(widget.imageUrl), context);

      if (mounted) {
        setState(() {
          _fullImageLoaded = true;
        });
        _blurController.forward();
        widget.onLoadComplete?.call(widget.imageUrl, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        widget.onLoadComplete?.call(widget.imageUrl, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildImageStack();

    // Apply border radius if specified
    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    // Wrap with hero animation if enabled
    if (widget.enableHeroAnimation && widget.heroTag != null) {
      imageWidget = Hero(tag: widget.heroTag!, child: imageWidget);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: imageWidget,
    );
  }

  /// Build the image stack with progressive loading
  Widget _buildImageStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Placeholder layer
        if (!_thumbnailLoaded && !_fullImageLoaded && !_hasError)
          _buildPlaceholder(),

        // Progressive JPEG layers
        if (widget.enableProgressiveJPEG && _progressiveData?.success == true)
          ..._buildProgressiveLayers(),

        // Traditional thumbnail layer (blurred) - fallback
        if (!widget.enableProgressiveJPEG && _thumbnailLoaded)
          _buildThumbnailLayer(),

        // Full image layer - traditional loading
        if (!widget.enableProgressiveJPEG && _fullImageLoaded)
          _buildFullImageLayer(),

        // Error layer
        if (_hasError && !_thumbnailLoaded && !_fullImageLoaded)
          _buildErrorWidget(),

        // Loading indicator for progressive loading
        if (_isLoadingProgressive && widget.enableProgressiveJPEG)
          _buildProgressiveLoadingIndicator(),
      ],
    );
  }

  /// Build progressive JPEG layers
  List<Widget> _buildProgressiveLayers() {
    final layers = <Widget>[];
    final sortedQualities = widget.progressiveQualityLevels.toList()..sort();

    for (int i = 0; i < sortedQualities.length; i++) {
      final quality = sortedQualities[i];
      final imagePath = _progressiveData!.progressivePaths[quality];
      final isLoaded = _progressiveLevelsLoaded[quality] == true;

      if (imagePath != null && isLoaded) {
        final isCurrentLevel = quality == _currentProgressiveLevel;
        final isFinalLevel = i == sortedQualities.length - 1;

        layers.add(
          AnimatedBuilder(
            animation: isCurrentLevel ? _progressiveAnimation : _fadeAnimation,
            builder: (context, child) {
              double opacity = 1.0;
              double blurSigma = 0.0;

              if (isCurrentLevel && !isFinalLevel) {
                // Current level with potential blur reduction
                opacity = _fadeAnimation.value;
                blurSigma = isFinalLevel
                    ? 0.0
                    : (widget.blurRadius * (1 - (quality / 100)));
              } else if (isFinalLevel && _fullImageLoaded) {
                // Final level - sharp and clear
                opacity = _blurAnimation.value;
                blurSigma = _blurAnimation.value * widget.blurRadius;
              }

              return Opacity(
                opacity: opacity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: widget.fit,
                    width: widget.width,
                    height: widget.height,
                    placeholder: (context, url) => const SizedBox.shrink(),
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return layers;
  }

  /// Build traditional thumbnail layer
  Widget _buildThumbnailLayer() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: AnimatedBuilder(
            animation: _blurAnimation,
            builder: (context, child) {
              return ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _fullImageLoaded
                      ? _blurAnimation.value
                      : widget.blurRadius,
                  sigmaY: _fullImageLoaded
                      ? _blurAnimation.value
                      : widget.blurRadius,
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl ?? widget.imageUrl,
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
      },
    );
  }

  /// Build traditional full image layer
  Widget _buildFullImageLayer() {
    return AnimatedBuilder(
      animation: _blurAnimation,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: _fullImageLoaded ? 1.0 : 0.0,
          duration: widget.animationDuration,
          curve: widget.animationCurve,
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

  /// Build progressive loading indicator
  Widget _buildProgressiveLoadingIndicator() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${_currentProgressiveLevel}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build placeholder widget
  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    // Smart placeholder based on image URL or custom color
    Color placeholderColor = widget.placeholderColor ?? Colors.grey[300]!;

    if (widget.enableSmartPlaceholder) {
      // Generate a subtle color based on image URL hash for variety
      final urlHash = widget.imageUrl.hashCode;
      final hue = (urlHash % 360).toDouble();
      placeholderColor = HSVColor.fromAHSV(1.0, hue, 0.1, 0.95).toColor();
    }

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
            if (widget.enableProgressiveJPEG) ...[
              const SizedBox(height: 8),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 12,
                  color: placeholderColor.computeLuminance() > 0.5
                      ? Colors.grey[600]
                      : Colors.grey[400],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build error widget
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
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Retry loading
                setState(() {
                  _hasError = false;
                  _thumbnailLoaded = false;
                  _fullImageLoaded = false;
                  _isLoadingProgressive = false;
                  _currentProgressiveLevel = 0;
                  _progressiveLevelsLoaded.clear();
                });
                _preloadImages();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for progressive images
class ProgressiveImageShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ProgressiveImageShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<ProgressiveImageShimmer> createState() =>
      _ProgressiveImageShimmerState();
}

class _ProgressiveImageShimmerState extends State<ProgressiveImageShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _shimmerAnimation.value - 0.3,
                _shimmerAnimation.value,
                _shimmerAnimation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Progressive image grid for efficient loading of multiple images
class ProgressiveImageGrid extends StatefulWidget {
  final List<String> imageUrls;
  final List<String>? thumbnailUrls;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final bool enableHeroAnimations;
  final String Function(int index)? heroTagBuilder;
  final void Function(int index, String imageUrl)? onImageTap;

  const ProgressiveImageGrid({
    super.key,
    required this.imageUrls,
    this.thumbnailUrls,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.childAspectRatio = 1.0,
    this.padding,
    this.enableHeroAnimations = false,
    this.heroTagBuilder,
    this.onImageTap,
  });

  @override
  State<ProgressiveImageGrid> createState() => _ProgressiveImageGridState();
}

class _ProgressiveImageGridState extends State<ProgressiveImageGrid> {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        final imageUrl = widget.imageUrls[index];
        final thumbnailUrl =
            widget.thumbnailUrls != null && index < widget.thumbnailUrls!.length
            ? widget.thumbnailUrls![index]
            : null;
        final heroTag = widget.enableHeroAnimations
            ? (widget.heroTagBuilder?.call(index) ?? 'image_$index')
            : null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onImageTap?.call(index, imageUrl),
          child: ProgressiveImage(
            imageUrl: imageUrl,
            thumbnailUrl: thumbnailUrl,
            fit: BoxFit.cover,
            enableHeroAnimation: widget.enableHeroAnimations,
            heroTag: heroTag,
            borderRadius: BorderRadius.circular(8.0),
            placeholder: const ProgressiveImageShimmer(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
          ),
        );
      },
    );
  }
}
