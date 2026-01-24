import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/services/settings/library_settings_service.dart';

class AudioFilterUtils {
  static Future<List<SongModel>> getFilteredSongs(
    OnAudioQuery audioQuery, {
    SongSortType? sortType,
    OrderType? orderType,
    String? path,
  }) async {
    List<String> excludedPaths = await LibrarySettingsService.instance.getExcludedFolders();
    List<SongModel> allSongs = await audioQuery.querySongs(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
      path: path,
      ignoreCase: true,
    );

    if (excludedPaths.isEmpty) {
      return allSongs;
    }

    allSongs.removeWhere(
      (song) => excludedPaths.any(
        (excludedPath) => song.data.startsWith(excludedPath),
      ),
    );
    return allSongs;
  }

  static Future<List<AlbumModel>> getFilteredAlbums(
    OnAudioQuery audioQuery, {
    AlbumSortType? sortType,
    OrderType? orderType,
  }) async {
    List<SongModel> filteredSongs = await getFilteredSongs(
      audioQuery,
    );

    if (filteredSongs.isEmpty) {
      return [];
    }

    final Set<int?> albumIdsFromFilteredSongs =
        filteredSongs.map((s) => s.albumId).toSet();
    albumIdsFromFilteredSongs.removeWhere((id) => id == null);

    if (albumIdsFromFilteredSongs.isEmpty) {
      return [];
    }

    List<AlbumModel> allAlbums = await audioQuery.queryAlbums(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
    );

    List<AlbumModel> filteredAlbums =
        allAlbums
            .where((album) => albumIdsFromFilteredSongs.contains(album.id))
            .toList();

    return filteredAlbums;
  }

  static Future<List<ArtistModel>> getFilteredArtists(
    OnAudioQuery audioQuery, {
    ArtistSortType? sortType,
    OrderType? orderType,
  }) async {
    List<SongModel> filteredSongs = await getFilteredSongs(
      audioQuery,
    );

    if (filteredSongs.isEmpty) {
      return [];
    }

    List<ArtistModel> allArtists = await audioQuery.queryArtists(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
    );

    final Set<String> artistNamesFromSongs = filteredSongs
        .where((s) => s.artist != null)
        .map((s) => s.artist!.toLowerCase().trim())
        .toSet();

    List<ArtistModel> filteredArtists = allArtists.where((artist) {
      final artistNameLower = artist.artist.toLowerCase().trim();

      return artistNamesFromSongs.any((songArtist) {
        if (songArtist == artistNameLower) return true;

        final separators = [', ', ' feat. ', ' ft. ', ' featuring ', ' / ', '/', ' & ', '&', ' and ', ' x ', ' X '];
        for (final sep in separators) {
          if (songArtist.startsWith('$artistNameLower$sep') ||
              songArtist.endsWith('$sep$artistNameLower') ||
              songArtist.contains('$sep$artistNameLower$sep')) {
            return true;
          }
        }
        return false;
      });
    }).toList();

    return filteredArtists;
  }

  static Future<List<PlaylistModel>> getFilteredPlaylists(
    OnAudioQuery audioQuery, {
    PlaylistSortType? sortType,
    OrderType? orderType,
  }) async {
    return audioQuery.queryPlaylists(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
    );
  }
}