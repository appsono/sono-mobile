import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart' as query;
import '../../data/repositories/playlists_repository.dart';
import '../../data/repositories/playlist_songs_repository.dart';
import '../../data/models/playlist_model.dart';

/// Service for synchronizing playlists with Android MediaStore
/// Handles creating, updating, and deleting MediaStore playlists
class MediaStoreSyncService {
  final query.OnAudioQuery _audioQuery = query.OnAudioQuery();
  final PlaylistsRepository _playlistsRepo = PlaylistsRepository();
  final PlaylistSongsRepository _playlistSongsRepo = PlaylistSongsRepository();

  //== MediaStore Playlist Creation ===

  /// Create a playlist in MediaStore with duplicate name handling
  /// Returns the MediaStore playlist ID or null if failed
  Future<int?> createMediaStorePlaylist(String baseName) async {
    try {
      String finalName = baseName;
      int attempt = 1;

      //check for duplicates and append number if needed
      while (await _mediaStorePlaylistExists(finalName)) {
        attempt++;
        finalName = '$baseName ($attempt)';

        //safety limit to prevent infinite loops
        if (attempt > 100) {
          debugPrint(
            'MediaStoreSyncService: Too many duplicate playlists for "$baseName"',
          );
          return null;
        }
      }

      //create the playlist
      final success = await _audioQuery.createPlaylist(finalName);

      if (!success) {
        debugPrint(
          'MediaStoreSyncService: Failed to create MediaStore playlist "$finalName"',
        );
        return null;
      }

      //query to get the newly created playlist ID
      final playlists = await _audioQuery.queryPlaylists();
      final newPlaylist = playlists.firstWhere(
        (p) => p.playlist == finalName,
        orElse: () => throw Exception('Playlist not found after creation'),
      );

      debugPrint(
        'MediaStoreSyncService: Created MediaStore playlist "$finalName" with ID ${newPlaylist.id}',
      );
      return newPlaylist.id;
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error creating MediaStore playlist: $e',
      );
      return null;
    }
  }

  /// Check if a MediaStore playlist with the given name exists
  Future<bool> _mediaStorePlaylistExists(String name) async {
    try {
      final playlists = await _audioQuery.queryPlaylists();
      return playlists.any((p) => p.playlist == name);
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error checking playlist existence: $e',
      );
      return false;
    }
  }

  //== MediaStore Playlist Deletion ===

  /// Delete a playlist from MediaStore
  Future<bool> deleteMediaStorePlaylist(int mediastoreId) async {
    try {
      final success = await _audioQuery.removePlaylist(mediastoreId);

      if (success) {
        debugPrint(
          'MediaStoreSyncService: Deleted MediaStore playlist $mediastoreId',
        );
      } else {
        debugPrint(
          'MediaStoreSyncService: Failed to delete MediaStore playlist $mediastoreId',
        );
      }

      return success;
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error deleting MediaStore playlist: $e',
      );
      return false;
    }
  }

  //== MediaStore Song Management ===

  /// Add a song to a MediaStore playlist
  Future<bool> addSongToMediaStorePlaylist(int mediastoreId, int songId) async {
    try {
      final success = await _audioQuery.addToPlaylist(mediastoreId, songId);

      if (success) {
        debugPrint(
          'MediaStoreSyncService: Added song $songId to MediaStore playlist $mediastoreId',
        );
      } else {
        debugPrint(
          'MediaStoreSyncService: Failed to add song to MediaStore playlist',
        );
      }

      return success;
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error adding song to MediaStore playlist: $e',
      );
      return false;
    }
  }

  /// Remove a song from a MediaStore playlist
  Future<bool> removeSongFromMediaStorePlaylist(
    int mediastoreId,
    int songId,
  ) async {
    try {
      final success = await _audioQuery.removeFromPlaylist(
        mediastoreId,
        songId,
      );

      if (success) {
        debugPrint(
          'MediaStoreSyncService: Removed song $songId from MediaStore playlist $mediastoreId',
        );
      } else {
        debugPrint(
          'MediaStoreSyncService: Failed to remove song from MediaStore playlist',
        );
      }

      return success;
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error removing song from MediaStore playlist: $e',
      );
      return false;
    }
  }

  /// Sync all songs in a playlist to MediaStore
  Future<bool> syncPlaylistSongsToMediaStore(
    int playlistId,
    int mediastoreId,
  ) async {
    try {
      //get songs from database
      final songIds = await _playlistSongsRepo.getSongIds(playlistId);

      if (songIds.isEmpty) {
        debugPrint(
          'MediaStoreSyncService: No songs to sync for playlist $playlistId',
        );
        return true;
      }

      //clear MediaStore playlist first (easier than trying to sync deltas)
      final currentSongs = await _audioQuery.queryAudiosFrom(
        query.AudiosFromType.PLAYLIST,
        mediastoreId,
      );

      for (final song in currentSongs) {
        await _audioQuery.removeFromPlaylist(mediastoreId, song.id);
      }

      //add all songs from database in order
      bool allSucceeded = true;
      for (final songId in songIds) {
        final success = await addSongToMediaStorePlaylist(mediastoreId, songId);
        if (!success) {
          allSucceeded = false;
        }
      }

      if (allSucceeded) {
        debugPrint(
          'MediaStoreSyncService: Successfully synced ${songIds.length} songs to MediaStore playlist $mediastoreId',
        );
      } else {
        debugPrint(
          'MediaStoreSyncService: Some songs failed to sync to MediaStore playlist $mediastoreId',
        );
      }

      return allSucceeded;
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error syncing songs to MediaStore: $e',
      );
      return false;
    }
  }

  //== Retry Failed Syncs ===

  /// Retry syncing a playlist that previously failed
  Future<bool> retrySyncPlaylist(int playlistId) async {
    try {
      final playlist = await _playlistsRepo.getPlaylist(playlistId);
      if (playlist == null) {
        debugPrint(
          'MediaStoreSyncService: Playlist $playlistId not found for retry',
        );
        return false;
      }

      //if already has MediaStore ID => try to sync songs
      if (playlist.mediastoreId != null) {
        final success = await syncPlaylistSongsToMediaStore(
          playlistId,
          playlist.mediastoreId!,
        );

        if (success) {
          await _playlistsRepo.updateSyncStatus(
            playlistId,
            PlaylistSyncStatus.synced,
          );
          return true;
        } else {
          await _playlistsRepo.updateSyncStatus(
            playlistId,
            PlaylistSyncStatus.failed,
          );
          return false;
        }
      }

      //try to create MediaStore playlist
      final mediastoreId = await createMediaStorePlaylist(playlist.name);

      if (mediastoreId == null) {
        await _playlistsRepo.updateSyncStatus(
          playlistId,
          PlaylistSyncStatus.failed,
        );
        return false;
      }

      //store MediaStore ID
      await _playlistsRepo.setMediaStoreId(playlistId, mediastoreId);

      //sync songs
      final success = await syncPlaylistSongsToMediaStore(
        playlistId,
        mediastoreId,
      );

      if (success) {
        await _playlistsRepo.updateSyncStatus(
          playlistId,
          PlaylistSyncStatus.synced,
        );
        debugPrint(
          'MediaStoreSyncService: Successfully retried sync for playlist $playlistId',
        );
        return true;
      } else {
        await _playlistsRepo.updateSyncStatus(
          playlistId,
          PlaylistSyncStatus.failed,
        );
        debugPrint(
          'MediaStoreSyncService: Retry sync partially failed for playlist $playlistId',
        );
        return false;
      }
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error retrying sync for playlist $playlistId: $e',
      );
      await _playlistsRepo.updateSyncStatus(
        playlistId,
        PlaylistSyncStatus.failed,
      );
      return false;
    }
  }

  /// Retry all playlists that need syncing
  Future<Map<String, int>> retryAllFailedSyncs() async {
    try {
      final playlistsNeedingSync =
          await _playlistsRepo.getPlaylistsNeedingSync();

      int succeeded = 0;
      int failed = 0;

      for (final playlist in playlistsNeedingSync) {
        final success = await retrySyncPlaylist(playlist.id);
        if (success) {
          succeeded++;
        } else {
          failed++;
        }
      }

      debugPrint(
        'MediaStoreSyncService: Retry complete - $succeeded succeeded, $failed failed',
      );

      return {
        'succeeded': succeeded,
        'failed': failed,
        'total': playlistsNeedingSync.length,
      };
    } catch (e) {
      debugPrint('MediaStoreSyncService: Error retrying all failed syncs: $e');
      return {'succeeded': 0, 'failed': 0, 'total': 0};
    }
  }

  //== Utilities ===

  /// Get the display name for a MediaStore playlist (with number suffix if exists)
  Future<String> getDisplayName(String baseName) async {
    String finalName = baseName;
    int attempt = 1;

    while (await _mediaStorePlaylistExists(finalName)) {
      attempt++;
      finalName = '$baseName ($attempt)';

      if (attempt > 100) {
        debugPrint(
          'MediaStoreSyncService: Warning - many duplicates for "$baseName"',
        );
        break;
      }
    }

    return finalName;
  }

  /// Check if MediaStore playlist still exists
  Future<bool> mediaStorePlaylistExists(int mediastoreId) async {
    try {
      final playlists = await _audioQuery.queryPlaylists();
      return playlists.any((p) => p.id == mediastoreId);
    } catch (e) {
      debugPrint(
        'MediaStoreSyncService: Error checking MediaStore playlist existence: $e',
      );
      return false;
    }
  }
}