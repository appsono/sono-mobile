import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP methods that are considered safe for retry
enum HttpMethod { get, head, options, post, put, patch, delete }

/// Configuration for retry behavior
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Set<int> retryableStatusCodes;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 16),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
  });

  static const RetryConfig defaultConfig = RetryConfig();

  /// Config for idempotent requests (GET, HEAD, OPTIONS, PUT, DELETE)
  static const RetryConfig idempotent = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 16),
  );

  /// Config for non-idempotent requests (POST, PATCH) => no retry by default
  static const RetryConfig nonIdempotent = RetryConfig(maxRetries: 0);
}

/// Result of an HTTP request with retry information
class HttpResult {
  final http.Response response;
  final int attemptCount;
  final Duration totalDuration;
  final bool wasRetried;
  final List<String> retryReasons;

  HttpResult({
    required this.response,
    required this.attemptCount,
    required this.totalDuration,
    required this.wasRetried,
    this.retryReasons = const [],
  });

  bool get isSuccess => response.statusCode >= 200 && response.statusCode < 300;
  bool get isClientError =>
      response.statusCode >= 400 && response.statusCode < 500;
  bool get isServerError => response.statusCode >= 500;
}

/// HTTP client with retry logic and error handling
class SonoHttpClient {
  static final SonoHttpClient instance = SonoHttpClient._internal();
  SonoHttpClient._internal();

  final http.Client _client = http.Client();

  /// Request timeout
  Duration requestTimeout = const Duration(seconds: 30);

