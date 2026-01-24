import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/data/models/playlist_model.dart';

///repository for managing playlist data
class PlaylistsRepository {
  final SonoDatabaseHelper _dbHelper = SonoDatabaseHelper.instance;

  //=== CREATE ===

  ///create a new playlist
  Future<int> createPlaylist({
    required String name,
    String? description,
    int? coverSongId,
    int? mediastoreId,
    bool isFavorite = false,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.pending,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final id = await db.insert('app_playlists', {
        'name': name,
        'description': description,
        'cover_song_id': coverSongId,
        'mediastore_id': mediastoreId,
        'is_favorite': isFavorite ? 1 : 0,
        'sync_status': syncStatus.value,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      debugPrint('PlaylistsRepository: Created playlist "$name" with ID $id');
      return id;
    } catch (e) {
      debugPrint('PlaylistsRepository: Error creating playlist: $e');
      rethrow;
    }
  }

  //=== READ ===

  ///get a playlist by ID
  Future<PlaylistModel?> getPlaylist(int id) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'app_playlists',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return PlaylistModel.fromMap(results.first);
    } catch (e) {
      debugPrint('PlaylistsRepository: Error getting playlist $id: $e');
      return null;
    }
  }

  ///get all playlists => ordered by creation date (newest first)
  Future<List<PlaylistModel>> getAllPlaylists({
    bool favoritesFirst = true,
  }) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'app_playlists',
        orderBy:
            favoritesFirst
                ? 'is_favorite DESC, created_at DESC'
                : 'created_at DESC',
      );

      return results.map((map) => PlaylistModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('PlaylistsRepository: Error getting all playlists: $e');
      return [];
    }
  }

  ///get playlist by MediaStore ID
  Future<PlaylistModel?> getPlaylistByMediaStoreId(int mediastoreId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'app_playlists',
        where: 'mediastore_id = ?',
        whereArgs: [mediastoreId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return PlaylistModel.fromMap(results.first);
    } catch (e) {
      debugPrint(
        'PlaylistsRepository: Error getting playlist by MediaStore ID: $e',
      );
      return null;
    }
  }

  ///get playlists that need syncing
  Future<List<PlaylistModel>> getPlaylistsNeedingSync() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'app_playlists',
        where: 'sync_status IN (?, ?)',
        whereArgs: [
          PlaylistSyncStatus.pending.value,
          PlaylistSyncStatus.failed.value,
        ],
      );

      return results.map((map) => PlaylistModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint(
        'PlaylistsRepository: Error getting playlists needing sync: $e',
      );
      return [];
    }
  }

  ///check if a playlist name exists (case-insensitive)
  Future<bool> playlistNameExists(String name, {int? excludeId}) async {
    try {
      final db = await _dbHelper.database;
      final whereClause =
          excludeId != null ? 'LOWER(name) = ? AND id != ?' : 'LOWER(name) = ?';
      final whereArgs =
          excludeId != null
              ? [name.toLowerCase(), excludeId]
              : [name.toLowerCase()];

      final results = await db.query(
        'app_playlists',
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      return results.isNotEmpty;
    } catch (e) {
      debugPrint('PlaylistsRepository: Error checking playlist name: $e');
      return false;
    }
  }

  //=== UPDATE ===

  ///update playlist details
  Future<void> updatePlaylist({
    required int id,
    String? name,
    String? description,
    int? coverSongId,
    bool? isFavorite,
    PlaylistSyncStatus? syncStatus,
  }) async {
    try {
      final db = await _dbHelper.database;
      final updateMap = <String, dynamic>{
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updateMap['name'] = name;
      if (description != null) updateMap['description'] = description;
      if (coverSongId != null) updateMap['cover_song_id'] = coverSongId;
      if (isFavorite != null) updateMap['is_favorite'] = isFavorite ? 1 : 0;
      if (syncStatus != null) updateMap['sync_status'] = syncStatus.value;

      await db.update(
        'app_playlists',
        updateMap,
        where: 'id = ?',
        whereArgs: [id],
      );

      debugPrint('PlaylistsRepository: Updated playlist $id');
    } catch (e) {
      debugPrint('PlaylistsRepository: Error updating playlist $id: $e');
      rethrow;
    }
  }

  ///set MediaStore ID for a playlist
  Future<void> setMediaStoreId(int playlistId, int mediastoreId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'app_playlists',
        {
          'mediastore_id': mediastoreId,
          'sync_status': PlaylistSyncStatus.synced.value,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      debugPrint(
        'PlaylistsRepository: Set MediaStore ID $mediastoreId for playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistsRepository: Error setting MediaStore ID: $e');
      rethrow;
    }
  }

  ///update sync status
  Future<void> updateSyncStatus(
    int playlistId,
    PlaylistSyncStatus status,
  ) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'app_playlists',
        {
          'sync_status': status.value,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      debugPrint(
        'PlaylistsRepository: Updated sync status to ${status.value} for playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistsRepository: Error updating sync status: $e');
      rethrow;
    }
  }

  ///set playlist cover (song artwork)
  Future<void> setPlaylistCover(int playlistId, int songId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'app_playlists',
        {
          'cover_song_id': songId,
          'custom_cover_path':
              null, //clear custom cover when setting song cover
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      debugPrint(
        'PlaylistsRepository: Set cover $songId for playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistsRepository: Error setting playlist cover: $e');
      rethrow;
    }
  }

  ///set custom cover image path
  Future<void> setCustomCover(int playlistId, String coverPath) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'app_playlists',
        {
          'custom_cover_path': coverPath,
          'cover_song_id': null, //Clear song cover when setting custom cover
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      debugPrint(
        'PlaylistsRepository: Set custom cover for playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistsRepository: Error setting custom cover: $e');
      rethrow;
    }
  }

  ///get custom cover path for a playlist
  Future<String?> getCustomCoverPath(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'app_playlists',
        columns: ['custom_cover_path'],
        where: 'id = ?',
        whereArgs: [playlistId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return results.first['custom_cover_path'] as String?;
    } catch (e) {
      debugPrint('PlaylistsRepository: Error getting custom cover path: $e');
      return null;
    }
  }

  ///remove playlist cover (both song and custom)
  Future<void> removePlaylistCover(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'app_playlists',
        {
          'cover_song_id': null,
          'custom_cover_path': null,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      debugPrint('PlaylistsRepository: Removed cover for playlist $playlistId');
    } catch (e) {
      debugPrint('PlaylistsRepository: Error removing playlist cover: $e');
      rethrow;
    }
  }

  //=== DELETE ===

  ///felete a playlist (CASCADE will delete all playlist_songs)
  Future<void> deletePlaylist(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('app_playlists', where: 'id = ?', whereArgs: [id]);

      debugPrint('PlaylistsRepository: Deleted playlist $id');
    } catch (e) {
      debugPrint('PlaylistsRepository: Error deleting playlist $id: $e');
      rethrow;
    }
  }

  //=== MIGRATION HELPERS ===

  ///batch create playlists (for migration)
  Future<void> batchCreatePlaylists(
    List<Map<String, dynamic>> playlists,
  ) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();

      for (final playlist in playlists) {
        batch.insert('app_playlists', playlist);
      }

      await batch.commit(noResult: true);
      debugPrint(
        'PlaylistsRepository: Batch created ${playlists.length} playlists',
      );
    } catch (e) {
      debugPrint('PlaylistsRepository: Error batch creating playlists: $e');
      rethrow;
    }
  }

  ///get cover song ID for a playlist
  Future<int?> getPlaylistCover(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'app_playlists',
        columns: ['cover_song_id'],
        where: 'id = ?',
        whereArgs: [playlistId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return results.first['cover_song_id'] as int?;
    } catch (e) {
      debugPrint('PlaylistsRepository: Error getting playlist cover: $e');
      return null;
    }
  }
}