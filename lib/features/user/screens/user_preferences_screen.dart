import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/user_preferences.dart';
import '../services/user_preferences_service.dart';
import '../../../shared/widgets/animated_form_field.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../shared/widgets/offline_indicator.dart';

/// Screen for user customization and preferences management
class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({super.key});

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen>
    with TickerProviderStateMixin {
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Form state
  UserPreferences? _currentPreferences;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _hasUnsavedChanges = false;

  // Form values
  double _locationRadius = 50.0;
  List<String> _selectedTraditions = [];
  bool _enableLocationServices = true;
  bool _enableNotifications = true;
  String _selectedTheme = 'auto';
  String _selectedLanguage = 'en';

  // Available options
  final List<String> _availableTraditions = [
    'Hinduism',
    'Buddhism',
    'Jainism',
    'Sikhism',
    'Christianity',
    'Islam',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  Future<void> _initializeService() async {
    try {
      await _preferencesService.initialize();
      await _loadPreferences();

      // Start animations
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _slideController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize preferences: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final preferences = await _preferencesService.getUserPreferences();

      if (mounted) {
        setState(() {
          _currentPreferences = preferences;
          _locationRadius = preferences.locationRadius;
          _selectedTraditions = List.from(preferences.preferredTraditions);
          _enableLocationServices = preferences.enableLocationServices;
          _enableNotifications = preferences.enableNotifications;
          _selectedTheme = preferences.theme;
          _selectedLanguage = preferences.language;
          _isLoading = false;
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load preferences: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _error = null;
      });

      final updatedPreferences = _currentPreferences!.copyWith(
        locationRadius: _locationRadius,
        preferredTraditions: _selectedTraditions,
        enableLocationServices: _enableLocationServices,
        enableNotifications: _enableNotifications,
        theme: _selectedTheme,
        language: _selectedLanguage,
        updatedAt: DateTime.now(),
      );

      await _preferencesService.updatePreferences(updatedPreferences);

      if (mounted) {
        setState(() {
          _currentPreferences = updatedPreferences;
          _isSaving = false;
          _hasUnsavedChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: AppColors.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save preferences: ${e.toString()}';
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await _showResetConfirmationDialog();
    if (!confirmed) return;

    try {
      setState(() {
        _isSaving = true;
        _error = null;
      });

      await _preferencesService.resetToDefaults();
      await _loadPreferences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences reset to defaults'),
            backgroundColor: AppColors.primaryOrange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to reset preferences: ${e.toString()}';
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _showResetConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Preferences'),
            content: const Text(
              'Are you sure you want to reset all preferences to their default values? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasUnsavedChanges) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Do you want to save them before leaving?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Discard'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await _savePreferences();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _onLocationRadiusChanged(double value) {
    setState(() {
      _locationRadius = value;
    });
    _onFormChanged();
  }

  void _onTraditionToggled(String tradition) {
    setState(() {
      if (_selectedTraditions.contains(tradition)) {
        _selectedTraditions.remove(tradition);
      } else {
        _selectedTraditions.add(tradition);
      }
    });
    _onFormChanged();
  }

  void _onLocationServicesToggled(bool value) {
    setState(() {
      _enableLocationServices = value;
    });
    _onFormChanged();
  }

  void _onNotificationsToggled(bool value) {
    setState(() {
      _enableNotifications = value;
    });
    _onFormChanged();
  }

  void _onThemeChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedTheme = value;
      });
      _onFormChanged();
    }
  }

  void _onLanguageChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedLanguage = value;
      });
      _onFormChanged();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _showUnsavedChangesDialog();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.creamBackground,
        appBar: AppBar(
          title: const Text(
            'Preferences',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.primaryOrange,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                onPressed: _isSaving ? null : _savePreferences,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.save),
                tooltip: 'Save preferences',
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'reset':
                    _resetToDefaults();
                    break;
                  case 'export':
                    _exportPreferences();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.restore, size: 20),
                      SizedBox(width: 8),
                      Text('Reset to defaults'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 8),
                      Text('Export preferences'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Offline Indicator
              const OfflineIndicator(),

              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryOrange,
                          ),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: AnimatedErrorDisplay(
                          title: 'Preferences Error',
                          message: _error!,
                          type: ErrorDisplayType.network,
                          onRetry: _loadPreferences,
                          onDismiss: () {
                            setState(() {
                              _error = null;
                            });
                          },
                          showDismissButton: true,
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildPreferencesForm(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Preferences Section
            _buildSectionHeader('Location Preferences'),
            const SizedBox(height: 16),
            _buildLocationRadiusSlider(),
            const SizedBox(height: 16),
            _buildLocationServicesToggle(),
            const SizedBox(height: 32),

            // Spiritual Traditions Section
            _buildSectionHeader('Spiritual Traditions'),
            const SizedBox(height: 16),
            _buildTraditionSelection(),
            const SizedBox(height: 32),

            // Notification Preferences Section
            _buildSectionHeader('Notifications'),
            const SizedBox(height: 16),
            _buildNotificationToggle(),
            const SizedBox(height: 32),

            // Display Preferences Section
            _buildSectionHeader('Display & Language'),
            const SizedBox(height: 16),
            _buildThemeSelection(),
            const SizedBox(height: 16),
            _buildLanguageSelection(),
            const SizedBox(height: 32),

            // Save Button
            if (_hasUnsavedChanges) _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryText,
      ),
    );
  }

  Widget _buildLocationRadiusSlider() {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Search Radius',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_locationRadius.round()} km',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryOrange,
              inactiveTrackColor: AppColors.borderGray,
              thumbColor: AppColors.primaryOrange,
              overlayColor: AppColors.primaryOrange.withValues(alpha: 0.2),
              valueIndicatorColor: AppColors.primaryOrange,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Slider(
              value: _locationRadius,
              min: 1.0,
              max: 200.0,
              divisions: 199,
              label: '${_locationRadius.round()} km',
              onChanged: _onLocationRadiusChanged,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Temples within this radius will be prioritized in search results',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationServicesToggle() {
    return Container(
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
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Services',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Allow app to access your location for nearby temple recommendations',
                  style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableLocationServices,
            onChanged: _onLocationServicesToggled,
            activeColor: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildTraditionSelection() {
    return Container(
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
          const Text(
            'Preferred Traditions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select spiritual traditions you\'re interested in',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTraditions.map((tradition) {
              final isSelected = _selectedTraditions.contains(tradition);
              return GestureDetector(
      behavior: HitTestBehavior.opaque,
                onTap: () => _onTraditionToggled(tradition),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.borderGray,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Icon(Icons.check, size: 16, color: Colors.white),
                      if (isSelected) const SizedBox(width: 4),
                      Text(
                        tradition,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryText,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
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
      child: Row(
        children: [
          const Icon(Icons.notifications, color: AppColors.primaryOrange, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Receive notifications about temple events, festivals, and updates',
                  style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableNotifications,
            onChanged: _onNotificationsToggled,
            activeColor: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelection() {
    return Container(
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
          const Text(
            'Theme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedDropdownField<String>(
            value: _selectedTheme,
            items: _preferencesService.getAvailableThemes().map((theme) {
              return DropdownMenuItem(
                value: theme,
                child: Text(_getThemeDisplayName(theme)),
              );
            }).toList(),
            onChanged: _onThemeChanged,
            prefixIcon: const Icon(Icons.palette),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return Container(
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
          const Text(
            'Language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedDropdownField<String>(
            value: _selectedLanguage,
            items: _preferencesService.getAvailableLanguages().map((language) {
              return DropdownMenuItem(
                value: language,
                child: Text(_getLanguageDisplayName(language)),
              );
            }).toList(),
            onChanged: _onLanguageChanged,
            prefixIcon: const Icon(Icons.language),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePreferences,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSaving
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Saving...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : const Text(
                'Save Preferences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'auto':
        return 'Auto (System)';
      default:
        return theme;
    }
  }

  String _getLanguageDisplayName(String language) {
    switch (language) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी (Hindi)';
      default:
        return language;
    }
  }

  Future<void> _exportPreferences() async {
    try {
      final preferencesJson = await _preferencesService.exportPreferences();

      // For now, just show a dialog with the JSON
      // In a real app, you might want to save to file or share
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Preferences'),
            content: SingleChildScrollView(
              child: Text(
                preferencesJson.toString(),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export preferences: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
}
