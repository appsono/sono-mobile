import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/data/migrations/migration_manager.dart';

///central database helper
///handles database initialization and provides access to database instance
class SonoDatabaseHelper {
  static final SonoDatabaseHelper instance = SonoDatabaseHelper._internal();
  static Database? _database;

  SonoDatabaseHelper._internal();

  ///gets the database instance => initializing if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  ///initializes the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sono_app.db');

    return await openDatabase(
      path,
      version: MigrationManager.currentVersion,
      onCreate: MigrationManager.onCreate,
      onUpgrade: MigrationManager.migrate,
      onConfigure: _onConfigure,
    );
  }

  ///configures database settings
  Future<void> _onConfigure(Database db) async {
    //enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  ///closes the database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('SonoDatabase: Database closed');
    }
  }

  ///clears all data from all tables
  Future<void> clearAllData() async {
    final db = await database;

    await db.delete('favorites');
    await db.delete('favorite_artists');
    await db.delete('favorite_albums');
    await db.delete('recent_plays');
    await db.delete('listening_stats');
    await db.delete('playlist_songs');
    await db.delete('app_playlists');
    await db.delete('song_metadata');
    await db.delete('artist_metadata');

    debugPrint('SonoDatabase: All data cleared');
  }

  ///gets database statistics for debugging
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final tables = [
      'favorites',
      'favorite_artists',
      'favorite_albums',
      'recent_plays',
      'listening_stats',
      'app_playlists',
      'playlist_songs',
      'song_metadata',
      'artist_metadata',
    ];

    final stats = <String, int>{};

    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      stats[table] = result.first['count'] as int? ?? 0;
    }

    return stats;
  }
}
