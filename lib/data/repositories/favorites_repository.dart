import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/data/database/tables/favorites_table.dart';

///repository for managing favorites data
class FavoritesRepository {
  final SonoDatabaseHelper _dbHelper = SonoDatabaseHelper.instance;

  //=== Song Favorites ===

  Future<void> addFavoriteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.insert(FavoritesTable.tableName, {
      'song_id': songId,
      'added_at': DateTime.now().millisecondsSinceEpoch,
      'type': 'song',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavoriteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.delete(
      FavoritesTable.tableName,
      where: 'song_id = ?',
      whereArgs: [songId],
    );
  }

  Future<bool> isSongFavorite(int songId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      FavoritesTable.tableName,
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<int>> getFavoriteSongIds() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      FavoritesTable.tableName,
      columns: ['song_id'],
      orderBy: 'added_at DESC',
    );
    return result.map((row) => row['song_id'] as int).toList();
  }

  Future<void> clearAllFavorites() async {
    final db = await _dbHelper.database;
    await db.delete(FavoritesTable.tableName);
  }

  //=== Artist Favorites ===

  Future<void> addFavoriteArtist(int artistId, String artistName) async {
    final db = await _dbHelper.database;
    await db.insert(FavoriteArtistsTable.tableName, {
      'artist_id': artistId,
      'artist_name': artistName,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavoriteArtist(int artistId) async {
    final db = await _dbHelper.database;
    await db.delete(
      FavoriteArtistsTable.tableName,
      where: 'artist_id = ?',
      whereArgs: [artistId],
    );
  }

  Future<bool> isArtistFavorite(int artistId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      FavoriteArtistsTable.tableName,
      where: 'artist_id = ?',
      whereArgs: [artistId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavoriteArtists() async {
    final db = await _dbHelper.database;
    return await db.query(
      FavoriteArtistsTable.tableName,
      orderBy: 'added_at DESC',
    );
  }

  //=== Album Favorites ===

  Future<void> addFavoriteAlbum(int albumId, String albumName) async {
    final db = await _dbHelper.database;
    await db.insert(FavoriteAlbumsTable.tableName, {
      'album_id': albumId,
      'album_name': albumName,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavoriteAlbum(int albumId) async {
    final db = await _dbHelper.database;
    await db.delete(
      FavoriteAlbumsTable.tableName,
      where: 'album_id = ?',
      whereArgs: [albumId],
    );
  }

  Future<bool> isAlbumFavorite(int albumId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      FavoriteAlbumsTable.tableName,
      where: 'album_id = ?',
      whereArgs: [albumId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavoriteAlbums() async {
    final db = await _dbHelper.database;
    return await db.query(
      FavoriteAlbumsTable.tableName,
      orderBy: 'added_at DESC',
    );
  }
}