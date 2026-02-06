import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:sono/data/repositories/artists_repository.dart';

/// Service for managing custom artist profile images
/// Similar to PlaylistCoverService but for artists
class ArtistProfileImageService {
  final ArtistsRepository _repository = ArtistsRepository();

  /// Get the directory where artist images are stored
  Future<Directory> _getArtistImagesDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final artistImagesDir = Directory('${appDocDir.path}/artist_images');

    if (!await artistImagesDir.exists()) {
      await artistImagesDir.create(recursive: true);
    }

    return artistImagesDir;
  }

  /// Generate a safe filename from artist name
  String _getSafeFileName(String artistName) {
    //URL encode the artist name to handle special characters
    final encoded = Uri.encodeComponent(artistName.toLowerCase());
    return 'artist_$encoded.jpg';
  }

  /// Get the file path for an artist's custom image
  Future<String> _getImagePath(String artistName) async {
    final dir = await _getArtistImagesDirectory();
    final fileName = _getSafeFileName(artistName);
    return '${dir.path}/$fileName';
  }

  /// Save a custom artist image from a source file path
  /// Resizes and compresses the image to 800x800 at 85% quality
  Future<String> saveArtistImage(String artistName, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source image file does not exist');
      }

      final imageBytes = await sourceFile.readAsBytes();
      final destinationPath = await _getImagePath(artistName);

      //process image in isolate to avoid blocking UI
      final processedBytes = await compute(
        _processImage,
        Uint8List.fromList(imageBytes),
      );

      //save processed image
      final destFile = File(destinationPath);
      await destFile.writeAsBytes(processedBytes);

      //update database with path
      await _repository.setCustomImage(artistName, destinationPath);

      if (kDebugMode) {
        print('ArtistProfileImageService: Saved image for "$artistName"');
      }

      return destinationPath;
    } catch (e) {
      if (kDebugMode) {
        print(
          'ArtistProfileImageService: Error saving image for "$artistName": $e',
        );
      }
      rethrow;
    }
  }

  /// Process image: decode, resize, and encode
  static Uint8List _processImage(Uint8List imageBytes) {
    //decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    //resize to 800x800 (maintaining aspect ratio => then crop to square)
    const targetSize = 800;

    //resize so the smaller dimension is targetSize
    if (image.width > image.height) {
      image = img.copyResize(
        image,
        height: targetSize,
        interpolation: img.Interpolation.linear,
      );
    } else {
      image = img.copyResize(
        image,
        width: targetSize,
        interpolation: img.Interpolation.linear,
      );
    }

    //crop to square if needed
    if (image.width != image.height) {
      final size = image.width < image.height ? image.width : image.height;
      final x = (image.width - size) ~/ 2;
      final y = (image.height - size) ~/ 2;
      image = img.copyCrop(image, x: x, y: y, width: size, height: size);
    }

    //rncode as JPEG
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }

  /// Delete custom artist image
  Future<bool> deleteArtistImage(String artistName) async {
    try {
      final imagePath = await _getImagePath(artistName);
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      //remove from database
      await _repository.removeCustomImage(artistName);

      if (kDebugMode) {
        print('ArtistProfileImageService: Deleted image for "$artistName"');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print(
          'ArtistProfileImageService: Error deleting image for "$artistName": $e',
        );
      }
      return false;
    }
  }

  /// Get the File object for an artists custom image
  Future<File?> getArtistImageFile(String artistName) async {
    final customPath = await _repository.getCustomImagePath(artistName);
    if (customPath == null) return null;

    final file = File(customPath);
    if (await file.exists()) {
      return file;
    }

    return null;
  }

  /// Check if an artist has a custom image
  Future<bool> hasCustomImage(String artistName) async {
    final file = await getArtistImageFile(artistName);
    return file != null;
  }

  /// Clean up orphaned artist images (images without database entries)
  Future<int> cleanupOrphanedImages() async {
    try {
      final dir = await _getArtistImagesDirectory();
      final files = await dir.list().toList();
      int deletedCount = 0;

      final artistsWithImages = await _repository.getArtistsWithCustomImages();
      final validPaths =
          artistsWithImages
              .map((a) => a['custom_image_path'] as String?)
              .where((p) => p != null)
              .toSet();

      for (final entity in files) {
        if (entity is File && !validPaths.contains(entity.path)) {
          await entity.delete();
          deletedCount++;
        }
      }

      if (kDebugMode && deletedCount > 0) {
        if (kDebugMode) {
          print(
            'ArtistProfileImageService: Cleaned up $deletedCount orphaned images',
          );
        }
      }

      return deletedCount;
    } catch (e) {
      if (kDebugMode) {
        print('ArtistProfileImageService: Error during cleanup: $e');
      }
      return 0;
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final dir = await _getArtistImagesDirectory();
      final files = await dir.list().toList();

      int totalSize = 0;
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return {
        'fileCount': files.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      if (kDebugMode) {
        print('ArtistProfileImageService: Error getting cache stats: $e');
      }
      return {'fileCount': 0, 'totalSizeBytes': 0, 'totalSizeMB': '0.00'};
    }
  }
}
