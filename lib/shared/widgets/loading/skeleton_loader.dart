import 'package:flutter/material.dart';

/// Optimized skeleton loader widget for temple list items
class TempleSkeletonLoader extends StatefulWidget {
  final int itemCount;
  final Duration animationDuration;
  final bool showShimmer;

  const TempleSkeletonLoader({
    super.key,
    this.itemCount = 5,
    this.animationDuration = const Duration(milliseconds: 1200),
    this.showShimmer = true,
  });

  @override
  State<TempleSkeletonLoader> createState() => _TempleSkeletonLoaderState();
}

class _TempleSkeletonLoaderState extends State<TempleSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    if (widget.showShimmer) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).disableAnimations
        ? _buildStaticSkeleton()
        : _buildAnimatedSkeleton();
  }

  Widget _buildAnimatedSkeleton() {
    return ListView.builder(
      itemCount: widget.itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildShimmerEffect(_buildSkeletonItem()),
        );
      },
    );
  }

  Widget _buildStaticSkeleton() {
    return ListView.builder(
      itemCount: widget.itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSkeletonItem(),
        );
      },
    );
  }

  Widget _buildShimmerEffect(Widget child) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.transparent,
                Colors.white54,
                Colors.transparent,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }

  Widget _buildSkeletonItem() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Temple image skeleton
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            // Temple info skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Temple name
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Temple title
                  Container(
                    height: 16,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Container(
                    height: 14,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Timing
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized skeleton loader for forms
class FormSkeletonLoader extends StatelessWidget {
  final int fieldCount;
  final bool showShimmer;

  const FormSkeletonLoader({
    super.key,
    this.fieldCount = 4,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).disableAnimations
        ? _buildStaticSkeleton()
        : _buildAnimatedSkeleton();
  }

  Widget _buildAnimatedSkeleton() {
    return Column(
      children: List.generate(fieldCount, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildShimmerEffect(_buildSkeletonField()),
        );
      }),
    );
  }

  Widget _buildStaticSkeleton() {
    return Column(
      children: List.generate(fieldCount, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSkeletonField(),
        );
      }),
    );
  }

  Widget _buildShimmerEffect(Widget child) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildSkeletonField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
    );
  }
}

/// Optimized skeleton loader for image grids
class ImageGridSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final bool showShimmer;

  const ImageGridSkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).disableAnimations
        ? _buildStaticSkeleton()
        : _buildAnimatedSkeleton();
  }

  Widget _buildAnimatedSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildShimmerEffect(_buildSkeletonImage());
      },
    );
  }

  Widget _buildStaticSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildSkeletonImage();
      },
    );
  }

  Widget _buildShimmerEffect(Widget child) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildSkeletonImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Generic skeleton widget for custom layouts
class SkeletonWidget extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final bool showShimmer;

  const SkeletonWidget({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    final skeleton = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );

    if (!showShimmer || MediaQuery.of(context).disableAnimations) {
      return skeleton;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
}

/// Skeleton loader for search results
class SearchSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool showShimmer;

  const SearchSkeletonLoader({
    super.key,
    this.itemCount = 3,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).disableAnimations
        ? _buildStaticSkeleton()
        : _buildAnimatedSkeleton();
  }

  Widget _buildAnimatedSkeleton() {
    return Column(
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: _buildShimmerEffect(_buildSkeletonSearchItem()),
        );
      }),
    );
  }

  Widget _buildStaticSkeleton() {
    return Column(
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: _buildSkeletonSearchItem(),
        );
      }),
    );
  }

  Widget _buildShimmerEffect(Widget child) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildSkeletonSearchItem() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 12,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
