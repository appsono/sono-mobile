import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:sono/utils/artist_string_utils.dart';

class AudioFilterUtils {
  static Future<List<SongModel>> getFilteredSongs(
    OnAudioQuery audioQuery, {
    SongSortType? sortType,
    OrderType? orderType,
    String? path,
  }) async {
    List<String> excludedPaths =
        await LibrarySettingsService.instance.getExcludedFolders();
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
    List<SongModel> filteredSongs = await getFilteredSongs(audioQuery);

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
    List<SongModel> filteredSongs = await getFilteredSongs(audioQuery);

    if (filteredSongs.isEmpty) {
      return [];
    }

    // Split artist strings and count songs for each individual artist
    Map<String, _ArtistInfo> artistsMap = {};

    for (final song in filteredSongs) {
      if (song.artist == null || song.artist!.isEmpty) continue;

      // Split the artist string into individual artists
      final individualArtists = ArtistStringUtils.splitArtists(song.artist!);

      for (final artistName in individualArtists) {
        final key = artistName.toLowerCase().trim();
        if (artistsMap.containsKey(key)) {
          artistsMap[key]!.songCount++;
          artistsMap[key]!.albumIds.add(song.albumId ?? 0);
        } else {
          artistsMap[key] = _ArtistInfo(
            name: artistName.trim(),
            songCount: 1,
            albumIds: {song.albumId ?? 0},
          );
        }
      }
    }

    // Create ArtistModel entries from the map
    List<ArtistModel> artists = artistsMap.entries.map((entry) {
      final info = entry.value;
      return ArtistModel({
        '_id': entry.key.hashCode,
        'artist': info.name,
        'number_of_tracks': info.songCount,
        'number_of_albums': info.albumIds.length,
      });
    }).toList();

    // Sort artists
    if (sortType != null) {
      artists.sort((a, b) {
        int comparison;
        switch (sortType) {
          case ArtistSortType.ARTIST:
            comparison = a.artist.compareTo(b.artist);
            break;
          case ArtistSortType.NUM_OF_ALBUMS:
            comparison = a.numberOfAlbums!.compareTo(b.numberOfAlbums!);
            break;
          case ArtistSortType.NUM_OF_TRACKS:
            comparison = a.numberOfTracks!.compareTo(b.numberOfTracks!);
            break;
        }
        return orderType == OrderType.DESC_OR_GREATER ? -comparison : comparison;
      });
    }

    return artists;
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

class _ArtistInfo {
  final String name;
  int songCount;
  Set<int> albumIds;

  _ArtistInfo({
    required this.name,
    required this.songCount,
    required this.albumIds,
  });
}
