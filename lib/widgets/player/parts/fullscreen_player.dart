// ignore_for_file: undefined_hidden_name

import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    hide RepeatMode; //required for build use in gitub workflow
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/services/api/musicbrainz_service.dart';
import 'package:sono/widgets/global/add_to_playlist_dialog.dart';
import 'package:sono/widgets/global/sleeptimer.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/api/lyrics_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/player/parts/queue_view.dart';
import 'package:sono/widgets/player/parts/lyrics_view.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:provider/provider.dart';
import 'package:sono/utils/artist_navigation.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class FavoriteIconButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback? onPressed;
  final double size;

  const FavoriteIconButton({
    super.key,
    required this.isLiked,
    this.onPressed,
    this.size = 28.0,
  });

  @override
  State<FavoriteIconButton> createState() => _FavoriteIconButtonState();
}

class _FavoriteIconButtonState extends State<FavoriteIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    _animationController.forward().then((_) {
      if (mounted) {
        _animationController.reverse();
      }
    });
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          widget.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color:
              widget.onPressed == null
                  ? AppTheme.textSecondaryDark.withValues(alpha: 0.3)
                  : (widget.isLiked
                      ? Theme.of(context).primaryColor
                      : AppTheme.textSecondaryDark),
        ),
        iconSize: widget.size,
        onPressed: widget.onPressed != null ? _handleTap : null,
        tooltip: widget.isLiked ? 'Unlike' : 'Like',
      ),
    );
  }
}

class SonoFullscreenPlayer extends StatefulWidget {
  const SonoFullscreenPlayer({super.key});

  @override
  State<SonoFullscreenPlayer> createState() => _SonoFullscreenPlayerState();
}

