import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../temple/services/channel_id_extractor.dart';

class UpdateChannelIdWidget extends StatefulWidget {
  const UpdateChannelIdWidget({super.key});

  @override
  State<UpdateChannelIdWidget> createState() => _UpdateChannelIdWidgetState();
}

class _UpdateChannelIdWidgetState extends State<UpdateChannelIdWidget> {
  final _channelUrlController = TextEditingController();
  final _extractor = ChannelIdExtractor(); // Create instance
  bool _isLoading = false;
  String? _extractedChannelId;
  String? _selectedTempleId;
  List<Map<String, dynamic>> _templesWithFallbackIds = [];

  @override
  void initState() {
    super.initState();
    _loadTemplesWithFallbackIds();
  }

  @override
  void dispose() {
    _channelUrlController.dispose();
    _extractor.dispose();
    super.dispose();
  }

  Future<void> _loadTemplesWithFallbackIds() async {
    try {
      // Load temples with fallback channel IDs (mock IDs starting with UC00000)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('temples')
          .where('liveDarshan.youtubeChannelId', isGreaterThanOrEqualTo: 'UC00000')
          .where('liveDarshan.youtubeChannelId', isLessThan: 'UC00001')
          .get();

      // Also check for the specific temples mentioned in the issue
      final specificTempleIds = [
        'BEz1yU1OcmeqU9PupBgo',
        'WXUQ5xm3p5n6lq5onOLL', 
        'd6VGXP5xBfoCLVDVk7ns',
      ];

      final allTemples = <Map<String, dynamic>>[];
      
      // Add temples from query
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final channelId = data['liveDarshan']?['youtubeChannelId'] as String? ?? 'N/A';
        
        allTemples.add({
          'id': doc.id,
          'name': data['name'] as String? ?? 'Unknown Temple',
          'channelId': channelId,
          'channelUrl': data['liveDarshan']?['youtubeChannelUrl'] as String? ?? '',
          'needsUpdate': channelId.contains('UC00000') || channelId == 'N/A',
        });
      }
      
      // Check specific temples
      for (final templeId in specificTempleIds) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('temples')
              .doc(templeId)
              .get();
              
          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              final channelId = data['liveDarshan']?['youtubeChannelId'] as String?;
              
              // Include if it has a mock ID or needs verification
              if (channelId == null || 
                  channelId.contains('UC00000') || 
                  channelId == 'UCI1r_MNxzyvUPHyTdWDe4NA') {
                
                // Check if already added
                final alreadyExists = allTemples.any((temple) => temple['id'] == templeId);
                if (!alreadyExists) {
                  String suggestedUrl = data['liveDarshan']?['youtubeChannelUrl'] as String? ?? '';
                  if (suggestedUrl.isEmpty) {
                    switch (templeId) {
                      case 'BEz1yU1OcmeqU9PupBgo':
                        suggestedUrl = 'https://youtube.com/@salangpurhanumanji';
                        break;
                      case 'WXUQ5xm3p5n6lq5onOLL':
                        suggestedUrl = 'Needs verification - check if UCI1r_MNxzyvUPHyTdWDe4NA is valid';
                        break;
                      case 'd6VGXP5xBfoCLVDVk7ns':
                        suggestedUrl = 'Please provide the correct YouTube channel URL';
                        break;
                    }
                  }
                  
                  allTemples.add({
                    'id': templeId,
                    'name': data['name'] as String? ?? 'Unknown Temple',
                    'channelId': channelId ?? 'N/A',
                    'channelUrl': suggestedUrl,
                    'needsUpdate': true,
                  });
                }
              }
            }
          }
        } catch (e) {
          print('Could not load temple $templeId: $e');
        }
      }

      setState(() {
        _templesWithFallbackIds = allTemples;
      });
    } catch (e) {
      print('❌ Error loading temples with fallback IDs: $e');
    }
  }

  Future<void> _extractChannelId() async {
    final url = _channelUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a YouTube channel URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _extractedChannelId = null;
    });

    try {
      final channelId = await _extractor.extractAndValidateChannelId(url);
      
      setState(() {
        _extractedChannelId = channelId;
        _isLoading = false;
      });

      if (channelId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Extracted Channel ID: $channelId'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Could not extract channel ID from URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error extracting channel ID: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTempleChannelId() async {
    if (_selectedTempleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a temple to update'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_extractedChannelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please extract a valid channel ID first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final channelUrl = _channelUrlController.text.trim();

      // 1. Update Firestore
      await FirebaseFirestore.instance
          .collection('temples')
          .doc(_selectedTempleId)
          .update({
        'liveDarshan.youtubeChannelId': _extractedChannelId,
            'liveDarshan.youtubeChannelUrl': channelUrl,
        'liveDarshan.lastChannelUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Upsert into Supabase so the live detection cron can find this temple
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('temples').upsert({
          'id': _selectedTempleId,
          'firebase_temple_id': _selectedTempleId,
          'youtube_channel_id': _extractedChannelId,
          'youtube_channel_url': channelUrl,
          'is_currently_live': false,
        }, onConflict: 'id');
        print('✅ Supabase row upserted for temple $_selectedTempleId');
      } catch (supabaseError) {
        // Non-fatal — Firestore is updated, Supabase will sync on next cron run
        print('⚠️ Supabase upsert failed (non-fatal): $supabaseError');
      }

      // Reload the list
      await _loadTemplesWithFallbackIds();

      setState(() {
        _isLoading = false;
        _selectedTempleId = null;
        _extractedChannelId = null;
        _channelUrlController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Temple channel ID updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating temple: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _quickFixKnownTemples() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fix Salangpur Hanuman Temple
      await _fixSpecificTemple(
        'BEz1yU1OcmeqU9PupBgo',
        'https://youtube.com/@salangpurhanumanji',
        'Salangpur Hanuman Temple',
      );

      // Verify Temple 2 channel ID
      await _verifyTempleChannelId(
        'WXUQ5xm3p5n6lq5onOLL',
        'UCI1r_MNxzyvUPHyTdWDe4NA',
        'Temple 2',
      );

      // Reload the list
      await _loadTemplesWithFallbackIds();

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Quick fix completed! Check results above.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Quick fix failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fixSpecificTemple(
    String templeId,
    String channelUrl,
    String templeName,
  ) async {
    try {
      print('🔧 Fixing $templeName...');
      
      final channelId = await _extractor.extractAndValidateChannelId(channelUrl);
      
      if (channelId != null) {
        await FirebaseFirestore.instance
            .collection('temples')
            .doc(templeId)
            .update({
          'liveDarshan.youtubeChannelId': channelId,
          'liveDarshan.youtubeChannelUrl': channelUrl,
          'liveDarshan.lastChannelUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Fixed $templeName with channel ID: $channelId');
      } else {
        print('❌ Could not extract channel ID for $templeName');
      }
    } catch (e) {
      print('❌ Error fixing $templeName: $e');
    }
  }

  Future<void> _verifyTempleChannelId(
    String templeId,
    String channelId,
    String templeName,
  ) async {
    try {
      print('🔍 Verifying $templeName channel ID...');
      
      final channelInfo = await _extractor.getChannelInfo(channelId);
      
      if (channelInfo != null && 
          channelInfo['items'] != null && 
          (channelInfo['items'] as List).isNotEmpty) {
        print('✅ $templeName channel ID is valid: $channelId');
        
        // Update last verification timestamp
        await FirebaseFirestore.instance
            .collection('temples')
            .doc(templeId)
            .update({
          'liveDarshan.lastChannelVerification': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        print('❌ $templeName channel ID is invalid: $channelId');
      }
    } catch (e) {
      print('❌ Error verifying $templeName: $e');
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
            Row(
              children: [
                const Icon(Icons.update, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Update Channel ID',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Fix temples with fallback channel IDs to enable live detection',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Temples with fallback IDs
            if (_templesWithFallbackIds.isNotEmpty) ...[
              const Text(
                'Temples with Fallback Channel IDs:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _templesWithFallbackIds.length,
                  itemBuilder: (context, index) {
                    final temple = _templesWithFallbackIds[index];
                    final isSelected = _selectedTempleId == temple['id'];
                    
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.orange[50],
                      title: Text(temple['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: ${temple['channelId']}',
                            style: TextStyle(
                              color: temple['needsUpdate'] == true 
                                  ? Colors.red[700] 
                                  : Colors.grey[600],
                              fontWeight: temple['needsUpdate'] == true 
                                  ? FontWeight.w500 
                                  : FontWeight.normal,
                            ),
                          ),
                          if (temple['channelUrl'] != 'N/A' && temple['channelUrl'].isNotEmpty)
                            Text(
                              'URL: ${temple['channelUrl']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: temple['channelUrl'].startsWith('http') 
                                    ? Colors.orange[600] 
                                    : Colors.orange[700],
                              ),
                            ),
                        ],
                      ),
                      leading: temple['needsUpdate'] == true
                          ? Icon(Icons.warning, color: Colors.orange[700])
                          : Icon(Icons.info, color: Colors.orange[600]),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Colors.orange)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedTempleId = temple['id'];
                          if (temple['channelUrl'] != 'N/A' && 
                              temple['channelUrl'].startsWith('http')) {
                            _channelUrlController.text = temple['channelUrl'];
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No temples found with fallback channel IDs',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Channel URL input
            TextFormField(
              controller: _channelUrlController,
              decoration: InputDecoration(
                labelText: 'YouTube Channel URL',
                hintText: 'https://youtube.com/@salangpurhanumanji',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _extractChannelId,
                        icon: const Icon(Icons.search),
                        tooltip: 'Extract Channel ID',
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Extracted channel ID display
            if (_extractedChannelId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Extracted Channel ID:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _extractedChannelId!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valid: ${_extractor.isValidChannelId(_extractedChannelId!) ? "✅ Yes" : "❌ No"}',
                      style: TextStyle(
                        color: _extractor.isValidChannelId(_extractedChannelId!)
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _extractChannelId,
                    icon: const Icon(Icons.search),
                    label: const Text('Extract Channel ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || 
                               _selectedTempleId == null || 
                               _extractedChannelId == null)
                        ? null
                        : _updateTempleChannelId,
                    icon: const Icon(Icons.update),
                    label: const Text('Update Temple'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Quick fix button for known temples
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _quickFixKnownTemples,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Quick Fix Known Temples'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Instructions:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Select a temple from the list above\n'
                    '2. Enter the correct YouTube channel URL\n'
                    '3. Click "Extract Channel ID" to get the real channel ID\n'
                    '4. Click "Update Temple" to save the changes\n'
                    '5. Live detection will work after the update',
                    style: TextStyle(fontSize: 13),
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