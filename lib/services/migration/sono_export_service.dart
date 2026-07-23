import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/utils/audio_filter_utils.dart';

/// Exports this install into new Sono's backup format
///
/// MediaStore ids only mean something on this device, so they are resolved
/// to file paths here rather than by the new app
class SonoExportService {
  SonoExportService(this._db);

  final SonoDatabaseHelper _db;
  final _audioQuery = OnAudioQuery();

  //matches BackupExportService in sono-new
  static const formatVersion = 2;

  Future<String> exportToJson() async {
    final map = await exportToMap();
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<Map<String, dynamic>> exportToMap() async {
    final info = await PackageInfo.fromPlatform();
    final index = await _buildIndex();

    return {
      'formatVersion': formatVersion,
      'app': 'wtf.sono',
      'sourceApp': 'wtf.sono.app',
      'appVersion': '${info.version}+${info.buildNumber}',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': const <String, String>{},
      'profile': null,
      'likedSongs': await _likedSongs(index),
      'favoriteAlbums': await _favoriteAlbums(index),
      'favoriteArtists': await _favoriteArtists(),
      'playlists': await _playlists(index),
      'legacySettings': await _legacySettings(),
    };
  }

  /// One pass, since every lookup below needs the same table
  Future<_Index> _buildIndex() async {
    final songs = await AudioFilterUtils.querySongsSafely(
      _audioQuery,
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    final byId = <int, String>{};
    final albumTrack = <int, String>{};
    for (final s in songs) {
      final path = s.data;
      if (path.isEmpty) continue;
      byId[s.id] = path;
      //first track wins, matches the new app picking one member per album
      final album = s.albumId;
      if (album != null) albumTrack.putIfAbsent(album, () => path);
    }
    debugPrint('SonoExport: indexed ${byId.length} songs');
    return (byId: byId, albumTrack: albumTrack);
  }

  // ==== sections ====

  Future<List<Map<String, dynamic>>> _likedSongs(_Index index) async {
    final rows = await _query(
      "SELECT song_id, added_at FROM favorites WHERE type = 'song'",
    );
    return [
      for (final r in rows)
        if (index.byId[_int(r['song_id'])] case final path?)
          {'path': path, 'likedAt': _iso(r['added_at'])},
    ];
  }

  /// New schema keys albums by a member song path
  Future<List<Map<String, dynamic>>> _favoriteAlbums(_Index index) async {
    final rows = await _query('SELECT album_id, added_at FROM favorite_albums');
    return [
      for (final r in rows)
        if (index.albumTrack[_int(r['album_id'])] case final path?)
          {'songPath': path, 'favoritedAt': _iso(r['added_at'])},
    ];
  }

  /// Names carry over as is
  Future<List<Map<String, dynamic>>> _favoriteArtists() async {
    final rows = await _query(
      'SELECT artist_name, added_at FROM favorite_artists',
    );
    return [
      for (final r in rows)
        if (r['artist_name'] case final String name when name.isNotEmpty)
          {'name': name, 'favoritedAt': _iso(r['added_at'])},
    ];
  }

  Future<List<Map<String, dynamic>>> _playlists(_Index index) async {
    final cols = await _columns('app_playlists');
    final hasCover = cols.contains('custom_cover_path');

    final select = [
      'id',
      'name',
      'description',
      if (hasCover) 'custom_cover_path',
      'created_at',
    ].join(', ');

    final rows = await _query('SELECT $select FROM app_playlists ORDER BY id');
    final out = <Map<String, dynamic>>[];

    for (final r in rows) {
      final id = _int(r['id']);
      if (id == null) continue;

      final members = await _query(
        'SELECT song_id, position, added_at FROM playlist_songs '
        'WHERE playlist_id = ? ORDER BY position',
        [id],
      );

      out.add({
        'name': r['name'] ?? 'Playlist $id',
        'description': r['description'],
        'createdAt': _iso(r['created_at']),
        'coverB64':
            hasCover ? await _base64(r['custom_cover_path'] as String?) : null,
        'songs': [
          for (final m in members)
            if (index.byId[_int(m['song_id'])] case final path?)
              {
                'path': path,
                'position': _int(m['position']) ?? 0,
                'addedAt': _iso(m['added_at']),
              },
        ],
      });
    }
    return out;
  }

  /// Everything from app_settings, new app decides what to keep
  Future<List<Map<String, dynamic>>> _legacySettings() async {
    if (!await _hasTable('app_settings')) return const [];
    final rows = await _query('SELECT category, key, value FROM app_settings');
    return [
      for (final r in rows)
        {'category': r['category'], 'key': r['key'], 'value': r['value']},
    ];
  }

  // ==== helpers ====

  /// Missing tables are normal on old installs, never fatal
  Future<List<Map<String, Object?>>> _query(
    String sql, [
    List<Object?>? args,
  ]) async {
    try {
      final db = await _db.database;
      return await db.rawQuery(sql, args);
    } catch (e) {
      debugPrint('SonoExport: query failed: $e');
      return const [];
    }
  }

  Future<bool> _hasTable(String name) async {
    final rows = await _query(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [name],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columns(String table) async {
    final rows = await _query('PRAGMA table_info($table)');
    return {
      for (final r in rows)
        if (r['name'] case final String name) name,
    };
  }

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  /// New app parses iso strings, old app stored epoch millis
  static String _iso(Object? v) {
    final ms = _int(v);
    final at =
        ms == null || ms <= 0
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(ms);
    return at.toUtc().toIso8601String();
  }

  /// Never fail an export over a cover
  static Future<String?> _base64(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }
}

typedef _Index = ({Map<int, String> byId, Map<int, String> albumTrack});
