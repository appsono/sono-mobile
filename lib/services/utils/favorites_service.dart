import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/data/repositories/favorites_repository.dart';
import 'package:sono/services/playlist/playlist_service.dart';

/// Service for managing user favorites (songs, albums, artists)
/// Provides caching and notifies listeners when favorites change
class FavoritesService extends ChangeNotifier {
  final FavoritesRepository _repository = FavoritesRepository();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final PlaylistService _playlistService = PlaylistService();

  Set<int>? _favoriteSongsCache;
  Set<int>? _favoriteArtistsCache;
  Set<int>? _favoriteAlbumsCache;

  int? _likedPlaylistId;
  bool _isCreatingPlaylist = false;
  bool _hasMigrated = false;
  int? _likedDbPlaylistId;

  static const String likedPlaylistName = 'Liked Songs';

  /// Migration from SharedPreferences to Database
  Future<void> _migrateFromSharedPreferences() async {
    if (_hasMigrated) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      //migrate favorite songs
      final oldFavoriteSongs = prefs.getStringList('favorite_songs_v1') ?? [];
      if (oldFavoriteSongs.isNotEmpty) {
        for (final songIdStr in oldFavoriteSongs) {
          final songId = int.tryParse(songIdStr);
          if (songId != null && songId > 0) {
            await _repository.addFavoriteSong(songId);
          }
        }
        await prefs.remove('favorite_songs_v1');
        debugPrint(
          'FavoritesService: Migrated ${oldFavoriteSongs.length} favorite songs',
        );
      }

      //migrate favorite artists
      final oldFavoriteArtists =
          prefs.getStringList('favorite_artists_v1') ?? [];
      if (oldFavoriteArtists.isNotEmpty) {
        for (final artistIdStr in oldFavoriteArtists) {
          final artistId = int.tryParse(artistIdStr);
          if (artistId != null && artistId > 0) {
            await _repository.addFavoriteArtist(artistId, 'Unknown');
          }
        }
        await prefs.remove('favorite_artists_v1');
        debugPrint(
          'FavoritesService: Migrated ${oldFavoriteArtists.length} favorite artists',
        );
      }

      //migrate favorite albums
      final oldFavoriteAlbums = prefs.getStringList('favorite_albums_v1') ?? [];
      if (oldFavoriteAlbums.isNotEmpty) {
        for (final albumIdStr in oldFavoriteAlbums) {
          final albumId = int.tryParse(albumIdStr);
          if (albumId != null && albumId > 0) {
            await _repository.addFavoriteAlbum(albumId, 'Unknown');
          }
        }
        await prefs.remove('favorite_albums_v1');
        debugPrint(
          'FavoritesService: Migrated ${oldFavoriteAlbums.length} favorite albums',
        );
      }

      _hasMigrated = true;
    } catch (e) {
      debugPrint('FavoritesService: Error during migration: $e');
    }
  }

  /// Sync of existing favorites to database playlist
  Future<void> syncExistingFavoritesToPlaylist() async {
    try {
      debugPrint('FavoritesService: Starting sync');

      final favoriteSongIds = await _repository.getFavoriteSongIds();
      if (favoriteSongIds.isEmpty) return;

      final playlistId = await _getOrCreateDbPlaylistId();
      if (playlistId == null) return;

      final existingSongIds = await _playlistService.getPlaylistSongIds(
        playlistId,
      );
      final existingSet = existingSongIds.toSet();
      final songsToAdd =
          favoriteSongIds.where((id) => !existingSet.contains(id)).toList();

      if (songsToAdd.isEmpty) return;

      for (final songId in songsToAdd) {
        await _playlistService.addSongToPlaylist(playlistId, songId);
      }

      debugPrint('Synced ${songsToAdd.length} favorites');
    } catch (e) {
      debugPrint('Error syncing favorites: $e');
    }
  }

  /// Song favorites methods
  Future<void> _loadFavoriteSongsCache() async {
    if (_favoriteSongsCache != null) return;

    await _migrateFromSharedPreferences();

    try {
      final favoriteIds = await _repository.getFavoriteSongIds();
      _favoriteSongsCache = favoriteIds.toSet();
    } catch (e) {
      debugPrint('FavoritesService: Error loading favorite songs cache: $e');
      _favoriteSongsCache = <int>{};
    }
  }

  Future<void> addSongToFavorites(int songId) async {
    if (songId <= 0) {
      debugPrint('FavoritesService: Invalid song ID: $songId');
      return;
    }

    await _loadFavoriteSongsCache();

    if (_favoriteSongsCache!.contains(songId)) {
      return;
    }

    try {
      _favoriteSongsCache!.add(songId);
      notifyListeners();

      await _repository.addFavoriteSong(songId);
      await _addToSystemPlaylist(songId);
      await _addToDbPlaylist(songId);

      debugPrint(
        'FavoritesService: Added song $songId to favorites (all 3 systems)',
      );
    } catch (e) {
      _favoriteSongsCache!.remove(songId);
      notifyListeners();
      debugPrint('FavoritesService: Error adding song to favorites: $e');
      rethrow;
    }
  }

  Future<void> removeSongFromFavorites(int songId) async {
    if (songId <= 0) return;

    await _loadFavoriteSongsCache();

    if (!_favoriteSongsCache!.contains(songId)) {
      return;
    }

    try {
      _favoriteSongsCache!.remove(songId);
      notifyListeners();

      await _repository.removeFavoriteSong(songId);
      await _removeFromSystemPlaylist(songId);
      await _removeFromDbPlaylist(songId);

      debugPrint(
        'FavoritesService: Removed song $songId from favorites (all 3 systems)',
      );
    } catch (e) {
      _favoriteSongsCache!.add(songId);
      notifyListeners();
      debugPrint('FavoritesService: Error removing song from favorites: $e');
      rethrow;
    }
  }

  Future<bool> isSongFavorite(int songId) async {
    if (songId <= 0) return false;

    await _loadFavoriteSongsCache();
    return _favoriteSongsCache!.contains(songId);
  }

  Future<List<int>> getFavoriteSongIds() async {
    await _loadFavoriteSongsCache();
    return _favoriteSongsCache!.toList();
  }

  Future<List<SongModel>> getFavoriteSongs() async {
    try {
      final favoriteIds = await getFavoriteSongIds();
      if (favoriteIds.isEmpty) return [];

      final allSongs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      final favoriteIdSet = favoriteIds.toSet();
      final favoriteSongs =
          allSongs.where((song) => favoriteIdSet.contains(song.id)).toList();

      favoriteSongs.sort((a, b) {
        final aIndex = favoriteIds.indexOf(a.id);
        final bIndex = favoriteIds.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });

      return favoriteSongs;
    } catch (e) {
      debugPrint('FavoritesService: Error getting favorite songs: $e');
      return [];
    }
  }

  /// Artist favorites methods
  Future<void> _loadFavoriteArtistsCache() async {
    if (_favoriteArtistsCache != null) return;

    await _migrateFromSharedPreferences();

    try {
      final favoriteArtists = await _repository.getFavoriteArtists();
      _favoriteArtistsCache =
          favoriteArtists.map((a) => a['artist_id'] as int).toSet();
    } catch (e) {
      debugPrint('FavoritesService: Error loading favorite artists cache: $e');
      _favoriteArtistsCache = <int>{};
    }
  }

  Future<void> addArtistToFavorites(int artistId, String artistName) async {
    if (artistId <= 0) return;

    await _loadFavoriteArtistsCache();

    if (_favoriteArtistsCache!.contains(artistId)) {
      return;
    }

    try {
      _favoriteArtistsCache!.add(artistId);
      notifyListeners();

      await _repository.addFavoriteArtist(artistId, artistName);

      debugPrint('FavoritesService: Added artist $artistId to favorites');
    } catch (e) {
      _favoriteArtistsCache!.remove(artistId);
      notifyListeners();
      debugPrint('FavoritesService: Error adding artist to favorites: $e');
      rethrow;
    }
  }

  Future<void> removeArtistFromFavorites(int artistId) async {
    if (artistId <= 0) return;

    await _loadFavoriteArtistsCache();

    if (!_favoriteArtistsCache!.contains(artistId)) {
      return;
    }

    try {
      _favoriteArtistsCache!.remove(artistId);
      notifyListeners();

      await _repository.removeFavoriteArtist(artistId);

      debugPrint('FavoritesService: Removed artist $artistId from favorites');
    } catch (e) {
      _favoriteArtistsCache!.add(artistId);
      notifyListeners();
      debugPrint('FavoritesService: Error removing artist from favorites: $e');
      rethrow;
    }
  }

  Future<bool> isArtistFavorite(int artistId) async {
    if (artistId <= 0) return false;

    await _loadFavoriteArtistsCache();
    return _favoriteArtistsCache!.contains(artistId);
  }

  Future<List<int>> getFavoriteArtistIds() async {
    await _loadFavoriteArtistsCache();
    return _favoriteArtistsCache!.toList();
  }

  Future<List<ArtistModel>> getFavoriteArtists() async {
    try {
      final favoriteIds = await getFavoriteArtistIds();
      if (favoriteIds.isEmpty) return [];

      final allArtists = await _audioQuery.queryArtists(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      final favoriteIdSet = favoriteIds.toSet();
      return allArtists
          .where((artist) => favoriteIdSet.contains(artist.id))
          .toList();
    } catch (e) {
      debugPrint('FavoritesService: Error getting favorite artists: $e');
      return [];
    }
  }

  /// Album favorites methods
  Future<void> _loadFavoriteAlbumsCache() async {
    if (_favoriteAlbumsCache != null) return;

    await _migrateFromSharedPreferences();

    try {
      final favoriteAlbums = await _repository.getFavoriteAlbums();
      _favoriteAlbumsCache =
          favoriteAlbums.map((a) => a['album_id'] as int).toSet();
    } catch (e) {
      debugPrint('FavoritesService: Error loading favorite albums cache: $e');
      _favoriteAlbumsCache = <int>{};
    }
  }

  Future<void> addAlbumToFavorites(int albumId, String albumName) async {
    if (albumId <= 0) return;

    await _loadFavoriteAlbumsCache();

    if (_favoriteAlbumsCache!.contains(albumId)) {
      return;
    }

    try {
      _favoriteAlbumsCache!.add(albumId);
      notifyListeners();

      await _repository.addFavoriteAlbum(albumId, albumName);

      debugPrint('FavoritesService: Added album $albumId to favorites');
    } catch (e) {
      _favoriteAlbumsCache!.remove(albumId);
      notifyListeners();
      debugPrint('FavoritesService: Error adding album to favorites: $e');
      rethrow;
    }
  }

  Future<void> removeAlbumFromFavorites(int albumId) async {
    if (albumId <= 0) return;

    await _loadFavoriteAlbumsCache();

    if (!_favoriteAlbumsCache!.contains(albumId)) {
      return;
    }

    try {
      _favoriteAlbumsCache!.remove(albumId);
      notifyListeners();

      await _repository.removeFavoriteAlbum(albumId);

      debugPrint('FavoritesService: Removed album $albumId from favorites');
    } catch (e) {
      _favoriteAlbumsCache!.add(albumId);
      notifyListeners();
      debugPrint('FavoritesService: Error removing album from favorites: $e');
      rethrow;
    }
  }

  Future<bool> isAlbumFavorite(int albumId) async {
    if (albumId <= 0) return false;

    await _loadFavoriteAlbumsCache();
    return _favoriteAlbumsCache!.contains(albumId);
  }

  Future<List<int>> getFavoriteAlbumIds() async {
    await _loadFavoriteAlbumsCache();
    return _favoriteAlbumsCache!.toList();
  }

  Future<List<AlbumModel>> getFavoriteAlbums() async {
    try {
      final favoriteIds = await getFavoriteAlbumIds();
      if (favoriteIds.isEmpty) return [];

      final allAlbums = await _audioQuery.queryAlbums(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      final favoriteIdSet = favoriteIds.toSet();
      return allAlbums
          .where((album) => favoriteIdSet.contains(album.id))
          .toList();
    } catch (e) {
      debugPrint('FavoritesService: Error getting favorite albums: $e');
      return [];
    }
  }

  /// System playlist integration methods
  Future<int?> _getOrCreateLikedPlaylistId() async {
    if (_likedPlaylistId != null) return _likedPlaylistId;

    if (_isCreatingPlaylist) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _likedPlaylistId;
    }

    try {
      _isCreatingPlaylist = true;

      final playlists = await _audioQuery.queryPlaylists();
      final likedPlaylist = playlists.where(
        (p) => p.playlist == likedPlaylistName,
      );

      if (likedPlaylist.isNotEmpty) {
        _likedPlaylistId = likedPlaylist.first.id;
        return _likedPlaylistId;
      }

      final success = await _audioQuery.createPlaylist(likedPlaylistName);
      if (success) {
        final updatedPlaylists = await _audioQuery.queryPlaylists();
        final newLikedPlaylist = updatedPlaylists.where(
          (p) => p.playlist == likedPlaylistName,
        );
        if (newLikedPlaylist.isNotEmpty) {
          _likedPlaylistId = newLikedPlaylist.first.id;
          return _likedPlaylistId;
        }
      }

      debugPrint('FavoritesService: Failed to create or find liked playlist');
    } catch (e) {
      debugPrint('FavoritesService: Error managing liked playlist: $e');
    } finally {
      _isCreatingPlaylist = false;
    }

    return null;
  }

  Future<void> _addToSystemPlaylist(int songId) async {
    try {
      final playlistId = await _getOrCreateLikedPlaylistId();
      if (playlistId == null) return;

      //check if song is already in playlist before adding
      final existingSongs = await _audioQuery.queryAudiosFrom(
        AudiosFromType.PLAYLIST,
        playlistId,
      );

      final isAlreadyInPlaylist = existingSongs.any(
        (song) => song.id == songId,
      );

      if (!isAlreadyInPlaylist) {
        await _audioQuery.addToPlaylist(playlistId, songId);
        debugPrint('FavoritesService: Added song $songId to system playlist');
      } else {
        debugPrint(
          'FavoritesService: Song $songId already in system playlist, skipping add',
        );
      }
    } catch (e) {
      debugPrint('FavoritesService: Error adding to system playlist: $e');
    }
  }

  Future<void> _removeFromSystemPlaylist(int songId) async {
    try {
      final playlistId = await _getOrCreateLikedPlaylistId();
      if (playlistId == null) return;

      await _audioQuery.removeFromPlaylist(playlistId, songId);
      debugPrint('FavoritesService: Removed song $songId from system playlist');
    } catch (e) {
      debugPrint('FavoritesService: Error removing from system playlist: $e');
    }
  }

  /// Utility Methods
  Future<void> clearAllFavorites() async {
    await _repository.clearAllFavorites();
    _favoriteSongsCache?.clear();
    _favoriteArtistsCache?.clear();
    _favoriteAlbumsCache?.clear();
    notifyListeners();
    debugPrint('FavoritesService: Cleared all favorites');
  }

  void invalidateCache() {
    _favoriteSongsCache = null;
    _favoriteArtistsCache = null;
    _favoriteAlbumsCache = null;
    _likedDbPlaylistId = null;
    notifyListeners();
  }

  /// Get or create database "Liked Songs" playlist
  Future<int?> _getOrCreateDbPlaylistId() async {
    if (_likedDbPlaylistId != null) return _likedDbPlaylistId;

    try {
      final allPlaylists = await _playlistService.getAllPlaylists();
      final likedPlaylist = allPlaylists.where(
        (p) => p.name == likedPlaylistName && p.isFavorite,
      );

      if (likedPlaylist.isNotEmpty) {
        _likedDbPlaylistId = likedPlaylist.first.id;
        return _likedDbPlaylistId;
      }

      _likedDbPlaylistId = await _playlistService.createPlaylist(
        name: likedPlaylistName,
        isFavorite: true,
      );

      return _likedDbPlaylistId;
    } catch (e) {
      debugPrint('FavoritesService: Error getting/creating DB playlist: $e');
      return null;
    }
  }

  /// Add song to database "Liked Songs" playlist
  Future<void> _addToDbPlaylist(int songId) async {
    try {
      final playlistId = await _getOrCreateDbPlaylistId();
      if (playlistId == null) return;

      final existingSongIds = await _playlistService.getPlaylistSongIds(
        playlistId,
      );
      if (existingSongIds.contains(songId)) {
        return;
      }

      await _playlistService.addSongToPlaylist(playlistId, songId);
      debugPrint(
        'FavoritesService: Added song $songId to DB Liked Songs playlist',
      );
    } catch (e) {
      debugPrint('FavoritesService: Error adding song to DB playlist: $e');
    }
  }

  /// Remove song from database "Liked Songs" playlist
  Future<void> _removeFromDbPlaylist(int songId) async {
    try {
      final playlistId = await _getOrCreateDbPlaylistId();
      if (playlistId == null) return;

      await _playlistService.removeSongFromPlaylist(playlistId, songId);
      debugPrint(
        'FavoritesService: Removed song $songId from DB Liked Songs playlist',
      );
    } catch (e) {
      debugPrint('FavoritesService: Error removing song from DB playlist: $e');
    }
  }
}
