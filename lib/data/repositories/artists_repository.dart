import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/data/database/tables/artists_table.dart';

/// Repository for managing custom artist metadata (profile pictures, etc.)
class ArtistsRepository {
  final SonoDatabaseHelper _dbHelper = SonoDatabaseHelper.instance;

  /// Get custom metadata for an artist by name
  Future<Map<String, dynamic>?> getArtistMetadata(String artistName) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      ArtistMetadataTable.tableName,
      where: 'artist_name_lower = ?',
      whereArgs: [artistName.toLowerCase()],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Get custom metadata for an artist by MediaStore ID
  Future<Map<String, dynamic>?> getArtistMetadataById(int mediaStoreId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      ArtistMetadataTable.tableName,
      where: 'mediastore_id = ?',
      whereArgs: [mediaStoreId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Save or update artist metadata
  Future<void> saveArtistMetadata({
    required String artistName,
    String? customImagePath,
    int? mediaStoreId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(ArtistMetadataTable.tableName, {
      'artist_name': artistName,
      'artist_name_lower': artistName.toLowerCase(),
      'custom_image_path': customImagePath,
      'mediastore_id': mediaStoreId,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update just the custom image path for an artist
  Future<void> setCustomImage(String artistName, String? imagePath) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    //check if artist exists
    final existing = await getArtistMetadata(artistName);

    if (existing != null) {
      await db.update(
        ArtistMetadataTable.tableName,
        {'custom_image_path': imagePath, 'updated_at': now},
        where: 'artist_name_lower = ?',
        whereArgs: [artistName.toLowerCase()],
      );
    } else {
      await saveArtistMetadata(
        artistName: artistName,
        customImagePath: imagePath,
      );
    }
  }

  /// Get custom image path for an artist
  Future<String?> getCustomImagePath(String artistName) async {
    final metadata = await getArtistMetadata(artistName);
    return metadata?['custom_image_path'] as String?;
  }

  /// Get all artists with custom images
  Future<List<Map<String, dynamic>>> getArtistsWithCustomImages() async {
    final db = await _dbHelper.database;
    return await db.query(
      ArtistMetadataTable.tableName,
      where: 'custom_image_path IS NOT NULL',
      orderBy: 'artist_name ASC',
    );
  }

  /// Remove custom image for an artist
  Future<void> removeCustomImage(String artistName) async {
    await setCustomImage(artistName, null);
  }

  /// Delete all metadata for an artist
  Future<void> deleteArtistMetadata(String artistName) async {
    final db = await _dbHelper.database;
    await db.delete(
      ArtistMetadataTable.tableName,
      where: 'artist_name_lower = ?',
      whereArgs: [artistName.toLowerCase()],
    );
  }

  /// Bulk save artist metadata (useful for initial sync)
  Future<void> bulkSaveArtists(List<Map<String, dynamic>> artists) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final batch = db.batch();
    for (final artist in artists) {
      batch.insert(ArtistMetadataTable.tableName, {
        'artist_name': artist['name'],
        'artist_name_lower': (artist['name'] as String).toLowerCase(),
        'custom_image_path': artist['imagePath'],
        'mediastore_id': artist['mediaStoreId'],
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// Set fetched image URL
  Future<void> setFetchedImageUrl(String artistName, String url) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    //check if artist exists
    final existing = await getArtistMetadata(artistName);

    if (existing != null) {
      await db.update(
        ArtistMetadataTable.tableName,
        {
          'fetched_image_url': url,
          'fetch_attempted_at': now,
          'updated_at': now,
        },
        where: 'artist_name_lower = ?',
        whereArgs: [artistName.toLowerCase()],
      );
    } else {
      await db.insert(
        ArtistMetadataTable.tableName,
        {
          'artist_name': artistName,
          'artist_name_lower': artistName.toLowerCase(),
          'fetched_image_url': url,
          'fetch_attempted_at': now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Get fetched image URL for an artist
  Future<String?> getFetchedImageUrl(String artistName) async {
    final metadata = await getArtistMetadata(artistName);
    return metadata?['fetched_image_url'] as String?;
  }

  /// Get artist image information with priority: custom > fetched
  /// Returns map with 'customPath' and 'fetchedUrl' keys
  Future<Map<String, String?>> getArtistImageInfo(String artistName) async {
    final metadata = await getArtistMetadata(artistName);

    if (kDebugMode) {
      print(
        'ArtistsRepository.getArtistImageInfo [$artistName]: metadata=$metadata',
      );
    }

    return {
      'customPath': metadata?['custom_image_path'] as String?,
      'fetchedUrl': metadata?['fetched_image_url'] as String?,
    };
  }

  /// Mark that we attempted to fetch an image for this artist
  /// (even if the fetch failed => to avoid retry loops)
  Future<void> markFetchAttempted(String artistName) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    //check if artist exists
    final existing = await getArtistMetadata(artistName);

    if (existing != null) {
      await db.update(
        ArtistMetadataTable.tableName,
        {'fetch_attempted_at': now, 'updated_at': now},
        where: 'artist_name_lower = ?',
        whereArgs: [artistName.toLowerCase()],
      );
    } else {
      await db.insert(
        ArtistMetadataTable.tableName,
        {
          'artist_name': artistName,
          'artist_name_lower': artistName.toLowerCase(),
          'fetch_attempted_at': now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Check if need to fetch an image for this artist
  /// Returns false if:
  /// - Artist has a custom image (user preference takes priority)
  /// - Artist already has a fetched URL
  /// - We attempted to fetch recently (within 7 days)
  Future<bool> shouldFetchImage(String artistName) async {
    final metadata = await getArtistMetadata(artistName);

    //no metadata => should fetch
    if (metadata == null) return true;

    //has custom image => dont override
    if (metadata['custom_image_path'] != null) return false;

    //already has fetched URL => dont refetch
    if (metadata['fetched_image_url'] != null) return false;

    //check if attempted recently (within 7 days)
    final fetchAttemptedAt = metadata['fetch_attempted_at'] as int?;
    if (fetchAttemptedAt != null) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(fetchAttemptedAt);
      final daysSince = DateTime.now().difference(lastAttempt).inDays;
      if (daysSince < 7) return false;
    }

    return true;
  }

  /// Clear all fetched image URLs (for refresh feature in settings)
  Future<void> clearAllFetchedImages() async {
    final db = await _dbHelper.database;
    await db.update(
      ArtistMetadataTable.tableName,
      {'fetched_image_url': null, 'fetch_attempted_at': null},
      where: 'fetched_image_url IS NOT NULL OR fetch_attempted_at IS NOT NULL',
    );
  }

  /// Clear fetched image URL for a single artist (to allow refetch)
  Future<void> clearFetchedImageForArtist(String artistName) async {
    final db = await _dbHelper.database;
    await db.update(
      ArtistMetadataTable.tableName,
      {'fetched_image_url': null, 'fetch_attempted_at': null},
      where: 'artist_name_lower = ?',
      whereArgs: [artistName.toLowerCase()],
    );
  }
}
