import 'package:sqflite/sqflite.dart';

class RecentsTable {
  static const String tableName = 'recent_plays';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        played_at INTEGER NOT NULL,
        context TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recent_plays_played_at ON $tableName(played_at DESC)',
    );
  }
}