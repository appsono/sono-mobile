import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/data/database/tables/favorites_table.dart';
import 'package:sono/data/database/tables/recents_table.dart';
import 'package:sono/data/database/tables/playlists_table.dart';
import 'package:sono/data/database/tables/stats_table.dart';

class MigrationV1 {
  static const int version = 1;

  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v1...');

    //create all tables
    await FavoritesTable.createTable(db);
    await FavoriteArtistsTable.createTable(db);
    await FavoriteAlbumsTable.createTable(db);
    await RecentsTable.createTable(db);
    await PlaylistsTable.createTable(db);
    await PlaylistSongsTable.createTable(db);
    await ListeningStatsTable.createTable(db);
    await SongMetadataTable.createTable(db);

    debugPrint('SonoDatabase: Migration v1 completed successfully');
  }
}
