import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../styles/app_theme.dart';
import '../../services/artists/artist_profile_image_service.dart';

/// Result of artist picture picker selection
class ArtistPictureResult {
  final bool remove;
  final String? imagePath;

  const ArtistPictureResult({required this.remove, this.imagePath});

  /// Create result for removing picture
  factory ArtistPictureResult.remove() =>
      const ArtistPictureResult(remove: true);

  /// Create result for setting custom picture
  factory ArtistPictureResult.customImage(String path) =>
      ArtistPictureResult(remove: false, imagePath: path);
}

class ArtistPicturePickerDialog extends StatefulWidget {
  final String artistName;

  const ArtistPicturePickerDialog({
    super.key,
    required this.artistName,
  });

  @override
  State<ArtistPicturePickerDialog> createState() =>
      _ArtistPicturePickerDialogState();
}

class _ArtistPicturePickerDialogState extends State<ArtistPicturePickerDialog> {
  String? _selectedImagePath;
  bool _hasExistingImage = false;
  bool _isLoading = true;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkExistingImage();
  }

  Future<void> _checkExistingImage() async {
    final service = ArtistProfileImageService();
    final hasImage = await service.hasCustomImage(widget.artistName);
    setState(() {
      _hasExistingImage = hasImage;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      }
    }
  }

  void _onSavePressed() {
    if (_selectedImagePath != null) {
      Navigator.pop(
        context,
        ArtistPictureResult.customImage(_selectedImagePath!),
      );
    }
  }

  void _onRemovePressed() {
    Navigator.pop(context, ArtistPictureResult.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: AppTheme.borderDark),
            _buildContent(),
            const Divider(height: 1, color: AppTheme.borderDark),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        children: [
          const Icon(Icons.image_rounded, color: AppTheme.textPrimaryDark),
          const SizedBox(width: AppTheme.spacingSm),
          const Text(
            'Artist Picture',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondaryDark),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacing),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImagePath != null) _buildPreview(),
          if (_selectedImagePath != null) const SizedBox(height: AppTheme.spacing),

          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_rounded),
            label: Text(
              _selectedImagePath == null ? 'Choose from Gallery' : 'Choose Different Image',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPink,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),

          if (_hasExistingImage && _selectedImagePath == null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            OutlinedButton.icon(
              onPressed: _onRemovePressed,
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Remove Current Picture'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 200,
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.brandPink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Image.file(
          File(_selectedImagePath!),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          ElevatedButton(
            onPressed: _selectedImagePath != null ? _onSavePressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPink,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: const Text('Set Picture'),
          ),
        ],
      ),
    );
  }
}