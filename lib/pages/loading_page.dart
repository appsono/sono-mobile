import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:sono/app_scaffold.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/artists/artist_image_fetch_service.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/services/settings/developer_settings_service.dart';
import 'package:sono/services/utils/crashlytics_service.dart';
import 'package:sono/pages/setup/setup_flow_page.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String _loadingMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    //check if setup has been completed
    final setupCompleted =
        await DeveloperSettingsService.instance.getSetupCompleted();

    if (!setupCompleted && mounted) {
      //show setup flow for first-time users
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => SetupFlowPage(
                onSetupComplete: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoadingPage(),
                    ),
                  );
                },
              ),
        ),
      );
      return;
    }

    await _checkAndRequestPermissions();
    await _initializeAudioService();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AppScaffold()),
      );
    }

    //restore playback state in background after UI navigation
    //this prevents blocking the main thread during startup
    _restorePlaybackState();

    //fetch artist images in background (non-blocking)
    _fetchArtistImagesInBackground();
  }

  Future<void> _checkAndRequestPermissions() async {
    if (!mounted) return;
    setState(() => _loadingMessage = "Checking permissions...");

    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.audio.request();
        } else {
          status = await Permission.storage.request();
        }
      } else {
        status = PermissionStatus.granted;
      }

      if (mounted && !status.isGranted) {
        debugPrint("Storage/Audio permission denied.");
      }
    } catch (e, s) {
      debugPrint("Error checking permissions: $e");
      CrashlyticsService.instance.recordError(
        e,
        s,
        reason: "Permission check failed",
      );
    }
  }

  Future<void> _initializeAudioService() async {
    if (!mounted) return;
    setState(() => _loadingMessage = "Starting audio service...");

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        await AudioService.init(
          builder: () {
            final handler = SonoPlayer();
            handler.initialize();
            return handler;
          },
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'wtf.sono.beta.channel',
            androidNotificationChannelName: 'Sono Player',
            androidNotificationOngoing: false,
            androidStopForegroundOnPause: false,
            androidNotificationChannelDescription:
                'Sono audio playback controls',
            androidShowNotificationBadge: true,
            androidNotificationClickStartsActivity: true,
            androidResumeOnClick: true,
            androidNotificationIcon: 'drawable/ic_notification',
          ),
        ).timeout(Duration(seconds: 15));

        return;
      } catch (e) {
        retryCount++;
        debugPrint('AudioService init attempt $retryCount failed: $e');

        if (retryCount < maxRetries) {
          setState(
            () =>
                _loadingMessage =
                    "Retrying audio service... ($retryCount/$maxRetries)",
          );
          await Future.delayed(Duration(milliseconds: 2000 * retryCount));
        } else if (mounted) {
          setState(
            () => _loadingMessage = "Audio service failed, continuing...",
          );
          await Future.delayed(Duration(milliseconds: 1000));
          break;
        }
      }
    }
  }

  Future<void> _restorePlaybackState() async {
    //this runs in the background after UI navigation
    //font check mounted or call setState => this is fire-and-forget
    try {
      final player = SonoPlayer();
      await player.restorePlaybackSnapshot();
      debugPrint('Playback state restored successfully');
    } catch (e) {
      debugPrint('Failed to restore playback state: $e');
      //non-critical error => app continues normally
    }
  }

  Future<void> _fetchArtistImagesInBackground() async {
    //this runs in background
    try {
      final progressService = ArtistFetchProgressService();
      final fetchService = ArtistImageFetchService(
        progressService: progressService,
      );

      //check if it needs to run the initial fetch
      if (!await fetchService.shouldRunInitialFetch()) {
        debugPrint('Artist images already fetched, skipping');
        return;
      }

      debugPrint('Starting background artist image fetch');

      await fetchService.fetchAllArtistImages(skipIfDone: true);
      await fetchService.markInitialFetchComplete();

      debugPrint('Background artist images fetch completed');
    } catch (e, s) {
      debugPrint('Error fetching artist images in background: $e');
      CrashlyticsService.instance.recordError(
        e,
        s,
        reason: "Background artist image fetch failed",
      );
      //non-critical error => app continues normally
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.brandPink),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              _loadingMessage,
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: AppTheme.font,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
