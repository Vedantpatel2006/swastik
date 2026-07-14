import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';

/// Auto-swiping carousel for live temples with full-width background images
class LiveTempleCarousel extends StatefulWidget {
  final List<Temple> liveTemples;
  final Function(Temple) onTempleTap;
  final Function(Temple) onDonateTap;
  final Duration autoPlayDuration;

  const LiveTempleCarousel({
    super.key,
    required this.liveTemples,
    required this.onTempleTap,
    required this.onDonateTap,
    this.autoPlayDuration = const Duration(seconds: 5),
  });

  @override
  State<LiveTempleCarousel> createState() => _LiveTempleCarouselState();
}

class _LiveTempleCarouselState extends State<LiveTempleCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.liveTemples.length > 1) {
      _autoPlayTimer = Timer.periodic(widget.autoPlayDuration, (timer) {
        if (_pageController.hasClients) {
          final nextPage = (_currentPage + 1) % widget.liveTemples.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveTemples.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onPanDown: (_) => _stopAutoPlay(),
      onPanEnd: (_) => _startAutoPlay(),
      child: Column(
        children: [
          // Carousel
          SizedBox(
            height: 420,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: widget.liveTemples.length,
              itemBuilder: (context, index) {
                return _buildCarouselCard(widget.liveTemples[index]);
              },
            ),
          ),

          // Pagination Dots
          const SizedBox(height: 16),
          _buildPaginationDots(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(Temple temple) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            _buildBackgroundImage(temple),

            // Gradient Overlay
            _buildGradientOverlay(),

            // Content
            _buildContent(temple),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage(Temple temple) {
    final imageUrl = temple.images.isNotEmpty ? temple.images.first : null;

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholderImage();
        },
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFF8E53),
            Color(0xFFFFA726),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.temple_hindu,
          size: 120,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent(Temple temple) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Live Badge
          Row(
            children: [
              _buildLiveBadge(temple),
              const Spacer(),
            ],
          ),

          const Spacer(),

          // Bottom Section: Temple Info and Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temple Name
              Text(
                temple.name,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Location
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${temple.location.city ?? 'Unknown'}, ${temple.location.state ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  // Watch Live Button
                  Expanded(
                    flex: 2,
                    child: _buildWatchLiveButton(temple),
                  ),
                  const SizedBox(width: 12),

                  // Donate Button
                  Expanded(
                    child: _buildDonateButton(temple),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge(Temple temple) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation for pulsing effect
        setState(() {});
      },
    );
  }

  Widget _buildWatchLiveButton(Temple temple) {
    return ElevatedButton(
      onPressed: () => widget.onTempleTap(temple),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFFF3B30),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_filled, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Watch Live',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonateButton(Temple temple) {
    return ElevatedButton(
      onPressed: () => widget.onDonateTap(temple),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        elevation: 0,
      ),
      child: const Icon(Icons.volunteer_activism, size: 24),
    );
  }

  Widget _buildPaginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.liveTemples.length,
        (index) => _buildDot(index),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
