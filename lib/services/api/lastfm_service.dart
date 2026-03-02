import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/services/utils/env_config.dart';
import 'package:sono/services/utils/preferences_service.dart';

class LastfmService {
  static String get _apiKey => EnvConfig.lastfmApiKey;
  static String get _apiSecret => EnvConfig.lastfmSharedSecret;
  final String _apiUrl = 'https://ws.audioscrobbler.com/2.0/';
  final _prefsService = PreferencesService();

  static const String _sessionKeyPref = 'lastfm_session_key_v3';
  static const String _userNamePref = 'lastfm_username_v3';
  static const String _artistInfoCachePrefix = 'lastfm_artist_info_cache_v1_';
  static const String _pendingScrobblesKey = 'lastfm_pending_scrobbles_v1';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<Map<String, dynamic>?> getAlbumInfo({
    required String artist,
    required String album,
  }) async {
    if (artist.isEmpty || album.isEmpty) return null;

    final params = {
      'method': 'album.getInfo',
      'artist': artist,
      'album': album,
      'autocorrect': '1',
    };

    try {
      final response = await _callApi(params, isPost: false, requiresSk: false);
      if (response.containsKey('album')) {
        return response['album'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Last.fm: Could not fetch album info for "$album". Error: $e');
      }
      return null;
    }
  }

  Future<void> _saveSessionDetails(String sessionKey, String userName) async {
    final prefs = await _prefs;
    await prefs.setString(_sessionKeyPref, sessionKey);
    await prefs.setString(_userNamePref, userName);
    if (kDebugMode) {
      print('Last.fm: Session saved for $userName.');
    }
  }

  Future<String?> getSessionKey() async {
    final prefs = await _prefs;
    return prefs.getString(_sessionKeyPref);
  }

  Future<String?> getUserName() async {
    final prefs = await _prefs;
    return prefs.getString(_userNamePref);
  }

  Future<void> clearSessionDetails() async {
    final prefs = await _prefs;
    await prefs.remove(_sessionKeyPref);
    await prefs.remove(_userNamePref);
    if (kDebugMode) {
      print('Last.fm: Session cleared.');
    }
  }

  /// Clear all cached artist info
  Future<void> clearCache() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys();

    //remove all keys that start with the artist info cache prefix
    for (final key in keys) {
      if (key.startsWith(_artistInfoCachePrefix)) {
        await prefs.remove(key);
      }
    }

    if (kDebugMode) {
      print('Last.fm: Artist info cache cleared.');
    }
  }

  Future<bool> isLoggedIn() async {
    return await getSessionKey() != null;
  }

  Future<bool> validateSession() async {
    if (!await isLoggedIn()) {
      return false;
    }
    final username = await getUserName();
    if (username == null) {
      await clearSessionDetails();
      return false;
    }

    final params = {'method': 'user.getInfo', 'user': username};

    try {
      await _callApi(params);
      if (kDebugMode) print('Last.fm: Session is valid for $username.');
      return true;
    } catch (e) {
      if (e is Exception && e.toString().contains('(9)')) {
        if (kDebugMode) {
          print('Last.fm: Invalid session key detected. Clearing session.');
        }
        await clearSessionDetails();
      } else {
        if (kDebugMode) {
          print(
            'Last.fm: Session validation failed with an unexpected error: $e',
          );
        }
      }
      return false;
    }
  }

  String _generateApiSig(Map<String, String> params) {
    var sortedKeys = params.keys.toList()..sort();
    var sigString = StringBuffer();
    for (var key in sortedKeys) {
      sigString.write(key);
      sigString.write(params[key]);
    }
    sigString.write(_apiSecret);
    return md5.convert(utf8.encode(sigString.toString())).toString();
  }

