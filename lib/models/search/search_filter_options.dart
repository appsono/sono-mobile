import 'package:sono/models/search/search_item.dart';

/// Sort options for search results
enum SearchSortType {
  /// Sort by relevance score (default - best matches first)
  relevance,

  /// Sort alphabetically A-Z
  alphabetical,

  /// Sort alphabetically Z-A
  reverseAlphabetical,

  /// Sort by date added (newest first)
  dateAdded,
}

/// Filter options for search results
class SearchFilterOptions {
  /// The sort type to apply to results
  final SearchSortType sortType;

  /// Which result types to show (songs, albums, artists)
  final Set<SearchItemType> enabledTypes;

  /// Show only favorited items
  final bool showOnlyFavorites;

  const SearchFilterOptions({
    this.sortType = SearchSortType.relevance,
    this.enabledTypes = const {
      SearchItemType.song,
      SearchItemType.album,
      SearchItemType.artist,
    },
    this.showOnlyFavorites = false,
  });

  /// Create a copy with updated fields
  SearchFilterOptions copyWith({
    SearchSortType? sortType,
    Set<SearchItemType>? enabledTypes,
    bool? showOnlyFavorites,
  }) {
    return SearchFilterOptions(
      sortType: sortType ?? this.sortType,
      enabledTypes: enabledTypes ?? this.enabledTypes,
      showOnlyFavorites: showOnlyFavorites ?? this.showOnlyFavorites,
    );
  }

  /// Check if all types are enabled
  bool get allTypesEnabled =>
      enabledTypes.length == SearchItemType.values.length;

  /// Check if a specific type is enabled
  bool isTypeEnabled(SearchItemType type) => enabledTypes.contains(type);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilterOptions &&
        other.sortType == sortType &&
        other.enabledTypes.length == enabledTypes.length &&
        other.enabledTypes.containsAll(enabledTypes) &&
        other.showOnlyFavorites == showOnlyFavorites;
  }

  @override
  int get hashCode =>
      Object.hash(sortType, Object.hashAll(enabledTypes), showOnlyFavorites);
}
