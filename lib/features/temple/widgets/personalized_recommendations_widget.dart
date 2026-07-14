import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../services/recommendation_manager.dart';
import '../../user/services/user_preferences_service.dart';
import '../../../shared/services/location_service.dart';
import '../../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Widget for displaying personalized temple recommendations
class PersonalizedRecommendationsWidget extends StatefulWidget {
  final int maxRecommendations;
  final bool showExplanations;
  final VoidCallback? onSeeAll;
  final Function(Temple)? onTempleSelected;

  const PersonalizedRecommendationsWidget({
    super.key,
    this.maxRecommendations = 5,
    this.showExplanations = true,
    this.onSeeAll,
    this.onTempleSelected,
  });

  @override
  State<PersonalizedRecommendationsWidget> createState() =>
      _PersonalizedRecommendationsWidgetState();
}

class _PersonalizedRecommendationsWidgetState
    extends State<PersonalizedRecommendationsWidget> {
  final RecommendationManager _recommendationManager = RecommendationManager();
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final LocationService _locationService = LocationService();
  
  List<RecommendedTemple> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  Location? _userLocation;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadRecommendations();
  }

  Future<void> _initializeAndLoadRecommendations() async {
    try {
      await _recommendationManager.initialize();
      await _loadUserLocation();
      await _loadRecommendations();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load recommendations: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      _userLocation = await _locationService.getCurrentLocation();
    } catch (e) {
      // Continue without location - recommendations will still work
      debugPrint('Failed to get user location for recommendations: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        setState(() {
          _error = 'Please sign in to see personalized recommendations';
          _isLoading = false;
        });
        return;
      }

      // Get user preferences from the preferences service
      final preferences = await _preferencesService.getUserPreferencesById(
        user.uid,
      );

      final recommendations = await _recommendationManager.getPersonalizedRecommendations(
        preferences: preferences,
        userLocation: _userLocation,
        limit: widget.maxRecommendations,
        includeExplanations: widget.showExplanations,
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load recommendations: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshRecommendations() async {
    await _loadRecommendations();
  }

  void _onTempleInteraction(RecommendedTemple recommendation, InteractionType type) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null) {
      _recommendationManager.trackUserInteraction(
        user.uid,
        recommendation.temple.id,
        type,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recommended for You',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (widget.onSeeAll != null && _recommendations.isNotEmpty)
          TextButton(
            onPressed: widget.onSeeAll,
            child: const Text('See All'),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_recommendations.isEmpty) {
      return _buildEmptyState();
    }

    return _buildRecommendationsList();
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) => _buildLoadingCard(),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 16,
                width: double.infinity,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 4),
              Container(
                height: 12,
                width: 200,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 150,
                color: Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshRecommendations,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.temple_hindu,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            'No recommendations available yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Visit some temples to get personalized suggestions',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsList() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final recommendation = _recommendations[index];
          return RecommendationCard(
            recommendation: recommendation,
            onTap: () {
              _onTempleInteraction(recommendation, InteractionType.view);
              widget.onTempleSelected?.call(recommendation.temple);
            },
            onFavorite: () {
              _onTempleInteraction(recommendation, InteractionType.favorite);
            },
            onShare: () {
              _onTempleInteraction(recommendation, InteractionType.share);
            },
            showExplanation: widget.showExplanations,
          );
        },
      ),
    );
  }
}

/// Individual recommendation card widget
class RecommendationCard extends StatelessWidget {
  final RecommendedTemple recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final bool showExplanation;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.onFavorite,
    this.onShare,
    this.showExplanation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 4),
                      _buildLocation(),
                      const SizedBox(height: 8),
                      if (showExplanation) _buildExplanation(),
                      const Spacer(),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final temple = recommendation.temple;
    
    return Stack(
      children: [
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: temple.images.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(temple.images.first),
                    fit: BoxFit.cover,
                    onError: (error, stackTrace) {
                      // Handle image loading error
                    },
                  )
                : null,
          ),
          child: temple.images.isEmpty
              ? Icon(
                  Icons.temple_hindu,
                  size: 32,
                  color: Colors.grey[600],
                )
              : null,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildScoreBadge(),
        ),
        if (temple.liveDarshan?.isCurrentlyLive == true)
          Positioned(
            top: 8,
            left: 8,
            child: _buildLiveBadge(),
          ),
      ],
    );
  }

  Widget _buildScoreBadge() {
    final score = recommendation.relevanceScore;
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${score.toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.circle,
            size: 6,
            color: Colors.white,
          ),
          SizedBox(width: 2),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final temple = recommendation.temple;
    
    return Row(
      children: [
        Expanded(
          child: Text(
            temple.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFavorite != null)
              InkWell(
                onTap: onFavorite,
                child: Icon(
                  temple.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: temple.isFavorite ? Colors.red : Colors.grey,
                ),
              ),
            if (onShare != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onShare,
                child: const Icon(
                  Icons.share,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLocation() {
    final temple = recommendation.temple;
    
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 12,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            temple.location.city ?? temple.location.address ?? 'Unknown location',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (temple.distanceFromUser != null) ...[
          const SizedBox(width: 4),
          Text(
            '${temple.distanceFromUser!.toStringAsFixed(1)}km',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExplanation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Text(
        recommendation.recommendationReason,
        style: TextStyle(
          fontSize: 11,
          color: Colors.orange[800],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFooter() {
    final temple = recommendation.temple;
    
    return Row(
      children: [
        if (temple.averageRating > 0) ...[
          Icon(
            Icons.star,
            size: 12,
            color: Colors.amber[600],
          ),
          const SizedBox(width: 2),
          Text(
            temple.averageRating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${temple.totalReviews})',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
        const Spacer(),
        if (temple.traditions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              temple.traditions.first,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen recommendations view
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationManager _recommendationManager = RecommendationManager();
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final LocationService _locationService = LocationService();
  
  List<RecommendedTemple> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  Location? _userLocation;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadRecommendations();
  }

  Future<void> _initializeAndLoadRecommendations() async {
    try {
      await _recommendationManager.initialize();
      await _loadUserLocation();
      await _loadRecommendations();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load recommendations: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      _userLocation = await _locationService.getCurrentLocation();
    } catch (e) {
      debugPrint('Failed to get user location for recommendations: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        setState(() {
          _error = 'Please sign in to see personalized recommendations';
          _isLoading = false;
        });
        return;
      }

      final preferences = await _preferencesService.getUserPreferencesById(
        user.uid,
      );

      final recommendations = await _recommendationManager.getPersonalizedRecommendations(
        preferences: preferences,
        userLocation: _userLocation,
        limit: 20,
        includeExplanations: true,
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load recommendations: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.temple_hindu,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No recommendations available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visit some temples to get personalized suggestions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recommendations.length,
      itemBuilder: (context, index) {
        final recommendation = _recommendations[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: RecommendationCard(
            recommendation: recommendation,
            onTap: () {
              // Navigate to temple details
              Navigator.pushNamed(
                context,
                '/temple_detail',
                arguments: recommendation.temple,
              );
            },
            onFavorite: () {
              // Handle favorite action
            },
            onShare: () {
              // Handle share action
            },
          ),
        );
      },
    );
  }
}