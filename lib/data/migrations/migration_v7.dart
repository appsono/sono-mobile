import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../database/tables/artists_table.dart';

///migration v7: Add artist image fetching support
class MigrationV7 {
  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v7...',);

    final tableInfo = await db.rawQuery('PRAGMA table_info(${ArtistMetadataTable.tableName})');
    final columnNames = tableInfo.map((col) => col['name'] as String).toSet();

    //add fetched_image_url column for storing Last.fm image URLs
    if (!columnNames.contains('fetched_image_url')) {
      await db.execute('ALTER TABLE ${ArtistMetadataTable.tableName} ADD COLUMN fetched_image_url TEXT');
    }

    //add fetch_attempted_at column to track when we last tried to fetch
    if (!columnNames.contains('fetch_attempted_at')) {
      await db.execute('ALTER TABLE ${ArtistMetadataTable.tableName} ADD COLUMN fetch_attempted_at INTEGER');
    }

    debugPrint('SonoDatabase: Migration v7 complete');
  }
}