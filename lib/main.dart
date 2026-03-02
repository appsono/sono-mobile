import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sono/firebase_init.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono_extensions/sono_extensions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sono/data/repositories/favorites_repository.dart';
import 'package:sono/services/utils/theme_service.dart';
import 'package:sono/services/utils/env_config.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/servers/server_service.dart';
import 'package:sono/services/player/player.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/audio/visualizer_service.dart';
import 'pages/loading_page.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Extension SDK: library cache
//
// These lists are populated asynchronously at startup (Android/iOS only) and
// serve as a synchronous snapshot for extensions that call sono.library.*.
// Extensions receive an empty list during the brief window before the first
// scan completes.

List<ExtensionSong> _librarySongsCache = [];
List<ExtensionAlbum> _libraryAlbumsCache = [];
List<int> _libraryFavIdsCache = [];

/// Populates the extension library caches in the background.
///
/// Only runs on Android/iOS where [OnAudioQuery] is available.
void _warmLibraryCache() {
  final audioQuery = OnAudioQuery();

  AudioFilterUtils.getFilteredSongs(audioQuery).then((songs) {
    _librarySongsCache = songs
        .map(
          (s) => ExtensionSong(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            durationMs: s.duration,
            path: s.data,
          ),
        )
        .toList();
  }).catchError((_) {});

  audioQuery.queryAlbums().then((albums) {
    _libraryAlbumsCache = albums
        .map(
          (a) => ExtensionAlbum(
            id: a.id,
            album: a.album,
            artist: a.artist,
            numOfSongs: a.numOfSongs,
          ),
        )
        .toList();
  }).catchError((_) {});

  FavoritesRepository().getFavoriteSongIds().then((ids) {
    _libraryFavIdsCache = ids;
  }).catchError((_) {});
}

/// Wires [SonoPlayer] ValueNotifier listeners that fire extension hooks.
///
/// Called once after the [ExtensionRegistry] is created and before [runApp].
void _wirePlayerHooks(ExtensionRegistry registry) {
  SonoPlayer().currentSong.addListener(() {
    final s = SonoPlayer().currentSong.value;
    if (s == null) return;
    final track = ExtensionTrack(
      id: s.id,
      title: s.title,
      artist: s.artist,
      album: s.album,
      durationMs: s.duration,
      path: s.data,
    );
    registry.fireHook('onTrackChanged', [track.toMap()]);
  });

  SonoPlayer().isPlaying.addListener(() {
    registry.fireHook('onPlaybackStateChanged', [SonoPlayer().isPlaying.value]);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //initialize sqflite for desktop platforms (Linux, Windows, macOS)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('[Init] Initialized sqflite_common_ffi for desktop platform');
  }

  //initialize just_audio_media_kit for Linux (fixes MPV URI encoding issues)
  if (Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized();
    debugPrint('[Init] Initialized just_audio_media_kit for Linux');
  }

  //cap flutters imageCache to prevent RAM overflow
  //default is unbounded which can cause memory to balloon to 1GB+
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      100 * 1024 * 1024; //100MB max
  PaintingBinding.instance.imageCache.maximumSize = 100; //100 items max

  if (kDebugMode) {
    debugPrint('[Memory] Image cache limits set: 100MB / 100 items');
  }

  //run independent initializations
  debugPrint('[Init] Starting EnvConfig + Firebase initialization...');
  await Future.wait([
    EnvConfig.initialize(),
    initializeFirebase(),
    MusicServerService.instance.loadServers(),
  ]);
  debugPrint('[Init] Firebase initialization complete');

  //warm library cache in background (Android/iOS)
  if (Platform.isAndroid || Platform.isIOS) {
    _warmLibraryCache();
  }

  //start FFT visualizer service (Android only)
  final visualizerService = VisualizerService();
  await visualizerService.initialize();

  //create extension registry eagerly so we can wire player hooks
  //before runApp (listeners must be attached before first song plays)
  final extensionRegistry = ExtensionRegistry(
    sonoContext: SonoContext(
      //read-only player state
      getCurrentTrack: () {
        final s = SonoPlayer().currentSong.value;
        if (s == null) return null;
        return ExtensionTrack(
          id: s.id,
          title: s.title,
          artist: s.artist,
          album: s.album,
          durationMs: s.duration,
          path: s.data,
        );
      },
      getIsPlaying: () => SonoPlayer().isPlaying.value,
      getPositionMs: () => SonoPlayer().position.value.inMilliseconds,
      getDurationMs: () => SonoPlayer().duration.value.inMilliseconds,
      //player control
      play: () => SonoPlayer().play(),
      pause: () => SonoPlayer().pause(),
      seekTo: (ms) => SonoPlayer().seek(Duration(milliseconds: ms)),
      skipToNext: () => SonoPlayer().skipToNext(),
      skipToPrevious: () => SonoPlayer().skipToPrevious(),
      setSpeed: (s) => SonoPlayer().setSpeed(s),
      //library (synchronous cached snapshots)
      getSongs: () => _librarySongsCache,
      getAlbums: () => _libraryAlbumsCache,
      getFavoriteSongIds: () => _libraryFavIdsCache,
      //audio FFT
      getSpectrum: () => visualizerService.spectrum,
    ),
  );

  //wire player state => extension hooks.
  _wirePlayerHooks(extensionRegistry);

  debugPrint('[Init] Calling runApp...');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => PlaylistService()),
        ChangeNotifierProvider(create: (_) => FavoritesService()),
        ChangeNotifierProvider.value(value: ArtistFetchProgressService()),
        ChangeNotifierProvider.value(value: MusicServerService.instance),
        ChangeNotifierProvider.value(value: extensionRegistry),
      ],
      child: const Sono(),
    ),
  );
}

