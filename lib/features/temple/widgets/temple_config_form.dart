import 'package:flutter/material.dart';
import '../services/temple_config_manager.dart';

/// Temple Configuration Form Widget
/// 
/// Example admin interface for configuring temple live darshan settings.
/// Shows proper validation, real-time feedback, and monitoring restart.
class TempleConfigForm extends StatefulWidget {
  final String templeId;
  final String templeName;

  const TempleConfigForm({
    super.key,
    required this.templeId,
    required this.templeName,
  });

  @override
  State<TempleConfigForm> createState() => _TempleConfigFormState();
}

class _TempleConfigFormState extends State<TempleConfigForm> {
  final _formKey = GlobalKey<FormState>();
  final _channelController = TextEditingController();
  final _keywordController = TextEditingController();
  final _configManager = TempleConfigManager();

  List<String> _keywords = [];
  String? _streamQuality = '720p';
  bool _isLoading = false;
  bool _isConfigured = false;
  String? _validationError;
  String? _validationWarning;
  Map<String, dynamic>? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfiguration();
  }

  @override
  void dispose() {
    _channelController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await _configManager.getTempleConfiguration(widget.templeId);
      if (config != null) {
        setState(() {
          _currentConfig = config;
          _isConfigured = config['isConfigured'] == true;
          _channelController.text = config['channelUrl'] ?? '';
          _keywords = List<String>.from(config['keywords'] ?? []);
          _streamQuality = config['streamQuality'] ?? '720p';
        });
      }
    } catch (e) {
      _showError('Failed to load configuration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateChannel() async {
    final input = _channelController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _validationError = null;
        _validationWarning = null;
      });
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = await _configManager.validateYouTubeChannel(input);
      setState(() {
        _validationError = result.error;
        _validationWarning = result.warning;
      });
    } catch (e) {
      setState(() => _validationError = 'Validation failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addKeyword() {
    final keyword = _keywordController.text.trim();
    if (keyword.isNotEmpty && !_keywords.contains(keyword)) {
      setState(() {
        _keywords.add(keyword);
        _keywordController.clear();
      });
    }
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _keywords.remove(keyword);
    });
  }

  Future<void> _saveConfiguration() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await _configManager.saveTempleConfiguration(
        templeId: widget.templeId,
        channelInput: _channelController.text.trim(),
        keywords: _keywords,
        streamQuality: _streamQuality,
      );

      if (result.isValid) {
        _showSuccess(
          'Configuration saved successfully! ${result.warning ?? ''}'
          '\nMonitoring ${result.extractedData?['monitoringRestarted'] == true ? 'restarted' : 'will start shortly'}.'
        );
        await _loadCurrentConfiguration();
      } else {
        _showError(result.error ?? 'Failed to save configuration');
      }
    } catch (e) {
      _showError('Failed to save configuration: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testConfiguration() async {
    setState(() => _isLoading = true);

    try {
      final result = await _configManager.testTempleConfiguration(widget.templeId);
      
      if (result.isValid) {
        final data = result.extractedData;
        if (data != null) {
          _showSuccess(
            'Test completed!\n'
            'Live status: ${data['isLive'] == true ? 'LIVE' : 'OFFLINE'}\n'
            'Last check: ${data['lastCheck']?.toString() ?? 'Never'}\n'
            'Source: ${data['source'] ?? 'Unknown'}'
          );
        } else {
          _showSuccess('Test completed successfully!');
        }
      } else {
        _showError(result.error ?? 'Test failed');
      }
    } catch (e) {
      _showError('Test failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disableConfiguration() async {
    final confirmed = await _showConfirmDialog(
      'Disable Live Darshan',
      'Are you sure you want to disable live darshan for ${widget.templeName}?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final result = await _configManager.disableTempleConfiguration(widget.templeId);
      
      if (result.isValid) {
        _showSuccess('Live darshan disabled successfully');
        await _loadCurrentConfiguration();
      } else {
        _showError(result.error ?? 'Failed to disable configuration');
      }
    } catch (e) {
      _showError('Failed to disable configuration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure ${widget.templeName}'),
        actions: [
          if (_isConfigured) ...[
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _isLoading ? null : _testConfiguration,
              tooltip: 'Test Configuration',
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _isLoading ? null : _disableConfiguration,
              tooltip: 'Disable Live Darshan',
            ),
          ],
        ],
      ),
      body: _isLoading && _currentConfig == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Status Card
                    if (_currentConfig != null) _buildStatusCard(),
                    
                    const SizedBox(height: 16),
                    
                    // YouTube Channel Configuration
                    _buildChannelSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Keywords Configuration
                    _buildKeywordsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Stream Quality
                    _buildStreamQualitySection(),
                    
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final config = _currentConfig!;
    final isLive = config['isCurrentlyLive'] == true;
    final lastCheck = config['lastLiveCheck'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLive ? Icons.circle : Icons.circle_outlined,
                  color: isLive ? Colors.red : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isLive ? 'Currently Live' : 'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLive ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Status: ${_isConfigured ? 'Configured' : 'Not Configured'}'),
            if (lastCheck != null)
              Text('Last Check: ${lastCheck.toString()}'),
            Text('Source: ${config['liveStatusSource'] ?? 'Unknown'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YouTube Channel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _channelController,
          decoration: InputDecoration(
            labelText: 'Channel URL or Channel ID',
            hintText: 'https://youtube.com/channel/UC... or UC...',
            border: const OutlineInputBorder(),
            errorText: _validationError,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
              onPressed: _validateChannel,
            ),
          ),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Channel URL or ID is required';
            }
            return null;
          },
          onChanged: (_) {
            // Clear validation when user types
            if (_validationError != null) {
              setState(() {
                _validationError = null;
                _validationWarning = null;
              });
            }
          },
        ),
        if (_validationWarning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _validationWarning!,
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
      ],
    );
  }

  Widget _buildKeywordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Stream Keywords',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Keywords help identify live streams (e.g., "Live Darshan", "आरती", "Aarti")',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: 'Add keyword',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _addKeyword(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addKeyword,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _keywords.map((keyword) {
            return Chip(
              label: Text(keyword),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _removeKeyword(keyword),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStreamQualitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stream Quality',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _streamQuality,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '360p', child: Text('360p')),
            DropdownMenuItem(value: '480p', child: Text('480p')),
            DropdownMenuItem(value: '720p', child: Text('720p (Recommended)')),
            DropdownMenuItem(value: '1080p', child: Text('1080p')),
          ],
          onChanged: (value) {
            setState(() => _streamQuality = value);
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _saveConfiguration,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isConfigured ? 'Update Configuration' : 'Save Configuration'),
        ),
        if (_isConfigured) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isLoading ? null : _testConfiguration,
            child: const Text('Test Configuration'),
          ),
        ],
      ],
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
}