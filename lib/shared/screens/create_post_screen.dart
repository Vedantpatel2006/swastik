import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/community_post.dart';
import '../services/community_service.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_radius.dart';

/// Screen for creating community posts
class CreatePostScreen extends StatefulWidget {
  final String? templeId;
  final CommunityPostType? initialType;

  const CreatePostScreen({
    super.key,
    this.templeId,
    this.initialType,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _communityService = CommunityService();
  final _imagePicker = ImagePicker();

  CommunityPostType _postType = CommunityPostType.story;
  List<File> _selectedImages = [];
  bool _isSubmitting = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _postType = widget.initialType!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      final images = pickedFiles.map((xFile) => File(xFile.path)).toList();

      if (_selectedImages.length + images.length > 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 10 photos allowed'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate())
      return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to create posts'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload images if any
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _communityService.uploadImages(
          _selectedImages,
          user.uid,
        );
      }

      // Create post
      final post = CommunityPost(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous User',
        userPhotoUrl: user.photoURL,
        type: _postType,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        photos: imageUrls,
        templeId: widget.templeId,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _communityService.createPost(post);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Create Post',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPost,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.allLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post Type Selector
              _buildPostTypeSelector(),
              const SizedBox(height: AppSpacing.lg),

              // Title Field
              _buildTitleField(),
              const SizedBox(height: AppSpacing.md),

              // Content Field
              _buildContentField(),
              const SizedBox(height: AppSpacing.lg),

              // Images Section
              if (_postType == CommunityPostType.photo ||
                  _selectedImages.isNotEmpty)
                _buildImagesSection(),

              const SizedBox(height: AppSpacing.lg),

              // Privacy Toggle
              _buildPrivacyToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostTypeSelector() {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Post Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildTypeChip(
                CommunityPostType.story,
                'Story',
                Icons.article,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildTypeChip(
                CommunityPostType.photo,
                'Photo',
                Icons.photo_camera,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildTypeChip(
                CommunityPostType.question,
                'Question',
                Icons.help_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(CommunityPostType type, String label, IconData icon) {
    final isSelected = _postType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _postType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOrange.withValues(alpha: 0.1)
                : AppColors.scaffoldBackground,
            borderRadius: AppRadius.mediumRadius,
            border: Border.all(
              color: isSelected ? AppColors.primaryOrange : AppColors.borderGray,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: _postType == CommunityPostType.question
            ? 'Ask your question...'
            : 'Post title...',
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.largeRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.largeRadius,
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.largeRadius,
          borderSide: const BorderSide(
            color: AppColors.primaryOrange,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a title';
        }
        if (value.trim().length < 3) {
          return 'Title must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildContentField() {
    return TextFormField(
      controller: _contentController,
      maxLines: 8,
      maxLength: 5000,
      decoration: InputDecoration(
        hintText: 'Share your thoughts...',
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.largeRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.largeRadius,
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.largeRadius,
          borderSide: const BorderSide(
            color: AppColors.primaryOrange,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter content';
        }
        if (value.trim().length < 10) {
          return 'Content must be at least 10 characters';
        }
        return null;
      },
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            Text(
              '${_selectedImages.length}/10',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_selectedImages.isEmpty)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.largeRadius,
                border: Border.all(
                  color: AppColors.borderGray,
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 40,
                      color: AppColors.secondaryText,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap to add photos',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.mediumRadius,
                        child: Image.file(
                          _selectedImages[index],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.errorRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_selectedImages.length < 10) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add More Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: const BorderSide(color: AppColors.primaryOrange),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildPrivacyToggle() {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isPublic ? Icons.public : Icons.lock,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPublic ? 'Public Post' : 'Private Post',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                Text(
                  _isPublic
                      ? 'Everyone can see this post'
                      : 'Only you can see this post',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPublic,
            onChanged: (value) {
              setState(() {
                _isPublic = value;
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }
}
