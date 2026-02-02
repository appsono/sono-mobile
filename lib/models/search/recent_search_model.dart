/// Model for storing recent search queries
class RecentSearch {
  /// Search query string
  final String query;

  /// When this search was performed
  final DateTime timestamp;
  
  /// Number of results found for this query
  final int resultCount;

  const RecentSearch({
    required this.query,
    required this.timestamp,
    this.resultCount = 0,
  });

  /// Convert to JSON for SharedPreferences storage
  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
        'resultCount': resultCount,
      };

  /// Create from JSON stored in SharedPreferences
  factory RecentSearch.fromJson(Map<String, dynamic> json) {
    return RecentSearch(
      query: json['query'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      resultCount: (json['resultCount'] as int?) ?? 0,
    );
  }

  /// Create a copy with updated fields
  RecentSearch copyWith({
    String? query,
    DateTime? timestamp,
    int? resultCount,
  }) {
    return RecentSearch(
      query: query ?? this.query,
      timestamp: timestamp ?? this.timestamp,
      resultCount: resultCount ?? this.resultCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentSearch &&
        other.query == query &&
        other.timestamp == timestamp &&
        other.resultCount == resultCount;
  }

  @override
  int get hashCode => Object.hash(query, timestamp, resultCount);

  @override
  String toString() =>
      'RecentSearch(query: $query, timestamp: $timestamp, resultCount: $resultCount)';
}