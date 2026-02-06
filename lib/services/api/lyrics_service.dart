import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sono/utils/string_cleanup.dart';

class LyricsService {
  final String _searchApiUrl = 'https://lrclib.net/api/search';

  /// Searches for lyrics for given track
  /// and
  /// Returns list of potential lyric matches
  Future<List<Map<String, dynamic>>> searchLyrics({
    required String artistName,
    required String trackName,
    String? albumName,
    bool usePrimaryArtistCleanup = true,
  }) async {
    if (artistName.isEmpty || trackName.isEmpty) {
      return [];
    }

    final processedArtistName =
        usePrimaryArtistCleanup ? getPrimaryArtist(artistName) : artistName;

    final params = {
      'artist_name': processedArtistName,
      'track_name': trackName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
    };

    final uri = Uri.parse(_searchApiUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      } else {
        if (kDebugMode) {
          print(
            'LyricsService Error: Failed to search for lyrics - Status: ${response.statusCode}',
          );
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('LyricsService Error: Exception searching for lyrics: $e');
      }
      return [];
    }
  }
}

class LyricsCacheService {
  LyricsCacheService._privateConstructor();
  static final LyricsCacheService instance =
      LyricsCacheService._privateConstructor();

  final LyricsService _lyricsService = LyricsService();
  final Map<String, List<Map<String, dynamic>>> _lyricsCache = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _ongoingFetches = {};

  //prevent unbounded cache growth => limit to 50 lyrics
  static const int _maxCacheSize = 50;
  final List<String> _cacheAccessOrder = []; //LRU tracking

  String _getCacheKey(
    String artist,
    String title,
    bool usePrimaryArtistCleanup,
  ) {
    return "${artist.toLowerCase()}|${title.toLowerCase()}|$usePrimaryArtistCleanup";
  }

  Future<List<Map<String, dynamic>>> getOrFetchLyrics({
    required String artist,
    required String title,
    String? album,
    bool usePrimaryArtistCleanup = true,
  }) async {
    final cacheKey = _getCacheKey(artist, title, usePrimaryArtistCleanup);

    if (_lyricsCache.containsKey(cacheKey)) {
      //update LRU order
      _cacheAccessOrder.remove(cacheKey);
      _cacheAccessOrder.add(cacheKey);
      return _lyricsCache[cacheKey]!;
    }

    if (_ongoingFetches.containsKey(cacheKey)) {
      return await _ongoingFetches[cacheKey]!;
    }

    final future = _lyricsService.searchLyrics(
      artistName: artist,
      trackName: title,
      albumName: album,
      usePrimaryArtistCleanup: usePrimaryArtistCleanup,
    );
    _ongoingFetches[cacheKey] = future;

    try {
      final lyrics = await future;
      _lyricsCache[cacheKey] = lyrics;
      _cacheAccessOrder.add(cacheKey);

      //enforce cache size limit => remove oldest entries
      while (_lyricsCache.length > _maxCacheSize) {
        final oldestKey = _cacheAccessOrder.removeAt(0);
        _lyricsCache.remove(oldestKey);
        if (kDebugMode) {
          debugPrint('[Memory] Evicted old lyrics from cache: $oldestKey');
        }
      }

      return lyrics;
    } catch (e) {
      if (kDebugMode) {
        print(
          'LyricsCacheService: Error fetching lyrics for $artist - $title (cleanup: $usePrimaryArtistCleanup): $e',
        );
      }
      return [];
    } finally {
      _ongoingFetches.remove(cacheKey);
    }
  }

  void prefetchLyrics({
    required String artist,
    required String title,
    String? album,
    bool usePrimaryArtistCleanup = true,
  }) {
    final cacheKey = _getCacheKey(artist, title, usePrimaryArtistCleanup);
    if (!_lyricsCache.containsKey(cacheKey) &&
        !_ongoingFetches.containsKey(cacheKey)) {
      getOrFetchLyrics(
        artist: artist,
        title: title,
        album: album,
        usePrimaryArtistCleanup: usePrimaryArtistCleanup,
      );
    }
  }

  void clearCache() {
    _lyricsCache.clear();
    _ongoingFetches.clear();
  }
}