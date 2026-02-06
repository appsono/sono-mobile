import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/tables/artists_table.dart';

///migration v6: Add artist metadata table for custom profile pictures
class MigrationV6 {
  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v6...');

    await ArtistMetadataTable.createTable(db);

    debugPrint('SonoDatabase: Migration v6 complete');
  }
}