import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sono/services/utils/theme_service.dart';
import 'package:sono/services/utils/env_config.dart';
import 'package:sono/services/utils/crashlytics_service.dart';
import 'package:sono/services/utils/firebase_availability.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/styles/app_theme.dart';
import 'pages/loading_page.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Initialize Firebase and Crashlytics in a separate function
/// If Firebase fails (e.g. missing google-services / GoogleService-Info.plist),
/// the app will continue to run without Firebase features.
Future<void> _initializeFirebase() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    //mark firebase as available
    FirebaseAvailability.instance.markAvailable();

    //initialize crashlytics service (only meaningful when firebase is up)
    await CrashlyticsService.instance.initialize();

    //only set up error handlers if crashlytics is enabled
    if (CrashlyticsService.instance.isEnabled) {
      FlutterError.onError = (FlutterErrorDetails details) {
        if (FirebaseAvailability.instance.isAvailable) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (FirebaseAvailability.instance.isAvailable) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        return true;
      };
    }
  } catch (e) {
    if (e.toString().contains('already exists')) {
      //firebase was already initialized
      FirebaseAvailability.instance.markAvailable();
    } else {
      debugPrint('[Firebase] Init FAILED: $e');
      //do NOT rethrow, app works fine without firebase
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  await Future.wait([EnvConfig.initialize(), _initializeFirebase()]);
  debugPrint(
    '[Init] Firebase available: ${FirebaseAvailability.instance.isAvailable}',
  );

  debugPrint('[Init] Calling runApp...');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => PlaylistService()),
        ChangeNotifierProvider(create: (_) => FavoritesService()),
        ChangeNotifierProvider.value(value: ArtistFetchProgressService()),
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
        //his ensures state is persisted if app is killed
        _sonoPlayer.savePlaybackSnapshot();
        break;
      case AppLifecycleState.resumed:
        _sonoPlayer.onAppLifecycleStateChanged(state);
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
        return ScreenUtilInit(
          designSize: const Size(414, 896), //base design size
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
