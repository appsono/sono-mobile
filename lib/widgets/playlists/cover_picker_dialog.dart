import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sono/styles/app_theme.dart';

/// Result of cover picker selection
class CoverPickerResult {
  final CoverType type;
  final int? songId;
  final String? imagePath;

  const CoverPickerResult._({required this.type, this.songId, this.imagePath});

  /// Cover removed
  factory CoverPickerResult.remove() =>
      const CoverPickerResult._(type: CoverType.remove);

  /// Cover set from song artwork
  factory CoverPickerResult.song(int songId) =>
      CoverPickerResult._(type: CoverType.song, songId: songId);

  /// Cover set from custom image
  factory CoverPickerResult.customImage(String path) =>
      CoverPickerResult._(type: CoverType.customImage, imagePath: path);
}

enum CoverType { remove, song, customImage }

class CoverPickerDialog extends StatefulWidget {
  final int playlistId;
  final List<SongModel> playlistSongs;
  final bool isLikedSongsPlaylist;

  const CoverPickerDialog({
    super.key,
    required this.playlistId,
    required this.playlistSongs,
    this.isLikedSongsPlaylist = false,
  });

  @override
  State<CoverPickerDialog> createState() => _CoverPickerDialogState();
}

class _CoverPickerDialogState extends State<CoverPickerDialog>
    with SingleTickerProviderStateMixin {
  int? _selectedSongId;
  String? _selectedImagePath;
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isLikedSongsPlaylist ? 1 : 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _selectedSongId = null;
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
        CoverPickerResult.customImage(_selectedImagePath!),
      );
    } else if (_selectedSongId != null) {
      Navigator.pop(context, CoverPickerResult.song(_selectedSongId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: AppTheme.borderDark),
            if (!widget.isLikedSongsPlaylist) _buildTabs(),
            Expanded(
              child:
                  widget.isLikedSongsPlaylist
                      ? _buildLikedSongsContent()
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSongCoverGrid(),
                          _buildCustomImagePicker(),
                        ],
                      ),
            ),
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
          const Text(
            'Choose Playlist Cover',
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.fontTitle,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontFamilyHeading,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondaryDark),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(color: AppTheme.surfaceDark),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.brandPink,
        labelColor: AppTheme.brandPink,
        unselectedLabelColor: AppTheme.textSecondaryDark,
        tabs: const [Tab(text: 'From Songs'), Tab(text: 'Custom Image')],
      ),
    );
  }

  Widget _buildLikedSongsContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_rounded,
              size: AppTheme.iconHero,
              color: AppTheme.brandPink,
            ),
            const SizedBox(height: AppTheme.spacing),
            Text(
              'Liked Songs Playlist',
              style: TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: AppTheme.fontSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'This playlist always uses the default heart icon and cannot be customized.',
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: AppTheme.fontBody,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongCoverGrid() {
    if (widget.playlistSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing2xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_off_rounded,
                size: AppTheme.iconHero,
                color: AppTheme.textTertiaryDark,
              ),
              const SizedBox(height: AppTheme.spacing),
              Text(
                'No songs in playlist',
                style: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: AppTheme.font,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Add songs to select artwork as cover',
                style: TextStyle(
                  color: AppTheme.textTertiaryDark,
                  fontSize: AppTheme.fontSm,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppTheme.spacingMd,
        mainAxisSpacing: AppTheme.spacingMd,
        childAspectRatio: 1,
      ),
      itemCount: widget.playlistSongs.length,
      itemBuilder: (context, index) {
        final song = widget.playlistSongs[index];
        final isSelected =
            _selectedSongId == song.id && _selectedImagePath == null;

        return GestureDetector(
          onTap:
              () => setState(() {
                _selectedSongId = song.id;
                _selectedImagePath = null;
              }),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border:
                  isSelected
                      ? Border.all(color: AppTheme.brandPink, width: 3)
                      : null,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    isSelected ? AppTheme.radiusSm : AppTheme.radiusMd,
                  ),
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Container(
                      color: AppTheme.surfaceDark,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: AppTheme.textTertiaryDark,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.brandPink.withAlpha(77),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.brandPink,
                        size: 40,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomImagePicker() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_selectedImagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.brandPink, width: 3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg - 3),
                  child: Image.file(
                    File(_selectedImagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Choose Different Image'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.brandPink),
            ),
          ] else ...[
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.borderDark,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: AppTheme.iconXl,
                    color: AppTheme.textTertiaryDark,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'No image selected',
                    style: TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: AppTheme.fontSm,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Select from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPink,
                foregroundColor: AppTheme.textPrimaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLg,
                  vertical: AppTheme.spacingMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing),
          Text(
            'Select an image from your device\nto use as the playlist cover',
            style: TextStyle(
              color: AppTheme.textTertiaryDark,
              fontSize: AppTheme.fontSm,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final hasSelection = _selectedSongId != null || _selectedImagePath != null;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!widget.isLikedSongsPlaylist)
            TextButton(
              onPressed:
                  () => Navigator.pop(context, CoverPickerResult.remove()),
              child: const Text(
                'Remove Cover',
                style: TextStyle(color: AppTheme.warning),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryDark),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          ElevatedButton(
            onPressed: hasSelection ? _onSavePressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPink,
              disabledBackgroundColor: AppTheme.surfaceDark,
              foregroundColor: AppTheme.textPrimaryDark,
              disabledForegroundColor: AppTheme.textDisabledDark,
            ),
            child: const Text('Set Cover'),
          ),
        ],
      ),
    );
  }
}