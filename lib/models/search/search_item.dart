enum SearchItemType { song, album, artist }

class SearchItem {
  final SearchItemType type;
  final dynamic data;
  final String sortKey;
  final int score;

  SearchItem({
    required this.type,
    required this.data,
    required this.sortKey,
    this.score = 0,
  });
}
