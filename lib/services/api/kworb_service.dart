import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sono/models/kworb_response.dart';
import 'package:sono/services/api/http_client.dart';
import 'package:sono/services/utils/env_config.dart';

class KworbServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isOffline;

  KworbServiceException(
    this.message, {
    this.statusCode,
    this.isOffline = false,
  });

  @override
  String toString() => 'KworbServiceException: $message';
}

class KworbService {
  static const String _apiPrefix = '/api/v1';

  String get _baseUrl => EnvConfig.apiBaseUrl;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('KworbService: $message');
    }
  }

  void _logError(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint(
        'KworbService ERROR: $message${error != null ? ' - $error' : ''}',
      );
    }
  }

  Future<KworbResponse?> getArtistData(String artistName) async {
    if (artistName.isEmpty) {
      return null;
    }

    final encodedName = Uri.encodeComponent(artistName);
    final uri = Uri.parse('$_baseUrl$_apiPrefix/kworb/artist/$encodedName');

    _log('Fetching Kworb data for artist: $artistName');

    try {
      final result = await SonoHttpClient.instance.request(
        uri: uri,
        method: HttpMethod.get,
        retryConfig: RetryConfig.idempotent,
      );

      if (result.response.statusCode == 404) {
        _log('No data found for artist: $artistName');
        return null;
      }

      if (!result.isSuccess) {
        _logError(
          'Failed to fetch Kworb data',
          'Status: ${result.response.statusCode}',
        );
        throw KworbServiceException(
          'Failed to fetch artist data',
          statusCode: result.response.statusCode,
        );
      }

      final jsonData = jsonDecode(result.response.body);

      if (jsonData is! Map<String, dynamic>) {
        _logError('Unexpected response format');
        return null;
      }

      final response = KworbResponse.fromJson(jsonData);
      _log('Fetched ${response.topSongs.length} songs for artist: $artistName');

      if (response.monthlyListeners != null) {
        _log('Monthly listeners: ${response.monthlyListeners}');
      }

      return response;
    } on SocketException catch (e) {
      _logError('Network error', e);
      throw KworbServiceException('No internet connection', isOffline: true);
    } on HttpException catch (e) {
      _logError('HTTP error', e);
      throw KworbServiceException('Network error', isOffline: true);
    } catch (e) {
      if (e is KworbServiceException) rethrow;
      _logError('Unexpected error', e);
      throw KworbServiceException('Failed to fetch artist data');
    }
  }
}
