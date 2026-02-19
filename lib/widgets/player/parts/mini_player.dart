import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/player/parts/fullscreen_player.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/sas/sas_modal.dart';

class SonoBottomPlayer extends StatefulWidget {
  const SonoBottomPlayer({super.key});

  @override
  State<SonoBottomPlayer> createState() => _SonoBottomPlayerState();
}

class _SonoBottomPlayerState extends State<SonoBottomPlayer>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _spinController;
  late AnimationController _songSwitchController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideInAnimation;

  SongModel? _previousSong;
  bool _isInitialized = false;

  //dismissal state
  bool _isDismissed = false;
  Timer? _dismissalTimer;
  bool _wasPlaying = false;
  SongModel? _dismissedSong;
  Duration _dismissedPosition = Duration.zero;
  List<SongModel> _dismissedPlaylist = [];
  int? _dismissedIndex;
  late AnimationController _dismissalSlideController;
  late Animation<Offset> _dismissalSlideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _dismissalSlideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _dismissalSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _dismissalSlideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _spinController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _songSwitchController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _songSwitchController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideInAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _songSwitchController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _previousSong = SonoPlayer().currentSong.value;

    SonoPlayer().isPlaying.addListener(_onPlayerStateChanged);
    SonoPlayer().currentSong.addListener(_onSongChanged);
    SonoPlayer().albumCoverRotationEnabled.addListener(_onPlayerStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isInitialized = true;
      _onPlayerStateChanged();
    });
  }

  void _onSongChanged() {
    final currentSong = SonoPlayer().currentSong.value;
    if (currentSong != null && mounted && _isInitialized) {
      if (_previousSong == null || _previousSong!.id != currentSong.id) {
        _animateSongSwitch();
      }
    }
    _previousSong = currentSong;
    _onPlayerStateChanged();
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;
    final isPlaying = SonoPlayer().isPlaying.value;
    final isRotationEnabled = SonoPlayer().albumCoverRotationEnabled.value;

    if (isPlaying && isRotationEnabled) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else {
      if (_spinController.isAnimating) {
        _spinController.stop();
      }
    }
  }

  void _animateSongSwitch() {
    if (!_isInitialized) return;
    _songSwitchController.reset();
    _songSwitchController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _dismissalSlideController.dispose();
    _spinController.dispose();
    _songSwitchController.dispose();
    _dismissalTimer?.cancel();

    SonoPlayer().isPlaying.removeListener(_onPlayerStateChanged);
    SonoPlayer().currentSong.removeListener(_onSongChanged);
    SonoPlayer().albumCoverRotationEnabled.removeListener(
      _onPlayerStateChanged,
    );
    super.dispose();
  }

  void _openFullscreenPlayer() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const SonoFullscreenPlayer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  Future<void> _dismissPlayerWithUndo() async {
    final player = SonoPlayer();

    //save player state before stopping
    _wasPlaying = player.isPlaying.value;
    _dismissedSong = player.currentSong.value;
    _dismissedPosition = player.position.value;
    _dismissedPlaylist = List<SongModel>.from(player.playlist);
    _dismissedIndex = player.currentIndex;

    //set dismissed state FIRST to switch UI before stop() triggers rebuilds
    _dismissalSlideController.reset();
    setState(() {
      _isDismissed = true;
    });

    //stop player
    await player.stop();
    if (!mounted) return;
    _dismissalSlideController.forward();

    //auto-dismiss after 4 seconds
    _dismissalTimer?.cancel();
    _dismissalTimer = Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;

      //clear playback state so it wont restore on app restart
      await SonoPlayer().clearPlaybackSnapshot();

      //slide out dismissal banner
      await _dismissalSlideController.reverse();

      if (mounted) {
        setState(() {
          _isDismissed = false;
        });
      }
    });
  }

  Future<void> _undoDismissal() async {
    _dismissalTimer?.cancel();

    //slide out dismissal banner
    await _dismissalSlideController.reverse();

    if (!mounted) return;

    setState(() {
      _isDismissed = false;
    });

    final player = SonoPlayer();

    //restore player state
    if (_dismissedSong != null && _dismissedPlaylist.isNotEmpty) {
      await player.playNewPlaylist(_dismissedPlaylist, _dismissedIndex ?? 0);
      await player.seek(_dismissedPosition);
      if (!_wasPlaying) {
        await player.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    //listen to lifecycle state to rebuild when entering/exiting SAS mode
    return ValueListenableBuilder<PlayerLifecycleState>(
      valueListenable: SonoPlayer().lifecycleStateListenable,
      builder: (context, lifecycleState, child) {
        //if player has a NEW song and dismissal is active => cancel dismissal
        //check song ID to avoid canceling during stop() when currentSong briefly exists
        final currentSong = SonoPlayer().currentSong.value;
        if (_isDismissed &&
            currentSong != null &&
            currentSong.id != _dismissedSong?.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              _dismissalTimer?.cancel();
              await _dismissalSlideController.reverse();
              if (mounted) {
                setState(() {
                  _isDismissed = false;
                });
              }
            }
          });
        }

        //show dismissal UI if dismissed
        if (_isDismissed) {
          return _buildDismissalUI(screenWidth, isLargeScreen);
        }

        //check if connected as a SAS client
        final sasManager = SASManager();
        final isClient = sasManager.isConnected;

        return isClient
            ? _buildClientPlayer(screenWidth, isLargeScreen)
            : _buildLocalPlayer(screenWidth, isLargeScreen);
      },
    );
  }

  Widget _buildDismissalUI(double screenWidth, bool isLargeScreen) {
    final isDesktop = screenWidth > 900;
    return SlideTransition(
      position: _dismissalSlideAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 900.0 : 600.0),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandPink.withAlpha(128),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.brandPink,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Player dismissed',
                      style: TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _undoDismissal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'UNDO',
                          style: TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientPlayer(double screenWidth, bool isLargeScreen) {
    //show metadata from SAS host
    return ValueListenableBuilder<String?>(
      valueListenable: SASManager().clientSongTitle,
      builder: (context, title, child) {
        if (title == null) {
          if (!_isDismissed) {
            _slideController.reverse();
            _spinController.stop();
          }
          return const SizedBox.shrink();
        }

        if (!_isDismissed) _slideController.forward();
        final isDesktop = screenWidth > 900;
        final playerHeight = isDesktop
            ? 80.0
            : AppTheme.responsiveDimension(context, AppTheme.miniPlayerHeight);
        return SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            onTap: _openFullscreenPlayer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 900.0 : 600.0,
                  ),
                  child: SizedBox(
                    height: playerHeight,
                    child: _buildClientContent(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalPlayer(double screenWidth, bool isLargeScreen) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, child) {
        return ValueListenableBuilder<String?>(
          valueListenable: SonoPlayer().playerErrorMessage,
          builder: (context, errorMessage, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: SonoPlayer().isInitializing,
              builder: (context, isInitializing, _) {
                //show error state
                if (errorMessage != null && errorMessage.isNotEmpty) {
                  if (!_isDismissed) _slideController.forward();
                  return _buildErrorState(
                    screenWidth,
                    isLargeScreen,
                    errorMessage,
                  );
                }

                //show initializing state
                // if (isInitializing) {
                //   _slideController.forward();
                //   return _buildInitializingState(screenWidth, isLargeScreen);
                // }

                //hide if no song
                if (currentSong == null) {
                  if (!_isDismissed) {
                    _slideController.reverse();
                    _spinController.stop();
                  }
                  return const SizedBox.shrink();
                }

                //normal player state
                if (!_isDismissed) _slideController.forward();
                final isDesktop = screenWidth > 900;
                final playerHeight = isDesktop
                    ? 80.0
                    : AppTheme.responsiveDimension(
                        context,
                        AppTheme.miniPlayerHeight,
                      );
                return SlideTransition(
                  position: _slideAnimation,
                  child: GestureDetector(
                    onTap: _openFullscreenPlayer,
                    onHorizontalDragEnd: (details) {
                      if (SASManager().isInClientMode) return;

                      if (details.primaryVelocity == 0) return;

                      HapticFeedback.lightImpact();
                      if (details.primaryVelocity! < 0) {
                        SonoPlayer().skipToNext();
                      } else {
                        SonoPlayer().skipToPrevious();
                      }
                    },
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;

                      //swipe up (negative velocity) => open fullscreen
                      if (details.primaryVelocity! < -300) {
                        _openFullscreenPlayer();
                      }
                      //swipe down (positive velocity) => dismiss player with undo option
                      else if (details.primaryVelocity! > 300) {
                        HapticFeedback.lightImpact();
                        _dismissPlayerWithUndo();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 900.0 : 600.0,
                          ),
                          child: SizedBox(
                            height: playerHeight,
                            child: _MiniPlayerContent(
                              currentSong: currentSong,
                              songSwitchController: _songSwitchController,
                              slideInAnimation: _slideInAnimation,
                              fadeAnimation: _fadeAnimation,
                              buildArtwork: () => _buildArtwork(currentSong),
                              buildControls: _buildControls,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(
    double screenWidth,
    bool isLargeScreen,
    String errorMessage,
  ) {
    final isDesktop = screenWidth > 900;
    final playerHeight = isDesktop
        ? 80.0
        : AppTheme.responsiveDimension(context, AppTheme.miniPlayerHeight);
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 900.0 : 600.0),
            child: Container(
              height: playerHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: AppStyles.sonoPlayerTitle.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      onPressed: () {
                        //clear error message
                        SonoPlayer().playerErrorMessage.value = null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildInitializingState(double screenWidth, bool isLargeScreen) {
  //   return SlideTransition(
  //     position: _slideAnimation,
  //     child: Container(
  //       height: AppTheme.responsiveDimension(
  //         context,
  //         AppTheme.miniPlayerHeight,
  //       ),
  //       margin: EdgeInsets.fromLTRB(
  //         isLargeScreen ? (screenWidth - 600) / 2 + 12 : 12,
  //         0,
  //         isLargeScreen ? (screenWidth - 600) / 2 + 12 : 12,
  //         12,
  //       ),
  //       decoration: BoxDecoration(
  //         color: Theme.of(context).colorScheme.surfaceContainerHighest,
  //         borderRadius: BorderRadius.circular(12),
  //       ),
  //       child: Center(
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             SizedBox(
  //               width: 16,
  //               height: 16,
  //               child: CircularProgressIndicator(
  //                 strokeWidth: 2,
  //                 color: Theme.of(context).colorScheme.primary,
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //
  //             Text(
  //              'Loading...',
  //              style: AppStyles.sonoPlayerTitle.copyWith(
  //                color: Theme.of(context).colorScheme.onSurface,
  //              ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildClientContent() {
    return ValueListenableBuilder<Duration>(
      valueListenable: SonoPlayer().position,
      builder: (context, position, child) {
        return ValueListenableBuilder<Duration>(
          valueListenable: SonoPlayer().duration,
          builder: (context, duration, child) {
            final progress =
                (duration.inMilliseconds > 0)
                    ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                    : 0.0;

            return ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppTheme.miniPlayerProgressFill,
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.surfaceDark,
                          AppTheme.elevatedSurfaceDark,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Container(
                        margin: const EdgeInsets.all(2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: AppTheme.miniPlayerProgress,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(
                      AppTheme.responsiveSpacing(context, AppTheme.spacingXs),
                    ),
                    child: Row(
                      children: [
                        _buildClientArtwork(),
                        SizedBox(
                          width: AppTheme.responsiveSpacing(
                            context,
                            AppTheme.spacingSm + 2,
                          ),
                        ),
                        Expanded(child: _buildClientMetadata()),
                        Transform.translate(
                          offset: const Offset(-2, 0),
                          child: _buildControls(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClientArtwork() {
    return ValueListenableBuilder<String?>(
      valueListenable: SASManager().clientArtworkUrl,
      builder: (context, artworkUrl, child) {
        return ClipOval(
          child: Container(
            width: AppTheme.responsiveArtworkSize(context, AppTheme.artworkSm),
            height: AppTheme.responsiveArtworkSize(context, AppTheme.artworkSm),
            decoration: BoxDecoration(color: AppTheme.elevatedSurfaceDark),
            child:
                artworkUrl != null
                    ? Image.network(
                      artworkUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            strokeWidth: 2,
                            color: AppTheme.brandPink,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.music_note_rounded,
                          size: AppTheme.responsiveIconSize(
                            context,
                            AppTheme.icon,
                            min: 20.0,
                          ),
                          color: AppTheme.brandPink,
                        );
                      },
                    )
                    : Icon(
                      Icons.music_note_rounded,
                      size: AppTheme.responsiveIconSize(
                        context,
                        AppTheme.icon,
                        min: 20,
                      ),
                      color: AppTheme.brandPink,
                    ),
          ),
        );
      },
    );
  }

  Widget _buildClientMetadata() {
    return ValueListenableBuilder<String?>(
      valueListenable: SASManager().clientSongTitle,
      builder: (context, title, child) {
        return ValueListenableBuilder<String?>(
          valueListenable: SASManager().clientSongArtist,
          builder: (context, artist, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title ?? 'Unknown Title',
                  style: AppStyles.sonoPlayerTitle.copyWith(
                    fontSize: AppTheme.responsiveFontSize(context, 15.0, min: 13.0),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ArtistStringUtils.getShortDisplay(artist ?? 'Unknown Artist'),
                  style: AppStyles.sonoPlayerArtist.copyWith(
                    fontSize: AppTheme.responsiveFontSize(
                      context,
                      AppTheme.fontCaption,
                      min: 9,
                    ),
                    color: AppTheme.textSecondaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildArtwork(SongModel currentSong) {
    return ValueListenableBuilder<bool>(
      valueListenable: SonoPlayer().albumCoverRotationEnabled,
      builder: (context, isRotationEnabled, child) {
        return AnimatedBuilder(
          animation: _songSwitchController,
          builder: (context, child) {
            return Transform.scale(
              scale:
                  _songSwitchController.isAnimating
                      ? (_songSwitchController.value < 0.5
                          ? 1.0 - (_songSwitchController.value * 0.2)
                          : 0.8 + ((_songSwitchController.value - 0.5) * 0.4))
                      : 1.0,
              child: RotationTransition(
                turns:
                    isRotationEnabled && SonoPlayer().isPlaying.value
                        ? _spinController
                        : const AlwaysStoppedAnimation(0),
                child: ClipOval(
                  child: SizedBox(
                    width: AppTheme.responsiveArtworkSize(
                      context,
                      AppTheme.artworkSm,
                    ),
                    height: AppTheme.responsiveArtworkSize(
                      context,
                      AppTheme.artworkSm,
                    ),
                    child: currentSong.isRemote && currentSong.remoteArtworkUrl != null
                        ? Image.network(
                            currentSong.remoteArtworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppTheme.elevatedSurfaceDark,
                              child: Icon(
                                Icons.music_note_rounded,
                                color: AppTheme.textPrimaryDark,
                                size: AppTheme.responsiveIconSize(
                                  context, AppTheme.icon, min: 20.0,
                                ),
                              ),
                            ),
                          )
                        : QueryArtworkWidget(
                            id: currentSong.id,
                            type: ArtworkType.AUDIO,
                            size: 150,
                            quality: 100,
                            keepOldArtwork: true,
                            artworkBorder: BorderRadius.circular(AppTheme.radiusXl),
                            nullArtworkWidget: Container(
                              color: AppTheme.elevatedSurfaceDark,
                              child: Icon(
                                Icons.music_note_rounded,
                                color: AppTheme.textPrimaryDark,
                                size: AppTheme.responsiveIconSize(
                                  context,
                                  AppTheme.icon,
                                  min: 20.0,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSASSessionButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier(
        SASManager().isHost || SASManager().isConnected,
      ),
      builder: (context, isActive, child) {
        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            showSASAdaptiveModal(context);
          },
          customBorder: const CircleBorder(),
          splashColor: AppTheme.textPrimaryDark.opacity20,
          child: Container(
            padding: EdgeInsets.all(
              AppTheme.responsiveSpacing(context, AppTheme.spacingXs + 2),
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive ? AppTheme.brandPink.opacity20 : Colors.transparent,
            ),
            child: Icon(
              isActive ? Icons.group : Icons.group_rounded,
              color: isActive ? AppTheme.brandPink : AppTheme.textPrimaryDark,
              size: AppTheme.responsiveIconSize(
                context,
                AppTheme.icon,
                min: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return ValueListenableBuilder<bool>(
      valueListenable: SonoPlayer().isPlaying,
      builder: (context, isPlaying, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.responsiveSpacing(context, 3.5),
            vertical: AppTheme.responsiveSpacing(context, 3.5),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.elevatedSurfaceDark,
                AppTheme.elevatedSurfaceDark,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.borderDark, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSASSessionButton(),
              SizedBox(
                width: AppTheme.responsiveSpacing(context, AppTheme.spacingXs),
              ),
              _buildPlayPauseButton(isPlaying),
              SizedBox(
                width: AppTheme.responsiveSpacing(context, AppTheme.spacingXs),
              ),
              _buildSkipButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseButton(bool isPlaying) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        SonoPlayer().playPause();
      },
      customBorder: const CircleBorder(),
      splashColor: AppTheme.textPrimaryDark.opacity20,
      child: Container(
        padding: EdgeInsets.all(
          AppTheme.responsiveSpacing(context, AppTheme.spacingXs + 2),
        ),
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: AppTheme.textPrimaryDark,
          size: AppTheme.responsiveIconSize(context, 28.0, min: 24.0),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        SonoPlayer().skipToNext();
      },
      customBorder: const CircleBorder(),
      splashColor: AppTheme.textPrimaryDark.opacity20,
      child: Padding(
        padding: EdgeInsets.all(
          AppTheme.responsiveSpacing(context, AppTheme.spacingXs + 2),
        ),
        child: Icon(
          Icons.skip_next_rounded,
          color: AppTheme.textPrimaryDark,
          size: AppTheme.responsiveIconSize(context, 28.0, min: 24.0),
        ),
      ),
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final SongModel currentSong;
  final AnimationController songSwitchController;
  final Animation<Offset> slideInAnimation;
  final Animation<double> fadeAnimation;
  final Widget Function() buildArtwork;
  final Widget Function() buildControls;

  const _MiniPlayerContent({
    required this.currentSong,
    required this.songSwitchController,
    required this.slideInAnimation,
    required this.fadeAnimation,
    required this.buildArtwork,
    required this.buildControls,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: SonoPlayer().position,
      builder: (context, position, child) {
        return ValueListenableBuilder<Duration>(
          valueListenable: SonoPlayer().duration,
          builder: (context, duration, child) {
            final progress =
                (duration.inMilliseconds > 0)
                    ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                    : 0.0;

            return ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppTheme.miniPlayerProgressFill,
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.surfaceDark,
                          AppTheme.elevatedSurfaceDark,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Container(
                        margin: const EdgeInsets.all(2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: AppTheme.miniPlayerProgress,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: songSwitchController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: slideInAnimation.value * 50,
                        child: Opacity(
                          opacity:
                              songSwitchController.isAnimating
                                  ? (songSwitchController.value < 0.5
                                      ? fadeAnimation.value
                                      : 1.0 - fadeAnimation.value)
                                  : 1.0,
                          child: Padding(
                            padding: EdgeInsets.all(
                              MediaQuery.of(context).size.width > 900
                                  ? AppTheme.spacingXs
                                  : AppTheme.responsiveSpacing(
                                      context,
                                      AppTheme.spacingXs,
                                    ),
                            ),
                            child: Row(
                              children: [
                                buildArtwork(),
                                SizedBox(
                                  width: AppTheme.responsiveSpacing(
                                    context,
                                    AppTheme.spacingSm + 2,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        currentSong.title,
                                        style: AppStyles.sonoPlayerTitle
                                            .copyWith(
                                              fontSize:
                                                  AppTheme.responsiveFontSize(
                                                    context,
                                                    15.0,
                                                    min: 13.0,
                                                  ),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        ArtistStringUtils.getShortDisplay(
                                          currentSong.artist ??
                                              'Unknown Artist',
                                        ),
                                        style: AppStyles.sonoPlayerArtist
                                            .copyWith(
                                              fontSize:
                                                  AppTheme.responsiveFontSize(
                                                    context,
                                                    AppTheme.fontCaption,
                                                    min: 9,
                                                  ),
                                              color: AppTheme.textSecondaryDark,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(-2, 0),
                                  child: buildControls(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
