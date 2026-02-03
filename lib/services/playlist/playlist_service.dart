import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:sono/data/repositories/playlists_repository.dart';
import 'package:sono/data/repositories/playlist_songs_repository.dart';
import 'package:sono/data/models/playlist_model.dart';
import 'package:sono/services/playlist/mediastore_sync_service.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'playlist_cover_service.dart';

/// Main service for playlist management
/// Coordinates database operations and MediaStore synchronization
class PlaylistService extends ChangeNotifier {
  final PlaylistsRepository _playlistsRepo = PlaylistsRepository();
  final PlaylistSongsRepository _playlistSongsRepo = PlaylistSongsRepository();
  final MediaStoreSyncService _syncService = MediaStoreSyncService();
  final PlaylistCoverService _coverService = PlaylistCoverService.instance;

  //=== CREATE ===

  /// Create a new playlist
  /// Returns the database playlist ID
  Future<int> createPlaylist({
    required String name,
    String? description,
    int? coverSongId,
    bool isFavorite = false,
  }) async {
    try {
      //1. create in database first (critical => must succeed)
      final playlistId = await _playlistsRepo.createPlaylist(
        name: name,
        description: description,
        coverSongId: coverSongId,
        isFavorite: isFavorite,
        syncStatus: PlaylistSyncStatus.pending,
      );

      debugPrint(
        'PlaylistService: Created playlist "$name" in database with ID $playlistId',
      );

      //2. try to create in MediaStore (best effort)
      final mediastoreId = await _syncService.createMediaStorePlaylist(name);

      if (mediastoreId != null) {
        //uccess - update database with MediaStore ID
        await _playlistsRepo.setMediaStoreId(playlistId, mediastoreId);
        debugPrint(
          'PlaylistService: Synced playlist $playlistId to MediaStore with ID $mediastoreId',
        );
      } else {
        //failed => mark as failed but playlist still exists in database
        await _playlistsRepo.updateSyncStatus(
          playlistId,
          PlaylistSyncStatus.failed,
        );
        debugPrint(
          'PlaylistService: Failed to sync playlist $playlistId to MediaStore',
        );
      }

      notifyListeners();
      return playlistId;
    } catch (e) {
      debugPrint('PlaylistService: Error creating playlist: $e');
      rethrow;
    }
  }

  //=== READ ===

  /// Get a playlist by ID
  Future<PlaylistModel?> getPlaylist(int id) async {
    return await _playlistsRepo.getPlaylist(id);
  }

  /// Get all playlists
  Future<List<PlaylistModel>> getAllPlaylists({
    bool favoritesFirst = true,
  }) async {
    return await _playlistsRepo.getAllPlaylists(favoritesFirst: favoritesFirst);
  }

  /// Get song IDs in a playlist
  Future<List<int>> getPlaylistSongIds(int playlistId) async {
    return await _playlistSongsRepo.getSongIds(playlistId);
  }

  /// Get song count in a playlist
  Future<int> getPlaylistSongCount(int playlistId) async {
    return await _playlistSongsRepo.getSongCount(playlistId);
  }

  /// Get playlists that need syncing (for UI badges)
  Future<List<PlaylistModel>> getPlaylistsNeedingSync() async {
    return await _playlistsRepo.getPlaylistsNeedingSync();
  }

  //=== UPDATE ===

  /// Update playlist metadata
  Future<void> updatePlaylist({
    required int id,
    String? name,
    String? description,
    bool? isFavorite,
  }) async {
    try {
      await _playlistsRepo.updatePlaylist(
        id: id,
        name: name,
        description: description,
        isFavorite: isFavorite,
      );

      //note: we dont sync name changes to MediaStore to avoid complexity
      //MediaStore playlists might have numbered suffixes anyway

      notifyListeners();
      debugPrint('PlaylistService: Updated playlist $id');
    } catch (e) {
      debugPrint('PlaylistService: Error updating playlist: $e');
      rethrow;
    }
  }

