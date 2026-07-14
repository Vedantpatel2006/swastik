import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../shared/models/temple.dart';
import '../../../../core/themes/app_colors.dart';

/// Live Now Section
/// Layout: large full-bleed thumbnail cards with gradient text overlay
/// Primary: temples where liveDarshan.isCurrentlyLive == true
/// Fallback: random temples when nothing is live
class LiveNowSection extends StatefulWidget {
  final List<Temple> temples;
  final Function(Temple) onTempleTap;

  const LiveNowSection({
    super.key,
    required this.temples,
    required this.onTempleTap,
  });

  @override
  State<LiveNowSection> createState() => _LiveNowSectionState();
}

class _LiveNowSectionState extends State<LiveNowSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late List<Temple> _fallbackTemples;

  /// IDs of temples currently marked live in Firestore (real-time).
  Set<String> _liveTempleIds = {};
  StreamSubscription<QuerySnapshot>? _liveStatusSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize fallback temples once with a fixed seed for consistency
    _fallbackTemples = List<Temple>.from(widget.temples);
    _fallbackTemples.shuffle(Random(42));

    // Seed live IDs from the initial list so the UI is correct immediately
    _liveTempleIds = widget.temples
        .where((t) => t.liveDarshan?.isCurrentlyLive == true)
        .map((t) => t.id)
        .toSet();

    // Subscribe to Firestore for real-time live status changes
    _liveStatusSub = FirebaseFirestore.instance
        .collection('temples')
        .where('isCurrentlyLive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _liveTempleIds = snapshot.docs.map((d) => d.id).toSet();
          });
        });
  }

  @override
  void didUpdateWidget(LiveNowSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep fallback list in sync if parent passes new temples
    if (oldWidget.temples != widget.temples) {
      _fallbackTemples = List<Temple>.from(widget.temples);
      _fallbackTemples.shuffle(Random(42));
    }
  }

  @override
  void dispose() {
    _liveStatusSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveTemples = widget.temples
        .where((t) => _liveTempleIds.contains(t.id))
        .toList();

    final isLive = liveTemples.isNotEmpty;

    List<Temple> displayTemples;
    if (isLive) {
      displayTemples = liveTemples.take(5).toList();
    } else {
      // Use pre-shuffled fallback temples
      displayTemples = _fallbackTemples.take(5).toList();
    }

    if (displayTemples.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (isLive) ...[
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.liveRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ] else ...[
                const Icon(
                  Icons.play_circle_rounded,
                  size: 20,
                  color: AppColors.primaryOrange,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                isLive ? 'Live Now' : 'Watch Darshan',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              if (!isLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.borderGray,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'No stream right now',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Cards — full-bleed thumbnail style
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayTemples.length,
            itemBuilder: (context, index) {
              final temple = displayTemples[index];
              final isThisLive = _liveTempleIds.contains(temple.id);
              return _ThumbnailCard(
                temple: temple,
                isLive: isThisLive,
                pulseAnim: isThisLive ? _pulseAnim : null,
                onTap: () => widget.onTempleTap(temple),
                showMargin: index < displayTemples.length - 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThumbnailCard extends StatelessWidget {
  final Temple temple;
  final bool isLive;
  final Animation<double>? pulseAnim;
  final VoidCallback onTap;
  final bool showMargin;

  const _ThumbnailCard({
    required this.temple,
    required this.isLive,
    required this.onTap,
    this.pulseAnim,
    this.showMargin = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 220,
        margin: EdgeInsets.only(right: showMargin ? 12 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-bleed image
              _buildImage(),

              // Bottom gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),

              // Center play button for non-live fallback
              if (!isLive)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                ),

              // Bottom text: name + location
              Positioned(
                left: 10,
                right: 10,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      temple.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 10,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _locationText(),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Top-left: LIVE or WATCH badge
              Positioned(
                top: 10,
                left: 10,
                child: isLive && pulseAnim != null
                    ? AnimatedBuilder(
                        animation: pulseAnim!,
                        builder: (_, __) => Transform.scale(
                          scale: 0.92 + (pulseAnim!.value * 0.08),
                          child: _liveBadge(pulsing: true, alpha: pulseAnim!.value),
                        ),
                      )
                    : _watchBadge(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    const placeholders = [
      'assets/images/deities/ganesha.png',
      'assets/images/deities/krishna.png',
      'assets/images/deities/hanuman.png',
      'assets/images/deities/durga.png',
      'assets/images/deities/temple.png',
    ];

    if (temple.images.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: temple.images.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.lightGray,
          highlightColor: AppColors.white,
          child: Container(color: AppColors.lightGray),
        ),
        errorWidget: (_, __, ___) => Image.asset(
          placeholders[temple.id.hashCode % placeholders.length],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.lightGray,
            child: const Icon(
              Icons.temple_hindu,
              color: AppColors.secondaryText,
              size: 48,
            ),
          ),
        ),
      );
    }

    return Image.asset(
      placeholders[temple.id.hashCode % placeholders.length],
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.lightGray,
        child: const Icon(
          Icons.temple_hindu,
          color: AppColors.secondaryText,
          size: 48,
        ),
      ),
    );
  }

  Widget _liveBadge({required bool pulsing, double alpha = 1.0}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.liveRed.withValues(alpha: 0.85 + alpha * 0.15),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: AppColors.liveRed.withValues(alpha: alpha * 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: AppColors.white),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 11, color: AppColors.white),
          SizedBox(width: 3),
          Text(
            'WATCH',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  String _locationText() {
    final parts = <String>[];
    if (temple.location.city?.isNotEmpty == true) parts.add(temple.location.city!);
    if (temple.location.state?.isNotEmpty == true) parts.add(temple.location.state!);
    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }
}
