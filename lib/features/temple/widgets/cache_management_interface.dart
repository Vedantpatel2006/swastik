import 'package:flutter/material.dart';
import '../services/offline_state_manager.dart';

/// Comprehensive cache management interface widget
class CacheManagementInterface extends StatefulWidget {
  final OfflineStateManager offlineStateManager;
  final Function(List<CacheType>)? onClearCache;
  final VoidCallback? onOptimizeCache;

  const CacheManagementInterface({
    super.key,
    required this.offlineStateManager,
    this.onClearCache,
    this.onOptimizeCache,
  });

  @override
  State<CacheManagementInterface> createState() => _CacheManagementInterfaceState();
}

class _CacheManagementInterfaceState extends State<CacheManagementInterface> {
  CacheInfo? _cacheInfo;
  bool _isLoading = true;
  final Set<CacheType> _selectedTypes = {};

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() => _isLoading = true);
    try {
      final info = await widget.offlineStateManager.getCacheInformation();
      setState(() {
        _cacheInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cache info: $e')),
        );
      }
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
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_cacheInfo != null) ...[
              _buildCacheOverview(),
              const SizedBox(height: 16),
              _buildCacheBreakdown(),
              const SizedBox(height: 16),
              _buildCacheActions(),
              const SizedBox(height: 16),
              _buildCacheItems(),
            ] else
              const Center(child: Text('No cache information available')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.storage, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          'Cache Management',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _loadCacheInfo,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh cache info',
        ),
      ],
    );
  }

  Widget _buildCacheOverview() {
    if (_cacheInfo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Cache Size',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _cacheInfo!.totalSizeText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Items',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_cacheInfo!.items.length}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheBreakdown() {
    if (_cacheInfo == null || _cacheInfo!.sizeByType.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cache Breakdown by Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...CacheType.values.map((type) {
          final size = _cacheInfo!.sizeByType[type] ?? 0;
          final sizeText = _cacheInfo!.sizeByTypeText[type] ?? '0B';
          final itemCount = _cacheInfo!.items.where((item) => item.type == type).length;
          
          if (size == 0) return const SizedBox.shrink();
          
          return _buildCacheTypeRow(type, sizeText, itemCount);
        }).toList(),
      ],
    );
  }

  Widget _buildCacheTypeRow(CacheType type, String sizeText, int itemCount) {
    final isSelected = _selectedTypes.contains(type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedTypes.remove(type);
            } else {
              _selectedTypes.add(type);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.orange.shade200 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedTypes.add(type);
                    } else {
                      _selectedTypes.remove(type);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              Icon(
                _getCacheTypeIcon(type),
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCacheTypeName(type),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$itemCount items',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                sizeText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCacheActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cache Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _selectedTypes.isNotEmpty ? _clearSelectedCache : null,
              icon: const Icon(Icons.delete_outline),
              label: Text('Clear Selected (${_selectedTypes.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade700,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _clearAllCache,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade700,
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onOptimizeCache,
              icon: const Icon(Icons.tune),
              label: const Text('Optimize'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCacheItems() {
    if (_cacheInfo == null || _cacheInfo!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort items by size (largest first)
    final sortedItems = List<CachedItem>.from(_cacheInfo!.items)
      ..sort((a, b) => b.size.compareTo(a.size));

    // Show only top 10 items to avoid overwhelming the UI
    final displayItems = sortedItems.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Largest Cache Items',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...displayItems.map((item) => _buildCacheItemRow(item)).toList(),
        if (sortedItems.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${sortedItems.length - 10} more items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCacheItemRow(CachedItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: item.isStale ? Colors.amber.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: item.isStale ? Colors.amber.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getCacheTypeIcon(item.type),
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _truncateKey(item.key),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Accessed ${item.accessCount} times',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.sizeText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              if (item.isStale)
                Text(
                  'Stale',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade700,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCacheTypeIcon(CacheType type) {
    switch (type) {
      case CacheType.temples:
        return Icons.temple_hindu;
      case CacheType.events:
        return Icons.event;
      case CacheType.images:
        return Icons.image;
      case CacheType.recommendations:
        return Icons.recommend;
      case CacheType.searches:
        return Icons.search;
      case CacheType.userPreferences:
        return Icons.settings;
    }
  }

  String _getCacheTypeName(CacheType type) {
    switch (type) {
      case CacheType.temples:
        return 'Temples';
      case CacheType.events:
        return 'Events';
      case CacheType.images:
        return 'Images';
      case CacheType.recommendations:
        return 'Recommendations';
      case CacheType.searches:
        return 'Search Results';
      case CacheType.userPreferences:
        return 'User Preferences';
    }
  }

  String _truncateKey(String key) {
    if (key.length <= 30) return key;
    return '${key.substring(0, 27)}...';
  }

  Future<void> _clearSelectedCache() async {
    if (_selectedTypes.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      'Clear Selected Cache',
      'Are you sure you want to clear cache for ${_selectedTypes.length} selected type(s)? This action cannot be undone.',
    );

    if (confirmed == true) {
      try {
        await widget.offlineStateManager.clearCacheSelectively(_selectedTypes.toList());
        setState(() => _selectedTypes.clear());
        await _loadCacheInfo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected cache cleared successfully')),
          );
        }
        
        widget.onClearCache?.call(_selectedTypes.toList());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear cache: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await _showConfirmationDialog(
      'Clear All Cache',
      'Are you sure you want to clear all cached data? This will remove all offline content and may affect app performance until data is reloaded.',
    );

    if (confirmed == true) {
      try {
        await widget.offlineStateManager.clearCacheSelectively(CacheType.values);
        setState(() => _selectedTypes.clear());
        await _loadCacheInfo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All cache cleared successfully')),
          );
        }
        
        widget.onClearCache?.call(CacheType.values);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear cache: $e')),
          );
        }
      }
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Download progress widget for offline content
class DownloadProgressWidget extends StatelessWidget {
  final String itemName;
  final double progress;
  final bool isDownloading;
  final VoidCallback? onCancel;

  const DownloadProgressWidget({
    super.key,
    required this.itemName,
    required this.progress,
    required this.isDownloading,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDownloading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading $itemName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.orange.shade100,
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% complete',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cache optimization suggestions widget
class CacheOptimizationWidget extends StatelessWidget {
  final CacheInfo cacheInfo;
  final VoidCallback? onOptimize;

  const CacheOptimizationWidget({
    super.key,
    required this.cacheInfo,
    this.onOptimize,
  });

  @override
  Widget build(BuildContext context) {
    final staleItems = cacheInfo.items.where((item) => item.isStale).length;
    final totalSize = cacheInfo.totalSizeBytes;
    
    // Show optimization suggestions if there are stale items or cache is large
    if (staleItems == 0 && totalSize < 50 * 1024 * 1024) { // 50MB threshold
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cache Optimization',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (staleItems > 0)
            Text(
              '• $staleItems stale items can be removed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
              ),
            ),
          if (totalSize > 50 * 1024 * 1024)
            Text(
              '• Cache size is large (${cacheInfo.totalSizeText})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
              ),
            ),
          const SizedBox(height: 8),
          if (onOptimize != null)
            ElevatedButton.icon(
              onPressed: onOptimize,
              icon: const Icon(Icons.tune),
              label: const Text('Optimize Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade700,
              ),
            ),
        ],
      ),
    );
  }
}