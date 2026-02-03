import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Artwork cache service with LRU cache and memory management
class ArtworkCacheService {
  static final ArtworkCacheService instance = ArtworkCacheService._internal();
  ArtworkCacheService._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();

  //LRU Cache with limited size => prevent memory issues
  //key format: "{typeIndex}_{id}_{size}" to allow distinct cached sizes
  final Map<String, Uint8List?> _cache = {};
  final List<String> _accessOrder = [];
  static const int _maxCacheSize = 50;
  static const int _cacheCleanupThreshold = 50;

  int _estimatedMemoryUsageBytes = 0;
  static const int _maxMemoryUsageMB = 20;

  /// Gets artwork with caching and memory management
  Future<Uint8List?> getArtwork(
    int songId, {
    ArtworkType type = ArtworkType.AUDIO,
    int size = 200,
  }) async {
    final String key = '${type.index}_${songId}_$size';

    //return from cache if available
    if (_cache.containsKey(key)) {
      _updateAccessOrder(key);
      return _cache[key];
    }

    //trim cache if needed before adding new item
    if (_cache.length >= _cacheCleanupThreshold) {
      await _trimCache();
    }

    //fetch artwork
    try {
      final artwork = await _audioQuery.queryArtwork(
        songId,
        type,
        size: size,
        quality: 100,
      );

      //update cache and memory tracking (keyed by type/id/size)
      _cache[key] = artwork;
      _updateAccessOrder(key);

      if (artwork != null) {
        _estimatedMemoryUsageBytes += artwork.lengthInBytes;

        //if memory usage too high => trim more aggressively
        if (_estimatedMemoryUsageBytes > _maxMemoryUsageMB * 1024 * 1024) {
          await _trimCacheByMemory();
        }
      }

      return artwork;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ArtworkCacheService: Error fetching artwork for $songId: $e',
        );
      }
      _cache[key] = null;
      _updateAccessOrder(key);
      return null;
    }
  }

  /// Updates access order for LRU cache
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// Trims cache to max size using LRU strategy
  Future<void> _trimCache() async {
    if (_cache.length <= _maxCacheSize) return;

    final itemsToRemove = _cache.length - _maxCacheSize;
    final oldestKeys = _accessOrder.take(itemsToRemove).toList();

    for (final key in oldestKeys) {
      final artwork = _cache[key];
      if (artwork != null) {
        _estimatedMemoryUsageBytes -= artwork.lengthInBytes;
      }
      _cache.remove(key);
      _accessOrder.remove(key);
    }

    if (kDebugMode) {
      debugPrint(
        'ArtworkCacheService: Trimmed $itemsToRemove items. Cache size: ${_cache.length}',
      );
    }
  }

  /// Trims cache based on memory usage
  Future<void> _trimCacheByMemory() async {
    final targetMemory =
        (_maxMemoryUsageMB * 0.7 * 1024 * 1024).toInt(); //trim to 70% of max

    while (_estimatedMemoryUsageBytes > targetMemory &&
        _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.first;
      final artwork = _cache[oldestKey];

      if (artwork != null) {
        _estimatedMemoryUsageBytes -= artwork.lengthInBytes;
      }

      _cache.remove(oldestKey);
      _accessOrder.remove(oldestKey);
    }

    if (kDebugMode) {
      debugPrint(
        'ArtworkCacheService: Trimmed by memory. Size: ${_cache.length}, Memory: ${(_estimatedMemoryUsageBytes / 1024 / 1024).toStringAsFixed(2)}MB',
      );
    }
  }

  /// Preloads artwork for a list of songs
  Future<void> preloadArtwork(
    List<int> songIds, {
    ArtworkType type = ArtworkType.AUDIO,
    int size = 200,
    int maxPreload = 20, //limit preloading => prevent memory issues
  }) async {
    final idsToPreload = songIds.take(maxPreload).toList();

    for (final songId in idsToPreload) {
      final key = '${type.index}_${songId}_$size';
      if (!_cache.containsKey(key)) {
        await getArtwork(songId, type: type, size: size);
      }
    }
  }

  /// Clears specific artwork from cache
  /// Clears cached artwork for a given song id across any requested sizes/types.
  void clearArtwork(int songId) {
    final prefix = '_${songId}_';
    final keysToRemove = _cache.keys.where((k) => k.contains(prefix)).toList();

    for (final key in keysToRemove) {
      final artwork = _cache[key];
      if (artwork != null) {
        _estimatedMemoryUsageBytes -= artwork.lengthInBytes;
      }
      _cache.remove(key);
      _accessOrder.remove(key);
    }
  }

  /// Clears all cached artwork
  void clearAllCache() {
    _cache.clear();
    _accessOrder.clear();
    _estimatedMemoryUsageBytes = 0;

    if (kDebugMode) {
      debugPrint('ArtworkCacheService: Cache cleared');
    }
  }

  /// Gets cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cache_size': _cache.length,
      'max_cache_size': _maxCacheSize,
      'memory_usage_mb': (_estimatedMemoryUsageBytes / 1024 / 1024)
          .toStringAsFixed(2),
      'max_memory_mb': _maxMemoryUsageMB,
      'items_in_cache': _cache.length,
    };
  }

  /// Checks if artwork is cached
  bool isCached(int songId) {
    final prefix = '_${songId}_';
    return _cache.keys.any((k) => k.contains(prefix));
  }

  /// Gets cache hit rate
  double getCacheHitRate() {
    if (_accessOrder.isEmpty) return 0.0;
    return _cache.length / _accessOrder.length;
  }

  /// Periodic cleanup
  Future<void> performPeriodicCleanup() async {
    if (_cache.length > _maxCacheSize) {
      await _trimCache();
    }
    if (_estimatedMemoryUsageBytes > _maxMemoryUsageMB * 1024 * 1024) {
      await _trimCacheByMemory();
    }
  }
}
