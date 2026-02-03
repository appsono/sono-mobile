import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/models/search/search_item.dart';
import 'package:sono/models/search/search_filter_options.dart';

/// Parameters for "isolate-based" search
class _SearchIsolateParams {
  final String query;
  final List<SongModel> songs;
  final List<AlbumModel> albums;
  final List<ArtistModel> artists;
  final SearchFilterOptions filterOptions;

  const _SearchIsolateParams({
    required this.query,
    required this.songs,
    required this.albums,
    required this.artists,
    required this.filterOptions,
  });
}

/// Service for doing search operations
class SearchService {
  /// Do search across songs, albums, artists
  /// Runs in background isolate => avoids blocking UI thread
  Future<List<SearchItem>> performSearch({
    required String query,
    required List<SongModel> songs,
    required List<AlbumModel> albums,
    required List<ArtistModel> artists,
    SearchFilterOptions? filterOptions,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      //run search
      final results = await compute(
        _searchIsolate,
        _SearchIsolateParams(
          query: query,
          songs: songs,
          albums: albums,
          artists: artists,
          filterOptions: filterOptions ?? const SearchFilterOptions(),
        ),
      );

      return results;
    } catch (e) {
      debugPrint('SearchService: Error during search: $e');
      return [];
    }
  }

  /// Isolate function that performs the actual search
  /// This runs in a background thread
  static List<SearchItem> _searchIsolate(_SearchIsolateParams params) {
    final lowerCaseQuery = params.query.toLowerCase();
    final List<SearchItem> foundItems = [];
    final filterOptions = params.filterOptions;

    //search songs with scoring
    if (filterOptions.isTypeEnabled(SearchItemType.song)) {
      for (var song in params.songs) {
        int score = 0;

        //title matching => highest priority
        if (song.title.toLowerCase().startsWith(lowerCaseQuery)) {
          score += 10;
        } else if (song.title.toLowerCase().contains(lowerCaseQuery)) {
          score += 5;
        }

        //artist matching => medium priority
        if (song.artist?.toLowerCase().contains(lowerCaseQuery) ?? false) {
          score += 3;
        }

        //album matching => lower priority
        if (song.album?.toLowerCase().contains(lowerCaseQuery) ?? false) {
          score += 2;
        }

        if (score > 0) {
          foundItems.add(
            SearchItem(
              type: SearchItemType.song,
              data: song,
              sortKey: song.title.toLowerCase(),
              score: score,
            ),
          );
        }
      }
    }

    //search albums with scoring
    if (filterOptions.isTypeEnabled(SearchItemType.album)) {
      for (var album in params.albums) {
        int score = 0;

        //album name matching => highest priority
        if (album.album.toLowerCase().startsWith(lowerCaseQuery)) {
          score += 10;
        } else if (album.album.toLowerCase().contains(lowerCaseQuery)) {
          score += 5;
        }

        //artist matching => medium priority
        if (album.artist?.toLowerCase().contains(lowerCaseQuery) ?? false) {
          score += 3;
        }

        if (score > 0) {
          foundItems.add(
            SearchItem(
              type: SearchItemType.album,
              data: album,
              sortKey: album.album.toLowerCase(),
              score: score,
            ),
          );
        }
      }
    }

    //search artists with scoring
    if (filterOptions.isTypeEnabled(SearchItemType.artist)) {
      for (var artist in params.artists) {
        int score = 0;

        //artist name matching
        if (artist.artist.toLowerCase().startsWith(lowerCaseQuery)) {
          score += 10;
        } else if (artist.artist.toLowerCase().contains(lowerCaseQuery)) {
          score += 5;
        }

        if (score > 0) {
          foundItems.add(
            SearchItem(
              type: SearchItemType.artist,
              data: artist,
              sortKey: artist.artist.toLowerCase(),
              score: score,
            ),
          );
        }
      }
    }

    //apply sorting based on filter options
    _sortResults(foundItems, filterOptions.sortType);

    return foundItems;
  }

  /// Sort results based on selected sort type
  static void _sortResults(List<SearchItem> items, SearchSortType sortType) {
    switch (sortType) {
      case SearchSortType.relevance:
        //sort by score, highest first => then by type => then alphabetically
        items.sort((a, b) {
          if (a.score != b.score) return b.score.compareTo(a.score);
          if (a.type.index != b.type.index) {
            return a.type.index.compareTo(b.type.index);
          }
          return a.sortKey.compareTo(b.sortKey);
        });
        break;

      case SearchSortType.alphabetical:
        //sort alphabetically by sortKey => then by type
        items.sort((a, b) {
          final sortKeyCompare = a.sortKey.compareTo(b.sortKey);
          if (sortKeyCompare != 0) return sortKeyCompare;
          return a.type.index.compareTo(b.type.index);
        });
        break;

      case SearchSortType.reverseAlphabetical:
        //sort reverse alphabetically by sortKey => then by type
        items.sort((a, b) {
          final sortKeyCompare = b.sortKey.compareTo(a.sortKey);
          if (sortKeyCompare != 0) return sortKeyCompare;
          return a.type.index.compareTo(b.type.index);
        });
        break;

      case SearchSortType.dateAdded:
        // We use relevance sorting for this implementation
        // In the future we will switch to "date added"
        // This is low priority, as the Search Filters are disabled
        items.sort((a, b) {
          if (a.score != b.score) return b.score.compareTo(a.score);
          if (a.type.index != b.type.index) {
            return a.type.index.compareTo(b.type.index);
          }
          return a.sortKey.compareTo(b.sortKey);
        });
        break;
    }
  }

  /// Group results by type for display
  static Map<SearchItemType, List<SearchItem>> groupResultsByType(
    List<SearchItem> results,
  ) {
    final Map<SearchItemType, List<SearchItem>> grouped = {
      SearchItemType.song: [],
      SearchItemType.album: [],
      SearchItemType.artist: [],
    };

    for (var item in results) {
      grouped[item.type]?.add(item);
    }

    return grouped;
  }
}
