import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

///migration v9: artists table for caching kworb/lastfm data
class MigrationV9 {
  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v9...');

    await _createArtistsTable(db);

    debugPrint('SonoDatabase: Migration v9 completed');
  }

  ///creates the artists table for caching API data
  static Future<void> _createArtistsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS artists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        artist_name TEXT NOT NULL UNIQUE,
        artist_name_lower TEXT NOT NULL,
        api_response TEXT,
        top_songs TEXT,
        monthly_listeners INTEGER,
        bio TEXT,
        bio_url TEXT,
        last_fetched_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    //create indexes for faster queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_artists_name ON artists(artist_name_lower)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_artists_last_fetched ON artists(last_fetched_at)',
    );

    debugPrint('SonoDatabase: artists table created');
  }
}
