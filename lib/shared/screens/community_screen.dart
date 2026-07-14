import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/themes/app_colors.dart';
import '../models/community_post.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';
import 'create_post_screen.dart';
import 'community_post_detail_screen.dart';

/// Community Screen - For temple community posts and interactions
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  late TabController _tabController;
  late ScrollController _scrollController;
  int _limit = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _retryLoadPosts() {
    setState(() {
      _limit = 20; // Reset to initial limit
    });
  }

  /// ✅ NEW: Listen for scroll position to load more items
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // User scrolled to bottom
      if (!_isLoadingMore) {
        setState(() {
          _limit += 20;
          _isLoadingMore = true;
        });
        // Reset flag after a short delay to allow data to load
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _isLoadingMore = false);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Community',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
              );
            },
            color: AppColors.primaryOrange,
            tooltip: 'Create Post',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryOrange,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Stories'),
            Tab(text: 'Photos'),
            Tab(text: 'Questions'),
          ],
        ),
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _communityService.watchCommunityPosts(limit: _limit),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          final posts = snapshot.data ?? [];
          return _buildContent(posts);
        },
      ),
    );
  }

  Widget _buildContent(List<CommunityPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildPostsList(posts),
        _buildPostsList(
          posts.where((p) => p.type == CommunityPostType.story).toList(),
        ),
        _buildPostsList(
          posts.where((p) => p.type == CommunityPostType.photo).toList(),
        ),
        _buildPostsList(
          posts.where((p) => p.type == CommunityPostType.question).toList(),
        ),
      ],
    );
  }

  Widget _buildPostsList(List<CommunityPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      key: PageStorageKey('community_list_tab_${_tabController.index}'),
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CommunityPostCard(
            post: posts[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CommunityPostDetailScreen(post: posts[index]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildPostSkeleton(),
        ),
      ),
    );
  }

  Widget _buildPostSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 120, color: Colors.white),
                    const SizedBox(height: 4),
                    Container(height: 11, width: 80, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content lines
          Container(height: 13, color: Colors.white),
          const SizedBox(height: 6),
          Container(height: 13, width: 200, color: Colors.white),
          const SizedBox(height: 12),
          // Image placeholder
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          // Action row
          Row(
            children: [
              Container(height: 20, width: 60, color: Colors.white),
              const SizedBox(width: 16),
              Container(height: 20, width: 60, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _retryLoadPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 40,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to share your experience',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
