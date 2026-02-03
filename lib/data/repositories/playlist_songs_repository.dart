import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/data/models/playlist_model.dart';

///repository for managing songs within playlists
class PlaylistSongsRepository {
  final SonoDatabaseHelper _dbHelper = SonoDatabaseHelper.instance;

  //=== CREATE ===

  ///add song to playlist
  Future<void> addSong({required int playlistId, required int songId}) async {
    try {
      final db = await _dbHelper.database;

      //get current highest position in playlist
      final positionResult = await db.rawQuery(
        'SELECT MAX(position) as max_pos FROM playlist_songs WHERE playlist_id = ?',
        [playlistId],
      );
      final maxPosition = positionResult.first['max_pos'] as int? ?? -1;
      final newPosition = maxPosition + 1;

      await db.insert(
        'playlist_songs',
        {
          'playlist_id': playlistId,
          'song_id': songId,
          'position': newPosition,
          'added_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm:
            ConflictAlgorithm.ignore, //ignore if song already in playlist
      );

      debugPrint(
        'PlaylistSongsRepository: Added song $songId to playlist $playlistId at position $newPosition',
      );
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error adding song to playlist: $e');
      rethrow;
    }
  }

  ///add multiple songs to a playlist
  Future<void> addSongs({
    required int playlistId,
    required List<int> songIds,
  }) async {
    try {
      final db = await _dbHelper.database;

      //get current max position
      final positionResult = await db.rawQuery(
        'SELECT MAX(position) as max_pos FROM playlist_songs WHERE playlist_id = ?',
        [playlistId],
      );
      int position = (positionResult.first['max_pos'] as int? ?? -1) + 1;

      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final songId in songIds) {
        batch.insert('playlist_songs', {
          'playlist_id': playlistId,
          'song_id': songId,
          'position': position++,
          'added_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await batch.commit(noResult: true);
      debugPrint(
        'PlaylistSongsRepository: Added ${songIds.length} songs to playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error adding songs to playlist: $e');
      rethrow;
    }
  }

  //=== READ ===

  ///get all song IDs in a playlist, ordered by position
  Future<List<int>> getSongIds(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'playlist_songs',
        columns: ['song_id'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        orderBy: 'position ASC',
      );

      return results.map((row) => row['song_id'] as int).toList();
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error getting song IDs: $e');
      return [];
    }
  }

  ///get all PlaylistSongModel entries for a playlist
  Future<List<PlaylistSongModel>> getSongs(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        orderBy: 'position ASC',
      );

      return results.map((row) => PlaylistSongModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error getting songs: $e');
      return [];
    }
  }

  ///get count of songs in a playlist
  Future<int> getSongCount(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM playlist_songs WHERE playlist_id = ?',
        [playlistId],
      );

      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error getting song count: $e');
      return 0;
    }
  }

  ///check if a song is in a playlist
  Future<bool> isSongInPlaylist(int playlistId, int songId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'playlist_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId],
        limit: 1,
      );

      return results.isNotEmpty;
    } catch (e) {
      debugPrint(
        'PlaylistSongsRepository: Error checking if song in playlist: $e',
      );
      return false;
    }
  }

  //=== UPDATE ===

  ///Reorder a song within a playlist
  Future<void> reorderSong({
    required int playlistId,
    required int songId,
    required int newPosition,
  }) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        //get current position
        final currentResult = await txn.query(
          'playlist_songs',
          columns: ['position'],
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, songId],
          limit: 1,
        );

        if (currentResult.isEmpty) {
          throw Exception('Song not found in playlist');
        }

        final oldPosition = currentResult.first['position'] as int;

        if (oldPosition == newPosition) {
          return; //no change needed
        }

        if (oldPosition < newPosition) {
          //moving down: shift songs between old and new position up
          await txn.rawUpdate(
            'UPDATE playlist_songs SET position = position - 1 '
            'WHERE playlist_id = ? AND position > ? AND position <= ?',
            [playlistId, oldPosition, newPosition],
          );
        } else {
          //moving up: shift songs between new and old position down
          await txn.rawUpdate(
            'UPDATE playlist_songs SET position = position + 1 '
            'WHERE playlist_id = ? AND position >= ? AND position < ?',
            [playlistId, newPosition, oldPosition],
          );
        }

        //update the songs position
        await txn.update(
          'playlist_songs',
          {'position': newPosition},
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, songId],
        );
      });

      debugPrint(
        'PlaylistSongsRepository: Reordered song $songId from position to $newPosition',
      );
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error reordering song: $e');
      rethrow;
    }
  }

  ///normalize positions (fix gaps, ensure sequential 0, 1, 2...)
  Future<void> normalizePositions(int playlistId) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        //get all songs ordered by current position
        final songs = await txn.query(
          'playlist_songs',
          where: 'playlist_id = ?',
          whereArgs: [playlistId],
          orderBy: 'position ASC',
        );

        //update positions to be sequential
        final batch = txn.batch();
        for (int i = 0; i < songs.length; i++) {
          batch.update(
            'playlist_songs',
            {'position': i},
            where: 'id = ?',
            whereArgs: [songs[i]['id']],
          );
        }
        await batch.commit(noResult: true);
      });

      debugPrint(
        'PlaylistSongsRepository: Normalized positions for playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error normalizing positions: $e');
      rethrow;
    }
  }

  //=== DELETE ===

  ///remove a song from a playlist
  Future<void> removeSong({
    required int playlistId,
    required int songId,
  }) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        //get the songs position before deleting
        final positionResult = await txn.query(
          'playlist_songs',
          columns: ['position'],
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, songId],
          limit: 1,
        );

        if (positionResult.isEmpty) return;
        final deletedPosition = positionResult.first['position'] as int;

        //delete song
        await txn.delete(
          'playlist_songs',
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, songId],
        );

        //shift down all songs that were after the deleted song
        await txn.rawUpdate(
          'UPDATE playlist_songs SET position = position - 1 WHERE playlist_id = ? AND position > ?',
          [playlistId, deletedPosition],
        );
      });

      debugPrint(
        'PlaylistSongsRepository: Removed song $songId from playlist $playlistId',
      );
    } catch (e) {
      debugPrint(
        'PlaylistSongsRepository: Error removing song from playlist: $e',
      );
      rethrow;
    }
  }

  ///clear all songs from a playlist
  Future<void> clearPlaylist(int playlistId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );

      debugPrint(
        'PlaylistSongsRepository: Cleared all songs from playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error clearing playlist: $e');
      rethrow;
    }
  }

  //=== MIGRATION HELPERS ===

  ///batch add songs for migration (with positions)
  Future<void> batchAddSongs(List<Map<String, dynamic>> songs) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();

      for (final song in songs) {
        batch.insert(
          'playlist_songs',
          song,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await batch.commit(noResult: true);
      debugPrint('PlaylistSongsRepository: Batch added ${songs.length} songs');
    } catch (e) {
      debugPrint('PlaylistSongsRepository: Error batch adding songs: $e');
      rethrow;
    }
  }
}
