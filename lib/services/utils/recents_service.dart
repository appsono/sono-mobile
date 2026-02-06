import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/data/repositories/recents_repository.dart';
import 'package:sono/data/models/recent_play_model.dart';
import 'dart:convert';

class RecentsService {
  RecentsService._privateConstructor();
  static final RecentsService instance = RecentsService._privateConstructor();

  final RecentsRepository _repository = RecentsRepository();

  static const String _legacyRecentsKeyV1 = 'recently_played_songs_v1';
  static const String _legacyRecentsKeyV2 = 'recently_played_songs_v2';
  bool _hasMigrated = false;

  ///migrates legacy SharedPreferences data to database
  Future<void> _migrateLegacyData() async {
    if (_hasMigrated) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      //check for v2 format (with timestamps)
      if (prefs.containsKey(_legacyRecentsKeyV2)) {
        final List<String> recentsJson =
            prefs.getStringList(_legacyRecentsKeyV2) ?? [];

        for (final jsonStr in recentsJson.reversed) {
          try {
            final data = json.decode(jsonStr);
            final songId = data['songId'] as int;
            await _repository.addRecentPlay(songId);
          } catch (e) {
            debugPrint('RecentsService: Error migrating recent item: $e');
          }
        }

        await prefs.remove(_legacyRecentsKeyV2);
        debugPrint(
          'RecentsService: Migrated ${recentsJson.length} recent plays from v2',
        );
      }
      //check for v1 format (just IDs)
      else if (prefs.containsKey(_legacyRecentsKeyV1)) {
        final List<String> legacyRecentsStr =
            prefs.getStringList(_legacyRecentsKeyV1) ?? [];
        final List<int> legacyRecents =
            legacyRecentsStr
                .map((id) => int.tryParse(id))
                .whereType<int>()
                .toList();

        if (legacyRecents.isNotEmpty) {
          for (final songId in legacyRecents) {
            await _repository.addRecentPlay(songId);
          }

          await prefs.remove(_legacyRecentsKeyV1);
          debugPrint(
            'RecentsService: Migrated ${legacyRecents.length} recent plays from v1',
          );
        }
      }

      _hasMigrated = true;
    } catch (e) {
      debugPrint('RecentsService: Error during migration: $e');
    }
  }

  ///adds a song to recent plays with optional context
  Future<void> addRecentPlay(int songId, {String? context}) async {
    if (songId <= 0) return;

    await _migrateLegacyData();

    try {
      await _repository.addRecentPlay(songId, context: context);
      debugPrint('RecentsService: Added song $songId to recent plays with context: $context');
    } catch (e) {
      debugPrint('RecentsService: Error adding recent play: $e');
    }
  }

  ///gets recent plays
  ///with optional limit
  Future<List<RecentPlayModel>> getRecentPlays({int limit = 50}) async {
    await _migrateLegacyData();

    try {
      return await _repository.getRecentPlaysModels(limit: limit);
    } catch (e) {
      debugPrint('RecentsService: Error getting recent plays: $e');
      return [];
    }
  }

  ///gets unique recent song IDs (no duplicates)
  Future<List<int>> getRecentSongIds({int limit = 50}) async {
    await _migrateLegacyData();

    try {
      final results = await _repository.getRecentPlays(limit: limit * 2);
      final seen = <int>{};
      final uniqueIds = <int>[];

      for (final row in results) {
        final songId = row['song_id'] as int;
        if (!seen.contains(songId)) {
          seen.add(songId);
          uniqueIds.add(songId);
          if (uniqueIds.length >= limit) break;
        }
      }

      return uniqueIds;
    } catch (e) {
      debugPrint('RecentsService: Error getting recent song IDs: $e');
      return [];
    }
  }

  ///clears all recent plays
  Future<void> clearAllHistory() async {
    try {
      await _repository.clearRecentPlays();
      debugPrint('RecentsService: Cleared all recent plays');
    } catch (e) {
      debugPrint('RecentsService: Error clearing history: $e');
      rethrow;
    }
  }

  ///gets recent plays count
  Future<int> getRecentPlaysCount() async {
    await _migrateLegacyData();

    try {
      return await _repository.getRecentPlaysCount();
    } catch (e) {
      debugPrint('RecentsService: Error getting recent plays count: $e');
      return 0;
    }
  }
}