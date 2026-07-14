import 'package:flutter/material.dart';
import '../animations/loading_animations.dart';

/// Comprehensive loading indicators for search operations and filter applications
/// Implements requirements 7.1, 7.2, 7.3
class ComprehensiveLoadingIndicators {
  /// Creates a search operation loading indicator with progress feedback
  static Widget searchOperationLoading({
    String? searchQuery,
    int? estimatedResults,
    Duration? searchTime,
    bool showProgress = true,
    double? progress,
  }) {
    return _SearchLoadingWidget(
      searchQuery: searchQuery,
      estimatedResults: estimatedResults,
      searchTime: searchTime,
      showProgress: showProgress,
      progress: progress,
    );
  }

  /// Creates skeleton placeholders for expected search results content
  static Widget searchResultsSkeleton({
    int itemCount = 5,
    double itemHeight = 200.0,
    bool showFilters = true,
  }) {
    return _SearchResultsSkeletonWidget(
      itemCount: itemCount,
      itemHeight: itemHeight,
      showFilters: showFilters,
    );
  }

  /// Creates filter application processing state indicator
  static Widget filterProcessingState({
    required List<String> activeFilters,
    String? currentFilter,
    double? progress,
    int? matchingResults,
  }) {
    return _FilterProcessingWidget(
      activeFilters: activeFilters,
      currentFilter: currentFilter,
      progress: progress,
      matchingResults: matchingResults,
    );
  }

  /// Creates a comprehensive loading overlay for full-screen operations
  static Widget loadingOverlay({
    required String operation,
    String? details,
    double? progress,
    bool canCancel = false,
    VoidCallback? onCancel,
  }) {
    return _LoadingOverlayWidget(
      operation: operation,
      details: details,
      progress: progress,
      canCancel: canCancel,
      onCancel: onCancel,
    );
  }

  /// Creates inline loading indicator for specific UI sections
  static Widget inlineLoading({
    required String message,
    bool compact = false,
    Color? color,
  }) {
    return _InlineLoadingWidget(
      message: message,
      compact: compact,
      color: color,
    );
  }

  /// Creates progressive loading indicator that shows stages
  static Widget progressiveLoading({
    required List<String> stages,
    int currentStage = 0,
    String? currentStageDetails,
  }) {
    return _ProgressiveLoadingWidget(
      stages: stages,
      currentStage: currentStage,
      currentStageDetails: currentStageDetails,
    );
  }
}

/// Search operation loading widget with progress feedback
class _SearchLoadingWidget extends StatefulWidget {
  final String? searchQuery;
  final int? estimatedResults;
  final Duration? searchTime;
  final bool showProgress;
  final double? progress;

  const _SearchLoadingWidget({
    this.searchQuery,
    this.estimatedResults,
    this.searchTime,
    this.showProgress = true,
    this.progress,
  });

  @override
  State<_SearchLoadingWidget> createState() => _SearchLoadingWidgetState();
}

