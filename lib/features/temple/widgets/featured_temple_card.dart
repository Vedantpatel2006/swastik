import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../services/realtime_live_provider.dart';

class FeaturedTempleCard extends StatefulWidget {
  final Temple temple;
  final VoidCallback onTap;
  final VoidCallback onDonate;

  const FeaturedTempleCard({
    super.key,
    required this.temple,
    required this.onTap,
    required this.onDonate,
  });

  @override
  State<FeaturedTempleCard> createState() => _FeaturedTempleCardState();
}

class _FeaturedTempleCardState extends State<FeaturedTempleCard> {
  StreamSubscription<LiveStatus>? _liveSubscription;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _isLive = widget.temple.liveDarshan?.isCurrentlyLive == true;
    _initLiveStream();
  }

  void _initLiveStream() {
    if (widget.temple.liveDarshan?.isConfiguredByAdmin == true) {
      try {
        final liveProvider = RealtimeLiveProvider();
        _liveSubscription = liveProvider
            .watchLiveStatus(widget.temple.id)
            .listen(
              (liveStatus) {
                if (mounted) {
                  setState(() {
                    _isLive = liveStatus.isLive && !liveStatus.isStale;
                  });
                }
              },
              onError: (error) {
                debugPrint('FeaturedTempleCard: Error watching live status: $error');
              },
            );
      } catch (error) {
        debugPrint('FeaturedTempleCard: RealtimeLiveProvider error: $error');
      }
    }
  }

  @override
  void didUpdateWidget(FeaturedTempleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.temple.id != widget.temple.id) {
      _liveSubscription?.cancel();
      _isLive = widget.temple.liveDarshan?.isCurrentlyLive == true;
      _initLiveStream();
    }
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = screenWidth * 0.65; // 65% of screen width
    final isLive = _isLive;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full Background Image
              widget.temple.images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.temple.images.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF7A00),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[400]!,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.temple_hindu, 
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[300]!,
                            Colors.grey[400]!,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.temple_hindu, 
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),

              // Glassmorphism gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // Content Overlay
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIVE Badge (Top-left) - Only show if live
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF0844), Color(0xFFFF6B6B)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0844).withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 8,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'LIVE DARSHAN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Bottom Content Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Temple Name (Bottom-left)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.temple.name.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' '),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.temple.location.city != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.temple.location.city!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Donate Button (Bottom-right)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onDonate,
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '❤️',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Donate',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
