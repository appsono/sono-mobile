import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/models/kworb_response.dart';
import 'package:sono/models/popular_song.dart';
import 'package:sono/services/api/kworb_service.dart';
import 'package:sono/services/api/lastfm_service.dart';

class ArtistData {
  final String artistName;
  final List<PopularSong> topSongs;
  final String? bio;
  final String? bioUrl;
  final int? monthlyListeners;
  final int? totalPlays;
  final DateTime? lastFetchedAt;

  ArtistData({
    required this.artistName,
    this.topSongs = const [],
    this.bio,
    this.bioUrl,
    this.monthlyListeners,
    this.totalPlays,
    this.lastFetchedAt,
  });
}

class ArtistDataError {
  final String message;
  final String? reason;
  final bool isOffline;

  ArtistDataError({
    required this.message,
    this.reason,
    this.isOffline = false,
  });

  String get displayMessage {
    if (isOffline && reason != null) {
      return 'Unable to load data.\nReason: $reason';
    }
    if (reason != null) {
      return 'Unable to load description.\nReason: $reason';
    }
    return message;
  }
}

class ArtistDataRepository {
  static const String _tableName = 'artists';
  static const int _cacheValidityDays = 7;

  final SonoDatabaseHelper _dbHelper = SonoDatabaseHelper.instance;
  final KworbService _kworbService = KworbService();
  final LastfmService _lastfmService = LastfmService();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('ArtistDataRepository: $message');
    }
  }

  void _logError(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint(
        'ArtistDataRepository ERROR: $message${error != null ? ' - $error' : ''}',
      );
    }
  }

  Future<ArtistData?> getArtistData(
    String artistName, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedData(artistName);

    if (!forceRefresh && cached != null && _isCacheFresh(cached)) {
      _log('Returning cached data for: $artistName');
      return cached;
    }

    //try to fetch fresh data
    try {
      final freshData = await _fetchFreshData(artistName);
      await _cacheData(artistName, freshData);
      return freshData;
    } on SocketException catch (_) {
      _logError('Network unavailable for: $artistName');
      //return stale cache if available
      if (cached != null) {
        _log('Returning stale cache due to network error: $artistName');
        return cached;
      }
      rethrow;
    } catch (e) {
      _logError('Failed to fetch data for: $artistName', e);
      //return stale cache if available
      if (cached != null) {
        _log('Returning stale cache due to error: $artistName');
        return cached;
      }
      rethrow;
    }
  }

  Future<ArtistData?> _getCachedData(String artistName) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        _tableName,
        where: 'artist_name_lower = ?',
        whereArgs: [artistName.toLowerCase()],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return _parseRowToArtistData(row);
    } catch (e) {
      _logError('Error reading cache', e);
      return null;
    }
  }

  ArtistData _parseRowToArtistData(Map<String, dynamic> row) {
    List<PopularSong> topSongs = [];

    final topSongsJson = row['top_songs'] as String?;
    if (topSongsJson != null && topSongsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(topSongsJson) as List<dynamic>;
        topSongs = decoded
            .map((item) => PopularSong.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _logError('Error parsing top_songs JSON', e);
      }
    }

    DateTime? lastFetchedAt;
    final lastFetchedAtMs = row['last_fetched_at'] as int?;
    if (lastFetchedAtMs != null) {
      lastFetchedAt = DateTime.fromMillisecondsSinceEpoch(lastFetchedAtMs);
    }

    return ArtistData(
      artistName: row['artist_name'] as String,
      topSongs: topSongs,
      bio: row['bio'] as String?,
      bioUrl: row['bio_url'] as String?,
      monthlyListeners: row['monthly_listeners'] as int?,
      lastFetchedAt: lastFetchedAt,
    );
  }

  bool _isCacheFresh(ArtistData data) {
    if (data.lastFetchedAt == null) return false;
    final age = DateTime.now().difference(data.lastFetchedAt!);
    return age.inDays < _cacheValidityDays;
  }

  Future<ArtistData> _fetchFreshData(String artistName) async {
    _log('Fetching fresh data for: $artistName');

    //fetch kworb data and lastfm info in parallel
    final results = await Future.wait([
      _kworbService.getArtistData(artistName).catchError((e) {
        _logError('Failed to fetch Kworb data', e);
        return null;
      }),
      _lastfmService.getArtistInfo(artistName).catchError((e) {
        _logError('Failed to fetch lastfm info', e);
        return null;
      }),
    ]);

    final kworbResponse = results[0] as KworbResponse?;
    final lastfmInfo = results[1] as Map<String, dynamic>?;

    return ArtistData(
      artistName: artistName,
      topSongs: kworbResponse?.topSongs ?? [],
      bio: _extractBio(lastfmInfo),
      bioUrl: lastfmInfo?['url'] as String?,
      monthlyListeners: kworbResponse?.monthlyListeners,
      totalPlays: _extractPlayCount(lastfmInfo),
      lastFetchedAt: DateTime.now(),
    );
  }

  String? _extractBio(Map<String, dynamic>? info) {
    if (info == null) return null;
    final bio = info['bio'] as Map<String, dynamic>?;
    if (bio == null) return null;
    return bio['content'] as String? ?? bio['summary'] as String?;
  }

  int? _extractPlayCount(Map<String, dynamic>? info) {
    if (info == null) return null;
    final stats = info['stats'] as Map<String, dynamic>?;
    if (stats == null) return null;
    final playCount = stats['playcount'];
    if (playCount is int) return playCount;
    if (playCount is String) return int.tryParse(playCount);
    return null;
  }

  Future<void> _cacheData(String artistName, ArtistData data) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final topSongsJson = jsonEncode(
        data.topSongs.map((s) => s.toJson()).toList(),
      );

      await db.insert(
        _tableName,
        {
          'artist_name': artistName,
          'artist_name_lower': artistName.toLowerCase(),
          'top_songs': topSongsJson,
          'bio': data.bio,
          'bio_url': data.bioUrl,
          'monthly_listeners': data.monthlyListeners,
          'last_fetched_at': now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _log('Cached data for: $artistName');
    } catch (e) {
      _logError('Failed to cache data', e);
    }
  }

  Future<List<PopularSong>> matchSongsWithLibrary(
    List<PopularSong> popularSongs,
    List<SongModel> artistLibrarySongs,
  ) async {
    if (popularSongs.isEmpty || artistLibrarySongs.isEmpty) {
      return popularSongs;
    }

    _log('Matching ${popularSongs.length} songs against ${artistLibrarySongs.length} library songs');

    final matchedSongs = <PopularSong>[];

    for (final popularSong in popularSongs) {
      bool found = false;
      SongModel? bestMatch;

      /// Try 3 levels of matching => from strictest to most lenient

      /// Level 1: Exact match (case-insensitive, trimmed only)
      final exactTitle = popularSong.title.toLowerCase().trim();
      for (final librarySong in artistLibrarySongs) {
        final libraryTitle = librarySong.title.toLowerCase().trim();
        if (exactTitle == libraryTitle) {
          bestMatch = librarySong;
          found = true;
          break;
        }
      }

      /// Level 2: Match with basic normalization (remove feat/ft, special chars)
      if (!found) {
        final normalizedTitle = _normalizeTitle(popularSong.title, keepParentheses: true);
        for (final librarySong in artistLibrarySongs) {
          final normalizedLibraryTitle = _normalizeTitle(librarySong.title, keepParentheses: true);
          if (normalizedTitle == normalizedLibraryTitle) {
            bestMatch = librarySong;
            found = true;
            break;
          }
        }
      }

      /// Level 3: Match without parentheses (only if no better match found)
      if (!found) {
        final normalizedTitle = _normalizeTitle(popularSong.title, keepParentheses: false);
        for (final librarySong in artistLibrarySongs) {
          final normalizedLibraryTitle = _normalizeTitle(librarySong.title, keepParentheses: false);
          if (_titlesMatch(normalizedTitle, normalizedLibraryTitle)) {
            bestMatch = librarySong;
            found = true;
            break;
          }
        }
      }

      if (found && bestMatch != null) {
        matchedSongs.add(popularSong.copyWith(
          isInLibrary: true,
          localSong: bestMatch,
        ));
      } else {
        matchedSongs.add(popularSong);
      }
    }

    final matchCount = matchedSongs.where((s) => s.isInLibrary).length;
    _log('Matched $matchCount of ${popularSongs.length} songs');

    return matchedSongs;
  }

  String _normalizeTitle(String title, {bool keepParentheses = false}) {
    var normalized = title.toLowerCase();

    //remove feat/ft content
    normalized = normalized.replaceAll(RegExp(r'feat\..*', caseSensitive: false), '');
    normalized = normalized.replaceAll(RegExp(r'ft\..*', caseSensitive: false), '');

    //(optional) remove parenthetical and bracketed content
    //will keep it for now
    if (!keepParentheses) {
      normalized = normalized.replaceAll(RegExp(r'\(.*?\)'), '');
      normalized = normalized.replaceAll(RegExp(r'\[.*?\]'), '');
    }

    //remove special chars
    normalized = normalized.replaceAll(RegExp(r'[^\w\s()\[\]]'), '');

    //normalize whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  bool _titlesMatch(String title1, String title2) {
    //exact match after normalization
    if (title1 == title2) return true;

    //one contains the other (for partial matches)
    //only allow if match is substantial (>60% of the shorter title)
    if (title1.contains(title2) || title2.contains(title1)) {
      final shorter = title1.length < title2.length ? title1 : title2;
      final longer = title1.length >= title2.length ? title1 : title2;

      //require at least 60% overlap and substantial length
      if (shorter.length > 5 && shorter.length >= longer.length * 0.6) {
        return true;
      }
    }

    return false;
  }

  Future<void> clearCache() async {
    try {
      final db = await _dbHelper.database;
      await db.delete(_tableName);
      _log('Cache cleared');
    } catch (e) {
      _logError('Failed to clear cache', e);
    }
  }

  Future<void> clearCacheForArtist(String artistName) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        _tableName,
        where: 'artist_name_lower = ?',
        whereArgs: [artistName.toLowerCase()],
      );
      _log('Cache cleared for: $artistName');
    } catch (e) {
      _logError('Failed to clear cache for artist', e);
    }
  }
}