class _SonoFullscreenPlayerState extends State<SonoFullscreenPlayer>
    with SingleTickerProviderStateMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final SonoPlayer _sonoPlayer = SonoPlayer();
  bool _isCurrentSongFavorite = false;
  final Map<int, Future<Uint8List?>> _artworkFutures = {};
  static const int _maxCachedArtworks = 10;

  late PageController _pageController;
  late final ValueNotifier<double> _pageNotifier;
  bool _isControllerListenerAttached = false;

  Widget? _cachedBlurredBackground;
  int? _currentArtworkId;

  static final _CustomTrackShape _cachedTrackShape = _CustomTrackShape();
  late SliderThemeData _sliderTheme;

  bool _ignoreSwipe = false;
  bool _isUserSwiping = false; //track if actively swiping

  bool _isDraggingSeekBar = false;
  double? _draggedPosition;

  //track info animation controller
  late AnimationController _trackInfoSwitchController;
  late Animation<double> _trackInfoFadeAnimation;
  late Animation<Offset> _trackInfoSlideAnimation;

  //debounce for skip buttons
  DateTime? _lastSkipTime;
  static const Duration _skipDebounceMs = Duration(milliseconds: 300);

  void _onPageScroll() {
    if (_pageController.hasClients) {
      _pageNotifier.value = _pageController.page!;
    }
  }

  @override
  void initState() {
    super.initState();

    final initialPage = _sonoPlayer.currentIndex ?? 0;

    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.8,
    );

    _pageNotifier = ValueNotifier(initialPage.toDouble());

    //initialize track info animation controller
    _trackInfoSwitchController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
      value: 1.0,
    );

    _trackInfoFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _trackInfoSwitchController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _trackInfoSlideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _trackInfoSwitchController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _sonoPlayer.currentSong.addListener(_onSongChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.addListener(_onPageScroll);
        _isControllerListenerAttached = true;

        final currentPlayerIndex = _sonoPlayer.currentIndex ?? 0;
        if (_pageController.page?.round() != currentPlayerIndex) {
          _pageController.jumpToPage(currentPlayerIndex);
          _pageNotifier.value = currentPlayerIndex.toDouble();
        }
      }
    });

    _loadFavoriteStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: AppTheme.brandPink,
      inactiveTrackColor: AppTheme.textPrimaryDark.opacity20,
      thumbColor: AppTheme.brandPink,
      overlayColor: AppTheme.brandPink.opacity10,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 7,
        elevation: 2,
      ),
      trackHeight: 4.5,
      trackShape: _cachedTrackShape,
    );
  }

  @override
  void dispose() {
    if (_isControllerListenerAttached) {
      _pageController.removeListener(_onPageScroll);
    }
    _pageNotifier.dispose();
    _trackInfoSwitchController.dispose();
    _sonoPlayer.currentSong.removeListener(_onSongChanged);
    _pageController.dispose();
    _artworkFutures.clear();
    _cachedBlurredBackground = null;
    super.dispose();
  }

  void _onSongChanged() {
    if (!mounted) return;

    //trigger track info animation
    _trackInfoSwitchController.reset();
    _trackInfoSwitchController.forward();

    final currentSong = _sonoPlayer.currentSong.value;

    //smart cache: only clear blur if artwork ID actually changed
    if (currentSong != null && _currentArtworkId != currentSong.id) {
      _cachedBlurredBackground = null;
      _currentArtworkId = currentSong.id;
    }

    final playerIndex = _sonoPlayer.currentIndex ?? 0;

    //sync PageView to new song position
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? 0;

      if (currentPage != playerIndex) {
        //check if PageView is currently animating/being dragged
        if (_pageController.position.isScrollingNotifier.value) {
          // PageView is being swiped, wait for scroll to settle then sync
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(playerIndex);
              _pageNotifier.value = playerIndex.toDouble();
            }
          });
        } else {
          //not scrolling (skip button pressed) => animate the cover change
          _pageController.animateToPage(
            playerIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }

    _loadFavoriteStatus();

    //preload adjacent artworks for smooth transitions
    Future.microtask(() {
      final playlist = _sonoPlayer.playlist;
      final currentIdx = _sonoPlayer.currentIndex ?? 0;

      if (currentIdx + 1 < playlist.length) {
        _getOrCacheArtworkFuture(playlist[currentIdx + 1].id);
      }
      if (currentIdx > 0) {
        _getOrCacheArtworkFuture(playlist[currentIdx - 1].id);
      }
    });

    //force rebuild to show new blur immediately
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToArtistPage(SongModel song) {
    if (song.artist == null) return;
    //get the primary (first) artist from the songs artist string
    final primaryArtist = ArtistStringUtils.getPrimaryArtist(song.artist!);
    ArtistNavigation.navigateToArtistByName(
      context,
      primaryArtist,
      _audioQuery,
    );
  }

  Future<void> _loadFavoriteStatus() async {
    if (!mounted) return;
    final song = _sonoPlayer.currentSong.value;
    if (song == null) return;

    final favoritesService = context.read<FavoritesService>();
    final isFavorite = await favoritesService.isSongFavorite(song.id);
    if (mounted) {
      setState(() {
        _isCurrentSongFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (!mounted) return;
    final song = _sonoPlayer.currentSong.value;
    if (song == null) return;

    final bool newFavoriteState = !_isCurrentSongFavorite;
    setState(() {
      _isCurrentSongFavorite = newFavoriteState;
    });

    try {
      final favoritesService = context.read<FavoritesService>();
      if (newFavoriteState) {
        await favoritesService.addSongToFavorites(song.id);
      } else {
        await favoritesService.removeSongFromFavorites(song.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCurrentSongFavorite = !newFavoriteState;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = (duration.inSeconds % 60);

    if (hours > 0) {
      //for songs longer than 1 hour: "1:30:45"
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      //for songs shorter than 1 hour: "30:45"
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  bool _needsScrolling(String text, TextStyle style, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return textPainter.width > maxWidth;
  }

  Widget _buildArtworkPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.brandPink.opacity80,
            AppTheme.brandPinkSwatch[400]!.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.elevatedSurfaceDark, width: 1.5),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: AppTheme.textPrimaryDark,
        size: AppTheme.artworkLg,
      ),
    );
  }

  Future<Uint8List?> _getOrCacheArtworkFuture(int songId) {
    if (!_artworkFutures.containsKey(songId)) {
      //limit cache size to prevent memory bloat
      if (_artworkFutures.length >= _maxCachedArtworks) {
        //remove oldest entries (keep only the most recent ones)
        final keys = _artworkFutures.keys.toList();
        final toRemove = keys.take(
          _artworkFutures.length - _maxCachedArtworks + 1,
        );
        for (final key in toRemove) {
          _artworkFutures.remove(key);
        }
      }

      _artworkFutures[songId] = ArtworkCacheService.instance.getArtwork(
        songId,
        size: 600,
      );
    }
    return _artworkFutures[songId]!;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    //listen to lifecycle state to rebuild when entering/exiting SAS mode
    return GestureDetector(
      onVerticalDragStart: (details) {
        //ignore swipes starting in safe area (notch region)
        _ignoreSwipe = details.globalPosition.dy < topPadding + 50;
      },
      onVerticalDragEnd: (details) {
        if (_ignoreSwipe) return;

        //swipe down (positive velocity) => minimize to mini player
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        }
      },
      child: ValueListenableBuilder<PlayerLifecycleState>(
        valueListenable: _sonoPlayer.lifecycleStateListenable,
        builder: (context, lifecycleState, _) {
          return ValueListenableBuilder<SongModel?>(
            valueListenable: _sonoPlayer.currentSong,
            builder: (context, currentSong, child) {
              //check if content to display (either local song or SAS stream)
              final bool hasContent =
                  currentSong != null ||
                  (_sonoPlayer.isSASStream && _sonoPlayer.sasMetadata != null);
              final bool hasPlaylist =
                  _sonoPlayer.playlist.isNotEmpty || _sonoPlayer.isSASStream;

              if (!hasContent || !hasPlaylist) {
                return Scaffold(
                  backgroundColor: AppTheme.backgroundDark,
                  body: Center(
                    child: Text(
                      'No song playing',
                      style: AppStyles.sonoButtonText,
                    ),
                  ),
                );
              }

              return Scaffold(
                resizeToAvoidBottomInset: false,
                body: RepaintBoundary(
                  child: Stack(
                    children: [
                      //show background based on mode (local or SAS)
                      currentSong != null
                          ? _buildBlurredBackground(currentSong)
                          : _buildSASBackground(),
                      Scaffold(
                        backgroundColor: Colors.transparent,
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          leading: IconButton(
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.textPrimaryDark,
                              size: AppTheme.iconLg,
                            ),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Minimize player',
                          ),
                          title: ValueListenableBuilder<String?>(
                            valueListenable: _sonoPlayer.playbackContext,
                            builder: (context, contextValue, _) {
                              if (contextValue != null) {
                                final parts = contextValue.split(': ');
                                final contextType = parts[0].toUpperCase();
                                final contextName =
                                    parts.length > 1 ? parts[1] : '';
                                return Column(
                                  children: [
                                    Text(
                                      'PLAYING FROM $contextType',
                                      style: AppStyles.sonoPlayerArtist
                                          .copyWith(
                                            fontSize: AppTheme.fontCaption,
                                            color: AppTheme.textSecondaryDark,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      contextName,
                                      style: AppStyles.sonoPlayerTitle.copyWith(
                                        fontSize: AppTheme.fontBody,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                );
                              }
                              return Text(
                                'Now Playing',
                                style: AppStyles.sonoPlayerTitle.copyWith(
                                  fontSize: AppTheme.fontSubtitle,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          centerTitle: true,
                          actions: [
                            IconButton(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: AppTheme.textPrimaryDark,
                              ),
                              onPressed:
                                  currentSong != null
                                      ? () {
                                        _showMoreOptionsSheet(currentSong);
                                      }
                                      : null, //disable in SAS mode
                              tooltip: 'More options',
                            ),
                          ],
                        ),
                        body: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.responsiveSpacing(
                              context,
                              AppTheme.spacingXl,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Spacer(flex: 1),
                              //show SAS artwork or swipeable local playlist artwork
                              _sonoPlayer.isSASStream && currentSong == null
                                  ? _buildSASArtwork()
                                  : _buildSwipeableArtwork(),
                              const Spacer(flex: 2),
                              _buildTrackInfo(currentSong),
                              SizedBox(
                                height: AppTheme.responsiveSpacing(
                                  context,
                                  AppTheme.spacing,
                                ),
                              ),
                              _buildSeekbar(),
                              SizedBox(
                                height: AppTheme.responsiveSpacing(
                                  context,
                                  AppTheme.spacing,
                                ),
                              ),
                              _buildPlaybackControls(),
                              const Spacer(flex: 1),
                            ],
                          ),
                        ),
                        bottomNavigationBar:
                            currentSong != null
                                ? _buildBottomAppBar(currentSong)
                                : _buildSASBottomAppBar(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBlurredBackground(SongModel currentSong) {
    if (_cachedBlurredBackground != null &&
        _currentArtworkId == currentSong.id) {
      return _cachedBlurredBackground!;
    }
    _currentArtworkId = currentSong.id;
    _cachedBlurredBackground = Positioned.fill(
      child: RepaintBoundary(
        child: FutureBuilder<Uint8List?>(
          future: ArtworkCacheService.instance.getArtwork(
            currentSong.id,
            size: 250,
          ),
          builder: (context, snapshot) {
            final hasArtwork =
                snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData &&
                snapshot.data != null;

            Widget imageWidget =
                hasArtwork
                    ? Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                      alignment: Alignment.center,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 250,
                      cacheHeight: 250,
                    )
                    : Container(color: AppTheme.backgroundDark);

            return AnimatedOpacity(
              opacity: hasArtwork ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeIn,
              child: Stack(
                children: [
                  imageWidget,
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromRGBO(10, 0, 5, 0.4),
                            Color.fromRGBO(60, 0, 30, 0.95),
                          ],
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    return _cachedBlurredBackground!;
  }

  /// Build background for SAS mode (no local song)
  Widget _buildSASBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(10, 0, 5, 0.4),
              Color.fromRGBO(60, 0, 30, 0.95),
            ],
          ),
        ),
      ),
    );
  }

  /// Build artwork display for SAS mode (network image from host)
  Widget _buildSASArtwork() {
    return ValueListenableBuilder<String?>(
      valueListenable: SASManager().clientArtworkUrl,
      builder: (context, artworkUrl, _) {
        return RepaintBoundary(
          child: SizedBox(
            width: AppTheme.responsiveArtworkSize(
              context,
              AppTheme.artworkHero,
            ),
            height: AppTheme.responsiveArtworkSize(
              context,
              AppTheme.artworkHero,
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: AppTheme.elevatedSurfaceDark,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.elevatedSurfaceDark.opacity50,
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    child:
                        artworkUrl != null
                            ? Image.network(
                              artworkUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: AppTheme.elevatedSurfaceDark,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      strokeWidth: 3,
                                      color: AppTheme.brandPink,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildArtworkPlaceholder();
                              },
                            )
                            : _buildArtworkPlaceholder(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeableArtwork() {
    return RepaintBoundary(
      child: SizedBox(
        width: AppTheme.responsiveArtworkSize(context, AppTheme.artworkHero),
        height: AppTheme.responsiveArtworkSize(context, AppTheme.artworkHero),
        child: Listener(
          onPointerDown: (_) {
            _isUserSwiping = true;
          },
          onPointerUp: (_) {
            _handleSwipeRelease();
          },
          onPointerCancel: (_) {
            _handleSwipeCancel();
          },
          child: PageView.builder(
            controller: _pageController,
            itemCount: _sonoPlayer.playlist.length,
            clipBehavior: Clip.none,

            onPageChanged: (index) {
              //only trigger song change if user was swiping
              //(not from programmatic changes like skip buttons)
              if (_isUserSwiping) {
                final currentPlayerIndex = _sonoPlayer.currentIndex ?? 0;
                if (index != currentPlayerIndex) {
                  _sonoPlayer.skipToQueueItem(index);
                }
                _isUserSwiping = false;
              }
            },

            itemBuilder: (context, index) {
              return ValueListenableBuilder<double>(
                valueListenable: _pageNotifier,
                builder: (context, page, child) {
                  final double pageValue = page - index;
                  final double scale = (1 - (pageValue.abs() * 0.2)).clamp(
                    0.8,
                    1.0,
                  );
                  final double rotationY = pageValue * -0.4;

                  return Transform(
                    alignment: Alignment.center,
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(rotationY)
                          //ignore: deprecated_member_use
                          ..scale(scale),
                    child: child,
                  );
                },
                child: _buildArtworkPageItem(_sonoPlayer.playlist[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSwipeRelease() {
    if (_pageController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _isUserSwiping = false;
      });
    }
  }

  void _handleSwipeCancel() {
    //if swipe was cancelled => snap back to current song
    _isUserSwiping = false;
    final currentPlayerIndex = _sonoPlayer.currentIndex ?? 0;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        currentPlayerIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildArtworkPageItem(SongModel song) {
    return RepaintBoundary(
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Hero(
            tag: 'album_art_${song.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: AppTheme.elevatedSurfaceDark,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.elevatedSurfaceDark.opacity50,
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                child: FutureBuilder<Uint8List?>(
                  future: _getOrCacheArtworkFuture(song.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData &&
                        snapshot.data != null) {
                      final cacheSize =
                          (400 * MediaQuery.of(context).devicePixelRatio)
                              .round();
                      return Image.memory(
                        snapshot.data!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: cacheSize,
                        cacheHeight: cacheSize,
                        filterQuality:
                            MediaQuery.of(context).devicePixelRatio > 2
                                ? FilterQuality.high
                                : FilterQuality.medium,
                      );
                    }
                    return _buildArtworkPlaceholder();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(SongModel? currentSong) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textMaxWidth = screenWidth - (AppTheme.spacingXl * 2) - 56;

    //for SAS mode => listen to metadata updates from SASManager
    if (_sonoPlayer.isSASStream && currentSong == null) {
      return ValueListenableBuilder<String?>(
        valueListenable: SASManager().clientSongTitle,
        builder: (context, title, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: SASManager().clientSongArtist,
            builder: (context, artist, _) {
              final displayTitle = title ?? 'Unknown';
              final displayArtist = artist ?? 'Unknown Artist';

              return _buildTrackInfoContent(
                displayTitle: displayTitle,
                displayArtist: displayArtist,
                canNavigateToArtist: false,
                currentSong: null,
                textMaxWidth: textMaxWidth,
              );
            },
          );
        },
      );
    }

    //for local playback => use currentSong
    final String displayTitle;
    final String displayArtist;
    final bool canNavigateToArtist;

    if (currentSong != null) {
      displayTitle = currentSong.title;
      displayArtist = currentSong.artist ?? 'Unknown Artist';
      canNavigateToArtist = true;
    } else {
      displayTitle = 'No song playing';
      displayArtist = '';
      canNavigateToArtist = false;
    }

    return _buildTrackInfoContent(
      displayTitle: displayTitle,
      displayArtist: displayArtist,
      canNavigateToArtist: canNavigateToArtist,
      currentSong: currentSong,
      textMaxWidth: textMaxWidth,
    );
  }

  Widget _buildTrackInfoContent({
    required String displayTitle,
    required String displayArtist,
    required bool canNavigateToArtist,
    required SongModel? currentSong,
    required double textMaxWidth,
  }) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _trackInfoSwitchController,
        builder: (context, child) {
          return Transform.translate(
            offset: _trackInfoSlideAnimation.value * 50,
            child: Opacity(
              opacity:
                  _trackInfoSwitchController.isAnimating
                      ? (_trackInfoSwitchController.value < 0.5
                          ? _trackInfoFadeAnimation.value
                          : 1.0 - _trackInfoFadeAnimation.value)
                      : 1.0,
              child: child,
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _needsScrolling(
                        displayTitle,
                        AppStyles.sonoPlayerTitle.copyWith(
                          fontSize: AppTheme.fontHeading - 2,
                          fontWeight: FontWeight.bold,
                        ),
                        textMaxWidth,
                      )
                      ? SizedBox(
                        height: 28,
                        child: Marquee(
                          text: displayTitle,
                          style: AppStyles.sonoPlayerTitle.copyWith(
                            fontSize: AppTheme.responsiveFontSize(
                              context,
                              AppTheme.fontHeading - 2,
                              min: 18,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                          scrollAxis: Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          blankSpace: 60.0,
                          velocity: 35.0,
                          pauseAfterRound: const Duration(seconds: 4),
                          startPadding: 0.0,
                          accelerationDuration: const Duration(
                            milliseconds: 1000,
                          ),
                          accelerationCurve: Curves.ease,
                          decelerationDuration: const Duration(
                            milliseconds: 1000,
                          ),
                          decelerationCurve: Curves.ease,
                        ),
                      )
                      : Text(
                        displayTitle,
                        style: AppStyles.sonoPlayerTitle.copyWith(
                          fontSize: AppTheme.responsiveFontSize(
                            context,
                            AppTheme.fontHeading - 2,
                            min: 18,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  if (displayArtist.isNotEmpty) ...[
                    SizedBox(
                      height: AppTheme.responsiveSpacing(
                        context,
                        AppTheme.spacingXs + 2,
                      ),
                    ),
                    InkWell(
                      onTap:
                          canNavigateToArtist && currentSong != null
                              ? () => _navigateToArtistPage(currentSong)
                              : null,
                      child: Text(
                        displayArtist,
                        style: AppStyles.sonoPlayerArtist.copyWith(
                          fontSize: AppTheme.responsiveFontSize(
                            context,
                            15,
                            min: 13,
                          ),
                          color: AppTheme.textSecondaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: AppTheme.responsiveSpacing(context, AppTheme.spacingSm),
            ),
            FavoriteIconButton(
              isLiked: _isCurrentSongFavorite,
              onPressed: SASManager().isInClientMode ? null : _toggleFavorite,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekbar() {
    return RepaintBoundary(
      child: ValueListenableBuilder<Duration>(
        valueListenable: _sonoPlayer.position,
        builder: (context, position, child) {
          final duration = _sonoPlayer.duration.value;

          //use dragged position if actively dragging => otherwise use actual position
          final currentPosition =
              _isDraggingSeekBar && _draggedPosition != null
                  ? _draggedPosition!
                  : (duration.inMilliseconds > 0 &&
                      position.inMilliseconds <= duration.inMilliseconds)
                  ? position.inMilliseconds.toDouble()
                  : 0.0;

          final sliderMax =
              duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0;

          final displayPosition =
              _isDraggingSeekBar && _draggedPosition != null
                  ? Duration(milliseconds: _draggedPosition!.toInt())
                  : position;

          return Column(
            children: [
              SliderTheme(
                data: _sliderTheme,
                child: Slider(
                  value: currentPosition,
                  max: sliderMax,
                  onChangeStart:
                      SASManager().isInClientMode
                          ? null
                          : (value) {
                            setState(() {
                              _isDraggingSeekBar = true;
                              _draggedPosition = value;
                            });
                          },
                  onChanged:
                      SASManager().isInClientMode
                          ? null
                          : (value) {
                            setState(() {
                              _draggedPosition = value;
                            });
                          },
                  onChangeEnd:
                      SASManager().isInClientMode
                          ? null
                          : (value) {
                            _sonoPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                            setState(() {
                              _isDraggingSeekBar = false;
                              _draggedPosition = null;
                            });
                          },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(displayPosition),
                    style: AppStyles.sonoButtonTextSmaller.copyWith(
                      color: AppTheme.textPrimaryDark.opacity80,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: AppStyles.sonoButtonTextSmaller.copyWith(
                      color: AppTheme.textPrimaryDark.opacity80,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final sasManager = SASManager();
    final isClient = sasManager.isInClientMode;

    return RepaintBoundary(
      child: Column(
        children: [
          //show client mode indicator banner
          if (isClient) ...[
            Container(
              margin: EdgeInsets.only(
                bottom: AppTheme.responsiveSpacing(context, AppTheme.spacingMd),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.responsiveSpacing(
                  context,
                  AppTheme.spacingMd,
                ),
                vertical: AppTheme.responsiveSpacing(
                  context,
                  AppTheme.spacingSm,
                ),
              ),
              decoration: BoxDecoration(
                color: AppTheme.brandPink.withAlpha(38),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: AppTheme.brandPink.withAlpha(76),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: AppTheme.responsiveIconSize(context, 16, min: 14),
                    color: AppTheme.brandPink,
                  ),
                  SizedBox(
                    width: AppTheme.responsiveSpacing(
                      context,
                      AppTheme.spacingXs,
                    ),
                  ),
                  Text(
                    'Playback controlled by host',
                    style: TextStyle(
                      color: AppTheme.brandPink,
                      fontSize: AppTheme.responsiveFontSize(
                        context,
                        13,
                        min: 11,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          //control buttons
          ValueListenableBuilder<bool>(
            valueListenable: _sonoPlayer.isPlaying,
            builder: (context, isPlaying, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _sonoPlayer.isShuffleEnabled,
                    builder: (context, isShuffleEnabled, child) {
                      return _buildControlButton(
                        icon: Icons.shuffle_rounded,
                        onPressed:
                            isClient
                                ? null
                                : () {
                                  HapticFeedback.lightImpact();
                                  _sonoPlayer.toggleShuffle();
                                },
                        isActive: isShuffleEnabled,
                        tooltip: isClient ? 'Host only' : 'Shuffle',
                      );
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.skip_previous_rounded,
                    isLarger: true,
                    onPressed:
                        isClient
                            ? null
                            : () {
                              final now = DateTime.now();
                              if (_lastSkipTime != null &&
                                  now.difference(_lastSkipTime!) <
                                      _skipDebounceMs) {
                                return; //debounce => ignore rapid presses
                              }
                              _lastSkipTime = now;
                              HapticFeedback.lightImpact();
                              _sonoPlayer.skipToPrevious();
                            },
                    tooltip: isClient ? 'Host only' : 'Previous',
                  ),
                  _buildPlayPauseButton(isPlaying, isClient: isClient),
                  _buildControlButton(
                    icon: Icons.skip_next_rounded,
                    isLarger: true,
                    onPressed:
                        isClient
                            ? null
                            : () {
                              final now = DateTime.now();
                              if (_lastSkipTime != null &&
                                  now.difference(_lastSkipTime!) <
                                      _skipDebounceMs) {
                                return; //debounce => ignore rapid presses
                              }
                              _lastSkipTime = now;
                              HapticFeedback.lightImpact();
                              _sonoPlayer.skipToNext();
                            },
                    tooltip: isClient ? 'Host only' : 'Next',
                  ),
                  _buildRepeatButton(isClient: isClient),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatButton({bool isClient = false}) {
    return ValueListenableBuilder<RepeatMode>(
      valueListenable: _sonoPlayer.repeatMode,
      builder: (context, repeatMode, child) {
        IconData repeatIcon;
        String tooltipMsg;
        switch (repeatMode) {
          case RepeatMode.off:
            repeatIcon = Icons.repeat_rounded;
            tooltipMsg = isClient ? 'Host only' : 'Repeat: Off';
            break;
          case RepeatMode.all:
            repeatIcon = Icons.repeat_rounded;
            tooltipMsg = isClient ? 'Host only' : 'Repeat: All';
            break;
          case RepeatMode.one:
            repeatIcon = Icons.repeat_one_rounded;
            tooltipMsg = isClient ? 'Host only' : 'Repeat: One';
            break;
        }
        return _buildControlButton(
          icon: repeatIcon,
          onPressed: isClient ? null : _sonoPlayer.toggleRepeat,
          isActive: repeatMode != RepeatMode.off,
          tooltip: tooltipMsg,
        );
      },
    );
  }

  Widget _buildPlayPauseButton(bool isPlaying, {bool isClient = false}) {
    return Tooltip(
      message: isClient ? 'Host only' : (isPlaying ? 'Pause' : 'Play'),
      child: Container(
        width: AppTheme.responsiveDimension(context, 72),
        height: AppTheme.responsiveDimension(context, 72),
        decoration: BoxDecoration(
          gradient:
              isClient
                  ? LinearGradient(
                    colors: [
                      AppTheme.brandPink.withValues(alpha: 0.2),
                      AppTheme.brandPinkSwatch[400]!.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : LinearGradient(
                    colors: [
                      AppTheme.brandPink,
                      AppTheme.brandPinkSwatch[400]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          shape: BoxShape.circle,
          boxShadow:
              isClient
                  ? []
                  : [
                    BoxShadow(
                      color: AppTheme.brandPink.opacity50,
                      blurRadius: 15,
                      spreadRadius: -5,
                    ),
                  ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor:
                isClient
                    ? Colors.transparent
                    : AppTheme.textPrimaryDark.opacity30,
            highlightColor:
                isClient
                    ? Colors.transparent
                    : AppTheme.textPrimaryDark.opacity10,
            onTap:
                isClient
                    ? null
                    : () {
                      HapticFeedback.vibrate();
                      _sonoPlayer.playPause();
                    },
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color:
                  isClient
                      ? AppTheme.textPrimaryDark.withValues(alpha: 0.3)
                      : AppTheme.textPrimaryDark,
              size: AppTheme.responsiveIconSize(context, 40, min: 32),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool isActive = false,
    String? tooltip,
    bool isLarger = false,
  }) {
    final double buttonSize = AppTheme.responsiveDimension(
      context,
      isLarger ? 60 : 50,
    );
    final double iconSize = AppTheme.responsiveIconSize(
      context,
      isLarger ? AppTheme.iconLg : AppTheme.icon,
      min: isLarger ? 28 : 20,
    );
    final Color activeColor = AppTheme.brandPink.withValues(alpha: 0.9);
    final Color inactiveBackgroundColor = Colors.transparent;
    final Color activeIconColor = Theme.of(context).primaryColor;
    final Color inactiveIconColor =
        onPressed == null
            ? AppTheme.textSecondaryDark.withValues(alpha: 0.3)
            : AppTheme.textSecondaryDark;

    Widget button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        splashColor:
            onPressed == null ? Colors.transparent : activeColor.opacity50,
        highlightColor:
            onPressed == null ? Colors.transparent : activeColor.opacity30,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: inactiveBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? activeIconColor : inactiveIconColor,
            size: iconSize,
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildBottomAppBar(SongModel currentSong) {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.responsiveSpacing(context, AppTheme.spacing),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomBarButton(
              icon: Icons.queue_music_rounded,
              label: 'Queue',
              onPressed: _showQueueSheet,
            ),
            _buildBottomBarButton(
              icon: Icons.lyrics_rounded,
              label: 'Lyrics',
              onPressed: () => _showLyricsSheet(currentSong),
            ),
            _buildBottomBarButton(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddToPlaylistSheet(song: currentSong),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build bottom app bar for SAS mode (limited features)
  Widget _buildSASBottomAppBar() {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.responsiveSpacing(context, AppTheme.spacing),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomBarButton(
              icon: Icons.queue_music_rounded,
              label: 'Queue',
              onPressed: _showQueueSheet,
            ),
            //lyrics and add to playlist disabled in SAS mode
            _buildBottomBarButton(
              icon: Icons.lyrics_rounded,
              label: 'Lyrics',
              onPressed: null, //disabled in SAS mode
            ),
            _buildBottomBarButton(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add',
              onPressed: null, //disabled in SAS mode
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textSecondaryDark, size: AppTheme.icon),
            Text(
              label,
              style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptionsSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                title: Text(
                  'Song credits',
                  style: TextStyle(color: AppTheme.textPrimaryDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCreditsSheet(song);
                },
              ),
              if (!SASManager().isInClientMode)
                ListTile(
                  leading: Icon(
                    Icons.timer_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: Text(
                    'Sleep timer',
                    style: TextStyle(color: AppTheme.textPrimaryDark),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showSleepTimerOptions(context, _sonoPlayer);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreditsSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return SongCreditsView(
              song: song,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.spacingLg),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return QueueView(sonoPlayer: _sonoPlayer);
          },
        );
      },
    );
  }

  void _showLyricsSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.spacingLg),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return LyricsDisplayer(song: song, sonoPlayer: _sonoPlayer);
          },
        );
      },
    );
  }
}

class SongCreditsView extends StatefulWidget {
  final SongModel song;
  final ScrollController scrollController;
  const SongCreditsView({
    super.key,
    required this.song,
    required this.scrollController,
  });

  @override
  State<SongCreditsView> createState() => _SongCreditsViewState();
}

class _SongCreditsViewState extends State<SongCreditsView> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final MusicBrainzService _musicBrainzService = MusicBrainzService();
  String? _releaseDate;
  bool _isLoadingDate = true;
  AlbumModel? _album;

  @override
  void initState() {
    super.initState();
    _fetchCreditsData();
  }

  Future<void> _fetchCreditsData() async {
    setState(() => _isLoadingDate = true);
    final date = await _musicBrainzService.getFirstReleaseDate(
      artist: widget.song.artist ?? '',
      album: widget.song.album ?? '',
    );
    if (widget.song.albumId != null) {
      final albums = await _audioQuery.queryAlbums();
      final albumIndex = albums.indexWhere((a) => a.id == widget.song.albumId);
      if (albumIndex != -1) {
        _album = albums[albumIndex];
      }
    }

    if (mounted) {
      setState(() {
        _releaseDate = date;
        _isLoadingDate = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurfaceDark,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppTheme.spacingSm,
              horizontal: AppTheme.spacingLg,
            ),
            child: Text(
              "Song Credits",
              style: AppStyles.sonoPlayerTitle.copyWith(
                fontSize: AppTheme.fontTitle,
              ),
            ),
          ),
          Divider(color: AppTheme.textPrimaryDark.opacity20),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing,
                vertical: AppTheme.spacingSm,
              ),
              children: [
                if (_album != null)
                  _buildCreditTile(
                    label: "From album",
                    value: _album!.album,
                    artworkType: ArtworkType.ALBUM,
                    id: _album!.id,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AlbumPage(
                                album: _album!,
                                audioQuery: _audioQuery,
                              ),
                        ),
                      );
                    },
                  ),
                _buildCreditTile(
                  label: "Artist",
                  value: ArtistStringUtils.getPrimaryArtist(
                    widget.song.artist ?? '',
                  ),
                  artworkType: ArtworkType.ARTIST,
                  id: widget.song.artistId,
                  isArtist: true,
                  artistName: ArtistStringUtils.getPrimaryArtist(
                    widget.song.artist ?? '',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToArtistPage(widget.song);
                  },
                ),
                if (_isLoadingDate)
                  ListTile(
                    title: Text(
                      "Released",
                      style: TextStyle(color: AppTheme.textSecondaryDark),
                    ),
                    trailing: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_releaseDate != null)
                  _buildInfoTile(label: "Released", value: _releaseDate!),
                if (widget.song.genre != null)
                  _buildInfoTile(label: "Genre", value: widget.song.genre!),
                if (widget.song.composer != null)
                  _buildInfoTile(
                    label: "Composer",
                    value: widget.song.composer!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToArtistPage(SongModel song) {
    if (song.artist == null) return;
    //get the primary (first) artist from the songs artist string
    final primaryArtist = ArtistStringUtils.getPrimaryArtist(song.artist!);
    ArtistNavigation.navigateToArtistByName(
      context,
      primaryArtist,
      _audioQuery,
    );
  }
}

Widget _buildInfoTile({required String label, required String value}) {
  return ListTile(
    title: Text(label, style: TextStyle(color: AppTheme.textSecondaryDark)),
    subtitle: Text(
      value,
      style: TextStyle(
        color: AppTheme.textPrimaryDark,
        fontSize: AppTheme.font,
      ),
    ),
  );
}

Widget _buildCreditTile({
  required String label,
  required String value,
  required ArtworkType artworkType,
  required int? id,
  VoidCallback? onTap,
  bool isArtist = false,
  String? artistName,
}) {
  Widget leadingWidget;

  if (isArtist && artistName != null) {
    leadingWidget = ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: SizedBox(
        width: 50,
        height: 50,
        child: ArtistArtworkWidget(
          artistName: artistName,
          artistId: id ?? 0,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(25),
          placeholderWidget: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurfaceDark,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(Icons.person_rounded, color: AppTheme.textTertiaryDark),
          ),
        ),
      ),
    );
  } else {
    leadingWidget = QueryArtworkWidget(
      id: id ?? 0,
      type: artworkType,
      artworkWidth: 50,
      artworkHeight: 50,
      artworkBorder: BorderRadius.circular(isArtist ? 25 : AppTheme.radiusMd),
      nullArtworkWidget: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.elevatedSurfaceDark,
          borderRadius: BorderRadius.circular(
            isArtist ? 25 : AppTheme.radiusMd,
          ),
        ),
        child: Icon(Icons.music_note_rounded, color: AppTheme.textTertiaryDark),
      ),
    );
  }

  return ListTile(
    onTap: onTap,
    leading: leadingWidget,
    title: Text(
      label,
      style: TextStyle(
        color: AppTheme.textSecondaryDark,
        fontSize: AppTheme.fontSm,
      ),
    ),
    subtitle: Text(
      value,
      style: TextStyle(
        color: AppTheme.textPrimaryDark,
        fontSize: AppTheme.font,
      ),
    ),
    trailing:
        onTap != null
            ? Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textTertiaryDark,
              size: AppTheme.iconSm,
            )
            : null,
  );
}

class LyricsDisplayer extends StatefulWidget {
  final SongModel song;
  final SonoPlayer sonoPlayer;

  const LyricsDisplayer({
    super.key,
    required this.song,
    required this.sonoPlayer,
  });

  @override
  State<LyricsDisplayer> createState() => _LyricsDisplayerState();
}

class _LyricsDisplayerState extends State<LyricsDisplayer> {
  final LyricsCacheService _lyricsCacheService = LyricsCacheService.instance;

  List<Map<String, dynamic>>? _choices;
  Map<String, dynamic>? _selectedLyric;
  Map<String, dynamic>? _previouslySelectedLyric;
  bool _isLoading = true;

  bool get _hasMultipleChoices => _choices != null && _choices!.length > 1;
  bool get _isShowingChoiceList => _selectedLyric == null;

  @override
  void initState() {
    super.initState();
    _fetchAndProcessLyrics();
  }

  Future<void> _fetchAndProcessLyrics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedLyric = null;
      _choices = null;
    });

    List<Map<String, dynamic>> resultsNoCleanup = await _lyricsCacheService
        .getOrFetchLyrics(
          artist: widget.song.artist ?? '',
          title: widget.song.title,
          album: widget.song.album,
          usePrimaryArtistCleanup: false,
        );

    List<Map<String, dynamic>> resultsWithCleanup = await _lyricsCacheService
        .getOrFetchLyrics(
          artist: widget.song.artist ?? '',
          title: widget.song.title,
          album: widget.song.album,
          usePrimaryArtistCleanup: true,
        );

    List<Map<String, dynamic>> combinedResults = [];
    Map<String, dynamic>? selectedLyricCandidate;

    for (var lyric in resultsNoCleanup) {
      combinedResults.add(lyric);
      if (lyric['syncedLyrics'] != null && selectedLyricCandidate == null) {
        selectedLyricCandidate = lyric;
      }
    }

    for (var cleanedLyric in resultsWithCleanup) {
      bool alreadyExists = combinedResults.any(
        (existingLyric) =>
            existingLyric['trackName'] == cleanedLyric['trackName'] &&
            existingLyric['artistName'] == cleanedLyric['artistName'] &&
            existingLyric['albumName'] == cleanedLyric['albumName'] &&
            (existingLyric['syncedLyrics'] != null) ==
                (cleanedLyric['syncedLyrics'] != null),
      );

      if (!alreadyExists) {
        combinedResults.add(cleanedLyric);
      }
      if (cleanedLyric['syncedLyrics'] != null &&
          (selectedLyricCandidate == null ||
              selectedLyricCandidate['syncedLyrics'] == null)) {
        selectedLyricCandidate = cleanedLyric;
      }
    }

    if (!mounted) return;

    setState(() {
      if (combinedResults.isNotEmpty) {
        _choices = combinedResults;
        _selectedLyric = selectedLyricCandidate ?? combinedResults.first;
      } else {
        _choices = [];
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Divider(
          color: AppTheme.textPrimaryDark.opacity20,
          indent: 30,
          endIndent: 30,
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        top: AppTheme.spacingXl,
        left: AppTheme.spacing,
        right: AppTheme.spacing,
        bottom: AppTheme.spacingXs,
      ),
      child: Column(
        children: [
          Text(
            widget.song.title,
            style: AppStyles.sonoPlayerTitle.copyWith(
              fontSize: AppTheme.fontSubtitle,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppTheme.spacingXs),
          Text(
            widget.song.artist ?? 'Unknown Artist',
            style: AppStyles.sonoPlayerArtist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isShowingChoiceList) {
      return _buildLyricContentView(_selectedLyric!);
    }

    if (_choices != null && _choices!.isNotEmpty) {
      return _buildChoiceListView(_choices!);
    }

    return Center(
      child: Text(
        "No lyrics found.",
        style: TextStyle(color: AppTheme.textSecondaryDark),
      ),
    );
  }

  Widget _buildChoiceListView(List<Map<String, dynamic>> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacing,
            AppTheme.spacingSm,
            AppTheme.spacing,
            AppTheme.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Select a version:",
                style: AppStyles.sonoPlayerTitle.copyWith(
                  fontSize: AppTheme.font,
                ),
              ),
              if (_previouslySelectedLyric != null)
                TextButton.icon(
                  onPressed:
                      () => setState(
                        () => _selectedLyric = _previouslySelectedLyric,
                      ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  label: const Text("Back to Lyrics"),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final lyricChoice = results[index];
              final hasSynced = lyricChoice['syncedLyrics'] != null;
              return ListTile(
                title: Text(
                  lyricChoice['trackName'] ?? 'Unknown Title',
                  style: AppStyles.sonoListItemTitle,
                ),
                subtitle: Text(
                  lyricChoice['artistName'] ?? 'Unknown Artist',
                  style: AppStyles.sonoListItemSubtitle,
                ),
                trailing:
                    hasSynced
                        ? const Icon(
                          Icons.timer_rounded,
                          color: Colors.greenAccent,
                        )
                        : null,
                onTap: () => setState(() => _selectedLyric = lyricChoice),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLyricContentView(Map<String, dynamic> lyricsData) {
    final syncedLyrics = lyricsData['syncedLyrics'] as String?;
    final plainLyrics = lyricsData['plainLyrics'] as String?;
    Widget lyricWidget;

    if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
      lyricWidget = SyncedLyricsViewer(
        lrcLyrics: syncedLyrics,
        positionListenable: widget.sonoPlayer.position,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: AppTheme.textPrimaryDark.withValues(alpha: 0.6),
          fontSize: AppTheme.fontHeading,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
        highlightedStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: AppTheme.textPrimaryDark,
          fontSize: AppTheme.fontHeading,
          fontWeight: FontWeight.bold,
          height: 1.6,
        ),
      );
    } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
      lyricWidget = SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXl,
          vertical: AppTheme.spacing,
        ),
        child: Text(
          plainLyrics,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimaryDark.opacity80,
            fontSize: AppTheme.fontHeading - 2,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      lyricWidget = Center(
        child: Text(
          "Lyrics are empty.",
          style: TextStyle(color: AppTheme.textSecondaryDark),
        ),
      );
    }

    return Column(
      children: [
        if (_hasMultipleChoices)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: TextButton.icon(
                icon: Icon(Icons.swap_horiz_rounded, size: AppTheme.iconMd),
                label: const Text("Switch Version"),
                onPressed:
                    () => setState(() {
                      _previouslySelectedLyric = _selectedLyric;
                      _selectedLyric = null;
                    }),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondaryDark,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingXs,
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: lyricWidget),
      ],
    );
  }
}
