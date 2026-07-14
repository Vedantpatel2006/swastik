import 'dart:async';
import 'package:flutter/material.dart';
import '../animations/app_animations.dart';

/// Lazy loading strategy
enum LazyLoadingStrategy {
  onVisible, // Load when widget becomes visible
  onApproach, // Load when widget is approaching viewport
  onDemand, // Load only when explicitly requested
  immediate, // Load immediately
}

/// Loading state for lazy widgets
enum LazyLoadingState {
  idle, // Not started loading
  loading, // Currently loading
  loaded, // Successfully loaded
  error, // Error occurred
  retrying, // Retrying after error
}

/// Configuration for lazy loading behavior
class LazyLoadingConfig {
  final LazyLoadingStrategy strategy;
  final double approachThreshold; // Distance from viewport to start loading
  final Duration loadingTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enablePlaceholder;
  final bool enableErrorWidget;
  final bool enableShimmer;

  const LazyLoadingConfig({
    this.strategy = LazyLoadingStrategy.onApproach,
    this.approachThreshold = 200.0,
    this.loadingTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.enablePlaceholder = true,
    this.enableErrorWidget = true,
    this.enableShimmer = true,
  });
}

/// Lazy loading widget that loads content based on visibility and strategy
class LazyLoadingWidget extends StatefulWidget {
  final String? cacheKey;
  final Future<Widget> Function() contentBuilder;
  final Widget Function()? placeholderBuilder;
  final Widget Function(Object error, VoidCallback retry)? errorBuilder;
  final LazyLoadingConfig config;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final void Function(LazyLoadingState state)? onStateChanged;
  final void Function(Widget content)? onContentLoaded;
  final void Function(Object error)? onError;

  const LazyLoadingWidget({
    super.key,
    this.cacheKey,
    required this.contentBuilder,
    this.placeholderBuilder,
    this.errorBuilder,
    this.config = const LazyLoadingConfig(),
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onStateChanged,
    this.onContentLoaded,
    this.onError,
  });

  @override
  State<LazyLoadingWidget> createState() => _LazyLoadingWidgetState();
}

class _LazyLoadingWidgetState extends State<LazyLoadingWidget>
    with TickerProviderStateMixin {
  LazyLoadingState _state = LazyLoadingState.idle;
  Widget? _content;
  Object? _error;
  Timer? _loadingTimer;
  Timer? _retryTimer;
  int _retryCount = 0;

  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _startShimmer();
    _initializeLoading();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _retryTimer?.cancel();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _startShimmer() {
    if (widget.config.enableShimmer) {
      _shimmerController.repeat();
    }
  }

  void _initializeLoading() {
    switch (widget.config.strategy) {
      case LazyLoadingStrategy.immediate:
        _loadContent();
        break;
      case LazyLoadingStrategy.onVisible:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVisibility();
        });
        break;
      case LazyLoadingStrategy.onApproach:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkApproach();
        });
        break;
      case LazyLoadingStrategy.onDemand:
        // Do nothing, wait for explicit trigger
        break;
    }
  }

  void _checkVisibility() {
    if (!mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    final isVisible =
        position.dy < screenHeight && position.dy + size.height > 0;

    if (isVisible && _state == LazyLoadingState.idle) {
      _loadContent();
    }
  }

  void _checkApproach() {
    if (!mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    final isApproaching =
        position.dy < screenHeight + widget.config.approachThreshold &&
        position.dy + size.height > -widget.config.approachThreshold;

    if (isApproaching && _state == LazyLoadingState.idle) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    if (_state != LazyLoadingState.idle) return;

    _setState(LazyLoadingState.loading);

    // Set loading timeout
    _loadingTimer = Timer(widget.config.loadingTimeout, () {
      if (_state == LazyLoadingState.loading) {
        _setState(LazyLoadingState.error);
        _error = TimeoutException(
          'Loading timeout',
          widget.config.loadingTimeout,
        );
        widget.onError?.call(_error!);
      }
    });

    try {
      final content = await widget.contentBuilder();

      _loadingTimer?.cancel();

      if (mounted) {
        _content = content;
        _setState(LazyLoadingState.loaded);

        widget.onContentLoaded?.call(content);
        _fadeController.forward();
      }
    } catch (e) {
      _loadingTimer?.cancel();

      if (mounted) {
        _error = e;
        _setState(LazyLoadingState.error);
        widget.onError?.call(e);
      }
    }
  }

  void retry() {
    if (_retryCount >= widget.config.maxRetries) return;

    _retryCount++;
    _setState(LazyLoadingState.retrying);

    _retryTimer = Timer(widget.config.retryDelay, () {
      if (mounted) {
        _loadContent();
      }
    });
  }

  void _setState(LazyLoadingState newState) {
    if (_state != newState) {
      setState(() {
        _state = newState;
      });
      widget.onStateChanged?.call(newState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      margin: widget.margin,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (widget.config.strategy == LazyLoadingStrategy.onVisible) {
                _checkVisibility();
              } else if (widget.config.strategy ==
                  LazyLoadingStrategy.onApproach) {
                _checkApproach();
              }
            });
          }
          return false;
        },
        child: LazyContentBuilder(
          state: _state,
          content: _content,
          error: _error,
          retryCount: _retryCount,
          config: widget.config,
          placeholderBuilder: widget.placeholderBuilder,
          errorBuilder: widget.errorBuilder,
          fadeAnimation: _fadeAnimation,
          shimmerAnimation: _shimmerAnimation,
          onRetry: retry,
        ),
      ),
    );
  }
}