class _SearchLoadingWidgetState extends State<_SearchLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated search icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.search,
                    size: 30,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Search status text
          Text(
            _getSearchStatusText(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Search details
          if (widget.searchQuery != null) ...[
            Text(
              'Searching for "${widget.searchQuery}"',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],

          // Progress indicator
          if (widget.showProgress) ...[
            if (widget.progress != null) ...[
              LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(widget.progress! * 100).round()}% complete',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ] else ...[
              LoadingAnimations.pulsingDots(
                color: Theme.of(context).primaryColor,
              ),
            ],
          ],

          // Estimated results
          if (widget.estimatedResults != null) ...[
            const SizedBox(height: 8),
            Text(
              'Found ${widget.estimatedResults} temples',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Search time
          if (widget.searchTime != null) ...[
            const SizedBox(height: 4),
            Text(
              'Search time: ${widget.searchTime!.inMilliseconds}ms',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  String _getSearchStatusText() {
    if (widget.progress != null && widget.progress! > 0.8) {
      return 'Finalizing results...';
    } else if (widget.progress != null && widget.progress! > 0.5) {
      return 'Processing filters...';
    } else if (widget.searchQuery != null) {
      return 'Searching temples...';
    } else {
      return 'Loading...';
    }
  }
}

/// Search results skeleton widget for expected content
class _SearchResultsSkeletonWidget extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final bool showFilters;

  const _SearchResultsSkeletonWidget({
    required this.itemCount,
    required this.itemHeight,
    required this.showFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter skeleton
        if (showFilters) ...[
          _buildFilterSkeleton(context),
          const SizedBox(height: 16),
        ],

        // Results header skeleton
        _buildResultsHeaderSkeleton(context),

        const SizedBox(height: 16),

        // Temple card skeletons
        ...List.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LoadingAnimations.templeCardSkeleton(height: itemHeight),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSkeleton(BuildContext context) {
    return LoadingAnimations.shimmerLoading(
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeaderSkeleton(BuildContext context) {
    return LoadingAnimations.shimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 80,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter processing state widget
class _FilterProcessingWidget extends StatefulWidget {
  final List<String> activeFilters;
  final String? currentFilter;
  final double? progress;
  final int? matchingResults;

  const _FilterProcessingWidget({
    required this.activeFilters,
    this.currentFilter,
    this.progress,
    this.matchingResults,
  });

  @override
  State<_FilterProcessingWidget> createState() =>
      _FilterProcessingWidgetState();
}

class _FilterProcessingWidgetState extends State<_FilterProcessingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value * 2 * 3.14159,
                    child: Icon(
                      Icons.tune,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Applying Filters',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active filters
          if (widget.activeFilters.isNotEmpty) ...[
            Text(
              'Active filters:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.activeFilters.map((filter) {
                final isCurrentFilter = filter == widget.currentFilter;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentFilter
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentFilter
                        ? Border.all(color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrentFilter) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        filter,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isCurrentFilter
                              ? Theme.of(context).primaryColor
                              : Colors.grey[700],
                          fontWeight: isCurrentFilter
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Progress bar
          if (widget.progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: widget.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(widget.progress! * 100).round()}% complete',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],

          // Matching results
          if (widget.matchingResults != null) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.matchingResults} temples match your filters',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading overlay widget for full-screen operations
class _LoadingOverlayWidget extends StatelessWidget {
  final String operation;
  final String? details;
  final double? progress;
  final bool canCancel;
  final VoidCallback? onCancel;

  const _LoadingOverlayWidget({
    required this.operation,
    this.details,
    this.progress,
    this.canCancel = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading animation
              LoadingAnimations.templeLoadingAnimation(
                size: 80,
                color: Theme.of(context).primaryColor,
              ),

              const SizedBox(height: 24),

              // Operation title
              Text(
                operation,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),

              // Details
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // Progress indicator
              if (progress != null) ...[
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress! * 100).round()}% complete',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ] else ...[
                LoadingAnimations.pulsingDots(
                  color: Theme.of(context).primaryColor,
                ),
              ],

              // Cancel button
              if (canCancel && onCancel != null) ...[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline loading widget for specific UI sections
class _InlineLoadingWidget extends StatelessWidget {
  final String message;
  final bool compact;
  final Color? color;

  const _InlineLoadingWidget({
    required this.message,
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingAnimations.pulsingDots(color: effectiveColor),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Progressive loading widget that shows stages
class _ProgressiveLoadingWidget extends StatelessWidget {
  final List<String> stages;
  final int currentStage;
  final String? currentStageDetails;

  const _ProgressiveLoadingWidget({
    required this.stages,
    this.currentStage = 0,
    this.currentStageDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: stages.isEmpty ? null : (currentStage + 1) / stages.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // Current stage
          if (currentStage < stages.length) ...[
            Row(
              children: [
                LoadingAnimations.pulsingDots(
                  color: Theme.of(context).primaryColor,
                  dotCount: 3,
                  dotSize: 6,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stages[currentStage],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (currentStageDetails != null) ...[
              const SizedBox(height: 8),
              Text(
                currentStageDetails!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ],

          const SizedBox(height: 16),

          // Stage list
          Column(
            children: stages.asMap().entries.map((entry) {
              final index = entry.key;
              final stage = entry.value;
              final isCompleted = index < currentStage;
              final isCurrent = index == currentStage;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // Stage indicator
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Theme.of(context).primaryColor
                            : isCurrent
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.3)
                            : Colors.grey[300],
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : isCurrent
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(width: 12),

                    // Stage text
                    Expanded(
                      child: Text(
                        stage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isCompleted
                              ? Theme.of(context).primaryColor
                              : isCurrent
                              ? Colors.black87
                              : Colors.grey[500],
                          fontWeight: isCurrent ? FontWeight.w500 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
