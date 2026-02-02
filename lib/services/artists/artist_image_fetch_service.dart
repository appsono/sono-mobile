import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sono/data/repositories/artists_repository.dart';
import 'package:sono/services/utils/env_config.dart';
import 'artist_fetch_progress_service.dart';

/// Service for automatically fetching artist images
class ArtistImageFetchService {
  final ArtistsRepository _repository = ArtistsRepository();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtistFetchProgressService? _progressService;

  static String get _artistImageServiceURL => EnvConfig.artistProfileApiUrl;
  static const String _fetchCompleteKey = 'artist_images_initial_fetch_complete_v1';

  ArtistImageFetchService({ArtistFetchProgressService? progressService})
      : _progressService = progressService;

  /// Check if initial fetch should run
  /// Returns true if not yet completed
  Future<bool> shouldRunInitialFetch() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_fetchCompleteKey);
  }

  /// Mark initial fetch as complete
  Future<void> markInitialFetchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fetchCompleteKey, true);
    if (kDebugMode) {
      print('ArtistImageFetchService: Marked initial fetch as complete');
    }
  }

  /// Reset fetch state (for refresh feature in settings)
  Future<void> resetFetchState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fetchCompleteKey);
    await _repository.clearAllFetchedImages();
    if (kDebugMode) {
      print('ArtistImageFetchService: Reset fetch state');
    }
  }

  /// Fetch all artist images
  /// Processes artists in batches with rate limiting
  Future<void> fetchAllArtistImages({
    Function(int current, int total)? onProgress,
    bool skipIfDone = true,
  }) async {
    try {
      if (skipIfDone && !await shouldRunInitialFetch()) {
        if (kDebugMode) {
          print('ArtistImageFetchService: Initial fetch already completed, skipping');
        }
        return;
      }

      //get all artists from MediaStore
      final artists = await _audioQuery.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      if (artists.isEmpty) {
        if (kDebugMode) {
          print('ArtistImageFetchService: No artists found');
        }
        return;
      }

      if (kDebugMode) {
        print('ArtistImageFetchService: Starting fetch for ${artists.length} artists');
      }

      _progressService?.startFetch(artists.length);

      int processed = 0;
      int successful = 0;

      //process in batches of 10
      const batchSize = 10;
      for (int i = 0; i < artists.length; i += batchSize) {
        final batchEnd = min(i + batchSize, artists.length);
        final batch = artists.sublist(i, batchEnd);

        for (final artist in batch) {
          //skip <unknown> artists
          if (artist.artist.toLowerCase() == '<unknown>') {
            processed++;
            onProgress?.call(processed, artists.length);
            _progressService?.updateProgress(processed, artists.length, null);
            continue;
          }

          //update current artist
          _progressService?.updateProgress(processed, artists.length, artist.artist);

          //check if it should fetch this artist
          if (await _repository.shouldFetchImage(artist.artist)) {
            final url = await fetchArtistImage(artist.artist);
            if (url != null) {
              successful++;
              _progressService?.incrementSuccess(artist.artist);
            } else {
              _progressService?.incrementFailure(artist.artist, 'No image found');
            }
          }

          processed++;
          onProgress?.call(processed, artists.length);
          _progressService?.updateProgress(processed, artists.length, null);

          //rate limiting: 200ms delay between requests
          if (processed < artists.length) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      }

      _progressService?.completeFetch();

      if (kDebugMode) {
        print('ArtistImageFetchService: Completed. Processed: $processed, Successful: $successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ArtistImageFetchService: Error during fetchAllArtistImages: $e');
      }
      rethrow;
    }
  }

  /// Fetch a single artist image from custom Go API
  /// Returns the image URL if successful, null otherwise
  Future<String?> fetchArtistImage(String artistName) async {
    try {
      if (kDebugMode) {
        print('ArtistImageFetchService: Fetching image for "$artistName"');
      }

      final url = Uri.parse(
        '$_artistImageServiceURL/api/artist-image?name=${Uri.encodeComponent(artistName)}',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true && data['image_url'] != null) {
          final imageUrl = data['image_url'] as String;

          //save URL to database
          await _repository.setFetchedImageUrl(artistName, imageUrl);
          if (kDebugMode) {
            print('ArtistImageFetchService: Saved image URL for "$artistName"');
          }
          return imageUrl;
        }
      }

      if (kDebugMode) {
        print('ArtistImageFetchService: No image found for "$artistName"');
      }
      await _repository.markFetchAttempted(artistName);
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('ArtistImageFetchService: Error fetching image for "$artistName": $e');
      }
      //mark as attempted even on failure to avoid retry loops
      await _repository.markFetchAttempted(artistName);
      return null;
    }
  }

  /// Get fetch statistics
  Future<Map<String, dynamic>> getFetchStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fetchComplete = prefs.getBool(_fetchCompleteKey) ?? false;

      return {
        'fetchComplete': fetchComplete,
      };
    } catch (e) {
      if (kDebugMode) {
        print('ArtistImageFetchService: Error getting fetch stats: $e');
      }
      return {'fetchComplete': false};
    }
  }
}