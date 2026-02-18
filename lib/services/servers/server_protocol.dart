import 'package:sono/data/models/music_server_model.dart';
import 'package:sono/data/models/remote_models.dart';

/// Abstract protocol interface for music server communication
/// Each server type (Subsonic, Jellyfin, etc.) implements this
abstract class MusicServerProtocol {
  final MusicServerModel server;

  MusicServerProtocol(this.server);

  /// Test server connection and auth
  /// Returns null on success, error message on failure
  Future<String?> ping();

  /// Get all artists
  Future<List<RemoteArtist>> getArtists();

  /// Get albums for a specific artist
  Future<List<RemoteAlbum>> getArtistAlbums(String artistId);

  /// Get songs for a specific album
  Future<List<RemoteSong>> getAlbumSongs(String albumId);

  /// Browse albums by type (newest, random, frequent, recent, starred)
  Future<List<RemoteAlbum>> getAlbumList({
    String type = 'newest',
    int count = 50,
    int offset = 0,
  });

  /// Full-text search across artists, albums, songs
  Future<RemoteSearchResult> search(String query, {int limit = 20});

  /// Build stream URL for a song ID (URL passed to player)
  String getStreamUrl(String songId);

  /// Build cover art URL for a cover art ID
  String getCoverArtUrl(String coverArtId, {int size = 300});

  /// Get top/popular songs for an artist (by name)
  Future<List<RemoteSong>> getTopSongs(String artistName, {int count = 20});

  /// Get artist info (bio, image URLs, similar artists) by artist ID
  /// Returns raw map with keys like: biography, lastFmUrl, largeImageUrl, similarArtist
  Future<Map<String, dynamic>> getArtistInfo(String artistId);

  /// Get a single song by its ID (used to check starred status, etc.)
  Future<RemoteSong?> getSong(String songId);

  /// Get a single album by its ID (used to check starred status, etc.)
  Future<RemoteAlbum?> getAlbum(String albumId);

  /// Get a single artist by its ID (used to check starred status, etc.)
  Future<RemoteArtist?> getArtist(String artistId);

  /// Star (favorite) a song, album, or artist on the server
  Future<void> star({String? id, String? albumId, String? artistId});

  /// Unstar (unfavorite) a song, album, or artist on the server
  Future<void> unstar({String? id, String? albumId, String? artistId});
}
