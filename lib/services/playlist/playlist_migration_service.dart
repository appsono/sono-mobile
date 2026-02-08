import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart' as query;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/data/repositories/playlists_repository.dart';
import 'package:sono/data/repositories/playlist_songs_repository.dart';
import 'package:sono/data/models/playlist_model.dart';

/// Service for migrating playlists from MediaStore to database
/// This is a one-time (!) operation that runs on first app launch after update
/// Note: Only runs on Android (MediaStore doesnt exist on iOS)
class PlaylistMigrationService {
  final query.OnAudioQuery _audioQuery = query.OnAudioQuery();
  final PlaylistsRepository _playlistsRepo = PlaylistsRepository();
  final PlaylistSongsRepository _playlistSongsRepo = PlaylistSongsRepository();

  static const String _migrationFlagKey = 'playlists_migrated_to_db_v1';
  static const String _playlistCoverKeyPrefix = 'playlist_cover_song_id_v1_';
  static const String _likedSongsPlaylistName = 'Liked Songs';

  /// Check if migration has already been completed
  Future<bool> isMigrationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationFlagKey) ?? false;
    } catch (e) {
      debugPrint(
        'PlaylistMigrationService: Error checking migration status: $e',
      );
      return false;
    }
  }

  /// Perform the full migration
  /// Returns a map with migration statistics
  Future<Map<String, dynamic>> migrate() async {
    //skip migration on iOS (MediaStore doesnt exist)
    if (!Platform.isAndroid) {
      debugPrint(
        'PlaylistMigrationService: Skipping migration on iOS (MediaStore not available)',
      );
      //mark as complete so it doesnt try to run again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationFlagKey, true);
      return {
        'success': true,
        'skippedOnIOS': true,
        'playlistCount': 0,
        'songCount': 0,
      };
    }

    try {
      final stopwatch = Stopwatch()..start();
      debugPrint('PlaylistMigrationService: Starting migration...');

      //check if already migrated
      if (await isMigrationComplete()) {
        debugPrint(
          'PlaylistMigrationService: Migration already complete, skipping',
        );
        return {
          'success': true,
          'alreadyMigrated': true,
          'playlistCount': 0,
          'songCount': 0,
        };
      }

      //get all MediaStore playlists
      final mediaStorePlaylists = await _audioQuery.queryPlaylists();
      debugPrint(
        'PlaylistMigrationService: Found ${mediaStorePlaylists.length} MediaStore playlists',
      );

      int playlistCount = 0;
      int songCount = 0;
      final List<String> errors = [];

      //migrate each playlist
      for (final mediaStorePlaylist in mediaStorePlaylists) {
        try {
          final result = await _migratePlaylist(mediaStorePlaylist);

          if (result['success']) {
            playlistCount++;
            songCount += result['songCount'] as int;
            debugPrint(
              'PlaylistMigrationService: Migrated "${mediaStorePlaylist.playlist}" (${result['songCount']} songs)',
            );
          } else {
            errors.add(
              'Failed to migrate "${mediaStorePlaylist.playlist}": ${result['error']}',
            );
          }
        } catch (e) {
          errors.add('Error migrating "${mediaStorePlaylist.playlist}": $e');
          debugPrint('PlaylistMigrationService: Error migrating playlist: $e');
        }
      }

      //mark migration as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationFlagKey, true);

      stopwatch.stop();
      debugPrint(
        'PlaylistMigrationService: Migration complete in ${stopwatch.elapsedMilliseconds}ms',
      );
      debugPrint(
        'PlaylistMigrationService: Migrated $playlistCount playlists with $songCount total songs',
      );

      if (errors.isNotEmpty) {
        debugPrint(
          'PlaylistMigrationService: ${errors.length} errors occurred:',
        );
        for (final error in errors) {
          debugPrint('  - $error');
        }
      }

      return {
        'success': true,
        'alreadyMigrated': false,
        'playlistCount': playlistCount,
        'songCount': songCount,
        'errors': errors,
        'durationMs': stopwatch.elapsedMilliseconds,
      };
    } catch (e) {
      debugPrint('PlaylistMigrationService: Fatal error during migration: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Migrate a single playlist from MediaStore to database
  Future<Map<String, dynamic>> _migratePlaylist(
    query.PlaylistModel mediaStorePlaylist,
  ) async {
    try {
      debugPrint(
        'PlaylistMigrationService: Starting migration for "${mediaStorePlaylist.playlist}" (ID: ${mediaStorePlaylist.id})',
      );

      //check if this is the "Liked Songs" playlist (special case)
      final isFavorite = mediaStorePlaylist.playlist == _likedSongsPlaylistName;

      //get cover from SharedPreferences if exists
      final coverSongId = await _getPlaylistCoverFromPrefs(
        mediaStorePlaylist.id,
      );
      debugPrint('PlaylistMigrationService: Cover song ID: $coverSongId');

      //create playlist in database
      final dbPlaylistId = await _playlistsRepo.createPlaylist(
        name: mediaStorePlaylist.playlist,
        coverSongId: coverSongId,
        mediastoreId: mediaStorePlaylist.id, //store MediaStore ID
        isFavorite: isFavorite,
        syncStatus:
            PlaylistSyncStatus.synced, //already synced (its from MediaStore)
      );

      debugPrint(
        'PlaylistMigrationService: Created playlist in database with ID: $dbPlaylistId',
      );

      //get songs from MediaStore playlist
      List<query.SongModel> songs = [];
      try {
        songs = await _audioQuery.queryAudiosFrom(
          query.AudiosFromType.PLAYLIST,
          mediaStorePlaylist.id,
          sortType: null,
        );
        debugPrint(
          'PlaylistMigrationService: Found ${songs.length} songs in MediaStore playlist ${mediaStorePlaylist.id}',
        );
      } catch (e) {
        debugPrint(
          'PlaylistMigrationService: ERROR querying songs from MediaStore playlist ${mediaStorePlaylist.id}: $e',
        );
        //continue with empty songs list => playlist structure is still migrated
      }

      //add songs to database with positions
      if (songs.isNotEmpty) {
        final songData = <Map<String, dynamic>>[];

        for (int i = 0; i < songs.length; i++) {
          songData.add({
            'playlist_id': dbPlaylistId,
            'song_id': songs[i].id,
            'position': i,
            'added_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        try {
          await _playlistSongsRepo.batchAddSongs(songData);
          debugPrint(
            'PlaylistMigrationService: Successfully added ${songs.length} songs to database',
          );
        } catch (e) {
          debugPrint(
            'PlaylistMigrationService: ERROR adding songs to database: $e',
          );
          //dont fail the entire migration if songs fail => playlist structure is still migrated
          return {
            'success':
                true, //partial success => playlist created but songs failed
            'dbPlaylistId': dbPlaylistId,
            'songCount': 0,
            'hadCover': coverSongId != null,
            'warning': 'Playlist created but failed to migrate songs: $e',
          };
        }
      } else {
        debugPrint(
          'PlaylistMigrationService: No songs to migrate for "${mediaStorePlaylist.playlist}"',
        );
      }

      return {
        'success': true,
        'dbPlaylistId': dbPlaylistId,
        'songCount': songs.length,
        'hadCover': coverSongId != null,
      };
    } catch (e, stackTrace) {
      debugPrint(
        'PlaylistMigrationService: FATAL ERROR migrating playlist "${mediaStorePlaylist.playlist}": $e',
      );
      debugPrint('PlaylistMigrationService: Stack trace: $stackTrace');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get playlist cover from SharedPreferences
  Future<int?> _getPlaylistCoverFromPrefs(int mediaStorePlaylistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_playlistCoverKeyPrefix$mediaStorePlaylistId';
      return prefs.getInt(key);
    } catch (e) {
      debugPrint(
        'PlaylistMigrationService: Error getting cover from prefs: $e',
      );
      return null;
    }
  }

  ///reset migration (for testing/debugging only)
  Future<void> resetMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_migrationFlagKey);
      debugPrint('PlaylistMigrationService: Migration flag reset');
    } catch (e) {
      debugPrint('PlaylistMigrationService: Error resetting migration: $e');
    }
  }

  /// Get migration statistics (for debugging)
  Future<Map<String, dynamic>> getMigrationStats() async {
    try {
      final isComplete = await isMigrationComplete();
      final playlists = await _playlistsRepo.getAllPlaylists();

      int totalSongs = 0;
      int syncedCount = 0;
      int failedCount = 0;
      int withCovers = 0;

      for (final playlist in playlists) {
        final songCount = await _playlistSongsRepo.getSongCount(playlist.id);
        totalSongs += songCount;

        if (playlist.syncStatus == PlaylistSyncStatus.synced) {
          syncedCount++;
        } else if (playlist.syncStatus == PlaylistSyncStatus.failed) {
          failedCount++;
        }

        if (playlist.coverSongId != null) {
          withCovers++;
        }
      }

      return {
        'migrationComplete': isComplete,
        'totalPlaylists': playlists.length,
        'totalSongs': totalSongs,
        'syncedPlaylists': syncedCount,
        'failedPlaylists': failedCount,
        'playlistsWithCovers': withCovers,
      };
    } catch (e) {
      debugPrint('PlaylistMigrationService: Error getting stats: $e');
      return {};
    }
  }

  /// Clean up old SharedPreferences data (optional => run after successful migration)
  Future<void> cleanupOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int removedCount = 0;

      //remove playlist cover keys
      for (final key in keys) {
        if (key.startsWith(_playlistCoverKeyPrefix)) {
          await prefs.remove(key);
          removedCount++;
        }
      }

      debugPrint(
        'PlaylistMigrationService: Cleaned up $removedCount old preference keys',
      );
    } catch (e) {
      debugPrint('PlaylistMigrationService: Error cleaning up old data: $e');
    }
  }
}
