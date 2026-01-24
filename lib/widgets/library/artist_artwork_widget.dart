import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/data/repositories/artists_repository.dart';

/// Widget that displays artist artwork with priority:
/// 1. Custom image (user-selected from gallery)
/// 2. Fetched image (from Last.fm API)
/// 3. MediaStore artwork (from audio files)
class ArtistArtworkWidget extends StatelessWidget {
  final String artistName;
  final int artistId;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholderWidget;

  //static cache for artist image info to avoid repeated database queries
  static final Map<String, Map<String, String?>> _imageInfoCache = {};

  const ArtistArtworkWidget({
    super.key,
    required this.artistName,
    required this.artistId,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderWidget,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _loadImageInfo(),
      builder: (context, snapshot) {
        //show placeholder while loading
        if (!snapshot.hasData) {
          return _buildPlaceholder();
        }

        final imageInfo = snapshot.data!;
        final customPath = imageInfo['customPath'];
        final fetchedUrl = imageInfo['fetchedUrl'];

        // Priority 1: Custom image from local storage
        if (customPath != null && customPath.isNotEmpty) {
          return _buildCustomImage(customPath);
        }

        // Priority 2: Fetched image from Service
        if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
          return _buildFetchedImage(fetchedUrl);
        }

        // Priority 3: MediaStore artwork fallback
        return _buildMediaStoreArtwork();
      },
    );
  }

  /// Load image information from repository with caching
  Future<Map<String, String?>> _loadImageInfo() async {
    //check cache first
    if (_imageInfoCache.containsKey(artistName)) {
      if (kDebugMode) {
        print('ArtistArtworkWidget [$artistName]: Using cached image info');
      }
      return _imageInfoCache[artistName]!;
    }

    //fetch from database
    final repository = ArtistsRepository();
    final imageInfo = await repository.getArtistImageInfo(artistName);

    //store in cache
    _imageInfoCache[artistName] = imageInfo;

    if (kDebugMode) {
      print('ArtistArtworkWidget [$artistName]: Fetched and cached - customPath=${imageInfo['customPath']}, fetchedUrl=${imageInfo['fetchedUrl']}');
    }

    return imageInfo;
  }

  /// Clear the cache for a specific artist (useful after updating their image)
  static void clearCacheForArtist(String artistName) {
    _imageInfoCache.remove(artistName);
  }

  /// Clear all cached artist image info
  static void clearAllCache() {
    _imageInfoCache.clear();
  }

  /// Build custom image from local file
  Widget _buildCustomImage(String path) {
    final file = File(path);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.file(
        file,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          //if custom image fails to load => fall back to MediaStore
          return _buildMediaStoreArtwork();
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          );
        },
      ),
    );
  }

  /// Build fetched image from URL (Last.fm)
  Widget _buildFetchedImage(String url) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          //if fetched image fails to load => fall back to MediaStore
          return _buildMediaStoreArtwork();
        },
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  /// Build MediaStore artwork (fallback)
  Widget _buildMediaStoreArtwork() {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: QueryArtworkWidget(
        id: artistId,
        type: ArtworkType.ARTIST,
        artworkFit: fit,
        nullArtworkWidget: _buildPlaceholder(),
        keepOldArtwork: true,
        artworkBorder: BorderRadius.zero,
      ),
    );
  }

  /// Build placeholder widget
  Widget _buildPlaceholder() {
    if (placeholderWidget != null) {
      return placeholderWidget!;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = constraints.maxWidth > 0
            ? constraints.maxWidth * 0.4
            : 40.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              size: iconSize,
              color: Colors.white54,
            ),
          ),
        );
      },
    );
  }
}