  /// Get playlist cover (song artwork)
  Future<void> setPlaylistCover(int playlistId, int songId) async {
    try {
      //remove any existing custom cover file
      await _coverService.deletePlaylistCover(playlistId);

      await _playlistsRepo.setPlaylistCover(playlistId, songId);
      notifyListeners();
      debugPrint('PlaylistService: Set cover for playlist $playlistId');
    } catch (e) {
      debugPrint('PlaylistService: Error setting playlist cover: $e');
      rethrow;
    }
  }

  /// Get custom cover image from file path
  Future<bool> setCustomPlaylistCover(int playlistId, String imagePath) async {
    try {
      //save image to apps private storage
      final savedPath = await _coverService.savePlaylistCover(
        playlistId,
        imagePath,
      );

      if (savedPath == null) {
        debugPrint(
          'PlaylistService: Failed to save custom cover for playlist $playlistId',
        );
        return false;
      }

      //update database with custom cover path
      await _playlistsRepo.setCustomCover(playlistId, savedPath);
      notifyListeners();
      debugPrint('PlaylistService: Set custom cover for playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('PlaylistService: Error setting custom playlist cover: $e');
      return false;
    }
  }

  /// Remove playlist cover (both song and custom)
  Future<void> removePlaylistCover(int playlistId) async {
    try {
      //delete any custom cover file
      await _coverService.deletePlaylistCover(playlistId);

      await _playlistsRepo.removePlaylistCover(playlistId);
      notifyListeners();
      debugPrint('PlaylistService: Removed cover for playlist $playlistId');
    } catch (e) {
      debugPrint('PlaylistService: Error removing playlist cover: $e');
      rethrow;
    }
  }

  /// Get playlist cover song ID
  Future<int?> getPlaylistCover(int playlistId) async {
    return await _playlistsRepo.getPlaylistCover(playlistId);
  }

  /// Get custom cover path for a playlist
  Future<String?> getCustomCoverPath(int playlistId) async {
    return await _playlistsRepo.getCustomCoverPath(playlistId);
  }

  /// Get playlist cover info (returns both song ID and custom path)
  Future<PlaylistCoverInfo> getPlaylistCoverInfo(int playlistId) async {
    final playlist = await _playlistsRepo.getPlaylist(playlistId);
    return PlaylistCoverInfo(
      coverSongId: playlist?.coverSongId,
      customCoverPath: playlist?.customCoverPath,
    );
  }

  /// Cleanup orphaned cover files (covers for deleted playlists)
  Future<int> cleanupOrphanedCovers() async {
    try {
      final playlists = await _playlistsRepo.getAllPlaylists();
      final validIds = playlists.map((p) => p.id).toSet();
      return await _coverService.cleanupOrphanedCovers(validIds);
    } catch (e) {
      debugPrint('PlaylistService: Error cleaning up orphaned covers: $e');
      return 0;
    }
  }

  //== DELETE ===

  /// Delete a playlist
  Future<void> deletePlaylist(int id) async {
    try {
      //get playlist info before deleting
      final playlist = await _playlistsRepo.getPlaylist(id);

      if (playlist == null) {
        debugPrint('PlaylistService: Playlist $id not found');
        return;
      }

      //1. delete custom cover file if exists
      await _coverService.deletePlaylistCover(id);

      //2. delete from database (CASCADE will delete songs)
      await _playlistsRepo.deletePlaylist(id);
      debugPrint('PlaylistService: Deleted playlist $id from database');

      //3. try to delete from MediaStore (best effort)
      if (playlist.mediastoreId != null) {
        final success = await _syncService.deleteMediaStorePlaylist(
          playlist.mediastoreId!,
        );
        if (success) {
          debugPrint(
            'PlaylistService: Deleted MediaStore playlist ${playlist.mediastoreId}',
          );
        } else {
          debugPrint(
            'PlaylistService: Failed to delete MediaStore playlist ${playlist.mediastoreId}',
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('PlaylistService: Error deleting playlist: $e');
      rethrow;
    }
  }

  //== SONG MANAGEMENT ===

  /// Add a song to a playlist
  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    try {
      //1. add to database
      await _playlistSongsRepo.addSong(playlistId: playlistId, songId: songId);
      debugPrint(
        'PlaylistService: Added song $songId to playlist $playlistId in database',
      );

      //2. sync to MediaStore (best effort)
      final playlist = await _playlistsRepo.getPlaylist(playlistId);
      if (playlist?.mediastoreId != null) {
        final success = await _syncService.addSongToMediaStorePlaylist(
          playlist!.mediastoreId!,
          songId,
        );

        if (!success && playlist.syncStatus == PlaylistSyncStatus.synced) {
          //mark as failed if it was previously synced
          await _playlistsRepo.updateSyncStatus(
            playlistId,
            PlaylistSyncStatus.failed,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('PlaylistService: Error adding song to playlist: $e');
      rethrow;
    }
  }

  /// Add multiple songs to a playlist
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    try {
      //1. add to database
      await _playlistSongsRepo.addSongs(
        playlistId: playlistId,
        songIds: songIds,
      );
      debugPrint(
        'PlaylistService: Added ${songIds.length} songs to playlist $playlistId in database',
      );

      //2. sync to MediaStore (best effort)
      final playlist = await _playlistsRepo.getPlaylist(playlistId);
      if (playlist?.mediastoreId != null) {
        final success = await _syncService.syncPlaylistSongsToMediaStore(
          playlistId,
          playlist!.mediastoreId!,
        );

        if (!success && playlist.syncStatus == PlaylistSyncStatus.synced) {
          await _playlistsRepo.updateSyncStatus(
            playlistId,
            PlaylistSyncStatus.failed,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('PlaylistService: Error adding songs to playlist: $e');
      rethrow;
    }
  }

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      //1. remove from database
      await _playlistSongsRepo.removeSong(
        playlistId: playlistId,
        songId: songId,
      );
      debugPrint(
        'PlaylistService: Removed song $songId from playlist $playlistId in database',
      );

      //2. sync to MediaStore (best effort)
      final playlist = await _playlistsRepo.getPlaylist(playlistId);
      if (playlist?.mediastoreId != null) {
        final success = await _syncService.removeSongFromMediaStorePlaylist(
          playlist!.mediastoreId!,
          songId,
        );

        if (!success && playlist.syncStatus == PlaylistSyncStatus.synced) {
          await _playlistsRepo.updateSyncStatus(
            playlistId,
            PlaylistSyncStatus.failed,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('PlaylistService: Error removing song from playlist: $e');
      rethrow;
    }
  }

  /// Reorder a song in a playlist
  Future<void> reorderSong({
    required int playlistId,
    required int songId,
    required int newPosition,
  }) async {
    try {
      await _playlistSongsRepo.reorderSong(
        playlistId: playlistId,
        songId: songId,
        newPosition: newPosition,
      );

      //update MediaStore playlist if synced
      //MediaStore doesnt support reordering => so we rebuild the playlist
      final playlist = await _playlistsRepo.getPlaylist(playlistId);
      if (playlist?.mediastoreId != null) {
        final success = await _syncService.syncPlaylistSongsToMediaStore(
          playlistId,
          playlist!.mediastoreId!,
        );
        if (!success) {
          await _playlistsRepo.updateSyncStatus(
            playlistId,
            PlaylistSyncStatus.failed,
          );
          debugPrint(
            'PlaylistService: Failed to sync reordered playlist $playlistId to MediaStore',
          );
        }
      }

      notifyListeners();
      debugPrint(
        'PlaylistService: Reordered song $songId in playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PlaylistService: Error reordering song: $e');
      rethrow;
    }
  }

  /// Clear all songs from a playlist
  Future<void> clearPlaylist(int playlistId) async {
    try {
      //1. clear database
      await _playlistSongsRepo.clearPlaylist(playlistId);
      debugPrint('PlaylistService: Cleared playlist $playlistId in database');

      //2. sync to MediaStore (best effort)
      final playlist = await _playlistsRepo.getPlaylist(playlistId);
      if (playlist?.mediastoreId != null) {
        await _syncService.syncPlaylistSongsToMediaStore(
          playlistId,
          playlist!.mediastoreId!,
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('PlaylistService: Error clearing playlist: $e');
      rethrow;
    }
  }

  /// Check if a song is in a playlist
  Future<bool> isSongInPlaylist(int playlistId, int songId) async {
    return await _playlistSongsRepo.isSongInPlaylist(playlistId, songId);
  }

  //=== SYNC MANAGEMENT ===

  /// Retry syncing a failed playlist
  Future<bool> retrySync(int playlistId) async {
    try {
      final success = await _syncService.retrySyncPlaylist(playlistId);

      if (success) {
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('PlaylistService: Error retrying sync: $e');
      return false;
    }
  }

  /// Retry all failed syncs
  Future<Map<String, int>> retryAllFailedSyncs() async {
    try {
      final result = await _syncService.retryAllFailedSyncs();
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('PlaylistService: Error retrying all syncs: $e');
      return {'succeeded': 0, 'failed': 0, 'total': 0};
    }
  }

  //=== UTILITIES ===

  /// Check if playlist name already exists
  Future<bool> playlistNameExists(String name, {int? excludeId}) async {
    return await _playlistsRepo.playlistNameExists(name, excludeId: excludeId);
  }

  //=== M3U IMPORT ===

  /// Import a playlist from an M3U file
  /// Returns a result object with the playlist ID and import statistics
  Future<M3uImportResult> importM3uPlaylist(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return M3uImportResult(
        success: false,
        error: 'File not found: $filePath',
      );
    }

    try {
      //parse the M3U file
      final content = await file.readAsString();
      final parsedData = _parseM3uContent(content, filePath);

      if (parsedData.paths.isEmpty) {
        return M3uImportResult(
          success: false,
          error: 'No valid entries found in M3U file',
        );
      }

      //get all filtered songs from MediaStore to match paths
      final audioQuery = oaq.OnAudioQuery();
      final allSongs = await AudioFilterUtils.getFilteredSongs(
        audioQuery,
        sortType: null,
        orderType: oaq.OrderType.ASC_OR_SMALLER,
      );

      //match paths to songs
      final matchedSongIds = <int>[];
      final unmatchedPaths = <String>[];

      for (final path in parsedData.paths) {
        final matchedSong = _findSongByPath(allSongs, path);
        if (matchedSong != null) {
          matchedSongIds.add(matchedSong.id);
        } else {
          unmatchedPaths.add(path);
        }
      }

      if (matchedSongIds.isEmpty) {
        return M3uImportResult(
          success: false,
          error:
              'No songs matched from M3U file. Ensure the songs exist in your library.',
          totalEntries: parsedData.paths.length,
          unmatchedPaths: unmatchedPaths,
        );
      }

      //create the playlist
      final playlistName = parsedData.name ?? _extractPlaylistName(filePath);
      final playlistId = await createPlaylist(name: playlistName);

      //add matched songs to the playlist
      await addSongsToPlaylist(playlistId, matchedSongIds);

      debugPrint(
        'PlaylistService: Imported M3U playlist "$playlistName" with ${matchedSongIds.length} songs',
      );

      return M3uImportResult(
        success: true,
        playlistId: playlistId,
        playlistName: playlistName,
        totalEntries: parsedData.paths.length,
        matchedCount: matchedSongIds.length,
        unmatchedPaths: unmatchedPaths,
      );
    } catch (e) {
      debugPrint('PlaylistService: Error importing M3U: $e');
      return M3uImportResult(
        success: false,
        error: 'Failed to import M3U file: $e',
      );
    }
  }

  /// Parse M3U file content
  _M3uParseResult _parseM3uContent(String content, String filePath) {
    final lines =
        content
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
    final paths = <String>[];
    String? playlistName;

    final baseDir = File(filePath).parent.path;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      //skip M3U header
      if (line.startsWith('#EXTM3U')) continue;

      //parse extended info for playlist name
      if (line.startsWith('#PLAYLIST:')) {
        playlistName = line.substring('#PLAYLIST:'.length).trim();
        continue;
      }

      //skip other comments/metadata
      if (line.startsWith('#')) continue;

      //this is a path entry
      String path = line;

      //handle relative paths
      if (!path.startsWith('/') && !path.startsWith('file://')) {
        path = '$baseDir/$path';
      }

      //onrmalize file:///Ls
      if (path.startsWith('file://')) {
        path = Uri.decodeFull(path.substring('file://'.length));
      }

      //clean up path
      path = path.replaceAll('//', '/').replaceAll('/./', '/');

      paths.add(path);
    }

    return _M3uParseResult(paths: paths, name: playlistName);
  }

  /// Find a song by its file path
  oaq.SongModel? _findSongByPath(List<oaq.SongModel> songs, String path) {
    //try exact match first
    for (final song in songs) {
      if (song.data == path) {
        return song;
      }
    }

    //try matching by filename (fallback for moved files)
    final filename = path.split('/').last.toLowerCase();
    for (final song in songs) {
      final songFilename = song.data.split('/').last.toLowerCase();
      if (songFilename == filename) {
        return song;
      }
    }

    //try matching by title (last resort)
    final titleFromPath =
        filename
            .replaceAll(RegExp(r'\.[^.]+$'), '') //remove extension
            .replaceAll(
              RegExp(r'^\d+[\s._-]*'),
              '',
            ) //remove track number prefix
            .toLowerCase();

    for (final song in songs) {
      if (song.title.toLowerCase() == titleFromPath) {
        return song;
      }
    }

    return null;
  }

  /// Extract playlist name from file path
  String _extractPlaylistName(String filePath) {
    final filename = filePath.split('/').last;
    //remove extension (.m3u, .m3u8)
    return filename.replaceAll(RegExp(r'\.(m3u8?|M3U8?)$'), '');
  }

  /// Export a playlist to M3U format
  Future<String?> exportPlaylistToM3u(int playlistId, String outputPath) async {
    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) {
        debugPrint(
          'PlaylistService: Playlist $playlistId not found for export',
        );
        return null;
      }

      final songIds = await getPlaylistSongIds(playlistId);
      if (songIds.isEmpty) {
        debugPrint(
          'PlaylistService: Playlist $playlistId has no songs to export',
        );
        return null;
      }

      //get filtered song data
      final audioQuery = oaq.OnAudioQuery();
      final allSongs = await AudioFilterUtils.getFilteredSongs(audioQuery);

      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#PLAYLIST:${playlist.name}');
      buffer.writeln();

      for (final songId in songIds) {
        final song = allSongs.firstWhere(
          (s) => s.id == songId,
          orElse: () => throw StateError('Song not found'),
        );

        //write extended info
        final duration = (song.duration ?? 0) ~/ 1000; //convert ms to seconds
        buffer.writeln(
          '#EXTINF:$duration,${song.artist ?? "Unknown"} - ${song.title}',
        );
        buffer.writeln(song.data);
      }

      //write to file
      final file = File(outputPath);
      await file.writeAsString(buffer.toString());

      debugPrint(
        'PlaylistService: Exported playlist "${playlist.name}" to $outputPath',
      );
      return outputPath;
    } catch (e) {
      debugPrint('PlaylistService: Error exporting playlist to M3U: $e');
      return null;
    }
  }
}

/// Result of M3U parsing
class _M3uParseResult {
  final List<String> paths;
  final String? name;

  _M3uParseResult({required this.paths, this.name});
}

/// Result of M3U import operation
class M3uImportResult {
  final bool success;
  final int? playlistId;
  final String? playlistName;
  final String? error;
  final int totalEntries;
  final int matchedCount;
  final List<String> unmatchedPaths;

  M3uImportResult({
    required this.success,
    this.playlistId,
    this.playlistName,
    this.error,
    this.totalEntries = 0,
    this.matchedCount = 0,
    this.unmatchedPaths = const [],
  });

  int get unmatchedCount => totalEntries - matchedCount;
}

/// Playlist cover information
class PlaylistCoverInfo {
  final int? coverSongId;
  final String? customCoverPath;

  PlaylistCoverInfo({this.coverSongId, this.customCoverPath});

  bool get hasCustomCover =>
      customCoverPath != null && customCoverPath!.isNotEmpty;
  bool get hasSongCover => coverSongId != null;
  bool get hasCover => hasCustomCover || hasSongCover;
}
