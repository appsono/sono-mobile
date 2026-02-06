import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/data/database/tables/recents_table.dart';
import 'package:sono/data/models/recent_play_model.dart';

///repository for managing recent plays data
class RecentsRepository {
  final SonoDatabaseHelper _dbHelper = SonoDatabaseHelper.instance;
  static const int maxRecents = 100;

  Future<void> addRecentPlay(int songId, {String? context}) async {
    final db = await _dbHelper.database;

    await db.insert(RecentsTable.tableName, {
      'song_id': songId,
      'played_at': DateTime.now().millisecondsSinceEpoch,
      'context': context,
    });

    //trim to keep only last 100 plays
    await _trimRecentPlays(db);
  }

  Future<void> _trimRecentPlays(Database db) async {
    await db.delete(
      RecentsTable.tableName,
      where:
          'id NOT IN (SELECT id FROM ${RecentsTable.tableName} ORDER BY played_at DESC LIMIT $maxRecents)',
    );
  }

  Future<List<Map<String, dynamic>>> getRecentPlays({int limit = 50}) async {
    final db = await _dbHelper.database;
    return await db.query(
      RecentsTable.tableName,
      orderBy: 'played_at DESC',
      limit: limit,
    );
  }

  Future<List<RecentPlayModel>> getRecentPlaysModels({int limit = 50}) async {
    final results = await getRecentPlays(limit: limit);
    return results.map((row) => RecentPlayModel.fromMap(row)).toList();
  }

  Future<void> clearRecentPlays() async {
    final db = await _dbHelper.database;
    await db.delete(RecentsTable.tableName);
  }

  Future<int> getRecentPlaysCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${RecentsTable.tableName}',
    );
    return result.first['count'] as int? ?? 0;
  }
}