class Sono extends StatefulWidget {
  const Sono({super.key});

  @override
  State<Sono> createState() => _SonoState();
}

class _SonoState extends State<Sono> with WidgetsBindingObserver {
  late SonoPlayer _sonoPlayer;
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sonoPlayer = SonoPlayer();
    _loadBackgroundPlaybackSettings();
    _initDeepLinking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinking() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          _handleDeepLink(uri);
        },
        onError: (err) {
          if (kDebugMode) {
            debugPrint('Deep link error: $err');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize deep linking: $e');
      }
    }
  }

  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      debugPrint('Received deep link: $uri');
    }

    if (uri.scheme == 'sono' && (uri.host == 'sas' || uri.host == 'sas')) {
      _handleSASDeepLink(uri);
    }
  }

  Future<void> _handleSASDeepLink(Uri uri) async {
    final host = uri.queryParameters['host'];
    final portStr = uri.queryParameters['port'];

    if (host == null || portStr == null) {
      if (kDebugMode) {
        debugPrint('Invalid SAS link - missing host or port');
      }
      return;
    }

    try {
      final port = int.parse(portStr);

      await SASManager().joinSession(host, port);

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to SAS session at $host:$port'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (kDebugMode) {
        debugPrint('Auto-connected to SAS session via deep link');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to connect via deep link: $e');
      }

      //show error message
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        //save playback state when app goes to background
        //this ensures state is persisted if app is killed
        _sonoPlayer.savePlaybackSnapshot();
        break;
      case AppLifecycleState.resumed:
        _checkSASConnectionHealth();
        break;
      case AppLifecycleState.detached:
        //save one final time before app is detached
        _sonoPlayer.savePlaybackSnapshot();
        break;
      default:
        break;
    }

    _sonoPlayer.onAppLifecycleStateChanged(state);
  }

  Future<void> _checkSASConnectionHealth() async {
    final sasManager = SASManager();
    if (!sasManager.isConnected || sasManager.isHost) return;

    try {
      final sessionInfo = sasManager.sessionInfo;
      if (sessionInfo != null) {
        final pingUrl = 'http://${sessionInfo.host}:${sessionInfo.port}/ping';
        final response = await http
            .get(Uri.parse(pingUrl))
            .timeout(Duration(seconds: 3));

        if (response.statusCode != 200) {
          _showSASDisconnectedNotification();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Lifecycle] SAS health check failed: $e');
      }
      _showSASDisconnectedNotification();
    }
  }

  void _showSASDisconnectedNotification() {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SAS connection lost. Please reconnect.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadBackgroundPlaybackSettings() async {
    try {
      await _sonoPlayer.customAction('loadBackgroundPlaybackSettings');
      if (kDebugMode) {
        print('Background playback settings loaded');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading background playback settings: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final data = MediaQueryData.fromView(View.of(context));
        final shortestSide = data.size.shortestSide;
        final isTablet = shortestSide > 600;

        return ScreenUtilInit(
          designSize:
              isTablet
                  ? const Size(768, 1024) //tablet design size
                  : const Size(414, 896), //phone design size
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp(
              scrollBehavior: _SonoScrollBehavior(),
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              themeMode: themeService.themeMode,
              theme: _buildThemeData(
                themeService.accentColor,
                Brightness.light,
              ),
              darkTheme: _buildThemeData(
                themeService.accentColor,
                Brightness.dark,
              ),
              home: const LoadingPage(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildThemeData(MaterialColor primaryColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = AppTheme.background(brightness);
    final onBackground = AppTheme.textPrimary(brightness);
    final surface = AppTheme.surface(brightness);

    return ThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      fontFamily: AppTheme.fontFamily,
      canvasColor: background,
      cardColor: AppTheme.card(brightness),
      dividerColor: AppTheme.border(brightness),
      colorScheme:
          isDark
              ? ColorScheme.dark(
                primary: primaryColor,
                secondary: primaryColor,
                surface: surface,
                onSurface: onBackground,
              )
              : ColorScheme.light(
                primary: primaryColor,
                secondary: primaryColor,
                surface: surface,
                onSurface: onBackground,
              ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onBackground,
          fontSize: AppTheme.fontSubtitle,
          fontWeight: FontWeight.w600,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      iconTheme: const IconThemeData(fill: 1, weight: 600, opticalSize: 48),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: onBackground),
        bodyMedium: TextStyle(color: onBackground),
        titleLarge: TextStyle(color: onBackground),
      ),
    );
  }
}

class _SonoScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final glowColor = Theme.of(context).colorScheme.surface;
    return GlowingOverscrollIndicator(
      color: glowColor,
      axisDirection: details.direction,
      child: child,
    );
  }
}
