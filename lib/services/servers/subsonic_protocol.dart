import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/data/models/remote_models.dart';
import 'package:sono/services/api/http_client.dart';
import 'package:sono/services/servers/server_protocol.dart';

/// Subsonic/OpenSubsonic protocol implementation
/// Compatible with Navidrome, Airsonic, Gonic, Funkwhale, LMS, etc
class SubsonicProtocol extends MusicServerProtocol {
  static const String _apiVersion = '1.16.1';
  static const String _clientId = 'sono';

  /// Fixed salt used for cover art URLs so they can be cached
  static const String _coverArtSalt = 'sonocover';

  SubsonicProtocol(super.server);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('SubsonicProtocol: $message');
    }
  }

  /// Generate a random salt for auth tokens
  String _generateSalt([int length = 16]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Compute MD5 auth token: md5(password + salt)
  String _computeToken(String salt) {
    final bytes = utf8.encode('${server.password}$salt');
    return md5.convert(bytes).toString();
  }

  /// Build a Subsonic REST API URI with auth params
  Uri _buildUri(String method, [Map<String, String>? extraParams]) {
    final salt = _generateSalt();
    final token = _computeToken(salt);
    final baseUrl = server.url.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$baseUrl/rest/$method').replace(
      queryParameters: {
        'u': server.username,
        't': token,
        's': salt,
        'v': _apiVersion,
        'c': _clientId,
        'f': 'json',
        ...?extraParams,
      },
    );
  }

  /// Build a URI with the fixed cover art salt (for HTTP cache stability)
  Uri _buildCoverArtUri(String method, Map<String, String> params) {
    final token = _computeToken(_coverArtSalt);
    final baseUrl = server.url.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$baseUrl/rest/$method').replace(
      queryParameters: {
        'u': server.username,
        't': token,
        's': _coverArtSalt,
        'v': _apiVersion,
        'c': _clientId,
        'f': 'json',
        ...params,
      },
    );
  }

  /// Execute a Subsonic API call and return the parsed response body
  /// Throws on network errors or Subsonic error responses
  Future<Map<String, dynamic>> _request(
    String method, [
    Map<String, String>? params,
    RetryConfig? retryConfig,
    Duration? timeout,
  ]) async {
    final uri = _buildUri(method, params);
    _log('GET $method');

    final result = await SonoHttpClient.instance.get(
      uri,
      retryConfig: retryConfig,
      timeout: timeout,
    );
    final response = result.response;

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} from $method');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final subsonicResponse =
        json['subsonic-response'] as Map<String, dynamic>?;

    if (subsonicResponse == null) {
      throw Exception('Invalid Subsonic response from $method');
    }

    final status = subsonicResponse['status'] as String?;
    if (status != 'ok') {
      final error = subsonicResponse['error'] as Map<String, dynamic>?;
      final errorMessage = error?['message'] ?? 'Unknown error';
      final errorCode = error?['code'] ?? 0;
      throw Exception('Subsonic error $errorCode: $errorMessage');
    }

    return subsonicResponse;
  }

  @override
  Future<String?> ping() async {
    try {
      await _request(
        'ping',
        null,
        RetryConfig.nonIdempotent, // no retries for connectivity checks
        const Duration(seconds: 5),
      );
      return null;
    } catch (e) {
      _log('Ping failed: $e');
      return e.toString();
    }
  }

  @override
  Future<List<RemoteArtist>> getArtists() async {
    final response = await _request('getArtists');
    final artists = <RemoteArtist>[];

    final artistsData = response['artists'] as Map<String, dynamic>?;
    if (artistsData == null) return artists;

    //subsonic returns artists grouped by index letter
    final indexList = artistsData['index'] as List<dynamic>? ?? [];
    for (final index in indexList) {
      final artistList =
          (index as Map<String, dynamic>)['artist'] as List<dynamic>? ?? [];
      for (final a in artistList) {
        final artist = a as Map<String, dynamic>;
        artists.add(RemoteArtist(
          id: artist['id'].toString(),
          name: artist['name'] as String? ?? 'Unknown',
          albumCount: (artist['albumCount'] as int?) ?? 0,
          coverArtId: artist['coverArt']?.toString(),
          serverId: server.id!,
          starred: artist['starred'] != null,
        ));
      }
    }

    return artists;
  }

  @override
  Future<List<RemoteAlbum>> getArtistAlbums(String artistId) async {
    final response = await _request('getArtist', {'id': artistId});
    final albums = <RemoteAlbum>[];

    final artistData = response['artist'] as Map<String, dynamic>?;
    if (artistData == null) return albums;

    final albumList = artistData['album'] as List<dynamic>? ?? [];
    for (final a in albumList) {
      albums.add(_parseAlbum(a as Map<String, dynamic>));
    }

    return albums;
  }

  @override
  Future<List<RemoteSong>> getAlbumSongs(String albumId) async {
    final response = await _request('getAlbum', {'id': albumId});
    final songs = <RemoteSong>[];

    final albumData = response['album'] as Map<String, dynamic>?;
    if (albumData == null) return songs;

    final songList = albumData['song'] as List<dynamic>? ?? [];
    for (final s in songList) {
      songs.add(_parseSong(s as Map<String, dynamic>));
    }

    return songs;
  }

  @override
  Future<List<RemoteAlbum>> getAlbumList({
    String type = 'newest',
    int count = 50,
    int offset = 0,
  }) async {
    final response = await _request('getAlbumList2', {
      'type': type,
      'size': count.toString(),
      'offset': offset.toString(),
    });

    final albums = <RemoteAlbum>[];
    final albumList2 = response['albumList2'] as Map<String, dynamic>?;
    if (albumList2 == null) return albums;

    final albumList = albumList2['album'] as List<dynamic>? ?? [];
    for (final a in albumList) {
      albums.add(_parseAlbum(a as Map<String, dynamic>));
    }

    return albums;
  }

  @override
  Future<RemoteSearchResult> search(String query, {int limit = 20}) async {
    final response = await _request('search3', {
      'query': query,
      'artistCount': limit.toString(),
      'albumCount': limit.toString(),
      'songCount': limit.toString(),
    });

    final searchResult = response['searchResult3'] as Map<String, dynamic>?;
    if (searchResult == null) return RemoteSearchResult();

    final artists = (searchResult['artist'] as List<dynamic>? ?? [])
        .map((a) => RemoteArtist(
              id: (a as Map<String, dynamic>)['id'].toString(),
              name: a['name'] as String? ?? 'Unknown',
              albumCount: (a['albumCount'] as int?) ?? 0,
              coverArtId: a['coverArt']?.toString(),
              serverId: server.id!,
              starred: a['starred'] != null,
            ))
        .toList();

    final albums = (searchResult['album'] as List<dynamic>? ?? [])
        .map((a) => _parseAlbum(a as Map<String, dynamic>))
        .toList();

    final songs = (searchResult['song'] as List<dynamic>? ?? [])
        .map((s) => _parseSong(s as Map<String, dynamic>))
        .toList();

    return RemoteSearchResult(
      artists: artists,
      albums: albums,
      songs: songs,
    );
  }

  @override
  String getStreamUrl(String songId) {
    final uri = _buildUri('stream', {'id': songId});
    return uri.toString();
  }

  @override
  String getCoverArtUrl(String coverArtId, {int size = 300}) {
    final uri = _buildCoverArtUri('getCoverArt', {
      'id': coverArtId,
      'size': size.toString(),
    });
    return uri.toString();
  }

  RemoteAlbum _parseAlbum(Map<String, dynamic> data) {
    return RemoteAlbum(
      id: data['id'].toString(),
      name: data['name'] as String? ?? data['title'] as String? ?? 'Unknown',
      artistName: data['artist'] as String?,
      artistId: data['artistId']?.toString(),
      year: data['year'] as int?,
      songCount: (data['songCount'] as int?) ?? 0,
      duration: data['duration'] as int?,
      coverArtId: data['coverArt']?.toString(),
      serverId: server.id!,
      starred: data['starred'] != null,
    );
  }

  @override
  Future<List<RemoteSong>> getTopSongs(
    String artistName, {
    int count = 20,
  }) async {
    final response = await _request('getTopSongs', {
      'artist': artistName,
      'count': count.toString(),
    });

    final topSongs = response['topSongs'] as Map<String, dynamic>?;
    if (topSongs == null) return [];

    final songList = topSongs['song'] as List<dynamic>? ?? [];
    return songList
        .map((s) => _parseSong(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getArtistInfo(String artistId) async {
    final response = await _request('getArtistInfo2', {'id': artistId});
    return response['artistInfo2'] as Map<String, dynamic>? ?? {};
  }

  @override
  Future<RemoteSong?> getSong(String songId) async {
    try {
      final response = await _request('getSong', {'id': songId});
      final songData = response['song'] as Map<String, dynamic>?;
      if (songData == null) return null;
      return _parseSong(songData);
    } catch (e) {
      _log('getSong failed: $e');
      return null;
    }
  }

  @override
  Future<RemoteAlbum?> getAlbum(String albumId) async {
    try {
      final response = await _request('getAlbum', {'id': albumId});
      final albumData = response['album'] as Map<String, dynamic>?;
      if (albumData == null) return null;
      return _parseAlbum(albumData);
    } catch (e) {
      _log('getAlbum failed: $e');
      return null;
    }
  }

  @override
  Future<RemoteArtist?> getArtist(String artistId) async {
    try {
      final response = await _request('getArtist', {'id': artistId});
      final artistData = response['artist'] as Map<String, dynamic>?;
      if (artistData == null) return null;
      return RemoteArtist(
        id: artistData['id'].toString(),
        name: artistData['name'] as String? ?? 'Unknown',
        albumCount: (artistData['albumCount'] as int?) ?? 0,
        coverArtId: artistData['coverArt']?.toString(),
        serverId: server.id!,
        starred: artistData['starred'] != null,
      );
    } catch (e) {
      _log('getArtist failed: $e');
      return null;
    }
  }

  @override
  Future<void> star({String? id, String? albumId, String? artistId}) async {
    final params = <String, String>{};
    if (id != null) params['id'] = id;
    if (albumId != null) params['albumId'] = albumId;
    if (artistId != null) params['artistId'] = artistId;
    await _request('star', params);
  }

  @override
  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    final params = <String, String>{};
    if (id != null) params['id'] = id;
    if (albumId != null) params['albumId'] = albumId;
    if (artistId != null) params['artistId'] = artistId;
    await _request('unstar', params);
  }

  RemoteSong _parseSong(Map<String, dynamic> data) {
    return RemoteSong(
      id: data['id'].toString(),
      title: data['title'] as String? ?? 'Unknown',
      artist: data['artist'] as String?,
      album: data['album'] as String?,
      albumId: data['albumId']?.toString(),
      trackNumber: data['track'] as int?,
      duration: data['duration'] as int?,
      coverArtId: data['coverArt']?.toString(),
      bitRate: data['bitRate'] as int?,
      suffix: data['suffix'] as String?,
      serverId: server.id!,
      starred: data['starred'] != null,
    );
  }
}
