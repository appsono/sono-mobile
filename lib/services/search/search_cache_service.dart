import 'package:flutter/foundation.dart';
import 'package:sono/models/search/search_item.dart';

/// Cached search result with timestamp
class _CachedSearchResult {
  final List<SearchItem> results;
  final DateTime timestamp;

  const _CachedSearchResult({
    required this.results,
    required this.timestamp,
  });

  /// Check if cache entry is expired
  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// Service for caching search results with LRU eviction policy
class SearchCacheService {
  final Map<String, _CachedSearchResult> _cache = {};
  final int _maxCacheSize;
  final Duration _cacheDuration;

  /// Create a new search cache service
  ///
  /// [maxCacheSize] Maximum number of cached queries => default 50
  /// [cacheDuration] How long to keep cached results => default 5 minutes

  SearchCacheService({
    int maxCacheSize = 50, // maxCacheSize can be changed heree
    Duration cacheDuration = const Duration(minutes: 5), // Duration can be changed here
  })  : _maxCacheSize = maxCacheSize,
        _cacheDuration = cacheDuration;

  /// Get cached results for a query
  /// Returns null if not found or expired
  List<SearchItem>? get(String query) {
    final cacheKey = _getCacheKey(query);
    final cached = _cache[cacheKey];

    if (cached == null) {
      return null;
    }

    //check if expired
    if (cached.isExpired(_cacheDuration)) {
      _cache.remove(cacheKey);
      debugPrint('SearchCache: Cache expired for query "$query"');
      return null;
    }

    debugPrint('SearchCache: Cache hit for query "$query" (${cached.results.length} results)');

    //move to end to mark as recently used, LRU
    _cache.remove(cacheKey);
    _cache[cacheKey] = cached;

    return List.from(cached.results); //return copy
  }

  /// Cache search results for a query
  void put(String query, List<SearchItem> results) {
    final cacheKey = _getCacheKey(query);

    //evict oldest entry if cache is full
    if (_cache.length >= _maxCacheSize && !_cache.containsKey(cacheKey)) {
      _evictOldest();
    }

    //remove existing entry => if present, to update position
    _cache.remove(cacheKey);

    //add new entry at end, most recently used
    _cache[cacheKey] = _CachedSearchResult(
      results: List.from(results), //store copy
      timestamp: DateTime.now(),
    );

    debugPrint('SearchCache: Cached query "$query" (${results.length} results)');
  }

  /// Clear all cached results
  void clear() {
    final count = _cache.length;
    _cache.clear();
    debugPrint('SearchCache: Cleared $count cached queries');
  }

  /// Remove specific query from cache
  void remove(String query) {
    final cacheKey = _getCacheKey(query);
    final removed = _cache.remove(cacheKey);
    if (removed != null) {
      debugPrint('SearchCache: Removed query "$query" from cache');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'cacheDuration': _cacheDuration.inMinutes,
    };
  }

  /// Evict the oldest (least recently used) cache entry
  void _evictOldest() {
    if (_cache.isEmpty) return;

    //first entry is the oldest => LinkedHashMap maintains insertion order
    final oldestKey = _cache.keys.first;
    _cache.remove(oldestKey);
    debugPrint('SearchCache: Evicted oldest entry "$oldestKey" (LRU)');
  }

  /// Generate cache key from query, normalized
  String _getCacheKey(String query) {
    return query.toLowerCase().trim();
  }

  /// Check if query is in cache and not expired
  bool has(String query) {
    final cacheKey = _getCacheKey(query);
    final cached = _cache[cacheKey];
    if (cached == null) return false;
    return !cached.isExpired(_cacheDuration);
  }

  /// Get number of cached queries
  int get size => _cache.length;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is full
  bool get isFull => _cache.length >= _maxCacheSize;
}