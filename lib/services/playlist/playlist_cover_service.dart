import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Service for managing custom playlist cover images
/// Handles storage, loading, and deletion of custom cover images
class PlaylistCoverService {
  static final PlaylistCoverService instance = PlaylistCoverService._internal();
  PlaylistCoverService._internal();

  static const String _coversFolderName = 'playlist_covers';
  static const int _maxImageSize = 800;
  static const int _thumbnailSize = 200;
  static const int _imageQuality = 85;

  String? _coversDirPath;

  /// Gets the directory for storing playlist covers
  Future<Directory> _getCoversDirectory() async {
    if (_coversDirPath != null) {
      return Directory(_coversDirPath!);
    }

    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${appDir.path}/$_coversFolderName');

    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
      debugPrint(
        'PlaylistCoverService: Created covers directory at ${coversDir.path}',
      );
    }

    _coversDirPath = coversDir.path;
    return coversDir;
  }

  /// Gives a custom cover image for a playlist
  /// Returns the path to the saved image, or null if failed
  Future<String?> savePlaylistCover(int playlistId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint(
          'PlaylistCoverService: Source file does not exist: $sourcePath',
        );
        return null;
      }

      //read the source image
      final bytes = await sourceFile.readAsBytes();

      //process and compress the image in an isolate to avoid blocking UI
      final processedBytes = await compute(_processImage, bytes);

      if (processedBytes == null) {
        debugPrint('PlaylistCoverService: Failed to process image');
        return null;
      }

      //give the processed image
      final coversDir = await _getCoversDirectory();
      final coverPath = '${coversDir.path}/playlist_$playlistId.jpg';

      //delete existing cover if present
      final existingFile = File(coverPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      final coverFile = File(coverPath);
      await coverFile.writeAsBytes(processedBytes);

      debugPrint(
        'PlaylistCoverService: Saved cover for playlist $playlistId at $coverPath',
      );
      return coverPath;
    } catch (e) {
      debugPrint('PlaylistCoverService: Error saving cover: $e');
      return null;
    }
  }

  /// Saves a cover image from bytes (e.g., from clipboard or network)
  Future<String?> savePlaylistCoverFromBytes(
    int playlistId,
    Uint8List bytes,
  ) async {
    try {
      //process and compress the image
      final processedBytes = await compute(_processImage, bytes);

      if (processedBytes == null) {
        debugPrint('PlaylistCoverService: Failed to process image bytes');
        return null;
      }

      //give the processed image
      final coversDir = await _getCoversDirectory();
      final coverPath = '${coversDir.path}/playlist_$playlistId.jpg';

      //delete existing cover if present
      final existingFile = File(coverPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      //write new cover
      final coverFile = File(coverPath);
      await coverFile.writeAsBytes(processedBytes);

      debugPrint(
        'PlaylistCoverService: Saved cover from bytes for playlist $playlistId',
      );
      return coverPath;
    } catch (e) {
      debugPrint('PlaylistCoverService: Error saving cover from bytes: $e');
      return null;
    }
  }

  /// Deletes a custom cover for a playlist
  Future<bool> deletePlaylistCover(int playlistId) async {
    try {
      final coversDir = await _getCoversDirectory();
      final coverPath = '${coversDir.path}/playlist_$playlistId.jpg';

      final coverFile = File(coverPath);
      if (await coverFile.exists()) {
        await coverFile.delete();
        debugPrint(
          'PlaylistCoverService: Deleted cover for playlist $playlistId',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('PlaylistCoverService: Error deleting cover: $e');
      return false;
    }
  }

  /// Loads a custom cover image as bytes
  /// Returns null if the cover doesn't exist
  Future<Uint8List?> loadPlaylistCover(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) {
      return null;
    }

    try {
      final coverFile = File(coverPath);
      if (await coverFile.exists()) {
        return await coverFile.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('PlaylistCoverService: Error loading cover: $e');
      return null;
    }
  }

  /// Checks if a custom cover exists for a playlist
  Future<bool> hasCustomCover(int playlistId) async {
    final coversDir = await _getCoversDirectory();
    final coverPath = '${coversDir.path}/playlist_$playlistId.jpg';
    return File(coverPath).exists();
  }

  /// Gets the path for a playlist cover (if it exists)
  Future<String?> getCoverPath(int playlistId) async {
    final coversDir = await _getCoversDirectory();
    final coverPath = '${coversDir.path}/playlist_$playlistId.jpg';
    final file = File(coverPath);

    if (await file.exists()) {
      return coverPath;
    }
    return null;
  }

  /// Generates a thumbnail from an existing cover
  Future<Uint8List?> generateThumbnail(String coverPath) async {
    try {
      final coverFile = File(coverPath);
      if (!await coverFile.exists()) {
        return null;
      }

      final bytes = await coverFile.readAsBytes();
      return await compute(_generateThumbnail, bytes);
    } catch (e) {
      debugPrint('PlaylistCoverService: Error generating thumbnail: $e');
      return null;
    }
  }

  /// Cleans up orphaned cover files (covers without corresponding playlists)
  Future<int> cleanupOrphanedCovers(Set<int> validPlaylistIds) async {
    try {
      final coversDir = await _getCoversDirectory();
      final files = await coversDir.list().toList();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File) {
          final filename = file.path.split('/').last;
          //extract playlist ID from filename (playlist_123.jpg)
          final match = RegExp(r'playlist_(\d+)\.jpg').firstMatch(filename);
          if (match != null) {
            final playlistId = int.tryParse(match.group(1) ?? '');
            if (playlistId != null && !validPlaylistIds.contains(playlistId)) {
              await file.delete();
              deletedCount++;
              debugPrint(
                'PlaylistCoverService: Deleted orphaned cover for playlist $playlistId',
              );
            }
          }
        }
      }

      return deletedCount;
    } catch (e) {
      debugPrint('PlaylistCoverService: Error cleaning up orphaned covers: $e');
      return 0;
    }
  }

  /// Gets cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final coversDir = await _getCoversDirectory();
      final files = await coversDir.list().toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return {
        'directory': coversDir.path,
        'file_count': files.length,
        'total_size_bytes': totalSize,
        'total_size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// Processes an image: resize and compress (runs in isolate)
Uint8List? _processImage(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    //resize if larger than max size
    img.Image processed;
    if (image.width > PlaylistCoverService._maxImageSize ||
        image.height > PlaylistCoverService._maxImageSize) {
      if (image.width > image.height) {
        processed = img.copyResize(
          image,
          width: PlaylistCoverService._maxImageSize,
        );
      } else {
        processed = img.copyResize(
          image,
          height: PlaylistCoverService._maxImageSize,
        );
      }
    } else {
      processed = image;
    }

    //decode as JPEG with quality setting
    return Uint8List.fromList(
      img.encodeJpg(processed, quality: PlaylistCoverService._imageQuality),
    );
  } catch (e) {
    debugPrint('PlaylistCoverService: Error processing image in isolate: $e');
    return null;
  }
}

/// Generates a thumbnail (runs in isolate)
Uint8List? _generateThumbnail(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    //create square thumbnail
    final size = PlaylistCoverService._thumbnailSize;
    img.Image thumbnail;

    if (image.width > image.height) {
      //landscape: crop sides
      final cropX = (image.width - image.height) ~/ 2;
      final cropped = img.copyCrop(
        image,
        x: cropX,
        y: 0,
        width: image.height,
        height: image.height,
      );
      thumbnail = img.copyResize(cropped, width: size, height: size);
    } else if (image.height > image.width) {
      //portrait: crop top/bottom
      final cropY = (image.height - image.width) ~/ 2;
      final cropped = img.copyCrop(
        image,
        x: 0,
        y: cropY,
        width: image.width,
        height: image.width,
      );
      thumbnail = img.copyResize(cropped, width: size, height: size);
    } else {
      //square: just resize
      thumbnail = img.copyResize(image, width: size, height: size);
    }

    return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 80));
  } catch (e) {
    debugPrint(
      'PlaylistCoverService: Error generating thumbnail in isolate: $e',
    );
    return null;
  }
}