  Future<Map<String, dynamic>> _callApi(
    Map<String, String> params, {
    bool isPost = false,
    bool requiresSk = true,
  }) async {
    if (requiresSk) {
      final sk = await getSessionKey();
      if (sk == null) {
        if (kDebugMode) {
          print(
            'Last.fm: SK required but not found for method ${params['method']}.',
          );
        }
        throw Exception('Last.fm: Not authenticated for this action.');
      }
      params['sk'] = sk;
    }
    params['api_key'] = _apiKey;

    var paramsForSig = Map<String, String>.from(params);
    params['api_sig'] = _generateApiSig(paramsForSig);

    params['format'] = 'json';

    final uri = Uri.parse(_apiUrl);
    http.Response response;

    try {
      if (isPost) {
        Map<String, String> postBody = Map.from(params);
        postBody.remove('format');
        final postUri = uri.replace(queryParameters: {'format': 'json'});
        response = await http
            .post(postUri, body: postBody)
            .timeout(const Duration(seconds: 20));
      } else {
        response = await http
            .get(uri.replace(queryParameters: params))
            .timeout(const Duration(seconds: 20));
      }

      final decoded = json.decode(response.body);

      if (response.statusCode == 200) {
        if (decoded is Map && decoded.containsKey('error')) {
          final errorCode = decoded['error'];
          final errorMessage = decoded['message'];
          if (kDebugMode) {
            print(
              'Last.fm API Error ($errorCode): $errorMessage (Method: ${params['method']})',
            );
          }
          throw Exception('Last.fm API Error ($errorCode): $errorMessage');
        }
        return decoded;
      } else {
        if (kDebugMode) {
          print(
            'Last.fm HTTP Error: ${response.statusCode}, Body: ${response.body} (Method: ${params['method']})',
          );
        }
        final errorDetail =
            (decoded is Map && decoded.containsKey('message'))
                ? decoded['message']
                : 'API request failed';
        throw Exception(
          'Last.fm HTTP Error (${response.statusCode}): $errorDetail',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Last.fm Request Exception: $e (Method: ${params['method']})');
      }
      rethrow;
    }
  }

  Future<bool> authenticateDirect(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      throw Exception("Username and password cannot be empty.");
    }
    try {
      Map<String, String> bodyParams = {
        'method': 'auth.getMobileSession',
        'username': username,
        'password': password,
        'api_key': _apiKey,
      };
      bodyParams['api_sig'] = _generateApiSig(bodyParams);

      final uri = Uri.parse(
        _apiUrl,
      ).replace(queryParameters: {'format': 'json'});
      final response = await http
          .post(uri, body: bodyParams)
          .timeout(const Duration(seconds: 25));

      final decoded = json.decode(response.body);

      if (response.statusCode == 200) {
        if (decoded.containsKey('session')) {
          final session = decoded['session'];
          await _saveSessionDetails(session['key'], session['name']);
          return true;
        } else if (decoded.containsKey('error')) {
          if (kDebugMode) {
            print(
              'Last.fm Auth Error ${decoded['error']}: ${decoded['message']}',
            );
          }
          throw Exception(
            'Last.fm Auth Error (${decoded['error']}): ${decoded['message']}',
          );
        }
      } else {
        if (kDebugMode) {
          print(
            'Last.fm Auth HTTP Error: ${response.statusCode}, Body: ${response.body}',
          );
        }
        final errorDetail =
            (decoded is Map && decoded.containsKey('message'))
                ? decoded['message']
                : 'Authentication failed due to server error';
        throw Exception(
          'Last.fm Auth HTTP Error (${response.statusCode}): $errorDetail',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Last.fm: Error during direct authentication: $e");
      }
      rethrow;
    }
  }

  Future<bool> scrobbleTrack({
    required String artist,
    required String track,
    required int timestamp,
    String? album,
    String? albumArtist,
    int? duration,
  }) async {
    if (!await _prefsService.isLastfmScrobblingEnabled()) return false;

    final scrobbleData = {
      'artist': artist,
      'track': track,
      'timestamp': timestamp.toString(),
      if (album != null) 'album': album,
      if (albumArtist != null) 'albumArtist': albumArtist,
      if (duration != null) 'duration': duration.toString(),
    };

    //save locally first before attempting a network request
    await _queueScrobble(scrobbleData);
    //attempt to flush entire queue to api
    await _flushScrobbleQueue();
    return true;
  }

  /// Safely writes scrobble to local storage
  Future<void> _queueScrobble(Map<String, String> scrobble) async {
    final prefs = await _prefs;
    final queueString = prefs.getString(_pendingScrobblesKey) ?? '[]';

    try {
      final List<dynamic> queue = json.decode(queueString);
      queue.add(scrobble);
      await prefs.setString(_pendingScrobblesKey, json.encode(queue));
    } catch (e) {
      //if JSON gets corrupted > overwrite it instead of crashing app permanently
      await prefs.setString(_pendingScrobblesKey, json.encode([scrobble]));
    }
  }

  /// Handles batching and retrying failed requests
  Future<void> _flushScrobbleQueue() async {
    final prefs = await _prefs;
    final queueString = prefs.getString(_pendingScrobblesKey);
    if (queueString == null) return;

    List<dynamic> queue;
    try {
      queue = json.decode(queueString);
    } catch (_) {
      await prefs.remove(_pendingScrobblesKey);
      return;
    }

    if (queue.isEmpty) return;

    // Last.fms API strictly takes a maximum of 50 scrobbles per batch
    // This splits the queue into valid chunks
    final batches = <List<dynamic>>[];
    for (var i = 0; i < queue.length; i += 50) {
      batches.add(
        queue.sublist(i, i + 50 > queue.length ? queue.length : i + 50),
      );
    }

    bool hasNetworkError = false;
    List<dynamic> remainingQueue = [];

    for (var batch in batches) {
      if (hasNetworkError) {
        //if one batch fails > skip rest and keep them in queue
        remainingQueue.addAll(batch);
        continue;
      }

      final params = <String, String>{'method': 'track.scrobble'};
      for (var i = 0; i < batch.length; i++) {
        final trackData = batch[i] as Map<String, dynamic>;
        params['artist[$i]'] = trackData['artist'] as String;
        params['track[$i]'] = trackData['track'] as String;
        params['timestamp[$i]'] = trackData['timestamp'] as String;
        if (trackData.containsKey('album')) {
          params['album[$i]'] = trackData['album'] as String;
        }
        if (trackData.containsKey('albumArtist')) {
          params['albumArtist[$i]'] = trackData['albumArtist'] as String;
        }
        if (trackData.containsKey('duration')) {
          params['duration[$i]'] = trackData['duration'] as String;
        }
      }

      try {
        await _callApi(params, isPost: true, requiresSk: true);
        //success: batch is not added to remainingQueue > effectively deleting it
      } catch (e) {
        if (kDebugMode) {
          print('Last.fm: Batch failed. Keeping in queue. Error: $e');
        }
        hasNetworkError = true;
        remainingQueue.addAll(batch);
      }
    }

    //save whatever is left back to disk
    if (remainingQueue.isEmpty) {
      await prefs.remove(_pendingScrobblesKey);
    } else {
      await prefs.setString(_pendingScrobblesKey, json.encode(remainingQueue));
    }
  }

  /// updateNowPlaying does NOT need a queue since it represents current real-time state,
  /// but it DOES need to stop swallowing errors and return its status (yes I had to remind how trash this was)
  Future<bool> updateNowPlaying({
    required String artist,
    required String track,
    String? album,
    String? albumArtist,
    int? duration,
  }) async {
    if (!await _prefsService.isLastfmScrobblingEnabled()) return false;

    final params = {
      'method': 'track.updateNowPlaying',
      'artist': artist,
      'track': track,
    };
    if (album != null) params['album'] = album;
    if (albumArtist != null) params['albumArtist'] = albumArtist;
    if (duration != null) params['duration'] = duration.toString();

    try {
      await _callApi(params, isPost: true, requiresSk: true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Last.fm: Now playing failed. Network issue? Error: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getArtistInfo(String artist) async {
    if (artist.isEmpty) return null;

    final prefs = await _prefs;
    final cacheKey = '$_artistInfoCachePrefix${artist.toLowerCase()}';

    final String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      if (kDebugMode) {
        print('Last.fm: Loading artist info for "$artist" from cache.');
      }
      try {
        return json.decode(cachedData) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) {
          print(
            'Last.fm: Failed to decode cached artist info. Refetching. Error: $e',
          );
        }
      }
    }

    if (kDebugMode) {
      print('Last.fm: Fetching info for artist: $artist from API.');
    }
    final params = {
      'method': 'artist.getInfo',
      'artist': artist,
      'autocorrect': '0',
    };

    try {
      final response = await _callApi(params, isPost: false, requiresSk: false);
      if (response.containsKey('artist')) {
        final artistData = response['artist'] as Map<String, dynamic>;

        try {
          final String jsonString = json.encode(artistData);
          await prefs.setString(cacheKey, jsonString);
          if (kDebugMode) {
            print('Last.fm: Saved artist info for "$artist" to cache.');
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              'Last.fm: Failed to encode or save artist info to cache. Error: $e',
            );
          }
        }

        return artistData;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Last.fm: Could not fetch artist info for "$artist". Error: $e');
      }
      return null;
    }
  }
}
