import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/pages/library/artist_page.dart';

/// Helper class for navigating to artist pages
class ArtistNavigation {
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
      //query all artists to find the matching one
      //note: this is optimized by the native side
      final artists = await audioQuery.queryArtists();
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
      //query all artists
      final artists = await audioQuery.queryArtists();

      //find artist by name (case-insensitive)
      final artist = artists.firstWhere(
        (a) => a.artist.toLowerCase() == artistName.toLowerCase(),
        orElse: () => throw Exception('Artist not found'),
      );

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