/// Optimized content builder widget for lazy loading
class LazyContentBuilder extends StatelessWidget {
  final LazyLoadingState state;
  final Widget? content;
  final Object? error;
  final int retryCount;
  final LazyLoadingConfig config;
  final Widget Function()? placeholderBuilder;
  final Widget Function(Object error, VoidCallback retry)? errorBuilder;
  final Animation<double> fadeAnimation;
  final Animation<double> shimmerAnimation;
  final VoidCallback onRetry;

  const LazyContentBuilder({
    super.key,
    required this.state,
    this.content,
    this.error,
    required this.retryCount,
    required this.config,
    this.placeholderBuilder,
    this.errorBuilder,
    required this.fadeAnimation,
    required this.shimmerAnimation,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case LazyLoadingState.idle:
        return LazyPlaceholderWidget(
          placeholderBuilder: placeholderBuilder,
          config: config,
          shimmerAnimation: shimmerAnimation,
        );

      case LazyLoadingState.loading:
      case LazyLoadingState.retrying:
        return LazyLoadingIndicatorWidget(
          state: state,
          retryCount: retryCount,
          config: config,
          placeholderBuilder: placeholderBuilder,
          shimmerAnimation: shimmerAnimation,
        );

      case LazyLoadingState.loaded:
        return AnimatedBuilder(
          animation: fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: fadeAnimation.value,
              child:
                  content ??
                  LazyPlaceholderWidget(
                    placeholderBuilder: placeholderBuilder,
                    config: config,
                    shimmerAnimation: shimmerAnimation,
                  ),
            );
          },
        );

      case LazyLoadingState.error:
        return LazyErrorWidget(
          error: error!,
          errorBuilder: errorBuilder,
          config: config,
          placeholderBuilder: placeholderBuilder,
          shimmerAnimation: shimmerAnimation,
          onRetry: onRetry,
        );
    }
  }
}

/// Optimized placeholder widget for lazy loading
class LazyPlaceholderWidget extends StatelessWidget {
  final Widget Function()? placeholderBuilder;
  final LazyLoadingConfig config;
  final Animation<double> shimmerAnimation;

  const LazyPlaceholderWidget({
    super.key,
    this.placeholderBuilder,
    required this.config,
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (placeholderBuilder != null) {
      return placeholderBuilder!();
    }

    if (!config.enablePlaceholder) {
      return const SizedBox.shrink();
    }

    if (config.enableShimmer) {
      return LazyShimmerWidget(shimmerAnimation: shimmerAnimation);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
      ),
    );
  }
}

/// Optimized shimmer widget for lazy loading
class LazyShimmerWidget extends StatelessWidget {
  final Animation<double> shimmerAnimation;

  const LazyShimmerWidget({super.key, required this.shimmerAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                shimmerAnimation.value.clamp(0.0, 1.0),
                (shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
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

/// Optimized loading indicator widget for lazy loading
class LazyLoadingIndicatorWidget extends StatelessWidget {
  final LazyLoadingState state;
  final int retryCount;
  final LazyLoadingConfig config;
  final Widget Function()? placeholderBuilder;
  final Animation<double> shimmerAnimation;

  const LazyLoadingIndicatorWidget({
    super.key,
    required this.state,
    required this.retryCount,
    required this.config,
    this.placeholderBuilder,
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LazyPlaceholderWidget(
          placeholderBuilder: placeholderBuilder,
          config: config,
          shimmerAnimation: shimmerAnimation,
        ),
        const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
        if (state == LazyLoadingState.retrying)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Retry $retryCount/${config.maxRetries}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

/// Optimized error widget for lazy loading
class LazyErrorWidget extends StatelessWidget {
  final Object error;
  final Widget Function(Object error, VoidCallback retry)? errorBuilder;
  final LazyLoadingConfig config;
  final Widget Function()? placeholderBuilder;
  final Animation<double> shimmerAnimation;
  final VoidCallback onRetry;

  const LazyErrorWidget({
    super.key,
    required this.error,
    this.errorBuilder,
    required this.config,
    this.placeholderBuilder,
    required this.shimmerAnimation,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (errorBuilder != null) {
      return errorBuilder!(error, onRetry);
    }

    if (!config.enableErrorWidget) {
      return LazyPlaceholderWidget(
        placeholderBuilder: placeholderBuilder,
        config: config,
        shimmerAnimation: shimmerAnimation,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'Failed to load',
            style: TextStyle(color: Colors.red[700], fontSize: 12),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 32),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Lazy loading list widget for efficient scrolling
class LazyLoadingList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? placeholderBuilder;
  final LazyLoadingConfig config;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const LazyLoadingList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.placeholderBuilder,
    this.config = const LazyLoadingConfig(),
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<LazyLoadingList> createState() => _LazyLoadingListState();
}

class _LazyLoadingListState extends State<LazyLoadingList> {
  final Set<int> _loadedIndices = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return LazyLoadingWidget(
          cacheKey: 'list_item_$index',
          config: widget.config,
          contentBuilder: () async {
            _loadedIndices.add(index);
            return widget.itemBuilder(context, index);
          },
          placeholderBuilder: widget.placeholderBuilder != null
              ? () => widget.placeholderBuilder!(context, index)
              : null,
        );
      },
    );
  }
}
