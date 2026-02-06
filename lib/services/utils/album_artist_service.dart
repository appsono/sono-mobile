import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Service to extract and cache proper album artists from song metadata
class AlbumArtistService {
  static final AlbumArtistService _instance = AlbumArtistService._internal();
  factory AlbumArtistService() => _instance;
  AlbumArtistService._internal();

  final Map<int, String> _cache = {}; // albumId -> proper artist name
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Get proper album artist for an album
  ///
  /// Returns the album artist from song metadata if available,
  /// otherwise falls back to the albums generic artist field
  Future<String> getAlbumArtist(int albumId, String? fallbackArtist) async {
    // Check cache first
    if (_cache.containsKey(albumId)) {
      return _cache[albumId]!;
    }

    try {
      //query songs from this album
      final songs = await _audioQuery.queryAudiosFrom(
        AudiosFromType.ALBUM_ID,
        albumId,
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      if (songs.isEmpty) {
        final result = fallbackArtist ?? 'Unknown Artist';
        _cache[albumId] = result;
        return result;
      }

      //extract album_artist from first songs metadata
      final albumArtistFromMetadata = songs.first.getMap["album_artist"];

      if (albumArtistFromMetadata != null &&
          albumArtistFromMetadata.toString().isNotEmpty &&
          albumArtistFromMetadata.toString().toLowerCase() != 'unknown' &&
          albumArtistFromMetadata.toString() != '<unknown>') {
        final result = albumArtistFromMetadata.toString();
        _cache[albumId] = result;
        return result;
      }

      //fallback to albums artist field
      final result = fallbackArtist ?? 'Unknown Artist';
      _cache[albumId] = result;
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting album artist for album $albumId: $e');
      }
      final result = fallbackArtist ?? 'Unknown Artist';
      _cache[albumId] = result;
      return result;
    }
  }

  /// Synchronously get cached album artist, or return fallback immediately
  /// (for widgets that need immediate rendering)
  String getCachedAlbumArtist(int albumId, String? fallbackArtist) {
    return _cache[albumId] ?? fallbackArtist ?? 'Unknown Artist';
  }

  /// Preload album artists for a list of albums
  /// Useful: list views => to load album artists in background
  Future<void> preloadAlbumArtists(List<int> albumIds) async {
    final uncachedIds =
        albumIds.where((id) => !_cache.containsKey(id)).toList();

    if (uncachedIds.isEmpty) return;

    //load in batches to avoid overwhelming system
    const batchSize = 10;
    for (var i = 0; i < uncachedIds.length; i += batchSize) {
      final batch = uncachedIds.skip(i).take(batchSize);
      await Future.wait(batch.map((id) => getAlbumArtist(id, null)));
    }
  }

  /// Clear the cache
  /// (useful for refresh)
  void clearCache() {
    _cache.clear();
  }

  /// Clear cache for specific album
  void clearAlbumCache(int albumId) {
    _cache.remove(albumId);
  }
}
