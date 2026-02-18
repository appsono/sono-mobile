import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

///migration v10: music_servers table for custom server support
class MigrationV10 {
  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v10...');

    await _createMusicServersTable(db);

    debugPrint('SonoDatabase: Migration v10 completed');
  }

  static Future<void> _createMusicServersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS music_servers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'subsonic',
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    debugPrint('SonoDatabase: music_servers table created');
  }
}
