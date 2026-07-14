import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class OptimizedTempleList extends StatefulWidget {
  final List<Map<String, dynamic>> temples;
  final Function(String) onTempleSelected;
  final ScrollController? scrollController;
  final bool hasMore;
  final Future<void> Function()? onLoadMore;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedTempleList({
    super.key,
    required this.temples,
    required this.onTempleSelected,
    this.scrollController,
    this.hasMore = false,
    this.onLoadMore,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<OptimizedTempleList> createState() => _OptimizedTempleListState();
}

class _OptimizedTempleListState extends State<OptimizedTempleList> {
  final _scrollThreshold = 200.0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore) return;
    final maxScroll = widget.scrollController?.position.maxScrollExtent ?? 0;
    final currentScroll = widget.scrollController?.position.pixels ?? 0;
    if (maxScroll - currentScroll <= _scrollThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!mounted ||
        _isLoadingMore ||
        !widget.hasMore ||
        widget.onLoadMore == null) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      await widget.onLoadMore!();
    } catch (e, stackTrace) {
      debugPrint('Error loading more temples: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to load more temples. Please try again.',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (mounted) _loadMore();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.temples.isEmpty) {
      return const Center(child: Text('No temples found'));
    }

    return ListView.builder(
      controller: widget.scrollController,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      itemCount: widget.hasMore
          ? widget.temples.length + 1
          : widget.temples.length,
      itemBuilder: (context, index) {
        if (index >= widget.temples.length) {
          return const _LoadingIndicator();
        }

        final temple = widget.temples[index];
        final templeId = temple['id'] as String?;
        if (templeId == null) {
          return const SizedBox.shrink(); // Skip items without an ID
        }

        return _TempleListItem(
          name: temple['name']?.toString() ?? 'Unnamed Temple',
          location: temple['location']?.toString(),
          description: temple['description']?.toString(),
          imageUrl: temple['imageUrl']?.toString() ?? '',
          onTap: () => widget.onTempleSelected(templeId),
        );
      },
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.0),
        ),
      ),
    );
  }
}

class _TempleListItem extends StatelessWidget {
  final String name;
  final String? location;
  final String? description;
  final String imageUrl;
  final VoidCallback onTap;

  const _TempleListItem({
    required this.name,
    this.location,
    this.description,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TempleImage(imageUrl: imageUrl),
            _TempleInfo(
              name: name,
              location: location,
              description: description,
            ),
          ],
        ),
      ),
    );
  }
}

class _TempleImage extends StatelessWidget {
  final String imageUrl;

  const _TempleImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _ImageShimmer(),
        errorWidget: (context, url, error) => const _ImagePlaceholder(),
        memCacheWidth: 600, // compressed in memory
        maxHeightDiskCache: 400,
        maxWidthDiskCache: 800,
      ),
    );
  }
}

class _ImageShimmer extends StatelessWidget {
  const _ImageShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.temple_hindu, size: 48, color: Colors.grey),
      ),
    );
  }
}

class _TempleInfo extends StatelessWidget {
  final String name;
  final String? location;
  final String? description;

  const _TempleInfo({required this.name, this.location, this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (location != null && location!.isNotEmpty)
            _TempleLocation(location: location!),
          if (description != null && description!.isNotEmpty)
            _TempleDescription(description: description!),
        ],
      ),
    );
  }
}

class _TempleLocation extends StatelessWidget {
  final String location;

  const _TempleLocation({required this.location});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        location,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TempleDescription extends StatelessWidget {
  final String description;

  const _TempleDescription({required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        description,
        style: const TextStyle(fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
