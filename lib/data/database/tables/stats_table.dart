import 'package:sqflite/sqflite.dart';

class ListeningStatsTable {
  static const String tableName = 'listening_stats';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        song_id INTEGER PRIMARY KEY,
        play_count INTEGER NOT NULL DEFAULT 0,
        skip_count INTEGER NOT NULL DEFAULT 0,
        total_listen_time INTEGER NOT NULL DEFAULT 0,
        last_played INTEGER,
        first_played INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_listening_stats_play_count ON $tableName(play_count DESC)',
    );
  }
}

class SongMetadataTable {
  static const String tableName = 'song_metadata';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        song_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT,
        album TEXT,
        duration INTEGER,
        file_path TEXT,
        is_remote INTEGER NOT NULL DEFAULT 0,
        remote_url TEXT,
        artwork_cached INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_metadata_is_remote ON $tableName(is_remote)',
    );
  }
}
