import 'package:on_audio_query/on_audio_query.dart';
import '../services/utils/preferences_service.dart';

class AudioFilterUtils {
  static Future<List<SongModel>> getFilteredSongs(
    OnAudioQuery audioQuery,
    PreferencesService prefsService, {
    SongSortType? sortType,
    OrderType? orderType,
    String? path,
  }) async {
    List<String> excludedPaths = await prefsService.getExcludedFolders();
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
    OnAudioQuery audioQuery,
    PreferencesService prefsService, {
    AlbumSortType? sortType,
    OrderType? orderType,
  }) async {
    List<SongModel> filteredSongs = await getFilteredSongs(
      audioQuery,
      prefsService,
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
    OnAudioQuery audioQuery,
    PreferencesService prefsService, {
    ArtistSortType? sortType,
    OrderType? orderType,
  }) async {
    List<SongModel> filteredSongs = await getFilteredSongs(
      audioQuery,
      prefsService,
    );

    if (filteredSongs.isEmpty) {
      return [];
    }

    // Get all artists from the plugin (including split artists with negative IDs)
    List<ArtistModel> allArtists = await audioQuery.queryArtists(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
    );

    // Build a set of artist names from filtered songs
    final Set<String> artistNamesFromSongs = filteredSongs
        .where((s) => s.artist != null)
        .map((s) => s.artist!.toLowerCase().trim())
        .toSet();


    // Filter artists by checking if their name appears in any song's artist field
    // This works for both regular and split artists
    List<ArtistModel> filteredArtists = allArtists.where((artist) {
      final artistNameLower = artist.artist.toLowerCase().trim();

      // Check if this artist name appears in any song's artist field
      return artistNamesFromSongs.any((songArtist) {
        // Exact match
        if (songArtist == artistNameLower) return true;

        // Check if this artist is part of a combined string
        // e.g., "Kanye West" should match "Kanye West, Jay-Z"
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
    OnAudioQuery audioQuery,
    PreferencesService prefsService, {
    PlaylistSortType? sortType,
    OrderType? orderType,
  }) async {
    //TODO: determine if playlist members should be filtered
    return audioQuery.queryPlaylists(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
    );
  }
}