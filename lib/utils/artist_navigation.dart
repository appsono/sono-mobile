import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/pages/library/artist_page.dart';

/// Helper class for navigating to artist pages
class ArtistNavigation {
  //cached artist list to avoid re-querying MediaStore on every navigation
  static List<ArtistModel>? _cachedArtists;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  /// Get artists with caching to avoid slow MediaStore queries
  static Future<List<ArtistModel>> _getArtists(OnAudioQuery audioQuery) async {
    final now = DateTime.now();
    if (_cachedArtists != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedArtists!;
    }
    _cachedArtists = await audioQuery.queryArtists();
    _cacheTimestamp = now;
    return _cachedArtists!;
  }

  /// Invalidate the cached artist list
  static void invalidateCache() {
    _cachedArtists = null;
    _cacheTimestamp = null;
  }

  /// Navigate to an artist page using an ArtistModel directly
  static void navigateWithArtistModel(
    BuildContext context,
    ArtistModel artist,
    OnAudioQuery audioQuery,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistPage(artist: artist, audioQuery: audioQuery),
      ),
    );
  }

  /// Navigate to an artist page by artist ID
  static Future<void> navigateToArtistById(
    BuildContext context,
    int artistId,
    OnAudioQuery audioQuery,
  ) async {
    try {
      final artists = await _getArtists(audioQuery);
      final artist = artists.firstWhere(
        (a) => a.id == artistId,
        orElse: () => throw Exception('Artist not found'),
      );

      if (!context.mounted) return;

      navigateWithArtistModel(context, artist, audioQuery);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Artist not found');
    }
  }

  /// Navigate to an artist page by name
  /// Finds the artist in the list and navigates to their page
  static Future<void> navigateToArtistByName(
    BuildContext context,
    String artistName,
    OnAudioQuery audioQuery,
  ) async {
    try {
      final artists = await _getArtists(audioQuery);

      //try exact match first (case-insensitive)
      var artist = artists.cast<ArtistModel?>().firstWhere(
        (a) => a?.artist.toLowerCase() == artistName.toLowerCase(),
        orElse: () => null,
      );

      //if no exact match found, try partial matching
      //handles cases where "Tyler, The Creator" was split into "Tyler"
      //but we are searching for the full name
      artist ??= artists.cast<ArtistModel?>().firstWhere(
        (a) =>
            artistName.toLowerCase().startsWith('${a!.artist.toLowerCase()},'),
        orElse: () => null,
      );

      if (artist == null) {
        throw Exception('Artist not found');
      }

      if (!context.mounted) return;

      navigateWithArtistModel(context, artist, audioQuery);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Artist "$artistName" not found in library');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