  /// Connection timeout
  Duration connectionTimeout = const Duration(seconds: 10);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('SonoHttpClient: $message');
    }
  }

  void _logError(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint(
        'SonoHttpClient ERROR: $message${error != null ? ' - $error' : ''}',
      );
    }
  }

  /// Check if the HTTP method is safe to retry
  bool _isSafeToRetry(HttpMethod method) {
    return method == HttpMethod.get ||
        method == HttpMethod.head ||
        method == HttpMethod.options ||
        method == HttpMethod.put ||
        method == HttpMethod.delete;
  }

  /// Calculate delay for retry with exponential backoff
  Duration _calculateDelay(int attempt, RetryConfig config) {
    final delay =
        config.initialDelay.inMilliseconds *
        (config.backoffMultiplier * attempt).toInt();
    final clampedDelay = delay.clamp(
      config.initialDelay.inMilliseconds,
      config.maxDelay.inMilliseconds,
    );
    return Duration(milliseconds: clampedDelay);
  }

  /// Check if the error is a network error that should be retried
  bool _isNetworkError(Object error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is TimeoutException) return true;
    if (error is HandshakeException) return true;

    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable');
  }

  /// Check if the status code is retryable
  bool _isRetryableStatusCode(int statusCode, RetryConfig config) {
    return config.retryableStatusCodes.contains(statusCode);
  }

  /// Execute an HTTP request with retry logic
  Future<HttpResult> request({
    required Uri uri,
    required HttpMethod method,
    Map<String, String>? headers,
    Object? body,
    RetryConfig? retryConfig,
    Duration? timeout,
  }) async {
    final config =
        retryConfig ??
        (_isSafeToRetry(method)
            ? RetryConfig.idempotent
            : RetryConfig.nonIdempotent);

    final stopwatch = Stopwatch()..start();
    int attemptCount = 0;
    final retryReasons = <String>[];

    while (attemptCount <= config.maxRetries) {
      attemptCount++;

      try {
        _log(
          'Request attempt $attemptCount: ${method.name.toUpperCase()} $uri',
        );

        final response = await _executeRequest(
          uri: uri,
          method: method,
          headers: headers,
          body: body,
          timeout: timeout ?? requestTimeout,
        );

        //check if retry based on status code
        if (_isRetryableStatusCode(response.statusCode, config) &&
            attemptCount <= config.maxRetries &&
            _isSafeToRetry(method)) {
          final reason = 'Status code ${response.statusCode}';
          retryReasons.add(reason);
          _log('Retryable status code ${response.statusCode}, will retry');

          final delay = _calculateDelay(attemptCount, config);
          _log('Waiting ${delay.inMilliseconds}ms before retry');
          await Future.delayed(delay);
          continue;
        }

        stopwatch.stop();
        return HttpResult(
          response: response,
          attemptCount: attemptCount,
          totalDuration: stopwatch.elapsed,
          wasRetried: attemptCount > 1,
          retryReasons: retryReasons,
        );
      } catch (e) {
        //check if retry based on error type
        if (_isNetworkError(e) &&
            attemptCount <= config.maxRetries &&
            _isSafeToRetry(method)) {
          final reason = 'Network error: ${e.runtimeType}';
          retryReasons.add(reason);
          _logError('Network error on attempt $attemptCount', e);

          final delay = _calculateDelay(attemptCount, config);
          _log('Waiting ${delay.inMilliseconds}ms before retry');
          await Future.delayed(delay);
          continue;
        }

        stopwatch.stop();
        rethrow;
      }
    }

    //this should never be reached => just in case
    throw Exception('Max retry attempts exceeded');
  }

  /// Execute a single HTTP request
  Future<http.Response> _executeRequest({
    required Uri uri,
    required HttpMethod method,
    Map<String, String>? headers,
    Object? body,
    required Duration timeout,
  }) async {
    http.Response response;

    final requestBody =
        body is String
            ? body
            : body != null
            ? jsonEncode(body)
            : null;

    switch (method) {
      case HttpMethod.get:
        response = await _client.get(uri, headers: headers).timeout(timeout);
        break;
      case HttpMethod.head:
        response = await _client.head(uri, headers: headers).timeout(timeout);
        break;
      case HttpMethod.post:
        response = await _client
            .post(uri, headers: headers, body: requestBody)
            .timeout(timeout);
        break;
      case HttpMethod.put:
        response = await _client
            .put(uri, headers: headers, body: requestBody)
            .timeout(timeout);
        break;
      case HttpMethod.patch:
        response = await _client
            .patch(uri, headers: headers, body: requestBody)
            .timeout(timeout);
        break;
      case HttpMethod.delete:
        response = await _client.delete(uri, headers: headers).timeout(timeout);
        break;
      case HttpMethod.options:
        //HTTP package doesnt have options => use a generic request
        final request = http.Request('OPTIONS', uri);
        if (headers != null) request.headers.addAll(headers);
        final streamedResponse = await _client.send(request).timeout(timeout);
        response = await http.Response.fromStream(streamedResponse);
        break;
    }

    _log(
      'Response: ${response.statusCode} for ${method.name.toUpperCase()} $uri',
    );
    return response;
  }

  /// Convenience method for GET requests
  Future<HttpResult> get(
    Uri uri, {
    Map<String, String>? headers,
    RetryConfig? retryConfig,
    Duration? timeout,
  }) {
    return request(
      uri: uri,
      method: HttpMethod.get,
      headers: headers,
      retryConfig: retryConfig ?? RetryConfig.idempotent,
      timeout: timeout,
    );
  }

  /// Convenience method for POST requests (no retry by default)
  Future<HttpResult> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    RetryConfig? retryConfig,
    Duration? timeout,
  }) {
    return request(
      uri: uri,
      method: HttpMethod.post,
      headers: headers,
      body: body,
      retryConfig: retryConfig ?? RetryConfig.nonIdempotent,
      timeout: timeout,
    );
  }

  /// Convenience method for PUT requests
  Future<HttpResult> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    RetryConfig? retryConfig,
    Duration? timeout,
  }) {
    return request(
      uri: uri,
      method: HttpMethod.put,
      headers: headers,
      body: body,
      retryConfig: retryConfig ?? RetryConfig.idempotent,
      timeout: timeout,
    );
  }

  /// Convenience method for DELETE requests
  Future<HttpResult> delete(
    Uri uri, {
    Map<String, String>? headers,
    RetryConfig? retryConfig,
    Duration? timeout,
  }) {
    return request(
      uri: uri,
      method: HttpMethod.delete,
      headers: headers,
      retryConfig: retryConfig ?? RetryConfig.idempotent,
      timeout: timeout,
    );
  }

  /// Close the client
  void close() {
    _client.close();
  }
}

/// Extension to add retry capability to the ApiService
extension ApiServiceRetryExtension on http.Response {
  /// Check if the response indicates a retryable error
  bool get isRetryable {
    return statusCode == 408 || //request timeout
        statusCode == 429 || //too many requests
        statusCode == 500 || //internal server error
        statusCode == 502 || //bad gateway
        statusCode == 503 || //service unavailable
        statusCode == 504; //gateway timeout
  }

  /// Check if the response is a client error (400-499)
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Check if the response is a server error (500-599)
  bool get isServerError => statusCode >= 500;

  /// Check if the response is successful (200-299)
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
