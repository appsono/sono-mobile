import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sono/services/utils/env_config.dart';

class ApiService {
  /// API prefix for all endpoints
  static const String apiPrefix = "/api/v1";

  /// Get production base URL from environment config
  static String get prodBaseUrl => EnvConfig.apiBaseUrl;

  /// Get development base URL from environment config
  static String get devBaseUrl => EnvConfig.devApiBaseUrl;

  static const String _apiModeIsProdKey = 'api_mode_is_prod_preference_v1';
  static const String _accessTokenKey = 'auth_access_token_v2';
  static const String _refreshTokenKey = 'auth_refresh_token_v2';
  static const String _tokenExpiryKey = 'auth_token_expiry_v2';
  static const String _cachedUserDataKey = 'cached_user_data_v1';

  bool _isRefreshing = false;
  final List<Completer<String?>> _tokenWaiters = [];
  Timer? _refreshTimer;
  StreamController<bool>? _authStateController;
  StreamController<String>? _notificationController;
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;

  ApiService() {
    _authStateController = StreamController<bool>.broadcast();
    _notificationController = StreamController<String>.broadcast();
    _initializeNotifications();
    _startPeriodicTokenCheck();
  }

  Stream<bool> get authStateStream => _authStateController!.stream;
  Stream<String> get notificationStream => _notificationController!.stream;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('ApiService: $message');
    }
  }

  void _logError(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint(
        'ApiService ERROR: $message${error != null ? ' - $error' : ''}',
      );
    }
  }

  Future<String> _getBaseUrl() async {
    final prefs = await _prefs;
    bool useProduction = prefs.getBool(_apiModeIsProdKey) ?? true;
    return (useProduction ? prodBaseUrl : devBaseUrl) + apiPrefix;
  }

  Future<String> _getAssetBaseUrl(bool useProduction) async {
    if (useProduction) {
      return prodBaseUrl;
    } else {
      final devApiUrl = Uri.parse(devBaseUrl);
      try {
        return devApiUrl.replace(port: 9000).toString();
      } catch (e) {
        return devBaseUrl;
      }
    }
  }

  Future<Map<String, dynamic>> _transformUserData(
    Map<String, dynamic> userData,
  ) async {
    if (userData.containsKey('profile_picture_url') &&
        userData['profile_picture_url'] != null) {
      final prefs = await _prefs;
      final useProduction = prefs.getBool(_apiModeIsProdKey) ?? true;
      final assetBaseUrl = await _getAssetBaseUrl(useProduction);
      final originalUrl = userData['profile_picture_url'] as String;

      //minio:9000 is the internal docker address, in production we use cdn.sono.wtf
      //this address will only be used during local development of the API
      if (originalUrl.startsWith('http://minio:9000')) {
        userData['profile_picture_url'] = originalUrl.replaceFirst(
          'http://minio:9000',
          assetBaseUrl,
        );
      }
    }
    return userData;
  }

  Future<void> setApiMode({required bool useProduction}) async {
    final prefs = await _prefs;
    await prefs.setBool(_apiModeIsProdKey, useProduction);
  }

  Future<bool> isProductionMode() async {
    final prefs = await _prefs;
    return prefs.getBool(_apiModeIsProdKey) ?? true;
  }

  Future<void> _initializeNotifications() async {
    try {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin?.initialize(
        initializationSettings,
      );
    } catch (e) {
      _logError('Error initializing notifications', e);
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> deleteTokens() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_tokenExpiryKey),
      prefs.remove(_cachedUserDataKey),
    ]);

    _refreshTimer?.cancel();
    _authStateController?.add(false);
    _log('All authentication tokens and cached data cleared');
  }

  Future<void> _saveTokens(
    String accessToken,
    String refreshToken, {
    int? expiresInSeconds,
  }) async {
    try {
      final prefs = await _prefs;

      final expiryDuration = Duration(seconds: expiresInSeconds ?? (30 * 60));
      final expiryTime =
          DateTime.now().add(expiryDuration).millisecondsSinceEpoch;

      await Future.wait([
        prefs.setString(_accessTokenKey, accessToken),
        prefs.setString(_refreshTokenKey, refreshToken),
        prefs.setInt(_tokenExpiryKey, expiryTime),
      ]);

      _log(
        'Tokens saved successfully. Expiry: ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}',
      );

      _scheduleTokenRefresh(expiryTime);

      _authStateController?.add(true);
    } catch (e) {
      _logError('Error saving tokens', e);
      throw Exception('Failed to save authentication tokens');
    }
  }

  Future<bool> hasValidTokens() async {
    try {
      final prefs = await _prefs;
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final expiry = prefs.getInt(_tokenExpiryKey);

      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        return false;
      }

      if (expiry == null) {
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final bufferTime = 2 * 60 * 1000;

      return now < (expiry - bufferTime);
    } catch (e) {
      _logError('Error checking token validity', e);
      return false;
    }
  }

  /// Checks if tokens need refreshing on app start
  /// Returns true if a refresh should be attempted
  Future<bool> shouldRefreshOnStart() async {
    try {
      final prefs = await _prefs;
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final expiry = prefs.getInt(_tokenExpiryKey);

      //no tokens at all => skip refresh
      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        return false;
      }

      //no expiry info => play it safe and refresh
      if (expiry == null) {
        _log('No expiry info found, will refresh on start');
        return true;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final timeUntilExpiry = expiry - now;

      //token expired or expiring within 5 minutes => refresh
      const refreshThreshold = 5 * 60 * 1000; //5 minutes
      if (timeUntilExpiry <= refreshThreshold) {
        _log(
          'Token expiring soon ($timeUntilExpiry ms), will refresh on start',
        );
        return true;
      }

      _log('Token still fresh, no need to refresh on start');
      return false;
    } catch (e) {
      _logError('Error checking if refresh needed on start', e);
      return false; //conservative: dont refresh on error
    }
  }

  /// Attempts to refresh tokens on app start
  /// Throws errors for caller to handle (distinguishes auth vs network errors)
  Future<void> refreshOnAppStart() async {
    if (_isRefreshing) {
      _log('Refresh already in progress, skipping app start refresh');
      return;
    }

    try {
      if (!await shouldRefreshOnStart()) {
        return;
      }

      _log('Performing app start token refresh...');
      await _performBackgroundRefresh();
      _log('App start token refresh completed successfully');
    } catch (e) {
      _logError('App start token refresh failed', e);
      //rethrow so caller can distinguish between network vs auth errors
      rethrow;
    }
  }

  void _startPeriodicTokenCheck() {
    _refreshTimer?.cancel();

    _checkAndRefreshTokens();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_authStateController?.isClosed == true) {
        timer.cancel();
        return;
      }
      await _checkAndRefreshTokens();
    });
  }

  Future<void> _checkAndRefreshTokens() async {
    try {
      if (!await hasValidTokens()) {
        _log('No valid tokens found, clearing auth state');
        _authStateController?.add(false);
        return;
      }

      final prefs = await _prefs;
      final expiryTime = prefs.getInt(_tokenExpiryKey);

      if (expiryTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final timeUntilExpiry = expiryTime - now;

        const refreshThreshold = 5 * 60 * 1000;

        if (timeUntilExpiry <= refreshThreshold && timeUntilExpiry > 0) {
          _log('Token expires soon, performing preemptive refresh');
          await _performBackgroundRefresh();
        } else if (timeUntilExpiry <= 0) {
          _log('Token has expired, attempting refresh');
          await _performBackgroundRefresh();
        }
      }
    } catch (e) {
      _logError('Error during token check', e);
    }
  }

  Future<void> _performBackgroundRefresh() async {
    if (_isRefreshing) {
      _log('Refresh already in progress, skipping');
      return;
    }

    try {
      _log('Performing background token refresh...');
      await refreshToken();
      _log('Background token refresh successful');

      _authStateController?.add(true);
    } catch (e) {
      _logError('Background token refresh failed', e);

      if (e.toString().contains('No refresh token available') ||
          e.toString().contains('401') ||
          e.toString().contains('refresh token')) {
        _log('Clearing invalid tokens');
        await deleteTokens();
        _authStateController?.add(false);
      }
    }
  }

  void _scheduleTokenRefresh(int expiryTime) {
    _refreshTimer?.cancel();

    final now = DateTime.now().millisecondsSinceEpoch;
    final refreshTime = expiryTime - (5 * 60 * 1000);
    final delayMs = refreshTime - now;

    if (delayMs > 0 && delayMs < (24 * 60 * 60 * 1000)) {
      _refreshTimer = Timer(Duration(milliseconds: delayMs), () {
        _log('Scheduled token refresh triggered');
        _performBackgroundRefresh();
      });

      final refreshDateTime = DateTime.fromMillisecondsSinceEpoch(refreshTime);
      _log(
        'Token refresh scheduled for: $refreshDateTime (in ${Duration(milliseconds: delayMs).inMinutes} minutes)',
      );
    }
  }

  Future<Map<String, String>> _getHeaders({
    bool isAuthenticated = false,
    String contentType = 'application/json',
  }) async {
    Map<String, String> headers = {'Content-Type': contentType};

    if (isAuthenticated) {
      //check if need to refresh
      //BUT dont refresh if a refresh is already in progress => avoid deadlock
      if (!await hasValidTokens() && !_isRefreshing) {
        try {
          await refreshToken();
        } catch (e) {
          _logError('Failed to refresh token in _getHeaders', e);
          //let the request proceed => it will fail with 401 if token is truly invalid
        }
      }

      String? token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Check if an error is a network/transient error that should be retried
  bool _isRetryableError(Object error) {
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

  /// Check if a status code is retryable (server errors)
  bool _isRetryableStatusCode(int statusCode) {
    return statusCode == 408 || //request timeout
        statusCode == 429 || //too many requests
        statusCode == 502 || //bad gateway
        statusCode == 503 || //service unavailable
        statusCode == 504; //gateway timeout
  }

  /// Calculate delay for retry with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    //exponential backoff: 2s, 4s, 8s, 16s
    final delaySeconds = 2 * (1 << (attempt - 1)); //2^attempt
    return Duration(seconds: delaySeconds.clamp(2, 16));
  }

  /// Make an authenticated request with retry logic
  /// - Handles 401 by refreshing token and retrying
  /// - Handles network errors with exponential backoff
  /// - Handles retryable server errors (503, etc.) with exponential backoff
  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() requestFunction, {
    int maxRetries = 3,
    bool isIdempotent = true,
  }) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      attempts++;

      try {
        final response = await requestFunction();

        //handle 401 Unauthorized => try to refresh token
        if (response.statusCode == 401 && attempts <= maxRetries) {
          _log('Got 401, attempting token refresh (attempt $attempts)');
          final refreshTokenValue = await _getRefreshToken();
          if (refreshTokenValue != null && !_isRefreshing) {
            try {
              await refreshToken();
              _log('Token refreshed, retrying original request');
              continue; //retry with new token
            } catch (e) {
              _logError('Token refresh failed', e);
              await deleteTokens();
              _authStateController?.add(false);
              return response; //return 401 response
            }
          } else if (_isRefreshing) {
            //wait for ongoing refresh to complete
            final completer = Completer<String?>();
            _tokenWaiters.add(completer);
            try {
              await completer.future.timeout(const Duration(seconds: 30));
              continue; //Retry with new token
            } catch (e) {
              return response;
            }
          }
        }

        //handle retryable server errors
        if (_isRetryableStatusCode(response.statusCode) &&
            isIdempotent &&
            attempts <= maxRetries) {
          final delay = _calculateRetryDelay(attempts);
          _log(
            'Got ${response.statusCode}, retrying in ${delay.inSeconds}s (attempt $attempts/$maxRetries)',
          );
          await Future.delayed(delay);
          continue;
        }

        return response;
      } catch (e) {
        //handle network/transient errors with retry
        if (_isRetryableError(e) && isIdempotent && attempts <= maxRetries) {
          final delay = _calculateRetryDelay(attempts);
          _logError(
            'Network error, retrying in ${delay.inSeconds}s (attempt $attempts/$maxRetries)',
            e,
          );
          await Future.delayed(delay);
          continue;
        }

        if (attempts > maxRetries) {
          _logError('Max retries exceeded', e);
          rethrow;
        }
        rethrow;
      }
    }

    throw Exception('Max retry attempts exceeded');
  }

  /// Make an authenticated multipart request (for file uploads)
  Future<http.Response> _makeAuthenticatedMultipartRequest(
    Future<http.Response> Function() requestFunction, {
    int maxRetries = 1,
  }) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      attempts++;

      try {
        final response = await requestFunction();

        //handle 401 Unauthorized => try to refresh token
        if (response.statusCode == 401 && attempts <= maxRetries) {
          _log('Got 401 on upload, attempting token refresh');
          final refreshTokenValue = await _getRefreshToken();
          if (refreshTokenValue != null && !_isRefreshing) {
            try {
              await refreshToken();
              _log('Token refreshed, retrying upload');
              continue;
            } catch (e) {
              _logError('Token refresh failed on upload', e);
              await deleteTokens();
              _authStateController?.add(false);
              return response;
            }
          }
        }

        //dont retry file uploads for server errors (not safe)
        return response;
      } catch (e) {
        //dont retry file uploads for network errors (not safe)
        _logError('Upload failed', e);
        if (attempts >= maxRetries) rethrow;
        attempts++;
      }
    }

    throw Exception('Max retry attempts exceeded');
  }

  Future<void> refreshToken() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _tokenWaiters.add(completer);

      try {
        final newToken = await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Token refresh wait timeout'),
        );

        if (newToken == null || newToken.isEmpty) {
          throw Exception('Token refresh failed during wait');
        }

        _log('Token refresh completed via waiting');
        return;
      } catch (e) {
        _logError('Error waiting for token refresh', e);
        rethrow;
      }
    }

    _isRefreshing = true;
    String? newAccessToken;

    try {
      final refreshTokenValue = await _getRefreshToken();
      if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
        throw Exception("No refresh token available");
      }

      final baseUrl = await _getBaseUrl();
      final body = {'refresh_token': refreshTokenValue};

      _log('Attempting to refresh token...');
      final response = await http
          .post(
            Uri.parse('$baseUrl/users/token/refresh'),
            headers: await _getHeaders(),
            body: json.encode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Token refresh request timeout'),
          );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        _log('Token refresh successful');

        newAccessToken = responseBody['access_token'];

        await _saveTokens(
          newAccessToken!,
          responseBody['refresh_token'] ?? refreshTokenValue,
          expiresInSeconds: responseBody['expires_in'],
        );

        final prefs = await _prefs;
        final newExpiryTime = prefs.getInt(_tokenExpiryKey);
        if (newExpiryTime != null) {
          _scheduleTokenRefresh(newExpiryTime);
        }

        for (final waiter in _tokenWaiters) {
          if (!waiter.isCompleted) {
            waiter.complete(newAccessToken);
          }
        }
        _tokenWaiters.clear();
      } else {
        final errorMessage =
            'Failed to refresh token: ${response.statusCode} ${responseBody['detail'] ?? response.body}';

        for (final waiter in _tokenWaiters) {
          if (!waiter.isCompleted) {
            waiter.completeError(Exception(errorMessage));
          }
        }
        _tokenWaiters.clear();

        throw Exception(errorMessage);
      }
    } catch (e) {
      _logError('Token refresh error', e);

      for (final waiter in _tokenWaiters) {
        if (!waiter.isCompleted) {
          waiter.completeError(e);
        }
      }
      _tokenWaiters.clear();

      if (!e.toString().contains('timeout') &&
          !e.toString().contains('network') &&
          !e.toString().contains('connection')) {
        await deleteTokens();
      }

      throw Exception('Could not refresh token: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  //--- API ENDPOINTS ---

  // 1. Health Check
  Future<Map<String, dynamic>> healthCheck() async {
    final baseUrl = await _getBaseUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check health: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Health check failed: $e');
    }
  }

  // 2.1 Register a new user
  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final baseUrl = await _getBaseUrl();
    final body = {
      "username": username,
      "email": email,
      "password": password,
      if (displayName != null && displayName.isNotEmpty)
        "display_name": displayName,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      final responseBody = json.decode(response.body);
      if (response.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception(
          'Failed to register: ${response.statusCode} ${responseBody['detail'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // 2.2 Login for Access Token
  Future<Map<String, dynamic>> login(String username, String password) async {
    final baseUrl = await _getBaseUrl();
    final body = {'username': username, 'password': password};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/token'),
        headers: await _getHeaders(
          contentType: 'application/x-www-form-urlencoded',
        ),
        body: body,
      );

      final responseBody = json.decode(response.body);
      if (response.statusCode == 200) {
        await _saveTokens(
          responseBody['access_token'],
          responseBody['refresh_token'],
          expiresInSeconds: responseBody['expires_in'],
        );
        return responseBody;
      } else {
        throw Exception(
          'Failed to login: ${response.statusCode} ${responseBody['detail'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // 2.4 Get Current User Details
  Future<Map<String, dynamic>> getCurrentUser() async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    if (response.statusCode == 200) {
      final userData = json.decode(response.body) as Map<String, dynamic>;
      final transformedData = await _transformUserData(userData);

      //cache user data for quick loading on app start
      await _cacheUserData(transformedData);

      return transformedData;
    } else {
      final responseBody = json.decode(response.body);
      throw Exception(
        'Failed to get user: ${response.statusCode} ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  /// Cache user data to SharedPreferences for quick loading on app start
  Future<void> _cacheUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_cachedUserDataKey, json.encode(userData));
      _log('User data cached successfully');
    } catch (e) {
      _logError('Failed to cache user data', e);
    }
  }

  /// Load cached user data from SharedPreferences
  Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      final prefs = await _prefs;
      final cachedData = prefs.getString(_cachedUserDataKey);
      if (cachedData != null) {
        return json.decode(cachedData) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logError('Failed to load cached user data', e);
      return null;
    }
  }

  // 2.5 Update Current User Details
  Future<Map<String, dynamic>> updateCurrentUser({
    String? displayName,
    String? bio,
  }) async {
    final baseUrl = await _getBaseUrl();
    final Map<String, String> body = {};
    if (displayName != null) body['display_name'] = displayName;
    if (bio != null) body['bio'] = bio;

    if (body.isEmpty) return await getCurrentUser();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/users/me'),
        headers: await _getHeaders(isAuthenticated: true),
        body: json.encode(body),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return _transformUserData(responseBody);
    } else {
      throw Exception(
        'Failed to update user: ${response.statusCode} ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 2.6 Upload Profile Picture
  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedMultipartRequest(() async {
      final uri = Uri.parse('$baseUrl/users/me/upload-profile-picture');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _getHeaders(isAuthenticated: true));
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return _transformUserData(responseBody);
    } else {
      throw Exception(
        'Failed to upload picture: ${response.statusCode} ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 3.1 Admin - Get User Stats
  Future<Map<String, dynamic>> getAdminStats() async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/admin/stats'),
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return responseBody;
    } else {
      throw Exception(
        'Failed to get stats: ${response.statusCode} ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  //============= COLLECTIONS API =============

  // 4.1 Get My Collections
  Future<List<Map<String, dynamic>>> getMyCollections({
    int skip = 0,
    int limit = 20,
    String? collectionType,
  }) async {
    final baseUrl = await _getBaseUrl();

    final queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (collectionType != null)
        'collection_type': collectionType.toLowerCase(),
    };

    final uri = Uri.parse(
      '$baseUrl/collections/my-collections',
    ).replace(queryParameters: queryParams);

    _log('Fetching my collections...');

    final response = await _makeAuthenticatedRequest(() async {
      return await http.get(
        uri,
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    _log('Get my collections response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      final collections = responseBody['collections'] as List<dynamic>;
      _log('Successfully fetched ${collections.length} collections');
      return List<Map<String, dynamic>>.from(collections);
    } else if (response.statusCode == 500) {
      _logError(
        'Server error when fetching collections',
        '${response.statusCode}: ${response.body}',
      );
      throw Exception(
        'Server error when fetching collections. Please check your backend server logs.',
      );
    } else {
      try {
        final responseBody = json.decode(response.body);
        _logError(
          'Failed to get collections',
          '${response.statusCode}: ${responseBody['detail'] ?? response.body}',
        );
        throw Exception(
          'Failed to get my collections: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
        );
      } catch (e) {
        _logError(
          'Failed to get collections',
          '${response.statusCode}: ${response.body}',
        );
        throw Exception(
          'Failed to get my collections: ${response.statusCode} - ${response.body}',
        );
      }
    }
  }

  // 4.2 Create Collection
  Future<Map<String, dynamic>> createCollection({
    required String title,
    String? description,
    required String collectionType, //"playlist", "album", or "compilation"
    String? artist,
    String? curatorNote,
    bool isPublic = false,
    bool isCollaborative = false,
  }) async {
    final baseUrl = await _getBaseUrl();

    final body = {
      "title": title,
      if (description != null && description.isNotEmpty)
        "description": description,
      "collection_type": collectionType.toLowerCase(),
      if (artist != null && artist.isNotEmpty) "artist": artist,
      if (curatorNote != null && curatorNote.isNotEmpty)
        "curator_note": curatorNote,
      "is_public": isPublic,
      "is_collaborative": isCollaborative,
    };

    _log('Creating collection with body: $body');

    final response = await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/collections/'),
        headers: await _getHeaders(isAuthenticated: true),
        body: json.encode(body),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      _log('Collection created successfully');
      return responseBody;
    } else {
      _logError(
        'Failed to create collection',
        '${response.statusCode}: ${responseBody['detail'] ?? response.body}',
      );
      throw Exception(
        'Failed to create collection: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.3 Get Collection by ID
  Future<Map<String, dynamic>> getCollection(int collectionId) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/collections/$collectionId'),
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return responseBody;
    } else {
      throw Exception(
        'Failed to get collection: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.4 Delete Collection
  Future<void> deleteCollection(int collectionId) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/collections/$collectionId'),
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    if (response.statusCode == 200) {
      _log('Collection deleted successfully');
    } else {
      final responseBody = json.decode(response.body);
      throw Exception(
        'Failed to delete collection: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.5 Update Collection
  Future<Map<String, dynamic>> updateCollection({
    required int collectionId,
    String? title,
    String? description,
    String? artist,
    String? curatorNote,
    bool? isPublic,
    bool? isCollaborative,
  }) async {
    final baseUrl = await _getBaseUrl();

    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (artist != null) body['artist'] = artist;
    if (curatorNote != null) body['curator_note'] = curatorNote;
    if (isPublic != null) body['is_public'] = isPublic;
    if (isCollaborative != null) body['is_collaborative'] = isCollaborative;

    if (body.isEmpty) {
      throw Exception('No fields to update');
    }

    final response = await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/collections/$collectionId'),
        headers: await _getHeaders(isAuthenticated: true),
        body: json.encode(body),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return responseBody;
    } else {
      throw Exception(
        'Failed to update collection: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.6 Upload Collection Cover Art
  Future<Map<String, dynamic>> uploadCollectionCoverArt(
    int collectionId,
    File imageFile,
  ) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedMultipartRequest(() async {
      final uri = Uri.parse('$baseUrl/collections/$collectionId/cover-art');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _getHeaders(isAuthenticated: true));

      String? mimeType = lookupMimeType(imageFile.path);

      mimeType ??= 'image/jpeg';

      final contentType = mimeType.split('/');

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType(contentType[0], contentType[1]),
        ),
      );

      _log('Uploading cover art with MIME type: $mimeType');

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return responseBody;
    } else {
      throw Exception(
        'Failed to upload cover art: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.7 Add Track to Collection
  Future<Map<String, dynamic>> addTrackToCollection({
    required int collectionId,
    required int audioFileId,
    int? trackOrder,
  }) async {
    final baseUrl = await _getBaseUrl();

    final body = {
      'audio_file_id': audioFileId,
      if (trackOrder != null) 'track_order': trackOrder,
    };

    final response = await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/collections/$collectionId/tracks'),
        headers: await _getHeaders(isAuthenticated: true),
        body: json.encode(body),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return responseBody;
    } else {
      throw Exception(
        'Failed to add track: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.8 Remove Track from Collection
  Future<void> removeTrackFromCollection(int collectionId, int trackId) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/collections/$collectionId/tracks/$trackId'),
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    if (response.statusCode == 200) {
      _log('Track removed successfully');
    } else {
      final responseBody = json.decode(response.body);
      throw Exception(
        'Failed to remove track: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  // 4.9 Upload Audio File
  Future<Map<String, dynamic>> uploadAudioFile({
    required File audioFile,
    required String title,
    String? artist,
    String? album,
    String? description,
    int? trackNumber,
    int? year,
    String? genre,
    bool isPublic = false,
  }) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedMultipartRequest(() async {
      final uri = Uri.parse('$baseUrl/audio/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _getHeaders(isAuthenticated: true));

      //add file
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      //add metadata
      request.fields['title'] = title;
      if (artist != null) request.fields['artist'] = artist;
      if (album != null) request.fields['album'] = album;
      if (description != null) request.fields['description'] = description;
      if (trackNumber != null) {
        request.fields['track_number'] = trackNumber.toString();
      }
      if (year != null) request.fields['year'] = year.toString();
      if (genre != null) request.fields['genre'] = genre;
      request.fields['is_public'] = isPublic.toString();

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      _log('Audio file uploaded successfully');
      return responseBody;
    } else {
      throw Exception(
        'Failed to upload audio: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  //============= AUDIO STREAMING =============

  //get the stream URL for an audio file
  Future<String> getAudioStreamUrl(int audioFileId) async {
    final baseUrl = await _getBaseUrl();
    final token = await getAccessToken();

    if (token == null) {
      throw Exception('Not authenticated');
    }

    //return URL with auth token as query parameter for streaming
    return '$baseUrl/audio/stream/$audioFileId?token=$token';
  }

  /// get audio file metadata
  Future<Map<String, dynamic>> getAudioFile(int audioFileId) async {
    final baseUrl = await _getBaseUrl();

    final response = await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/audio/$audioFileId'),
        headers: await _getHeaders(isAuthenticated: true),
      );
    });

    final responseBody = json.decode(response.body);
    if (response.statusCode == 200) {
      return responseBody;
    } else {
      throw Exception(
        'Failed to get audio file: ${response.statusCode} - ${responseBody['detail'] ?? response.body}',
      );
    }
  }

  Future<bool> isAuthenticated() async {
    if (!await hasValidTokens()) {
      return false;
    }

    try {
      await getCurrentUser();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await deleteTokens();
    _isRefreshing = false;
  }

  Future<void> forceTokenRefresh() async {
    _log('Manual token refresh triggered');
    await _performBackgroundRefresh();
  }

  void dispose() {
    _refreshTimer?.cancel();
    _authStateController?.close();
    _notificationController?.close();
  }
}