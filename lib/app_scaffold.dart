import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

//pages
import 'package:sono/pages/info/announcements_changelog_page.dart';
import 'package:sono/pages/main/home_page.dart';
import 'package:sono/pages/main/library_page.dart';
import 'package:sono/pages/auth/login_page.dart';
import 'package:sono/pages/api/profile_page.dart';
import 'package:sono/pages/info/recents_page.dart';
import 'package:sono/pages/auth/registration_page.dart';
import 'package:sono/pages/main/search_page.dart';
import 'package:sono/pages/main/settings_page.dart';
//services
import 'package:sono/services/api/api_service.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/utils/update_service.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/services/playlist/playlist_initialization_service.dart';
import 'package:sono/services/playlist/playlist_service.dart';
//styles
import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
//utils
import 'package:sono/utils/error_handler.dart';
//widgets
import 'package:sono/widgets/player/parts/mini_player.dart';
import 'package:sono/widgets/global/sidebar_menu.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';
import 'package:sono/widgets/artists/artist_fetch_progress_button.dart';
import 'package:sono/widgets/global/consent_dialog.dart';
import 'package:sono/pages/info/privacy_page.dart';
import 'package:sono/pages/info/terms_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold>
    with SidebarMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  int? _pressedIndex;
  String? _activeNonTabRoute;
  late List<Widget> _screens;
  String _displayAppVersion = ' ';
  final UpdateService _updateService = UpdateService();
  bool _isCheckingForUpdate = false;
  bool _isUpdateDialogShowing = false;
  Timer? _periodicUpdateCheckTimer;

  final ApiService _apiService = ApiService();
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;
  String _sidebarUserName = 'Guest';
  String? _profilePictureUrl;

  bool _hasPermission = true;
  bool _isLoadingPermission = false;

  final PlaylistInitializationService _playlistInit =
      PlaylistInitializationService();

  Timer? _cacheCleanupTimer;

  //stream subscriptions => MUST be cancelled in dispose to prevent memory leaks
  StreamSubscription<bool>? _authStateSubscription;
  StreamSubscription<String>? _notificationSubscription;

  late PageController _pageController;

  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  AppLifecycleState? _lastLifecycleState;
  DateTime? _backgroundTime;
  bool _isInitializing = true;
  final Duration _backgroundThreshold = const Duration(minutes: 5);
  bool _hasPerformedInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _isInitializing = true;

    //quick check for existing tokens to set initial state before building UI
    _checkInitialAuthState().then((_) {
      if (!mounted) return;
      //after checking initial auth state => create the screens
      setState(() {
        _screens = _createAllScreens();
      });
    });

    //start with empty placeholder screens
    _screens = [
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
    ];

    //defer heavy operations to post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _loadAppVersion();
      _checkCurrentPermissionStatus();
      _initializeAuth();
      _startPeriodicChecks();
      _startCacheCleanup();
      _updateService.cleanupOldApks();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _initializePlaylists();
      }

      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted && !_hasPerformedInitialLoad) {
        _performUpdateCheckAndShowDialog();
        _hasPerformedInitialLoad = true;
      }

      if (mounted) {
        _isInitializing = false;
      }
    });

    //set up stream listeners => store subscriptions for proper disposal
    _authStateSubscription = _apiService.authStateStream.listen((
      isAuthenticated,
    ) {
      if (mounted && !_isInitializing) {
        if (!isAuthenticated && _isLoggedIn) {
          _handleLogout(showSnackbar: false);
        }
      }
    });

    _notificationSubscription = _apiService.notificationStream.listen((
      message,
    ) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _initializePlaylists() async {
    try {
      await _playlistInit.initialize(context);
      await FavoritesService().syncExistingFavoritesToPlaylist();
      debugPrint('Playlist system initialized successfully');
    } catch (e) {
      debugPrint('Error initializing playlists: $e');
    }
  }

  Future<void> _checkCurrentPermissionStatus() async {
    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.audio.status; //.status not .request()
        } else {
          status = await Permission.storage.status; //.status not .request()
        }
      } else {
        status = PermissionStatus.granted;
      }

      if (mounted) {
        setState(() {
          _hasPermission = status.isGranted;
          _isLoadingPermission = false;
        });
        _initializeScreens(
          preserveCurrentScreen: _screens.any((s) => s is! SizedBox),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isLoadingPermission = false;
        });
        _initializeScreens(
          preserveCurrentScreen: _screens.any((s) => s is! SizedBox),
        );
      }
    }
  }

  /// Refreshes all screens when user state changes
  void _initializeScreens({bool preserveCurrentScreen = false}) {
    setState(() {
      if (preserveCurrentScreen && _screens.isNotEmpty) {
        //preserve all already-initialized screens => prevents them from going blank
        final oldScreens = List<Widget>.from(_screens);
        _screens = _createAllScreens();
        for (int i = 0; i < oldScreens.length && i < _screens.length; i++) {
          if (oldScreens[i] is! SizedBox) {
            _screens[i] = _createScreen(i);
          }
        }
      } else {
        _screens = _createAllScreens();
      }
    });
  }

  /// Quick check to see if any tokens stored
  /// This sets initial state optimistically to avoid flashing guest UI
  Future<void> _checkInitialAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRefreshToken = prefs.getString('auth_refresh_token_v2') != null;

      if (!hasRefreshToken) {
        debugPrint('[AppScaffold] No refresh token found');
        return;
      }

      //load cached user data for immediate display
      final cachedUserData = await _apiService.getCachedUserData();

      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          if (cachedUserData != null) {
            _currentUser = cachedUserData;
            _sidebarUserName =
                cachedUserData['display_name'] as String? ??
                cachedUserData['username'] as String? ??
                'User';
            _profilePictureUrl =
                cachedUserData['profile_picture_url'] as String?;
            debugPrint(
              '[AppScaffold] Loaded cached user data: ${_currentUser?['username']}',
            );
          } else {
            _sidebarUserName = 'Loading...';
            debugPrint(
              '[AppScaffold] No cached user data, will fetch from server',
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[AppScaffold] Error checking initial auth state: $e');
    }
  }

  /// Creates all screen widgets with current auth state
  List<Widget> _createAllScreens() {
    return [
      HomePage(
        key: ValueKey('HomePage_${_isLoggedIn}_${_currentUser?['username']}'),
        onSearchTap: _switchToSearchTab,
        onMenuTap: _openSidebar,
        onSettingsTap: () => _onItemTapped(3),
        onCreatePlaylist: _showCreatePlaylistSheet,
        hasPermission: _hasPermission,
        onRequestPermission: _checkCurrentPermissionStatus,
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
      ),
      //placeholder widgets for other tabs => will be replaced on first access
      SizedBox.shrink(key: ValueKey('SearchPage_placeholder_$_isLoggedIn')),
      SizedBox.shrink(key: ValueKey('LibraryPage_placeholder_$_isLoggedIn')),
      SizedBox.shrink(key: ValueKey('SettingsPage_placeholder_$_isLoggedIn')),
    ];
  }

  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _displayAppVersion =
              'v${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayAppVersion = 'v?.?.?';
        });
      }
    }
  }

  Future<void> _initializeAuth() async {
    if (!mounted) return;

    try {
      debugPrint('[AppScaffold] Initializing authentication...');

      //check if any tokens at all first
      final prefs = await SharedPreferences.getInstance();
      final hasRefreshToken = prefs.getString('auth_refresh_token_v2') != null;

      if (!hasRefreshToken) {
        debugPrint('[AppScaffold] No refresh token found, user not logged in');
        return;
      }

      //fetch user => if access token is expired, _makeAuthenticatedRequest will
      //automatically refresh it via 401 handling; if refresh token is also dead,
      //it will emit false on authStateStream and trigger logout
      debugPrint('[AppScaffold] Fetching current user...');
      await _fetchCurrentUser();
    } catch (e) {
      debugPrint('[AppScaffold] Auth initialization error: $e');
      if (mounted && _isLoggedIn) {
        if (e.toString().contains('401') ||
            e.toString().contains('No refresh token')) {
          await _apiService.deleteTokens();
          setState(() {
            _isLoggedIn = false;
            _sidebarUserName = 'Guest';
            _profilePictureUrl = null;
            _currentUser = null;
          });
          //recreate all screens with logged-out state
          _initializeScreens(preserveCurrentScreen: true);
        }
      }
    }
  }

  Future<void> _fetchCurrentUser() async {
    if (!mounted) return;

    try {
      debugPrint('[AppScaffold] Fetching current user data...');
      final userData = await _apiService.getCurrentUser().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
            '[AppScaffold] ERROR: getCurrentUser() timed out after 10 seconds',
          );
          throw TimeoutException('User data fetch timed out');
        },
      );
      debugPrint('[AppScaffold] User data fetched: ${userData['username']}');
      if (mounted) {
        final newUsername = userData['username'];
        final newDisplayName = userData['display_name'];
        final newBio = userData['bio'];
        final newProfilePicture = userData['profile_picture_url'];

        final currentUsername = _currentUser?['username'];
        final currentDisplayName = _currentUser?['display_name'];
        final currentBio = _currentUser?['bio'];

        //check if ANY user data has changed
        final hasChanges =
            newUsername != currentUsername ||
            newDisplayName != currentDisplayName ||
            newBio != currentBio ||
            newProfilePicture != _profilePictureUrl ||
            !_isLoggedIn;

        if (hasChanges) {
          debugPrint('[AppScaffold] User data changed, updating state');
        }

        //always update user data
        setState(() {
          _currentUser = userData;
          _isLoggedIn = true;
          _sidebarUserName =
              _currentUser?['display_name'] ??
              _currentUser?['username'] ??
              'User';
          _profilePictureUrl = newProfilePicture;
          debugPrint(
            '[AppScaffold] User state updated. Username: ${_currentUser?['username']}, DisplayName: ${_currentUser?['display_name']}, isLoggedIn: $_isLoggedIn',
          );
        });

        //recreate screens if data changed
        if (hasChanges) {
          _initializeScreens(preserveCurrentScreen: true);
        }

        _checkConsent();
      }
    } catch (e, s) {
      debugPrint('[AppScaffold] Failed to fetch user: $e');
      if (mounted) {
        if (e.toString().contains("401")) {
          try {
            await _apiService.refreshToken();
            await _fetchCurrentUser();
          } catch (refreshError) {
            debugPrint('Token refresh failed: $refreshError');
            if (refreshError.toString().contains(
                  "No refresh token available",
                ) ||
                refreshError.toString().contains("401")) {
              await _handleLogout(showSnackbar: false);
            } else {
              if (_lastLifecycleState == AppLifecycleState.resumed &&
                  _backgroundTime != null) {
                return;
              }

              if (mounted) {
                ErrorHandler.showErrorSnackbar(
                  context: context,
                  message: 'Session expired. Please log in again.',
                  error: refreshError,
                  stackTrace: StackTrace.current,
                );
              }
              await _handleLogout(showSnackbar: false);
            }
          }
        } else if (e.toString().contains("No refresh token available")) {
          await _handleLogout(showSnackbar: false);
        } else {
          if (_lastLifecycleState != AppLifecycleState.resumed) {
            ErrorHandler.showErrorSnackbar(
              context: context,
              message: 'Could not fetch user details. Please try again.',
              error: e,
              stackTrace: s,
            );
          }
        }
      }
    }
  }

  Future<void> _checkConsent() async {
    const consentVersion = '2.0';

    //check privacy policy consent
    final privacyAccepted = await ConsentDialog.showIfNeeded(
      context: context,
      consentType: 'privacy_policy',
      consentVersion: consentVersion,
      title: 'Privacy Policy',
      content: '''
By using Sono, you agree to our Privacy Policy.

Key points:
• App can be used locally without any account - no data collection for local use
• Creating a Sono Account is OPTIONAL and enables uploading to CDN and cloud playlists
• Crash logs are optional and can be disabled in Settings
• Your data is never sold to third parties
• You have full GDPR rights (access, deletion, portability)

Age requirement for accounts: 13+ years old

Tap "Read Full Policy" below to view the complete Privacy Policy.
      ''',
      onViewFullDocument: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PrivacyPage()),
        );
      },
      onDeclined: () async {
        //logout if declined
        await _apiService.logout();
      },
    );

    if (privacyAccepted == null || !privacyAccepted) {
      //user declined, logout
      await _handleLogout(showSnackbar: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must accept the Privacy Policy to use Sono'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    //check terms of service consent
    if (!mounted) return;
    final termsAccepted = await ConsentDialog.showIfNeeded(
      context: context,
      consentType: 'terms_of_service',
      consentVersion: consentVersion,
      title: 'Terms of Service',
      content: '''
By using Sono, you agree to our Terms of Service.

Key terms:
• App can be used locally without any account for all basic features
• Creating a Sono Account is OPTIONAL and requires being 13+ years old
• Sono Accounts enable uploading songs to CDN and cloud playlists
• You must have legal rights to upload any content
• Do not violate copyright laws or abuse the service
• SAS sessions are peer-to-peer, no audio data stored on our servers

Operated by: Mathis Laarmanns, Germany
Contact: business@mail.sono.wtf

Tap "Read Full Terms" below to view the complete Terms of Service.
      ''',
      onViewFullDocument: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TermsPage()),
        );
      },
      onDeclined: () async {
        //logout if declined
        await _apiService.logout();
      },
    );

    if (termsAccepted == null || !termsAccepted) {
      //user declined, logout
      await _handleLogout(showSnackbar: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must accept the Terms of Service to use Sono'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
  }

  Future<void> _handleLogout({bool showSnackbar = true}) async {
    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Logout');
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
        _sidebarUserName = 'Guest';
        _profilePictureUrl = null;

        if (_activeNonTabRoute == "Profile" ||
            _activeNonTabRoute == "SomeOtherAuthPage") {
          if (Navigator.canPop(context)) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          _activeNonTabRoute = null;
          _onItemTapped(0);
        }
      });

      _initializeScreens();
      closeSidebar();

      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You have been logged out."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    debugPrint('App lifecycle changed: $_lastLifecycleState -> $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }

    _lastLifecycleState = state;
  }

  void _handleAppResumed() {
    debugPrint('App resumed from background');

    if (_backgroundTime != null && !_isInitializing) {
      final backgroundDuration = DateTime.now().difference(_backgroundTime!);
      debugPrint(
        'App was in background for: ${backgroundDuration.inMinutes} minutes',
      );

      if (backgroundDuration > _backgroundThreshold) {
        debugPrint('Performing full refresh after extended background time');
        _performFullRefresh();
      } else if (backgroundDuration.inMinutes > 1) {
        debugPrint('Performing light refresh after short background time');
        _performLightRefresh();
      }
    } else if (!_isInitializing && _backgroundTime == null) {
      _performLightRefresh();
    }

    _backgroundTime = null;
    _startPeriodicChecks();
  }

  void _handleAppPaused() {
    debugPrint('App paused/backgrounded');
    _backgroundTime = DateTime.now();
    _periodicUpdateCheckTimer?.cancel();
    _performCacheCleanup();
    if (kDebugMode) {
      debugPrint('AppScaffold: App backgrounded, cache cleaned');
    }
  }

  void _handleAppInactive() {
    debugPrint('App inactive (temporary state)');
  }

  void _handleAppDetached() {
    debugPrint('App detached');
    _periodicUpdateCheckTimer?.cancel();
    _performCacheCleanup();
  }

  void _handleAppHidden() {
    debugPrint('App hidden');
    _backgroundTime ??= DateTime.now();
  }

  Future<void> _performFullRefresh() async {
    try {
      final futures = <Future<void>>[
        _initializeAuth(),
        _checkCurrentPermissionStatus(),
      ];

      await Future.wait(futures, eagerError: false);

      _performUpdateCheckAndShowDialog();
      _performCacheCleanup();

      debugPrint('Full refresh completed successfully');
    } catch (e, s) {
      debugPrint('Error during full refresh: $e');
      if (e.toString().contains('401') ||
          e.toString().contains('authentication')) {
        if (mounted) {
          ErrorHandler.showErrorSnackbar(
            context: context,
            message: 'Session expired. Please log in again.',
            error: e,
            stackTrace: s,
          );
        }
      }
    }
  }

  Future<void> _performLightRefresh() async {
    try {
      final futures = <Future<void>>[];

      if (await _apiService.hasValidTokens()) {
        futures.add(_fetchCurrentUser());
      }

      futures.add(
        _performUpdateCheckAndShowDialog().catchError((e) {
          debugPrint('Update check failed during light refresh: $e');
        }),
      );

      if (futures.isNotEmpty) {
        await Future.wait(futures, eagerError: false);
      }

      debugPrint('Light refresh completed successfully');
    } catch (e) {
      debugPrint('Error during light refresh: $e');
    }
  }

  void _navigateToLoginPage() {
    closeSidebar();
    if (_activeNonTabRoute != "Login") {
      setState(() {
        _activeNonTabRoute = "Login";
      });
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LoginPage(
              onLoginSuccess: () async {
                if (!mounted) return;
                if (Navigator.canPop(context)) Navigator.pop(context);
                await _initializeAuth();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text("You are now logged in."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              onNavigateToRegister: _navigateToRegistrationPage,
            ),
      ),
    ).then((_) {
      if (mounted && _activeNonTabRoute == "Login") {
        setState(() {
          _activeNonTabRoute = _getRouteNameForSidebar(fromPop: true);
        });
      }
    });
  }

  void _navigateToRegistrationPage() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RegistrationPage(
              onRegistrationSuccess: () async {
                if (!mounted) return;
                if (Navigator.canPop(context)) Navigator.pop(context);
                await _initializeAuth();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Registration successful! You are now logged in.",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              onNavigateToLogin: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
      ),
    );
  }

  void _navigateToProfilePage() {
    closeSidebar();
    if (_activeNonTabRoute != "Profile") {
      setState(() {
        _activeNonTabRoute = "Profile";
      });
    }
    if (mounted && _currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProfilePage(
                currentUser: _currentUser,
                onLogout: () {
                  _handleLogout(showSnackbar: true);
                },
                onProfileUpdate: () async {
                  await _fetchCurrentUser();
                },
              ),
        ),
      ).then((_) {
        if (mounted && _activeNonTabRoute == "Profile") {
          setState(() {
            _activeNonTabRoute = _getRouteNameForSidebar(fromPop: true);
          });
        }
      });
    } else if (!_isLoggedIn) {
      _navigateToLoginPage();
    }
  }

  void _navigateToChangelog() {
    closeSidebar();
    if (_activeNonTabRoute != "Changelog") {
      setState(() {
        _activeNonTabRoute = "Changelog";
      });
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AnnouncementsChangelogPage(),
        ),
      ).then((_) {
        if (mounted && _activeNonTabRoute == "Changelog") {
          setState(() {
            _activeNonTabRoute = _getRouteNameForSidebar(fromPop: true);
          });
        }
      });
    }
  }

  void _navigateToRecents() {
    closeSidebar();
    if (_activeNonTabRoute != "Recents") {
      setState(() {
        _activeNonTabRoute = "Recents";
      });
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecentsPage()),
    ).then((_) {
      if (mounted && _activeNonTabRoute == "Recents") {
        setState(() {
          _activeNonTabRoute = _getRouteNameForSidebar(fromPop: true);
        });
      }
    });
  }

  void _startCacheCleanup() {
    //clean up cache every 5 minutes
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performCacheCleanup(),
    );

    if (kDebugMode) {
      debugPrint('AppScaffold: Cache cleanup timer started');
    }
  }

  Future<void> _performCacheCleanup() async {
    try {
      await ArtworkCacheService.instance.performPeriodicCleanup();

      //log stats in debug mode
      if (kDebugMode) {
        final stats = ArtworkCacheService.instance.getCacheStats();
        debugPrint('=== Artwork Cache Stats ===');
        debugPrint(
          'Cache size: ${stats['cache_size']}/${stats['max_cache_size']}',
        );
        debugPrint(
          'Memory usage: ${stats['memory_usage_mb']}MB / ${stats['max_memory_mb']}MB',
        );
        debugPrint('==========================');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during cache cleanup: $e');
      }
    }
  }

  Future<void> _performUpdateCheckAndShowDialog() async {
    await SharedPreferences.getInstance();
    bool autoUpdatesActuallyEnabled =
        await LibrarySettingsService.instance.getAutoUpdateEnabled();

    if (!autoUpdatesActuallyEnabled) {
      return;
    }

    if (_isCheckingForUpdate || _isUpdateDialogShowing || !mounted) return;

    setState(() => _isCheckingForUpdate = true);
    try {
      bool updateAvailable = await _updateService.isUpdateAvailable();
      if (mounted && updateAvailable) {
        UpdateInfo? updateInfo = await _updateService.getLatestReleaseInfo();
        if (mounted && updateInfo != null) {
          _showUpdateDialog(updateInfo);
        }
      }
    } catch (e, s) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: "Failed to check for updates.",
          error: e,
          stackTrace: s,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdate = false);
      }
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    if (!mounted || _isUpdateDialogShowing) return;

    _isUpdateDialogShowing = true;

    final channel = updateInfo.channel.toUpperCase();
    final channelColor = switch (updateInfo.channel.toLowerCase()) {
      'nightly' => AppTheme.warning,
      'beta' => AppTheme.info,
      _ => AppTheme.success,
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.brandPink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppTheme.brandPink,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Update Available",
                    style: AppStyles.sonoPlayerTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Version ${updateInfo.latestVersion}",
                        style: AppStyles.sonoButtonTextSmaller.copyWith(
                          color: AppTheme.textSecondaryDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: channelColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          channel,
                          style: TextStyle(
                            color: channelColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (updateInfo.releaseNotes != null &&
                      updateInfo.releaseNotes!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.elevatedSurfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.article_rounded,
                                color: AppTheme.textTertiaryDark,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "What's New",
                                style: TextStyle(
                                  color: AppTheme.textTertiaryDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            updateInfo.releaseNotes!,
                            style: AppStyles.sonoButtonTextSmaller.copyWith(
                              color: AppTheme.textSecondaryDark,
                              height: 1.5,
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 4),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          child: Text(
                            "Later",
                            style: AppStyles.sonoButtonTextSmaller.copyWith(
                              color: AppTheme.textSecondaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _startUpdateDownload(updateInfo);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Update Now",
                                style: AppStyles.sonoButtonTextSmaller.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        _isUpdateDialogShowing = false;
      }
    });
  }

  Future<void> _startUpdateDownload(UpdateInfo updateInfo) async {
    final hasPermission = await _updateService.isInstallPermissionGranted();
    if (!hasPermission) {
      if (!mounted) return;

      final shouldRequest = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.security_rounded, color: AppTheme.brandPink),
                  const SizedBox(width: 12),
                  Text(
                    'Permission Required',
                    style: AppStyles.sonoListItemTitle.copyWith(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                'To install updates, Sono needs permission to install apps from unknown sources.\n\nThis is a one-time setup required by Android.',
                style: AppStyles.sonoListItemSubtitle.copyWith(
                  color: AppTheme.textSecondaryDark,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondaryDark),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
      );

      if (shouldRequest != true || !mounted) return;

      final granted = await _updateService.requestInstallPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission denied. Cannot install updates.'),
            backgroundColor: Colors.redAccent.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Starting download...');
    bool isCompleted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, status, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.system_update_rounded,
                      color: AppTheme.brandPink,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      status,
                      style: AppStyles.sonoListItemTitle.copyWith(
                        color: AppTheme.textPrimaryDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, _) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress > 0 ? progress : null,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.brandPink,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            if (progress > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: AppStyles.sonoListItemSubtitle.copyWith(
                                  color: AppTheme.textSecondaryDark,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    _updateService.downloadAndInstallUpdate(
      updateInfo,
      (progress) {
        progressNotifier.value = progress;
        if (progress < 1.0) {
          statusNotifier.value = 'Downloading update...';
        } else {
          statusNotifier.value = 'Installing...';
        }
      },
      (errorMessage) {
        if (!isCompleted && mounted) {
          isCompleted = true;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: Colors.redAccent.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      },
      () {
        if (!isCompleted && mounted) {
          isCompleted = true;
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _startPeriodicChecks() {
    _periodicUpdateCheckTimer?.cancel();
    _periodicUpdateCheckTimer = Timer.periodic(const Duration(hours: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lastLifecycleState == AppLifecycleState.resumed) {
        _performUpdateCheckAndShowDialog();
      }
    });
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index && _activeNonTabRoute == null) return;

    //lazy-load screens on first access
    _ensureScreenInitialized(index);

    setState(() {
      _currentIndex = index;
      _activeNonTabRoute = null;
    });

    _pageController.jumpToPage(index);
  }

  /// Ensures a screen is initialized before accessing it (lazy loading)
  void _ensureScreenInitialized(int index) {
    //check if screen is still a placeholder
    if (_screens[index] is SizedBox) {
      setState(() {
        _screens[index] = _createScreen(index);
      });
    }
  }

  /// Creates a screen widget based on index
  Widget _createScreen(int index) {
    switch (index) {
      case 0:
        return HomePage(
          key: ValueKey('HomePage_${_isLoggedIn}_${_currentUser?['username']}'),
          onSearchTap: _switchToSearchTab,
          onMenuTap: _openSidebar,
          onSettingsTap: () => _onItemTapped(3),
          onCreatePlaylist: _showCreatePlaylistSheet,
          hasPermission: _hasPermission,
          onRequestPermission: _checkCurrentPermissionStatus,
          currentUser: _currentUser,
          isLoggedIn: _isLoggedIn,
        );
      case 1:
        return SearchPage(
          key: ValueKey(
            'SearchPage_${_isLoggedIn}_${_currentUser?['username']}',
          ),
          onMenuTap: _openSidebar,
          hasPermission: _hasPermission,
          onRequestPermission: _checkCurrentPermissionStatus,
          currentUser: _currentUser,
          isLoggedIn: _isLoggedIn,
        );
      case 2:
        return LibraryPage(
          key: ValueKey(
            'LibraryPage_${_isLoggedIn}_${_currentUser?['username']}',
          ),
          onMenuTap: _openSidebar,
          hasPermission: _hasPermission,
          onRequestPermission: _checkCurrentPermissionStatus,
          currentUser: _currentUser,
          isLoggedIn: _isLoggedIn,
        );
      case 3:
        return SettingsPage(
          key: ValueKey(
            'SettingsPage_${_isLoggedIn}_${_currentUser?['username']}',
          ),
          onMenuTap: _openSidebar,
          currentUser: _currentUser,
          isLoggedIn: _isLoggedIn,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _switchToSearchTab() {
    _onItemTapped(1);
  }

  void _openSidebar() {
    toggleSidebar();
  }

  void _navigateToTabAndCloseSidebar(int tabIndex) {
    _onItemTapped(tabIndex);
    if (isSidebarOpen) {
      closeSidebar();
    }
  }

  Future<void> _showCreatePlaylistSheet() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final playlistService = PlaylistService();

    return showSonoBottomSheet<void>(
      context: context,
      title: 'Create Playlist',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimaryDark),
            decoration: const InputDecoration(
              hintText: "Playlist Name",
              hintStyle: TextStyle(color: AppTheme.textTertiaryDark),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondaryDark),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(
            'Create',
            style: TextStyle(color: Theme.of(context).primaryColor),
          ),
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              try {
                await playlistService.createPlaylist(
                  name: nameController.text.trim(),
                );
                if (!mounted) return;

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist created'),
                    backgroundColor: AppTheme.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating playlist: $e'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  String? _getRouteNameForSidebar({bool fromPop = false}) {
    if (fromPop) {
      if (_currentIndex == 3) return "Settings";
      return null;
    }

    if (_activeNonTabRoute != null) {
      return _activeNonTabRoute;
    }

    if (_currentIndex == 3) {
      return "Settings";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveBreakpoints.isCompact(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return PageStorage(
      bucket: _pageStorageBucket,
      child: Container(
        color: const Color(0xFF121212),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body:
                isCompact
                    ? _buildCompactLayout()
                    : isDesktop
                    ? _buildDesktopLayout()
                    : _buildTabletLayout(),
            extendBody: isCompact,
            backgroundColor: Colors.transparent,
            bottomNavigationBar: isCompact ? _buildBottomNavBar() : null,
          ),
        ),
      ),
    );
  }

  /// Compact layout: slide-out sidebar + bottom nav
  Widget _buildCompactLayout() {
    return buildWithSidebar(
      customSidebarWidth:
          MediaQuery.of(context).size.width * 0.8 < 320
              ? MediaQuery.of(context).size.width * 0.8
              : 320.0,
      sidebar: _buildOverlaySidebar(),
      child: _buildPageContent(bottomPadding: 70),
    );
  }

  /// Tablet layout: NavigationRail on the left + page content
  Widget _buildTabletLayout() {
    return Row(
      children: [
        _buildNavigationRail(),
        Expanded(child: _buildPageContent(bottomPadding: 0)),
      ],
    );
  }

  /// Desktop layout: permanent expanded sidebar + page content
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 256,
          child: Sidebar(
            userName: _sidebarUserName,
            appVersion: _displayAppVersion,
            currentRoute: _getRouteNameForSidebar(),
            profilePictureUrl: _profilePictureUrl,
            showNavItems: true,
            currentTabIndex: _currentIndex,
            onNavItemTap: _onItemTapped,
            onProfileTap: () {
              if (_isLoggedIn) {
                _navigateToProfilePage();
              } else {
                _navigateToLoginPage();
              }
            },
            onWhatsNewTap: _navigateToChangelog,
            onSettingsTap: () => _onItemTapped(3),
            onRecentsTap: _navigateToRecents,
            onLogoutTap: () {
              if (_isLoggedIn) {
                _handleLogout();
              } else {
                _navigateToLoginPage();
              }
            },
          ),
        ),
        Expanded(child: _buildPageContent(bottomPadding: 0)),
      ],
    );
  }

  /// The overlay sidebar used on compact screens
  Sidebar _buildOverlaySidebar() {
    return Sidebar(
      userName: _sidebarUserName,
      appVersion: _displayAppVersion,
      currentRoute: _getRouteNameForSidebar(),
      profilePictureUrl: _profilePictureUrl,
      onProfileTap: () {
        if (_isLoggedIn) {
          _navigateToProfilePage();
        } else {
          _navigateToLoginPage();
        }
      },
      onWhatsNewTap: _navigateToChangelog,
      onSettingsTap: () {
        _navigateToTabAndCloseSidebar(3);
      },
      onRecentsTap: _navigateToRecents,
      onLogoutTap: () {
        if (_isLoggedIn) {
          _handleLogout();
        } else {
          _navigateToLoginPage();
        }
      },
    );
  }

  /// NavigationRail for tablet-sized screens
  Widget _buildNavigationRail() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: NavigationRail(
          backgroundColor: Colors.transparent,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onItemTapped,
          labelType: NavigationRailLabelType.selected,
          indicatorColor: AppTheme.brandPink.withAlpha(30),
          selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
          unselectedIconTheme: IconThemeData(
            color: Colors.white.withAlpha(153),
            size: 24,
          ),
          selectedLabelTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: Colors.white.withAlpha(153),
            fontSize: 11,
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: Text('Search'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: Text('Library'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  /// Page content stack (shared across all layouts)
  Widget _buildPageContent({required double bottomPadding}) {
    if (_isLoadingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4893)),
      );
    }

    return Stack(
      children: [
        PageView(
          key: const PageStorageKey('page_view_key'),
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              _activeNonTabRoute = null;
            });
          },
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
        ),
        Positioned(
          bottom: bottomPadding,
          left: 0,
          right: 0,
          child: const SonoBottomPlayer(),
        ),
        const ArtistFetchProgressButton(),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF121212).withAlpha(0),
            const Color(0xFF121212).withAlpha(204),
            const Color(0xFF121212),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            itemIndex: 0,
          ),
          _buildNavItem(
            icon: Icons.search_outlined,
            activeIcon: Icons.search_rounded,
            label: 'Search',
            itemIndex: 1,
          ),
          _buildNavItem(
            icon: Icons.library_music_outlined,
            activeIcon: Icons.library_music_rounded,
            label: 'Library',
            itemIndex: 2,
          ),
          _buildNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
            itemIndex: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int itemIndex,
  }) {
    bool isActive = _currentIndex == itemIndex && _activeNonTabRoute == null;
    bool isPressed = _pressedIndex == itemIndex;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressedIndex = itemIndex;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressedIndex = null;
        });
        _onItemTapped(itemIndex);
      },
      onTapCancel: () {
        setState(() {
          _pressedIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isPressed ? Colors.white.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color:
                    isActive
                        ? const Color.fromARGB(255, 255, 255, 255)
                        : Colors.white.withAlpha(153),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    isActive
                        ? const Color.fromARGB(255, 255, 255, 255)
                        : Colors.white.withAlpha(153),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    //cancel stream subscriptions to prevent memory leaks
    _authStateSubscription?.cancel();
    _notificationSubscription?.cancel();
    _pageController.dispose();
    _periodicUpdateCheckTimer?.cancel();
    _cacheCleanupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
