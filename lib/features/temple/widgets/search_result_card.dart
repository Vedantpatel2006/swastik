import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/models/temple.dart';
import '../services/temple_status_service.dart';
import '../../../core/services/accessibility_service.dart';

/// Comprehensive search result card widget
/// Displays temple name, location, distance, rating, and primary deity
/// Adds live darshan indicators and temple status display
/// Implements feature icons and supports paginated loading
/// (Requirements 5.1, 5.2, 5.3, 5.4, 5.5)
class SearchResultCard extends StatefulWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLiveDarshanTap;
  final bool showDistance;
  final bool showRating;
  final bool showFeatures;
  final bool showLiveIndicator;
  final bool showStatus;
  final bool isLoading;
  final int? animationIndex;

  const SearchResultCard({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.showDistance = true,
    this.showRating = true,
    this.showFeatures = true,
    this.showLiveIndicator = true,
    this.showStatus = true,
    this.isLoading = false,
    this.animationIndex,
  });

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard>
    with TickerProviderStateMixin {
  AnimationController? _slideController;
  AnimationController? _liveController;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _liveAnimation;

  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _isLive = widget.temple.liveDarshan?.isCurrentlyLive ?? false;
  }

  void _initializeAnimations() {
    if (widget.animationIndex != null) {
      _slideController = AnimationController(
        duration: Duration(milliseconds: 300 + (widget.animationIndex! * 50)),
        vsync: this,
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController!,
        curve: Curves.easeOutCubic,
      ));
      _slideController!.forward();
    }

    if (_isLive) {
      _liveController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      _liveAnimation = Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _liveController!,
        curve: Curves.easeInOut,
      ));
      _liveController!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _slideController?.dispose();
    _liveController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingCard();
    }

    final card = _buildCard(context);

    if (_slideAnimation != null) {
      return SlideTransition(
        position: _slideAnimation!,
        child: card,
      );
    }

    return card;
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildShimmer(width: 60, height: 60, borderRadius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmer(width: double.infinity, height: 16),
                    const SizedBox(height: 8),
                    _buildShimmer(width: 200, height: 14),
                    const SizedBox(height: 8),
                    _buildShimmer(width: 150, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildShimmer(width: 80, height: 24, borderRadius: 12),
              const SizedBox(width: 8),
              _buildShimmer(width: 60, height: 24, borderRadius: 12),
              const Spacer(),
              _buildShimmer(width: 40, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer({
    required double width,
    required double height,
    double borderRadius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;
    final semanticLabel = accessibilityService.createTempleSemanticLabel(
      widget.temple.name,
      location: widget.temple.location.address,
      distance: widget.showDistance && widget.temple.distanceFromUser != null
          ? '${widget.temple.distanceFromUser!.toStringAsFixed(1)} km'
          : null,
      isLive: _isLive,
      isFavorite: widget.temple.isFavorite,
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: widget.onTap != null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildContent(),
                  if (widget.showFeatures &&
                      widget.temple.features.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildFeatures(),
                  ],
                  const SizedBox(height: 12),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Temple image or placeholder
        _buildTempleImage(),
        const SizedBox(width: 12),
        
        // Temple info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temple name with live indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.temple.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.showLiveIndicator && _isLive)
                    AbsorbPointer(
                      absorbing: widget.onLiveDarshanTap == null,
                      child: _buildLiveIndicator(),
                    ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Primary deity/tradition
              if (widget.temple.traditions.isNotEmpty)
                Text(
                  widget.temple.traditions.first,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              
              const SizedBox(height: 4),
              
              // Location
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getLocationText(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
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
        
        // Favorite button
        if (widget.onFavoriteToggle != null)
          AbsorbPointer(absorbing: false, child: _buildFavoriteButton()),
      ],
    );
  }

  Widget _buildTempleImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: widget.temple.images.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.temple.images.first,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImagePlaceholder();
                },
              ),
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.temple_hindu,
        size: 24,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    final indicator = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_liveAnimation != null)
            AnimatedBuilder(
              animation: _liveAnimation!,
              builder: (context, child) {
                return Opacity(
                  opacity: _liveAnimation!.value,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (widget.onLiveDarshanTap == null) {
      return indicator;
    }

    return GestureDetector(
      onTap: () {
        widget.onLiveDarshanTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: indicator,
    );
  }

  Widget _buildFavoriteButton() {
    return InkWell(
      onTap: widget.onFavoriteToggle != null
          ? () {
              HapticFeedback.selectionClick();
              widget.onFavoriteToggle!();
            }
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          widget.temple.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: widget.temple.isFavorite ? Colors.red : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Text(
      widget.temple.description.isNotEmpty
          ? widget.temple.description
          : 'No description available',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFeatures() {
    final displayFeatures = widget.temple.features.take(4).toList();
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: displayFeatures.map((feature) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFeatureIcon(feature),
                size: 12,
                color: Colors.orange[700],
              ),
              const SizedBox(width: 4),
              Text(
                feature,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        // Rating
        if (widget.showRating && widget.temple.averageRating > 0)
          _buildRating(),
        
        // Distance
        if (widget.showDistance && widget.temple.distanceFromUser != null) ...[
          if (widget.showRating && widget.temple.averageRating > 0)
            const SizedBox(width: 12),
          _buildDistance(),
        ],
        
        const Spacer(),
        
        // Status
        if (widget.showStatus)
          _buildStatus(),
      ],
    );
  }

  Widget _buildRating() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: 14,
          color: Colors.amber[600],
        ),
        const SizedBox(width: 4),
        Text(
          widget.temple.averageRating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (widget.temple.totalReviews > 0) ...[
          const SizedBox(width: 2),
          Text(
            '(${widget.temple.totalReviews})',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDistance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.near_me,
            size: 12,
            color: Colors.green[700],
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.temple.distanceFromUser!.toStringAsFixed(1)} km',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final status = TempleStatusService.getTempleStatus(widget.temple);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.statusColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.getStatusWithTime(),
            style: TextStyle(
              color: status.statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationText() {
    if (widget.temple.location.address?.isNotEmpty == true) {
      return widget.temple.location.address!;
    }
    
    final parts = <String>[];
    if (widget.temple.location.city?.isNotEmpty == true) {
      parts.add(widget.temple.location.city!);
    }
    if (widget.temple.location.state?.isNotEmpty == true) {
      parts.add(widget.temple.location.state!);
    }
    
    return parts.isNotEmpty ? parts.join(', ') : 'Location not available';
  }

  IconData _getFeatureIcon(String feature) {
    final featureLower = feature.toLowerCase();
    
    if (featureLower.contains('parking')) return Icons.local_parking;
    if (featureLower.contains('wheelchair') || featureLower.contains('accessible')) {
      return Icons.accessible;
    }
    if (featureLower.contains('food') || featureLower.contains('prasad')) {
      return Icons.restaurant;
    }
    if (featureLower.contains('accommodation') || featureLower.contains('stay')) {
      return Icons.hotel;
    }
    if (featureLower.contains('shop') || featureLower.contains('store')) {
      return Icons.store;
    }
    if (featureLower.contains('garden') || featureLower.contains('park')) {
      return Icons.park;
    }
    if (featureLower.contains('library')) return Icons.library_books;
    if (featureLower.contains('meditation')) return Icons.self_improvement;
    
    return Icons.check_circle_outline;
  }
}

/// Loading placeholder for search results during pagination
class SearchResultLoadingCard extends StatelessWidget {
  const SearchResultLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchResultCard(
      temple: Temple(
        id: 'loading',
        name: '',
        description: '',
        location: const Location(latitude: 0, longitude: 0),
        contact: const ContactInfo(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      isLoading: true,
    );
  }
}