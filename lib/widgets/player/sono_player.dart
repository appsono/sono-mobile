/// What is this file?
/// This file handles everything related to audio playback in Sono.
/// It is intentionally written to be easy to understand, since it is
/// one of the most important files in the project.
///
/// You will see this check a lot:
/// "if (!SASManager().checkPlaybackControl()) return;"
/// It verifies whether the user is allowed to control playback.
/// This prevents users from changing songs or playback state
/// while connected to an SAS.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/services/utils/crashlytics_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sono/models/playback_snapshot.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/services/api/lyrics_service.dart';
import 'package:sono/services/utils/preferences_service.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:sono/services/settings/playback_settings_service.dart';
import 'package:sono/services/utils/recents_service.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:sono/services/settings/audio_effects_service.dart';

//============================================================================
// CONSTANTS
//============================================================================

const String lastfmScrobblingEnabledKeyInPlayer =
    'lastfm_scrobbling_enabled_v1';

const String playbackSnapshotKey = 'playback_snapshot_v1';

/// Minimal buffer configuration (reduce RAM usage
/// Default just_audio buffers are much larger than needed for local files
const AudioLoadConfiguration _minimalBufferConfig = AudioLoadConfiguration(
  androidLoadControl: AndroidLoadControl(
    minBufferDuration: Duration(milliseconds: 2500),
    maxBufferDuration: Duration(milliseconds: 8000),
    bufferForPlaybackDuration: Duration(milliseconds: 1500),
    bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 2500),
    prioritizeTimeOverSizeThresholds: true,
  ),
);

/// Network-optimized buffer configuration for SAS streaming
/// Minimal buffers for low-latency local network peer-to-peer streaming
const AudioLoadConfiguration _networkBufferConfig = AudioLoadConfiguration(
  androidLoadControl: AndroidLoadControl(
    minBufferDuration: Duration(milliseconds: 100),
    maxBufferDuration: Duration(seconds: 1),
    bufferForPlaybackDuration: Duration(milliseconds: 50),
    bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 100),
    prioritizeTimeOverSizeThresholds: true,
    targetBufferBytes: 256 * 1024,
  ),
);

//============================================================================
// ENUMS
//============================================================================

enum RepeatMode { off, all, one }

/// Internal playback mode to differentiate local vs network streaming
enum _PlaybackMode { local, network }

/// Player lifecycle states (better state tracking and debugging)
enum PlayerLifecycleState {
  idle,
  initializing,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
  sasConnecting, //connecting to SAS session (client only)
  sasPlaying, //playing SAS stream (client only)
}

//============================================================================
// SUBSCRIPTION MANAGER
// Centralized management of stream subscriptions to prevent memory leaks
//============================================================================

class _SubscriptionManager {
  final List<StreamSubscription> _subscriptions = [];

  void add(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void cancelAll() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  int get count => _subscriptions.length;
}

//============================================================================
// QUEUE MANAGER
// Single source of truth for playlist management. No duplicate lists
//============================================================================

class _QueueManager {
  /// Original playlist order (never shuffled)
  final List<SongModel> _originalQueue = [];

  /// Current playback indices.
  /// When shuffle is off (this is 0,1,2,3...)
  /// When shuffle is on => this is a shuffled sequence of indices
  List<int> _playOrder = [];

  /// Position in _playOrder => not in _originalQueue
  int _currentPosition = 0;

  bool _shuffleEnabled = false;

  bool get isEmpty => _originalQueue.isEmpty;
  int get length => _originalQueue.length;
  bool get shuffleEnabled => _shuffleEnabled;

  /// Returns current song => or null if queue is empty
  SongModel? get currentSong {
    if (_originalQueue.isEmpty ||
        _currentPosition < 0 ||
        _currentPosition >= _playOrder.length) {
      return null;
    }
    final idx = _playOrder[_currentPosition];
    if (idx < 0 || idx >= _originalQueue.length) return null;
    return _originalQueue[idx];
  }

  /// Returns current index in play order
  int get currentIndex => _currentPosition;

  /// Returns playlist in current play order
  List<SongModel> get orderedPlaylist {
    return _playOrder.map((idx) => _originalQueue[idx]).toList();
  }

  /// Returns original unshuffled playlist
  List<SongModel> get originalPlaylist => List.unmodifiable(_originalQueue);

  /// Clears queue entirely
  void clear() {
    _originalQueue.clear();
    _playOrder.clear();
    _currentPosition = 0;
  }

  /// Sets a new playlist and optionally starts at a specific index
  void setPlaylist(List<SongModel> songs, int startIndex) {
    _originalQueue.clear();
    _originalQueue.addAll(songs);

    _playOrder = List.generate(songs.length, (i) => i);

    if (_shuffleEnabled && songs.isNotEmpty) {
      _applyShuffle(preserveIndex: startIndex);
    } else {
      _currentPosition = startIndex.clamp(
        0,
        songs.isEmpty ? 0 : songs.length - 1,
      );
    }
  }

  /// Toggles shuffle mode
  void toggleShuffle() {
    if (_originalQueue.isEmpty) return;

    _shuffleEnabled = !_shuffleEnabled;

    if (_shuffleEnabled) {
      //get current song before shuffle
      final currentOriginalIdx =
          _playOrder.isNotEmpty && _currentPosition < _playOrder.length
              ? _playOrder[_currentPosition]
              : 0;
      _applyShuffle(preserveIndex: currentOriginalIdx);
    } else {
      //restore original order => find current songs position
      final currentOriginalIdx =
          _playOrder.isNotEmpty && _currentPosition < _playOrder.length
              ? _playOrder[_currentPosition]
              : 0;
      _playOrder = List.generate(_originalQueue.length, (i) => i);
      _currentPosition = currentOriginalIdx.clamp(0, _originalQueue.length - 1);
    }
  }

  void _applyShuffle({required int preserveIndex}) {
    if (_originalQueue.isEmpty) return;

    //create shuffled order => but keep specified song first
    final indices = List.generate(_originalQueue.length, (i) => i);
    indices.remove(preserveIndex);
    indices.shuffle();
    _playOrder = [preserveIndex, ...indices];
    _currentPosition = 0;
  }

  /// Moves to next song
  /// Returns true if successful
  bool moveToNext(RepeatMode repeatMode) {
    if (_playOrder.isEmpty) return false;

    final nextPos = _currentPosition + 1;
    if (nextPos >= _playOrder.length) {
      if (repeatMode == RepeatMode.all) {
        _currentPosition = 0;
        return true;
      }
      return false;
    }
    _currentPosition = nextPos;
    return true;
  }

  /// Moves to previous song
  /// Returns true if successful
  bool moveToPrevious(RepeatMode repeatMode) {
    if (_playOrder.isEmpty) return false;

    final prevPos = _currentPosition - 1;
    if (prevPos < 0) {
      if (repeatMode == RepeatMode.all) {
        _currentPosition = _playOrder.length - 1;
        return true;
      }
      return false;
    }
    _currentPosition = prevPos;
    return true;
  }

  /// Moves to a specific position in play order
  bool moveTo(int position) {
    if (position < 0 || position >= _playOrder.length) return false;
    _currentPosition = position;
    return true;
  }

  /// Adds songs to the end of the queue
  void addToQueue(List<SongModel> songs) {
    if (songs.isEmpty) return;

    final startIdx = _originalQueue.length;
    _originalQueue.addAll(songs);

    //Add new indices to play order
    for (int i = 0; i < songs.length; i++) {
      _playOrder.add(startIdx + i);
    }
  }

  /// Inserts a song to play next (after current position)
  void insertPlayNext(SongModel song) {
    _originalQueue.add(song);
    final newIdx = _originalQueue.length - 1;

    //insert after current position in play order
    final insertPos = (_currentPosition + 1).clamp(0, _playOrder.length);
    _playOrder.insert(insertPos, newIdx);
  }

  /// Removes a song by its play order position
  bool removeAt(int playOrderPosition) {
    if (playOrderPosition < 0 || playOrderPosition >= _playOrder.length) {
      return false;
    }

    final originalIdx = _playOrder[playOrderPosition];
    _playOrder.removeAt(playOrderPosition);

    //update indices that point to positions after removed song
    for (int i = 0; i < _playOrder.length; i++) {
      if (_playOrder[i] > originalIdx) {
        _playOrder[i]--;
      }
    }

    _originalQueue.removeAt(originalIdx);

    //adjust current position if needed
    if (_currentPosition >= _playOrder.length) {
      _currentPosition = _playOrder.isEmpty ? 0 : _playOrder.length - 1;
    }

    return true;
  }

  /// Reorders an item in the play order
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playOrder.length) return;
    if (newIndex < 0 || newIndex > _playOrder.length) return;
    if (oldIndex == newIndex) return;

    final item = _playOrder.removeAt(oldIndex);
    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    _playOrder.insert(adjustedNewIndex.clamp(0, _playOrder.length), item);

    //update current position if it was affected
    if (_currentPosition == oldIndex) {
      _currentPosition = adjustedNewIndex;
    } else if (oldIndex < _currentPosition &&
        adjustedNewIndex >= _currentPosition) {
      _currentPosition--;
    } else if (oldIndex > _currentPosition &&
        adjustedNewIndex <= _currentPosition) {
      _currentPosition++;
    }
  }

  /// Gets the next song without changing position (for crossfade preloading)
  SongModel? peekNext(RepeatMode repeatMode) {
    if (_playOrder.isEmpty) return null;

    final nextPos = _currentPosition + 1;
    if (nextPos >= _playOrder.length) {
      if (repeatMode == RepeatMode.all && _playOrder.isNotEmpty) {
        return _originalQueue[_playOrder[0]];
      }
      return null;
    }
    return _originalQueue[_playOrder[nextPos]];
  }

  /// Removes a song by its ID from all positions
  void removeSongById(int songId) {
    final originalIdx = _originalQueue.indexWhere((s) => s.id == songId);
    if (originalIdx < 0) return;

    _playOrder.removeWhere((idx) => idx == originalIdx);

    //update indices
    for (int i = 0; i < _playOrder.length; i++) {
      if (_playOrder[i] > originalIdx) {
        _playOrder[i]--;
      }
    }

    _originalQueue.removeAt(originalIdx);

    if (_currentPosition >= _playOrder.length) {
      _currentPosition = _playOrder.isEmpty ? 0 : _playOrder.length - 1;
    }
  }

  /// Clears all except current song
  void clearExceptCurrent() {
    if (_playOrder.isEmpty) return;

    final current = currentSong;
    if (current == null) {
      clear();
      return;
    }

    _originalQueue.clear();
    _originalQueue.add(current);
    _playOrder = [0];
    _currentPosition = 0;
  }
}

//============================================================================
// CROSSFADE CONTROLLER
// Manages crossfade transitions between tracks
// Created lazily
//============================================================================

class _CrossfadeController {
  final AudioPlayer _fadeOutPlayer;
  final AudioPlayer _fadeInPlayer;
  final Duration duration;

  Timer? _fadeTimer;
  bool _isActive = false;

  _CrossfadeController({
    required AudioPlayer fadeOutPlayer,
    required AudioPlayer fadeInPlayer,
    required this.duration,
  }) : _fadeOutPlayer = fadeOutPlayer,
       _fadeInPlayer = fadeInPlayer;

  bool get isActive => _isActive;

  /// Starts a crossfade transition
  /// Returns a Future that completes when done
  Future<void> execute() async {
    if (_isActive) return;
    _isActive = true;

    final completer = Completer<void>();

    try {
      await _fadeInPlayer.setVolume(0.0);
      _fadeInPlayer.play();

      const stepMs = 50;
      final steps = (duration.inMilliseconds / stepMs).round().clamp(1, 1000);
      final volumeStep = 1.0 / steps;

      int currentStep = 0;

      _fadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (
        timer,
      ) async {
        currentStep++;

        final fadeOutVolume = (1.0 - (volumeStep * currentStep)).clamp(
          0.0,
          1.0,
        );
        final fadeInVolume = (volumeStep * currentStep).clamp(0.0, 1.0);

        //fire and forget => dont await volume changes
        _fadeOutPlayer.setVolume(fadeOutVolume);
        _fadeInPlayer.setVolume(fadeInVolume);

        if (currentStep >= steps || fadeOutVolume <= 0.01) {
          timer.cancel();
          _fadeTimer = null;

          await _fadeOutPlayer.stop();
          await _fadeOutPlayer.setVolume(1.0);
          await _fadeInPlayer.setVolume(1.0);

          _isActive = false;
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });
    } catch (e) {
      _isActive = false;
      _fadeTimer?.cancel();
      _fadeTimer = null;

      //restore volumes on error
      try {
        await _fadeOutPlayer.setVolume(1.0);
        await _fadeInPlayer.setVolume(1.0);
      } catch (_) {}

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Cancels any in-progress crossfade
  Future<void> cancel() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isActive = false;

    try {
      await _fadeOutPlayer.setVolume(1.0);
      await _fadeInPlayer.setVolume(1.0);
    } catch (_) {}
  }

  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isActive = false;
  }
}

//============================================================================
// SLEEP TIMER CONTROLLER
// Manages sleep timer with minimal overhead
//============================================================================

class _SleepTimerController {
  Timer? _actionTimer;
  Timer? _tickTimer;
  final ValueNotifier<Duration?> remainingNotifier = ValueNotifier(null);
  final VoidCallback onTimerFired;

  _SleepTimerController({required this.onTimerFired});

  Duration? get remaining => remainingNotifier.value;
  bool get isActive => remainingNotifier.value != null;

  void start(Duration duration) {
    cancel();

    if (duration.inSeconds <= 0) return;

    remainingNotifier.value = duration;

    _actionTimer = Timer(duration, () {
      onTimerFired();
      remainingNotifier.value = null;
      _tickTimer?.cancel();
    });

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = remainingNotifier.value;
      if (current == null || current.inSeconds <= 1) {
        _tickTimer?.cancel();
        return;
      }
      remainingNotifier.value = current - const Duration(seconds: 1);
    });
  }

  void cancel() {
    _actionTimer?.cancel();
    _tickTimer?.cancel();
    _actionTimer = null;
    _tickTimer = null;
    remainingNotifier.value = null;
  }

  void dispose() {
    cancel();
    remainingNotifier.dispose();
  }
}

//============================================================================
// DEBOUNCED STATE BROADCASTER
// Prevents UI thrashing by debouncing rapid state updates
//============================================================================

class _DebouncedBroadcaster {
  Timer? _timer;
  final Duration delay = const Duration(milliseconds: 250);
  VoidCallback? _pendingCallback;

  _DebouncedBroadcaster();

  void schedule(VoidCallback callback) {
    _pendingCallback = callback;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _pendingCallback?.call();
      _pendingCallback = null;
    });
  }

  void executeNow(VoidCallback callback) {
    _timer?.cancel();
    _pendingCallback = null;
    callback();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendingCallback = null;
  }
}

//============================================================================
// ARTWORK CACHE
// Simple cache to avoid repeated artwork file I/O
//============================================================================

class _ArtworkCache {
  Uri? _cachedUri;
  int? _cachedSongId;

  bool hasArtworkFor(int songId) =>
      _cachedSongId == songId && _cachedUri != null;

  Uri? getArtwork(int songId) {
    if (_cachedSongId == songId) return _cachedUri;
    return null;
  }

  void setArtwork(int songId, Uri? uri) {
    _cachedSongId = songId;
    _cachedUri = uri;
  }

  void clear() {
    _cachedSongId = null;
    _cachedUri = null;
  }
}

//============================================================================
// SONO PLAYER
// Main audio player class
// Extends BaseAudioHandler for background playback
//============================================================================

class SonoPlayer extends BaseAudioHandler {
  //singleton
  static final SonoPlayer _instance = SonoPlayer._internal();
  factory SonoPlayer() => _instance;

  //core audio players => secondary player created lazily only when crossfade is enabled
  late AudioPlayer _primaryPlayer;
  AudioPlayer? _secondaryPlayer;
  AudioPlayer get _currentPlayer => _primaryPlayer;

  //audio effects
  AndroidEqualizer? _equalizer;

  //services
  final PreferencesService _prefsService = PreferencesService();
  final LastfmService _lastfmService = LastfmService();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final FavoritesService _favoritesService = FavoritesService();
  final LyricsCacheService _lyricsCacheService = LyricsCacheService.instance;
  final AudioEffectsService _audioEffectsService = AudioEffectsService.instance;
  final LibrarySettingsService _librarySettings =
      LibrarySettingsService.instance;
  final PlaybackSettingsService _playbackSettings =
      PlaybackSettingsService.instance;

  //state managers
  final _QueueManager _queueManager = _QueueManager();
  final _SubscriptionManager _subscriptions = _SubscriptionManager();
  late final _SleepTimerController _sleepTimer;
  final _DebouncedBroadcaster _stateBroadcaster = _DebouncedBroadcaster();
  final _ArtworkCache _artworkCache = _ArtworkCache();
  _CrossfadeController? _crossfadeController;
  Timer? _positionSaveTimer;

  //observable state => exposed to UI
  final ValueNotifier<SongModel?> _currentSong = ValueNotifier(null);
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isShuffleEnabled = ValueNotifier(false);
  final ValueNotifier<RepeatMode> _repeatMode = ValueNotifier(RepeatMode.off);
  final ValueNotifier<double> _currentSpeed = ValueNotifier(1.0);
  final ValueNotifier<double> _currentPitch = ValueNotifier(1.0);
  final ValueNotifier<String?> _playbackContext = ValueNotifier(null);
  final ValueNotifier<List<MediaItem>> queueNotifier = ValueNotifier([]);
  final ValueNotifier<bool> albumCoverRotationEnabled = ValueNotifier(true);

  //internal state
  bool _isInitialized = false;
  bool _crossfadeEnabled = false;
  Duration _crossfadeDuration = const Duration(seconds: 5);
  bool _lastfmScrobblingEnabled = true;
  _PlaybackMode _playbackMode = _PlaybackMode.local;
  bool _isCrossfading = false;
  bool _isPreloading = false;
  bool _isHandlingCompletion = false;
  DateTime? _lastCompletionTime;
  int? _lastCompletedSongId;
  bool _isSASStream = false;
  Map<String, dynamic>? _sasMetadata;
  int? sasCurrentIndex;
  PlayerLifecycleState _lifecycleState = PlayerLifecycleState.idle;
  final ValueNotifier<PlayerLifecycleState> lifecycleState = ValueNotifier(
    PlayerLifecycleState.idle,
  );
  final ValueNotifier<String?> _playerErrorMessage = ValueNotifier(null);
  final ValueNotifier<bool> _isInitializing = ValueNotifier(false);

  //getters for public API compatibility
  ValueNotifier<SongModel?> get currentSong => _currentSong;
  ValueNotifier<bool> get isPlaying => _isPlaying;
  ValueNotifier<Duration> get position => _position;
  ValueNotifier<Duration> get duration => _duration;
  ValueListenable<bool> get isShuffleEnabled => _isShuffleEnabled;
  ValueListenable<RepeatMode> get repeatMode => _repeatMode;
  ValueListenable<double> get currentSpeedListenable => _currentSpeed;
  ValueListenable<double> get currentPitchListenable => _currentPitch;
  ValueNotifier<String?> get playerErrorMessage => _playerErrorMessage;
  ValueNotifier<bool> get isInitializing => _isInitializing;
  ValueNotifier<Duration?> get sleepTimerRemaining =>
      _sleepTimer.remainingNotifier;
  ValueNotifier<String?> get playbackContext => _playbackContext;
  AudioPlayer get player => _primaryPlayer;
  List<SongModel> get playlist => _queueManager.orderedPlaylist;
  int? get currentIndex =>
      _isSASStream
          ? sasCurrentIndex
          : (_currentSong.value == null ? null : _queueManager.currentIndex);
  bool get isSASStream => _isSASStream;
  Map<String, dynamic>? get sasMetadata => _sasMetadata;
  ValueListenable<PlayerLifecycleState> get lifecycleStateListenable =>
      lifecycleState;

  SonoPlayer._internal() : super() {
    //initialize audio effects for audio pipeline
    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
    }

    //create primary player with audio effects pipeline
    _primaryPlayer = AudioPlayer(
      audioLoadConfiguration: _minimalBufferConfig,
      audioPipeline: _buildAudioPipeline(),
    );

    _sleepTimer = _SleepTimerController(onTimerFired: _onSleepTimerFired);
  }

  /// Builds the audio pipeline with effects for the current platform
  AudioPipeline? _buildAudioPipeline() {
    if (Platform.isAndroid) {
      final effects = <AndroidAudioEffect>[];
      if (_equalizer != null) effects.add(_equalizer!);
      return effects.isNotEmpty
          ? AudioPipeline(androidAudioEffects: effects)
          : null;
    }
    return null;
  }

  //============================================================================
  // INITIALIZATION
  //============================================================================

  void initialize() {
    if (_isInitialized) return;

    _setupPlayerListeners(_primaryPlayer);
    _isInitialized = true;
    _setLifecycleState(PlayerLifecycleState.ready);
    _broadcastState();

    _librarySettings.coverRotationEnabled.addListener(_onCoverRotationChanged);

    //load settings asynchronously => dont block initialization
    _loadSettingsAsync();
  }

  void _onCoverRotationChanged() {
    final enabled = _librarySettings.coverRotationEnabled.value;

    if (albumCoverRotationEnabled.value != enabled) {
      albumCoverRotationEnabled.value = enabled;
      _broadcastState();

      if (kDebugMode) {
        debugPrint('[Player] Album cover rotation updated: $enabled');
      }
    }
  }

  Future<void> _loadSettingsAsync() async {
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      await loadSettings();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Settings load failed (non-critical): $e');
      }
    }
  }

  void _setupPlayerListeners(AudioPlayer player) {
    _subscriptions.add(
      player.playerStateStream.listen(
        (state) {
          if (player == _currentPlayer) {
            _broadcastState();
          }
          _handleProcessingStateChange(player, state.processingState);
        },
        onError: (error) {
          //silently handle player state errors
          if (kDebugMode) {
            debugPrint('Player state stream error: $error');
          }
        },
      ),
    );

    _subscriptions.add(
      player.positionStream.listen(
        (pos) {
          if (player == _currentPlayer && !_isCrossfading) {
            //always update position immediately
            _position.value = pos;
            //debounce expensive state broadcast
            _stateBroadcaster.schedule(_broadcastState);
            _checkCrossfadeTrigger(pos);
          }
        },
        onError: (error) {
          //silently handle position stream errors
          if (kDebugMode) {
            debugPrint('Position stream error: $error');
          }
        },
      ),
    );

    _subscriptions.add(
      player.durationStream.listen(
        (dur) {
          if (player == _currentPlayer && dur != null) {
            _duration.value = dur;
            _broadcastState();
          }
        },
        onError: (error) {
          //silently handle duration stream errors
          if (kDebugMode) {
            debugPrint('Duration stream error: $error');
          }
        },
      ),
    );

    _subscriptions.add(
      player.speedStream.listen(
        (speed) {
          if (player == _currentPlayer && _currentSpeed.value != speed) {
            _currentSpeed.value = speed;
            _broadcastState();
          }
        },
        onError: (error) {
          //silently handle speed stream errors
          if (kDebugMode) {
            debugPrint('Speed stream error: $error');
          }
        },
      ),
    );
  }

  /// Re-attaches all stream listeners to current primary player
  /// Must be called after swapping primary/secondary players during gapless or crossfade
  void _reattachListenersToCurrentPlayer() {
    if (kDebugMode) {
      debugPrint('[Player] Re-attaching listeners to current player');
    }

    _subscriptions.cancelAll();

    //re-setup all listeners on current primary player
    _setupPlayerListeners(_primaryPlayer);

    if (kDebugMode) {
      debugPrint('[Player] Listeners re-attached successfully');
    }
  }

  void _checkCrossfadeTrigger(Duration currentPosition) {
    if (!_isInitialized || _isCrossfading) return;
    if (!_primaryPlayer.playing) return;

    final duration = _primaryPlayer.duration;
    if (duration == null || duration.inSeconds == 0) return;

    //safety check: dont trigger if position seems invalid
    if (currentPosition > duration) return;
    if (currentPosition.inSeconds < 0) return;

    final remaining = duration - currentPosition;

    //for crossfade mode: trigger crossfade when near end
    if (_crossfadeEnabled) {
      //add safety margin => only trigger if remaining time is positive and within crossfade window
      if (remaining.inMilliseconds < 100 || remaining > _crossfadeDuration) {
        return;
      }
      final nextSong = _queueManager.peekNext(_repeatMode.value);
      if (nextSong == null) return;
      _initiateCrossfade();
    } else {
      //for gapless mode: preload next song 10 seconds before end
      const preloadTrigger = Duration(seconds: 10);
      //add safety margin
      if (remaining.inMilliseconds < 100 || remaining > preloadTrigger) return;

      //skip if already preloading or secondary player is ready
      if (_isPreloading ||
          _secondaryPlayer?.processingState == ProcessingState.ready) {
        return;
      }

      final nextSong = _queueManager.peekNext(_repeatMode.value);
      if (nextSong == null) return;

      _preloadNextSong(nextSong);
    }
  }

  //============================================================================
  // SETTINGS
  //============================================================================

  Future<void> loadSettings() async {
    try {
      final results = await Future.wait([
        _playbackSettings.getCrossfadeEnabled().timeout(
          const Duration(seconds: 2),
        ),
        _playbackSettings.getCrossfadeDuration().timeout(
          const Duration(seconds: 2),
        ),
        _playbackSettings.getSpeed().timeout(const Duration(seconds: 2)),
        _playbackSettings.getPitch().timeout(const Duration(seconds: 2)),
        _librarySettings.getCoverRotationEnabled().timeout(
          const Duration(seconds: 2),
        ),
      ]);

      _crossfadeEnabled = results[0] as bool;
      _crossfadeDuration = Duration(seconds: results[1] as int);

      final speed = results[2] as double;
      final pitch = results[3] as double;
      albumCoverRotationEnabled.value = results[4] as bool;

      if (_currentSpeed.value != speed) {
        _currentSpeed.value = speed;
        await _primaryPlayer.setSpeed(speed);
        if (_secondaryPlayer != null) {
          await _secondaryPlayer!.setSpeed(speed);
        }
      }

      if (_currentPitch.value != pitch) {
        _currentPitch.value = pitch;
        await _primaryPlayer.setPitch(pitch);
        if (_secondaryPlayer != null) {
          await _secondaryPlayer!.setPitch(pitch);
        }
      }

      await loadLastfmSettings();

      //initialize audio effects asynchronously
      _loadEqualizerSettings();

      _broadcastState();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Settings loading failed, using defaults: $e');
      }
      _crossfadeEnabled = false;
      _crossfadeDuration = const Duration(seconds: 5);
    }
  }

  void setCrossfadeEnabled(bool enabled) {
    _crossfadeEnabled = enabled;
    _broadcastState();
    if (kDebugMode) {
      debugPrint('[Player] Crossfade immediately set to: $enabled');
    }
  }

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    _broadcastState();
    if (kDebugMode) {
      debugPrint(
        '[Player] Crossfade duration immediately set to: ${duration.inSeconds}s',
      );
    }
  }

  Future<void> loadLastfmSettings() async {
    _lastfmScrobblingEnabled =
        (await _prefsService.getBool(lastfmScrobblingEnabledKeyInPlayer)) ??
        true;
  }

  //============================================================================
  // PLAYBACK PERSISTENCE
  //============================================================================

  /// saves current playback state to preferences for restoration
  /// only saves meaningful state => called on queue changes, track changes, app pause and stop
  Future<void> savePlaybackSnapshot() async {
    try {
      //dont save if queue is empty or in SAS mode
      if (_queueManager.isEmpty ||
          _isSASStream ||
          _playbackMode != _PlaybackMode.local) {
        if (kDebugMode) {
          debugPrint('[Snapshot] Skipping save => empty queue or SAS mode');
        }
        return;
      }

      final snapshot = PlaybackSnapshot(
        queueSongIds: _queueManager.originalPlaylist.map((s) => s.id).toList(),
        currentIndex: _queueManager.currentIndex,
        positionMs: _position.value.inMilliseconds,
        shuffleEnabled: _isShuffleEnabled.value,
        repeatMode: _repeatMode.value.name,
        playbackSpeed: _currentSpeed.value,
        playbackPitch: _currentPitch.value,
        playbackContext: _playbackContext.value,
        wasPlaying: _isPlaying.value,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      final jsonString = jsonEncode(snapshot.toJson());
      await _prefsService.setString(playbackSnapshotKey, jsonString);

      if (kDebugMode) {
        debugPrint('[Snapshot] Saved: $snapshot');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Snapshot] Save failed: $e');
      }
      //non-critical error => dont throw
    }
  }

  /// clears saved playback snapshot from preferences
  /// should be called when user explicitly dismisses the player
  Future<void> clearPlaybackSnapshot() async {
    try {
      final prefs = await _prefsService.prefs;
      await prefs.remove(playbackSnapshotKey);

      if (kDebugMode) {
        debugPrint('[Snapshot] Cleared playback snapshot');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Snapshot] Clear failed: $e');
      }
      //non-critical error => dont throw
    }
  }

  /// restores playback state from a saved snapshot
  /// should be called after audio permissions are granted and OnAudioQuery is ready (IMPORTANT)
  /// rebuilds the queue and seeks to saved position
  Future<void> restorePlaybackSnapshot() async {
    try {
      //check if resume after reboot is enabled
      final resumeEnabled =
          await _playbackSettings.getResumeAfterRebootEnabled();
      if (!resumeEnabled) {
        if (kDebugMode) {
          debugPrint(
            '[Snapshot] Resume after reboot is disabled, skipping restore',
          );
        }
        _isInitializing.value = false;
        return;
      }

      final jsonString = await _prefsService.getString(playbackSnapshotKey);
      if (jsonString == null || jsonString.isEmpty) {
        if (kDebugMode) {
          debugPrint('[Snapshot] No saved snapshot found');
        }
        _isInitializing.value = false;
        return;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final snapshot = PlaybackSnapshot.fromJson(json);

      if (!snapshot.isValid) {
        if (kDebugMode) {
          debugPrint('[Snapshot] Invalid snapshot, skipping restore');
        }
        _isInitializing.value = false;
        return;
      }

      if (kDebugMode) {
        debugPrint('[Snapshot] Restoring: $snapshot');
      }

      //query all songs by their IDs using OnAudioQuery
      //query all songs once and filter by ID
      final allSongs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      //create a map for O(1) lookup
      final songMap = {for (var song in allSongs) song.id: song};

      //restore songs in original order => skipping missing ones
      final List<SongModel> restoredSongs = [];
      for (final songId in snapshot.queueSongIds) {
        final song = songMap[songId];
        if (song != null) {
          restoredSongs.add(song);
        } else {
          if (kDebugMode) {
            debugPrint('[Snapshot] Song $songId not found, skipping');
          }
        }
      }

      if (restoredSongs.isEmpty) {
        if (kDebugMode) {
          debugPrint('[Snapshot] No songs could be restored');
        }
        _isInitializing.value = false;
        return;
      }

      //clamp index to valid range in case some songs were skipped
      final clampedIndex = snapshot.currentIndex.clamp(
        0,
        restoredSongs.length - 1,
      );

      //clear any existing queue and set restored playlist
      _queueManager.clear();
      _queueManager.setPlaylist(restoredSongs, clampedIndex);

      //restore shuffle state (this may reorder the queue)
      if (snapshot.shuffleEnabled != _isShuffleEnabled.value) {
        _queueManager.toggleShuffle();
        _isShuffleEnabled.value = snapshot.shuffleEnabled;
      }

      //restore repeat mode
      final restoredRepeatMode = _parseRepeatMode(snapshot.repeatMode);
      _repeatMode.value = restoredRepeatMode;
      final loopMode =
          restoredRepeatMode == RepeatMode.one ? LoopMode.one : LoopMode.off;
      await _primaryPlayer.setLoopMode(loopMode);

      //restore speed and pitch
      if (_currentSpeed.value != snapshot.playbackSpeed) {
        _currentSpeed.value = snapshot.playbackSpeed;
        await _primaryPlayer.setSpeed(snapshot.playbackSpeed);
      }
      if (_currentPitch.value != snapshot.playbackPitch) {
        _currentPitch.value = snapshot.playbackPitch;
        await _primaryPlayer.setPitch(snapshot.playbackPitch);
      }

      //restore playback context
      _playbackContext.value = snapshot.playbackContext;

      //load the current song into player WITHOUT playing it
      final currentSong = _queueManager.currentSong;
      if (currentSong == null) {
        if (kDebugMode) {
          debugPrint('[Snapshot] No current song after restore');
        }
        _isInitializing.value = false;
        return;
      }

      //load the audio source
      final songUri = Uri.parse(currentSong.uri!);
      final AudioSource audioSource;
      if (songUri.scheme == 'content') {
        audioSource = AudioSource.uri(songUri);
      } else {
        audioSource = AudioSource.uri(Uri.file(currentSong.uri!));
      }

      final loadedDuration = await _primaryPlayer.setAudioSource(
        audioSource,
        initialPosition: Duration(milliseconds: snapshot.positionMs),
      );

      //set lifecycle to PAUSED FIRST before updating any observables
      //this prevents UI animations from triggering when currentSong changes
      _setLifecycleState(PlayerLifecycleState.paused);

      //clear initializing flag before state updates
      _isInitializing.value = false;

      //now update state
      _currentSong.value = currentSong;
      _duration.value = loadedDuration ?? currentSong.durationMsDuration();
      _position.value = Duration(milliseconds: snapshot.positionMs);

      //update media item
      _updateMediaItemAsync(currentSong, loadedDuration);

      _updateQueueNotifier();

      //broadcast the paused state
      _broadcastState();

      if (kDebugMode) {
        debugPrint(
          '[Snapshot] Restored successfully. Queue: ${restoredSongs.length} songs, '
          'Index: $clampedIndex, Position: ${snapshot.positionMs}ms',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Snapshot] Restore failed: $e');
      }
      CrashlyticsService.instance.recordError(
        e,
        stackTrace,
        reason: 'Playback snapshot restore failed',
      );
      //clear initializing flag even on error
      _isInitializing.value = false;
      //non-critical error => dont throw
    }
  }

  /// Starts periodic position saving timer
  void _startPositionSaveTimer() {
    //cancel existing timer if any
    _positionSaveTimer?.cancel();

    //save position every 15 seconds during playback
    _positionSaveTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => savePlaybackSnapshot(),
    );

    if (kDebugMode) {
      debugPrint('[PositionSave] Periodic saving started (15s interval)');
    }
  }

  /// Stops periodic position saving timer
  void _stopPositionSaveTimer() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;

    if (kDebugMode) {
      debugPrint('[PositionSave] Periodic saving stopped');
    }
  }

  /// Helper to parse repeat mode string to enum
  RepeatMode _parseRepeatMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'one':
        return RepeatMode.one;
      case 'all':
        return RepeatMode.all;
      default:
        return RepeatMode.off;
    }
  }

  //============================================================================
  // PLAYBACK CONTROL
  //============================================================================

  @override
  Future<void> play() async {
    if (_currentSong.value == null) return;

    //clear any previous error when user explicitly tries to play
    _playerErrorMessage.value = null;

    //start periodic position saving
    _startPositionSaveTimer();

    //if player idle => reload current song
    if (_primaryPlayer.processingState == ProcessingState.idle) {
      try {
        await _playSongInternal(_currentSong.value!);
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to resume from idle: $e');
        }
        return;
      }
    }

    try {
      await _primaryPlayer.play();
      _setLifecycleState(PlayerLifecycleState.playing);
      _broadcastState();
      _updateFavoriteStatusAsync();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to play: $e');
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _primaryPlayer.pause();
      _setLifecycleState(PlayerLifecycleState.paused);

      //stop periodic position saving and save one final time
      _stopPositionSaveTimer();
      await savePlaybackSnapshot();

      _broadcastState();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to pause: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    //stop periodic position saving and save one final snapshot
    _stopPositionSaveTimer();
    await savePlaybackSnapshot();

    await _cancelCrossfade();

    await _primaryPlayer.stop();
    await _primaryPlayer.setVolume(1.0);

    //sispose secondary player to free memory
    if (_secondaryPlayer != null) {
      await _disposeSecondaryPlayer(graceful: false);
    }

    _setLifecycleState(PlayerLifecycleState.idle);

    _isPlaying.value = false;
    _currentSong.value = null;
    _position.value = Duration.zero;
    _duration.value = Duration.zero;
    _playbackContext.value = null;
    _sleepTimer.cancel();

    //clear queue to fully dismiss the player UI
    _queueManager.clear();
    _updateQueueNotifier();

    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.play],
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        queueIndex: null,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    if (!SASManager().checkPlaybackControl()) return;

    if (_isCrossfading) {
      await _cancelCrossfade();
    }

    await _primaryPlayer.seek(position);
    _position.value = position;
    _broadcastState();

    //immediately broadcast seek position to SAS clients
    SASManager().broadcastPosition(position);
  }

  void playPause() {
    if (!SASManager().checkPlaybackControl()) return;

    if (_primaryPlayer.playing && !_isCrossfading) {
      pause();
    } else {
      play();
    }
  }

  //============================================================================
  // TRACK NAVIGATION
  //============================================================================

  @override
  Future<void> skipToNext() async {
    if (!SASManager().checkPlaybackControl()) return;

    if (_queueManager.isEmpty) {
      await stop();
      return;
    }

    if (_crossfadeEnabled && _currentSong.value != null && !_isCrossfading) {
      final success = _queueManager.moveToNext(_repeatMode.value);
      if (!success) {
        await stop();
        return;
      }
      await _crossfadeToCurrentSong();
    } else {
      final success = _queueManager.moveToNext(_repeatMode.value);
      if (!success) {
        await stop();
        return;
      }

      //check if next song is already preloaded on secondary player
      final nextSong = _queueManager.currentSong;
      if (nextSong != null &&
          _secondaryPlayer != null &&
          _secondaryPlayer!.processingState == ProcessingState.ready) {
        await _swapToPreloadedSong();
      } else {
        await _playCurrentSong();
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (!SASManager().checkPlaybackControl()) return;

    if (_queueManager.isEmpty) {
      await stop();
      return;
    }

    //if more than 3 seconds in => restart current track
    if (_primaryPlayer.position.inSeconds > 3 && !_isCrossfading) {
      await seek(Duration.zero);
      return;
    }

    if (_crossfadeEnabled && _currentSong.value != null && !_isCrossfading) {
      final success = _queueManager.moveToPrevious(_repeatMode.value);
      if (!success) {
        await seek(Duration.zero);
        return;
      }
      await _crossfadeToCurrentSong();
    } else {
      final success = _queueManager.moveToPrevious(_repeatMode.value);
      if (!success) {
        await seek(Duration.zero);
        return;
      }
      await _playCurrentSong();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (!SASManager().checkPlaybackControl()) return;

    if (index < 0 || index >= _queueManager.length) return;

    if (_crossfadeEnabled && _currentSong.value != null) {
      _queueManager.moveTo(index);
      await _crossfadeToCurrentSong();
    } else {
      _queueManager.moveTo(index);
      await _playCurrentSong();
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final index = playlist.indexWhere((s) => s.uri == mediaItem.id);
    if (index != -1) {
      await skipToQueueItem(index);
    }
  }

  //============================================================================
  // PLAYLIST MANAGEMENT
  //============================================================================

  Future<void> playNewPlaylist(
    List<SongModel> newPlaylist,
    int index, {
    String? context,
  }) async {
    //block local playback when connected as SAS client
    if (!SASManager().checkPlaybackControl()) {
      _playerErrorMessage.value =
          'Cannot play local music while connected to SAS';
      return;
    }

    if (newPlaylist.isEmpty) {
      _playerErrorMessage.value = 'Playlist is empty';
      await stop();
      return;
    }

    //clear any previous errors
    _playerErrorMessage.value = null;

    _playbackMode = _PlaybackMode.local;
    _playbackContext.value = context;

    final clampedIndex = index.clamp(0, newPlaylist.length - 1);
    _queueManager.setPlaylist(newPlaylist, clampedIndex);
    _isShuffleEnabled.value = _queueManager.shuffleEnabled;

    try {
      await _playCurrentSong();
      _updateQueueNotifier();
      //save snapshot after successfully loading new playlist
      savePlaybackSnapshot();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in playNewPlaylist: $e');
      }
      _playerErrorMessage.value = 'Failed to start playback';
      _setLifecycleState(PlayerLifecycleState.error);
    }
  }

  Future<void> addSongsToQueue(List<SongModel> songs) async {
    if (!SASManager().checkPlaybackControl()) return;
    if (songs.isEmpty) return;

    if (_queueManager.isEmpty) {
      await playNewPlaylist(songs, 0);
      return;
    }

    _queueManager.addToQueue(songs);
    _updateQueueNotifier();
  }

  Future<void> addSongToPlayNext(SongModel song) async {
    if (!SASManager().checkPlaybackControl()) return;

    if (_queueManager.isEmpty) {
      await playNewPlaylist([song], 0);
      return;
    }

    _queueManager.insertPlayNext(song);
    _updateQueueNotifier();
  }

  Future<void> clearQueue() async {
    final current = _currentSong.value;
    if (current == null) {
      await stop();
      return;
    }

    _queueManager.clearExceptCurrent();
    _updateQueueNotifier();
    playbackState.add(playbackState.value.copyWith(queueIndex: 0));
  }

  Future<void> reorderQueueItem(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _queueManager.reorder(oldIndex, newIndex);
    _updateQueueNotifier();
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = playlist.indexWhere((s) => s.uri == mediaItem.id);
    if (index < 0) return;

    final wasCurrentSong = index == _queueManager.currentIndex;

    _queueManager.removeAt(index);

    if (_queueManager.isEmpty) {
      await stop();
      return;
    }

    if (wasCurrentSong) {
      await _playCurrentSong();
    }

    _updateQueueNotifier();
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    super.queue.add(queue);
    queueNotifier.value = queue;
    await super.updateQueue(queue);
  }

  void _updateQueueNotifier() {
    final mediaItems = playlist.map((s) => s.toMediaItem()).toList();
    updateQueue(mediaItems);
  }

  //============================================================================
  // SHUFFLE & REPEAT
  //============================================================================

  void toggleShuffle() {
    if (!SASManager().checkPlaybackControl()) return;

    _queueManager.toggleShuffle();
    _isShuffleEnabled.value = _queueManager.shuffleEnabled;
    _updateQueueNotifier();

    playbackState.add(
      playbackState.value.copyWith(
        shuffleMode:
            _isShuffleEnabled.value
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none,
        queueIndex: _queueManager.currentIndex,
      ),
    );

    //save snapshot when shuffle state changes
    savePlaybackSnapshot();
  }

  void toggleRepeat() {
    if (!SASManager().checkPlaybackControl()) return;
    final current = _repeatMode.value;
    RepeatMode next;
    LoopMode playerLoop;

    switch (current) {
      case RepeatMode.off:
        next = RepeatMode.all;
        playerLoop = LoopMode.off;
        break;
      case RepeatMode.all:
        next = RepeatMode.one;
        playerLoop = LoopMode.one;
        break;
      case RepeatMode.one:
        next = RepeatMode.off;
        playerLoop = LoopMode.off;
        break;
    }

    _repeatMode.value = next;
    _primaryPlayer.setLoopMode(playerLoop);
    _secondaryPlayer?.setLoopMode(playerLoop);

    playbackState.add(
      playbackState.value.copyWith(repeatMode: _toAudioServiceRepeatMode(next)),
    );

    savePlaybackSnapshot();
  }

  //============================================================================
  // SPEED & PITCH
  //============================================================================

  @override
  Future<void> setSpeed(double speed) async {
    final clampedSpeed = speed.clamp(0.25, 4.0);
    await _primaryPlayer.setSpeed(clampedSpeed);
    await _secondaryPlayer?.setSpeed(clampedSpeed);
    _currentSpeed.value = clampedSpeed;
    await _playbackSettings.setSpeed(clampedSpeed);
    _broadcastState();
  }

  Future<void> setPitch(double pitch) async {
    final clampedPitch = pitch.clamp(0.5, 2.0);
    await _primaryPlayer.setPitch(clampedPitch);
    await _secondaryPlayer?.setPitch(clampedPitch);
    _currentPitch.value = clampedPitch;
    await _playbackSettings.setPitch(clampedPitch);
    _broadcastState();
  }

  //============================================================================
  // AUDIO EFFECTS (EQUALIZER)
  //============================================================================

  ///loads equalizer settings from database
  Future<void> _loadEqualizerSettings() async {
    if (_equalizer == null) return;

    try {
      //get parameters and load saved settings
      final params = await _equalizer!.parameters;
      final enabled = await _audioEffectsService.getEqualizerEnabled();
      final bandLevels = await _audioEffectsService.getAllEqualizerBandLevels();

      //apply enabled state
      await _equalizer!.setEnabled(enabled);

      //apply band levels
      for (int i = 0; i < params.bands.length; i++) {
        final savedGain = bandLevels[i];
        if (savedGain != null) {
          await params.bands[i].setGain(savedGain);
        }
      }

      debugPrint(
        'SonoPlayer: Equalizer settings loaded (enabled: $enabled, bands: ${bandLevels.length})',
      );
    } catch (e) {
      debugPrint('SonoPlayer: Error loading equalizer settings: $e');
    }
  }

  ///sets whether equalizer is enabled
  Future<void> setEqualizerEnabled(bool enabled) async {
    if (_equalizer == null) return;

    try {
      await _equalizer!.setEnabled(enabled);
      await _audioEffectsService.setEqualizerEnabled(enabled);
      debugPrint('SonoPlayer: Equalizer enabled: $enabled');
    } catch (e) {
      debugPrint('SonoPlayer: Error setting equalizer enabled: $e');
    }
  }

  ///sets the gain for a specific equalizer band
  Future<void> setEqualizerBandLevel(int bandIndex, double gain) async {
    if (_equalizer == null) return;

    try {
      final params = await _equalizer!.parameters;
      if (bandIndex >= 0 && bandIndex < params.bands.length) {
        await params.bands[bandIndex].setGain(gain);
        await _audioEffectsService.setEqualizerBandLevel(bandIndex, gain);
        debugPrint('SonoPlayer: Set EQ band $bandIndex to ${gain}dB');
      }
    } catch (e) {
      debugPrint('SonoPlayer: Error setting equalizer band level: $e');
    }
  }

  ///gets the equalizer parameters (for UI access to bands)
  Future<AndroidEqualizerParameters?> getEqualizerParameters() async {
    if (_equalizer == null) return null;
    try {
      return await _equalizer!.parameters;
    } catch (e) {
      debugPrint('SonoPlayer: Error getting equalizer parameters: $e');
      return null;
    }
  }

  ///gets the equalizer instance (for direct access in UI)
  AndroidEqualizer? get equalizer => _equalizer;

  //============================================================================
  // SLEEP TIMER
  //============================================================================

  void setSleepTimer(Duration? duration) {
    if (duration != null && duration.inSeconds > 0) {
      _sleepTimer.start(duration);
    } else {
      _sleepTimer.cancel();
    }
  }

  void _onSleepTimerFired() {
    if (kDebugMode) {
      debugPrint('Sleep timer fired: pausing playback');
    }
    pause();
  }

  //============================================================================
  // FAVORITES
  //============================================================================

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    final song = _currentSong.value;
    if (song == null) return;

    if (rating.hasHeart()) {
      if (rating.isRated()) {
        await _favoritesService.addSongToFavorites(song.id);
      } else {
        await _favoritesService.removeSongFromFavorites(song.id);
      }
    }
    await _updateFavoriteStatusAsync();
  }

  Future<void> _updateFavoriteStatusAsync() async {
    final song = _currentSong.value;
    if (song == null || mediaItem.value == null) return;

    try {
      final isFavorite = await _favoritesService.isSongFavorite(song.id);
      mediaItem.add(
        mediaItem.value!.copyWith(rating: Rating.newHeartRating(isFavorite)),
      );
    } catch (e) {
      //non-critical => ignore errors
    }
  }

  //============================================================================
  // NETWORK STREAM (SAS SUPPORT)
  //============================================================================

  /// Loads a network stream for SAS playback
  /// This switches the player to network mode with appropriate buffering
  Future<void> loadNetworkStream(
    String streamUrl, {
    Duration? initialPosition,
    bool autoPlay = false,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Loading network stream: $streamUrl');
      }

      _setLifecycleState(PlayerLifecycleState.sasConnecting);

      await _cancelCrossfade();

      await _disposeSecondaryPlayer(graceful: true);

      //always recreate player when switching to network mode to ensure proper buffer configuration
      if (_playbackMode != _PlaybackMode.network) {
        if (kDebugMode) {
          debugPrint('Switching to network mode with larger buffers');
        }

        //stop and dispose the current player before recreating
        try {
          if (_primaryPlayer.processingState != ProcessingState.idle) {
            await _primaryPlayer.stop();
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error stopping player before dispose: $e');
          }
        }

        await _primaryPlayer.dispose();

        //create new player with network buffer configuration
        //no audio pipeline here: effects hold a reference to the previous player
        //and just_audio asserts _player == null on _setup. SAS doesnt need EQ
        _primaryPlayer = AudioPlayer(
          audioLoadConfiguration: _networkBufferConfig,
        );
        _setupPlayerListeners(_primaryPlayer);
        _playbackMode = _PlaybackMode.network;
      }

      //load the network stream with timeout
      final audioSource = AudioSource.uri(Uri.parse(streamUrl));
      final loadedDuration = await _primaryPlayer
          .setAudioSource(
            audioSource,
            initialPosition: initialPosition ?? Duration.zero,
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Network stream took too long to load');
            },
          );

      if (loadedDuration != null) {
        _duration.value = loadedDuration;
      }
      _position.value = initialPosition ?? Duration.zero;

      _setLifecycleState(PlayerLifecycleState.ready);

      if (kDebugMode) {
        debugPrint('Network stream loaded successfully');
      }

      if (autoPlay) {
        await play();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load network stream: $e');
      }
      _setLifecycleState(PlayerLifecycleState.error);
      rethrow;
    }
  }

  /// Switches back to local playback mode with minimal buffer configuration
  /// Called when returning to local file playback after network streaming
  Future<void> _switchToLocalMode() async {
    if (_playbackMode == _PlaybackMode.local) return;

    if (kDebugMode) {
      debugPrint('Switching back to local mode with minimal buffers');
    }

    await _primaryPlayer.dispose();

    //recreate equalizer: the old instance is still bound to the disposed player
    //and just_audio asserts _player == null on effect._setup
    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
    }

    _primaryPlayer = AudioPlayer(
      audioLoadConfiguration: _minimalBufferConfig,
      audioPipeline: _buildAudioPipeline(),
    );
    _setupPlayerListeners(_primaryPlayer);
    _playbackMode = _PlaybackMode.local;

    //restore saved EQ settings onto the fresh equalizer
    await _loadEqualizerSettings();
  }

  /// Updates player state with SAS metadata to create a "virtual" song
  /// This ensures UI shows correct metadata even though the audio source is a network stream
  void setSASMetadata({
    required String title,
    required String artist,
    required String album,
    required int durationMs,
    String? artworkUrl,
    int? songId,
  }) {
    _isSASStream = true;
    _playbackContext.value = 'stream: SAS';
    _sasMetadata = {
      'title': title,
      'artist': artist,
      'album': album,
      'duration': durationMs,
      'artworkUrl': artworkUrl,
      'songId': songId,
    };

    //IMPORTANT(!): clear currentSong when entering SAS mode
    //this ensures fullscreen player shows SAS metadata instead of old local song
    _currentSong.value = null;

    //create a virtual SongModel-like representation
    //note: cant create a real SongModel since its from on_audio_query
    //so we update the observable state directly
    _duration.value = Duration(milliseconds: durationMs);

    //update MediaItem for system controls
    final item = MediaItem(
      id: artworkUrl ?? 'sas_stream',
      title: title,
      artist: artist,
      album: album,
      duration: Duration(milliseconds: durationMs),
      artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
    );
    mediaItem.add(item);

    _broadcastState();

    if (kDebugMode) {
      debugPrint('[Player] Set SAS metadata: $title by $artist');
    }
  }

  /// Clears SAS mode and resets to local playback state
  void clearSASMetadata() {
    _isSASStream = false;
    _sasMetadata = null;
    sasCurrentIndex = null;
    _currentSong.value = null;
    _duration.value = Duration.zero;
    _position.value = Duration.zero;

    if (kDebugMode) {
      debugPrint('[Player] Cleared SAS metadata');
    }
  }

  /// Sets the player lifecycle state and notifies listeners
  void _setLifecycleState(PlayerLifecycleState newState) {
    final stateChanged = _lifecycleState != newState;

    if (stateChanged) {
      _lifecycleState = newState;
      lifecycleState.value = newState;

      if (kDebugMode) {
        debugPrint('[Player] Lifecycle: $_lifecycleState');
      }
    }

    //always sync initializing flag with lifecycle state
    //this prevents stuck "Loading..." badge in edge cases
    final shouldBeInitializing =
        newState == PlayerLifecycleState.initializing ||
        newState == PlayerLifecycleState.sasConnecting;

    if (_isInitializing.value != shouldBeInitializing) {
      if (kDebugMode) {
        debugPrint(
          '[Player] Syncing initializing flag: $shouldBeInitializing (state: $newState)',
        );
      }
      _isInitializing.value = shouldBeInitializing;
    }
  }

  /// Exits SAS mode and returns to local playback mode
  Future<void> exitSASMode() async {
    if (!_isSASStream) return;

    if (kDebugMode) {
      debugPrint('[Player] Exiting SAS mode');
    }

    //stop current playback
    await stop();

    clearSASMetadata();

    //switch back to local mode if needed
    await _switchToLocalMode();

    _setLifecycleState(PlayerLifecycleState.idle);

    if (kDebugMode) {
      debugPrint('[Player] SAS mode exited, ready for local playback');
    }
  }

  /// Play the currently loaded network stream (SAS client mode)
  /// Bypasses the _currentSong null check in play()
  Future<void> playStream() async {
    if (!_isSASStream) return;
    await _primaryPlayer.play();
    _setLifecycleState(PlayerLifecycleState.sasPlaying);
    _broadcastState();
  }

  /// Pause the currently loaded network stream (SAS client mode)
  /// Skips playback snapshot saving that pause() does
  Future<void> pauseStream() async {
    if (!_isSASStream) return;
    await _primaryPlayer.pause();
    _setLifecycleState(PlayerLifecycleState.paused);
    _broadcastState();
  }

  /// Seek within the current network stream (SAS client mode)
  /// Does NOT call broadcastPosition (avoids loop on client side)
  Future<void> seekStream(Duration position) async {
    if (!_isSASStream) return;
    await _primaryPlayer.seek(position);
    _position.value = position;
    _broadcastState();
  }

  //============================================================================
  // INTERNAL PLAYBACK
  //============================================================================

  Future<void> _playCurrentSong() async {
    final song = _queueManager.currentSong;
    if (song == null) {
      await stop();
      return;
    }
    await _playSongInternal(song);
  }

  Future<void> playSongFromCurrentPlaylist(int index) async {
    if (index < 0 || index >= _queueManager.length) {
      if (_repeatMode.value == RepeatMode.all && !_queueManager.isEmpty) {
        _queueManager.moveTo(0);
      } else {
        await stop();
        return;
      }
    } else {
      _queueManager.moveTo(index);
    }
    await _playCurrentSong();
  }

  Future<void> _playSongInternal(
    SongModel song, {
    bool isPreloading = false,
  }) async {
    if (!isPreloading) {
      _setLifecycleState(PlayerLifecycleState.initializing);
    }

    try {
      //switch back to local mode if in network mode before
      if (!isPreloading && _playbackMode == _PlaybackMode.network) {
        await _switchToLocalMode();
      }

      //verify song is playable (only for local files => not preloading)
      if (!isPreloading && _playbackMode == _PlaybackMode.local) {
        final isPlayable = await _isSongPlayable(song);
        if (!isPlayable) {
          if (kDebugMode) {
            debugPrint("Unplayable song: '${song.title}'. Skipping.");
          }
          _queueManager.removeSongById(song.id);
          _updateQueueNotifier();

          //check if queue is now empty after removal
          if (_queueManager.isEmpty) {
            _playerErrorMessage.value = 'No playable songs in queue';
            _setLifecycleState(PlayerLifecycleState.error);
            await stop();
            return;
          }

          await skipToNext();
          return;
        }
      }

      //cancel any in-progress crossfade if this is not a preload
      if (!isPreloading && _isCrossfading) {
        await _cancelCrossfade();
      }

      final targetPlayer =
          isPreloading ? _getOrCreateSecondaryPlayer() : _primaryPlayer;

      //dispose secondary player if not preloading => prevents orphaned MediaCodec resources
      if (!isPreloading && _secondaryPlayer != null) {
        if (kDebugMode) {
          debugPrint(
            'PlaySong: Disposing secondary player before loading on primary...',
          );
        }
        final oldSecondary = _secondaryPlayer;
        _secondaryPlayer = null;
        unawaited(
          oldSecondary!
              .dispose()
              .then((_) {
                if (kDebugMode) {
                  debugPrint(
                    'PlaySong: Secondary player disposed successfully',
                  );
                }
              })
              .catchError((e) {
                if (kDebugMode) {
                  debugPrint('PlaySong: Secondary player disposal error: $e');
                }
              }),
        );
      }

      final AudioSource audioSource;
      final songUri = Uri.parse(song.uri!);

      if (songUri.scheme == 'content') {
        audioSource = AudioSource.uri(songUri);
      } else {
        audioSource = AudioSource.uri(Uri.file(song.uri!));
      }

      final loadedDuration = await targetPlayer.setAudioSource(
        audioSource,
        initialPosition: Duration.zero,
      );

      if (!isPreloading) {
        _currentSong.value = song;
        _duration.value = loadedDuration ?? song.durationMsDuration();
        _position.value = Duration.zero;

        RecentsService.instance.addRecentPlay(
          song.id,
          context: _playbackContext.value,
        );

        //update media item with artwork
        _updateMediaItemAsync(song, loadedDuration);

        _prefetchLyrics(song);
      }

      //set playback parameters
      await targetPlayer.setLoopMode(
        _repeatMode.value == RepeatMode.one ? LoopMode.one : LoopMode.off,
      );
      await targetPlayer.setSpeed(_currentSpeed.value);
      await targetPlayer.setPitch(_currentPitch.value);

      if (!isPreloading) {
        await targetPlayer.play();
        _setLifecycleState(PlayerLifecycleState.playing);
        _broadcastState();
        _scrobbleNowPlaying(song);
      }
    } catch (e, stackTrace) {
      await _handlePlaybackError(e, stackTrace, song, isPreloading);
    }
  }

  Future<void> _handlePlaybackError(
    Object e,
    StackTrace stackTrace,
    SongModel song,
    bool isPreloading,
  ) async {
    final safeTitle = song.title.replaceAll(RegExp(r'[^\w\s]'), '');

    if (e is PlayerInterruptedException) {
      if (kDebugMode) {
        debugPrint("Player interrupted for '$safeTitle' - normal behavior");
      }
      return;
    }

    if (e is PlayerException) {
      final message = e.message?.toLowerCase() ?? '';
      final isSourceError =
          message.contains("source error") ||
          message.contains("file not found") ||
          message.contains("loading interrupted") ||
          message.contains("unable to extract") ||
          message.contains("failed to load") ||
          message.contains("invalid source");

      if (isSourceError) {
        if (kDebugMode) {
          debugPrint("Unplayable source for '$safeTitle': ${e.message}");
        }

        if (!isPreloading) {
          _queueManager.removeSongById(song.id);
          _updateQueueNotifier();

          if (!_queueManager.isEmpty) {
            Future.microtask(() => skipToNext());
          } else {
            _playerErrorMessage.value = 'No playable songs remaining';
            _setLifecycleState(PlayerLifecycleState.error);
            Future.microtask(() => stop());
          }
        }
        return;
      }
    }

    if (e.toString().contains('disposed')) {
      if (kDebugMode) {
        debugPrint("Player disposed during '$safeTitle' - ignoring");
      }
      return;
    }

    //handle unexpected errors
    if (!isPreloading) {
      final errorStr = e.toString();
      final truncatedError =
          errorStr.length > 50 ? errorStr.substring(0, 50) : errorStr;
      _playerErrorMessage.value = 'Playback error: $truncatedError';
      _setLifecycleState(PlayerLifecycleState.error);

      //try to skip to next song if available
      if (!_queueManager.isEmpty &&
          _queueManager.currentIndex < _queueManager.length - 1) {
        Future.microtask(() => skipToNext());
      } else {
        Future.microtask(() => stop());
      }
    }

    if (kDebugMode) {
      debugPrint("Unexpected error playing '$safeTitle': $e");
    }

    CrashlyticsService.instance.recordError(
      e,
      stackTrace,
      reason: 'SonoPlayer._playSongInternal error for $safeTitle',
    );

    if (!isPreloading) {
      if (_queueManager.length > 1) {
        Future.microtask(() => skipToNext());
      } else {
        Future.microtask(() => stop());
      }
    }
  }

  Future<bool> _isSongPlayable(SongModel song) async {
    if (song.uri?.startsWith('content://') ?? false) {
      try {
        await _audioQuery.queryArtwork(song.id, ArtworkType.AUDIO, size: 2);
        return true;
      } catch (e) {
        return false;
      }
    } else if (song.uri?.startsWith('/') ?? false) {
      return await File(song.uri!).exists();
    }
    return false;
  }

  //============================================================================
  // CROSSFADE
  //============================================================================

  AudioPlayer _getOrCreateSecondaryPlayer() {
    _secondaryPlayer ??= AudioPlayer(
      audioLoadConfiguration: _minimalBufferConfig,
      audioPipeline: null,
    );
    return _secondaryPlayer!;
  }

  /// preloads next song on secondary player without playing it
  /// used for gapless playback when crossfade is disabled
  Future<void> _preloadNextSong(SongModel song) async {
    if (_playbackMode != _PlaybackMode.local) return;
    if (_isPreloading) return;

    _isPreloading = true;
    try {
      await _playSongInternal(song, isPreloading: true);

      if (kDebugMode) {
        debugPrint('Gapless: Preloaded ${song.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gapless preload failed: $e');
      }
    } finally {
      _isPreloading = false;
    }
  }

  /// Swaps to the preloaded song on secondary player
  Future<void> _swapToPreloadedSong() async {
    if (_secondaryPlayer == null) {
      await _playCurrentSong();
      return;
    }

    try {
      final song = _queueManager.currentSong;
      if (song == null) {
        await stop();
        return;
      }

      //stop current player
      await _primaryPlayer.stop();
      await _primaryPlayer.setVolume(1.0);

      //swap players => dispose old primary to release MediaCodec resources
      final oldPrimary = _primaryPlayer;
      _primaryPlayer = _secondaryPlayer!;
      _secondaryPlayer = null;

      _reattachListenersToCurrentPlayer();

      //dispose old player in background to free native resources
      if (kDebugMode) {
        debugPrint('Gapless: Disposing old primary player...');
      }
      unawaited(
        oldPrimary
            .dispose()
            .then((_) {
              if (kDebugMode) {
                debugPrint('Gapless: Old primary player disposed successfully');
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                debugPrint('Gapless: Old player disposal error: $e');
              }
            }),
      );

      //update state
      _currentSong.value = song;
      _duration.value = _primaryPlayer.duration ?? song.durationMsDuration();
      _position.value = Duration.zero;

      RecentsService.instance.addRecentPlay(
        song.id,
        context: _playbackContext.value,
      );

      //update media item with artwork
      _updateMediaItemAsync(song, _primaryPlayer.duration);

      _prefetchLyrics(song);

      //start playback
      await _primaryPlayer.play();
      _broadcastState();
      _scrobbleNowPlaying(song);

      if (kDebugMode) {
        debugPrint('Gapless: Instant skip to ${song.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gapless swap failed: $e');
      }
      await _playCurrentSong();
    }
  }

  Future<void> _disposeSecondaryPlayer({bool graceful = true}) async {
    if (_secondaryPlayer == null) return;

    try {
      if (graceful && _secondaryPlayer!.playing) {
        //gradual fade out over 200ms
        final steps = 10;
        for (int i = steps; i >= 0; i--) {
          final volume = i / steps;
          await _secondaryPlayer!.setVolume(volume);
          await Future.delayed(Duration(milliseconds: 20));
        }
        await _secondaryPlayer!.stop();
      }

      await _secondaryPlayer!.dispose();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Secondary player disposal error: $e');
      }
    } finally {
      _secondaryPlayer = null;
    }
  }

  Future<void> _initiateCrossfade() async {
    if (_isCrossfading || !_crossfadeEnabled || !_isInitialized) return;

    final nextSong = _queueManager.peekNext(_repeatMode.value);
    if (nextSong == null) return;

    _isCrossfading = true;

    if (kDebugMode) {
      debugPrint('Crossfade: Starting to ${nextSong.title}');
    }

    try {
      //preload next song on secondary player
      final secondary = _getOrCreateSecondaryPlayer();
      await _playSongInternal(nextSong, isPreloading: true);

      //create crossfade controller
      _crossfadeController = _CrossfadeController(
        fadeOutPlayer: _primaryPlayer,
        fadeInPlayer: secondary,
        duration: _crossfadeDuration,
      );

      //execute crossfade
      await _crossfadeController!.execute();

      //swap players => dispose old primary to release MediaCodec resources
      final oldPrimary = _primaryPlayer;
      _primaryPlayer = secondary;
      _secondaryPlayer = null;

      //re-attach listeners to new primary player
      _reattachListenersToCurrentPlayer();

      //dispose old player in background to free native resources
      if (kDebugMode) {
        debugPrint('Crossfade: Disposing old primary player...');
      }
      unawaited(
        oldPrimary
            .dispose()
            .then((_) {
              if (kDebugMode) {
                debugPrint(
                  'Crossfade: Old primary player disposed successfully',
                );
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                debugPrint('Crossfade: Old player disposal error: $e');
              }
            }),
      );

      //move to next song in queue
      _queueManager.moveToNext(_repeatMode.value);

      //update state
      _currentSong.value = nextSong;
      _duration.value =
          _primaryPlayer.duration ?? nextSong.durationMsDuration();

      //update media item
      _updateMediaItemAsync(nextSong, _primaryPlayer.duration);

      //scrobble
      _scrobbleNowPlaying(nextSong);

      _isCrossfading = false;
      _broadcastState();

      if (kDebugMode) {
        debugPrint('Crossfade: Completed to ${nextSong.title}');
      }
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('Crossfade error: $e');
      }
      CrashlyticsService.instance.recordError(e, s, reason: 'Crossfade error');

      await _cancelCrossfade();

      //fall back to regular skip
      _queueManager.moveToNext(_repeatMode.value);
      await _playCurrentSong();
    }
  }

  Future<void> _crossfadeToCurrentSong() async {
    if (_isCrossfading) return;

    final song = _queueManager.currentSong;
    if (song == null) {
      await stop();
      return;
    }

    _isCrossfading = true;

    try {
      final secondary = _getOrCreateSecondaryPlayer();
      await _playSongInternal(song, isPreloading: true);

      _crossfadeController = _CrossfadeController(
        fadeOutPlayer: _primaryPlayer,
        fadeInPlayer: secondary,
        duration: _crossfadeDuration,
      );

      await _crossfadeController!.execute();

      //swap players => dispose old primary to release MediaCodec resources
      final oldPrimary = _primaryPlayer;
      _primaryPlayer = secondary;
      _secondaryPlayer = null;

      //re-attach listeners to new primary player
      _reattachListenersToCurrentPlayer();

      //dispose old player in background to free native resources
      if (kDebugMode) {
        debugPrint('Manual crossfade: Disposing old primary player...');
      }
      unawaited(
        oldPrimary
            .dispose()
            .then((_) {
              if (kDebugMode) {
                debugPrint(
                  'Manual crossfade: Old primary player disposed successfully',
                );
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                debugPrint('Manual crossfade: Old player disposal error: $e');
              }
            }),
      );

      _currentSong.value = song;
      _duration.value = _primaryPlayer.duration ?? song.durationMsDuration();

      _updateMediaItemAsync(song, _primaryPlayer.duration);
      _scrobbleNowPlaying(song);

      _isCrossfading = false;
      _broadcastState();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Manual crossfade error: $e');
      }
      await _cancelCrossfade();
      await _playCurrentSong();
    }
  }

  Future<void> _cancelCrossfade() async {
    _crossfadeController?.dispose();
    _crossfadeController = null;
    _isCrossfading = false;

    try {
      await _primaryPlayer.setVolume(1.0);
      if (_secondaryPlayer != null) {
        await _secondaryPlayer!.stop();
        await _secondaryPlayer!.setVolume(1.0);
      }
    } catch (_) {}
  }

  //============================================================================
  // PROCESSING STATE
  //============================================================================

  void _handleProcessingStateChange(AudioPlayer player, ProcessingState state) {
    if (player != _currentPlayer ||
        state != ProcessingState.completed ||
        _isCrossfading) {
      return;
    }

    //get current song/stream identifier
    final currentSongId = _currentSong.value?.id ?? _sasMetadata?['songId'];

    //debounce ONLY if trying to complete same song twice
    final now = DateTime.now();
    if (_isHandlingCompletion) {
      if (kDebugMode) {
        debugPrint('Ignoring completion event - already handling');
      }
      return;
    }

    //ignore if just handled a completion for SAME song within last 2 seconds
    if (_lastCompletedSongId == currentSongId &&
        _lastCompletionTime != null &&
        now.difference(_lastCompletionTime!).inSeconds < 2) {
      if (kDebugMode) {
        debugPrint('Ignoring duplicate completion for same song/stream');
      }
      return;
    }

    //validate that the song actually finished playing
    final currentPos = _primaryPlayer.position;
    final duration = _primaryPlayer.duration;

    if (duration != null && duration.inSeconds > 0) {
      //only consider it complete if within 2 seconds of the end
      final remaining = duration - currentPos;
      if (remaining.inSeconds > 2) {
        if (kDebugMode) {
          debugPrint(
            'Ignoring false completion - ${remaining.inSeconds}s remaining',
          );
        }
        return;
      }
    }

    _isHandlingCompletion = true;
    _lastCompletionTime = now;
    _lastCompletedSongId = currentSongId;
    _setLifecycleState(PlayerLifecycleState.completed);

    final finishedSong = _currentSong.value;

    //scrobble completed track
    if (finishedSong != null && _lastfmScrobblingEnabled) {
      _scrobbleCompletedTrack(finishedSong);
    }

    //save snapshot when track completes (captures position before moving to next)
    savePlaybackSnapshot();

    //handle repeat/next
    try {
      if (_repeatMode.value == RepeatMode.one) {
        _primaryPlayer.seek(Duration.zero);
        if (!_primaryPlayer.playing) {
          play();
        }
      } else {
        final hasNext =
            _repeatMode.value == RepeatMode.all ||
            _queueManager.currentIndex < _queueManager.length - 1;

        if (hasNext) {
          skipToNext()
              .then((_) {
                if (kDebugMode) {
                  debugPrint('Completed skipToNext after song completion');
                }
              })
              .catchError((error) {
                if (kDebugMode) {
                  debugPrint('Error in skipToNext during completion: $error');
                }
              });
        } else {
          Future.delayed(const Duration(milliseconds: 100), () {
            pause();
            if (_duration.value > Duration.zero) {
              seek(_duration.value);
            }
          });
        }
      }
    } finally {
      //always reset flag, regardless of what happens above
      //use a small delay to ensure async operations have started
      Future.delayed(const Duration(milliseconds: 50), () {
        _isHandlingCompletion = false;
        if (kDebugMode) {
          debugPrint('Reset completion handler flag');
        }
      });
    }
  }

  //============================================================================
  // ARTWORK & MEDIA ITEM
  //============================================================================

  Future<void> _updateMediaItemAsync(
    SongModel song,
    Duration? loadedDuration,
  ) async {
    try {
      final futures = await Future.wait([
        _favoritesService.isSongFavorite(song.id),
        _getAlbumArtUri(song.id),
      ]);

      final isFavorite = futures[0] as bool;
      final artUri = futures[1] as Uri?;

      final item = song.toMediaItem().copyWith(
        artUri: artUri,
        duration: loadedDuration ?? song.durationMsDuration(),
        rating: Rating.newHeartRating(isFavorite),
      );

      mediaItem.add(item);
    } catch (e) {
      //non-critical => use basic media item
      mediaItem.add(song.toMediaItem());
    }
  }

  Future<Uri?> _getAlbumArtUri(int songId) async {
    //check cache first
    final cached = _artworkCache.getArtwork(songId);
    if (cached != null) return cached;

    try {
      final artworkBytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: 512,
        quality: 100,
        format: ArtworkFormat.JPEG,
      );

      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/artwork_$songId.jpg');
        await file.writeAsBytes(artworkBytes, flush: true);
        final uri = Uri.file(file.path);
        _artworkCache.setArtwork(songId, uri);
        return uri;
      }
    } catch (e) {
      //artwork loading is non-critical
    }

    _artworkCache.setArtwork(songId, null);
    return null;
  }

  //============================================================================
  // LYRICS PREFETCH
  //============================================================================

  void _prefetchLyrics(SongModel song) {
    _lyricsCacheService.prefetchLyrics(
      artist: song.artist ?? '',
      title: song.title,
      album: song.album,
      usePrimaryArtistCleanup: false,
    );
    _lyricsCacheService.prefetchLyrics(
      artist: song.artist ?? '',
      title: song.title,
      album: song.album,
      usePrimaryArtistCleanup: true,
    );

    //prefetch next song lyrics
    final nextSong = _queueManager.peekNext(_repeatMode.value);
    if (nextSong != null) {
      _lyricsCacheService.prefetchLyrics(
        artist: nextSong.artist ?? '',
        title: nextSong.title,
        album: nextSong.album,
        usePrimaryArtistCleanup: false,
      );
    }
  }

  //============================================================================
  // LAST.FM SCROBBLING
  //============================================================================

  void _scrobbleNowPlaying(SongModel song) {
    if (!_lastfmScrobblingEnabled) return;

    _lastfmService.isLoggedIn().then((loggedIn) {
      if (loggedIn) {
        _lastfmService
            .updateNowPlaying(
              song.artist ?? "Unknown Artist",
              song.title,
              album: song.album ?? "Unknown Album",
              durationSeconds: _duration.value.inSeconds,
            )
            .catchError((e) {
              if (kDebugMode) {
                debugPrint("Last.fm Now Playing error: $e");
              }
            });
      }
    });
  }

  void _scrobbleCompletedTrack(SongModel song) {
    _lastfmService.isLoggedIn().then((loggedIn) {
      if (!loggedIn) return;

      final durationMs =
          _duration.value.inMilliseconds > 0
              ? _duration.value.inMilliseconds
              : (song.duration ?? 0);

      const minScrobbleMs = 30000;
      const fourMinutesMs = 240000;

      bool shouldScrobble = false;
      if (durationMs >= fourMinutesMs) {
        shouldScrobble = true;
      } else if (durationMs > minScrobbleMs &&
          durationMs >= ((song.duration ?? 0) / 2)) {
        shouldScrobble = true;
      }

      if (shouldScrobble) {
        final timestamp =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 -
            (durationMs ~/ 1000);
        _lastfmService
            .scrobbleTrack(
              song.artist ?? "Unknown Artist",
              song.title,
              timestamp,
              album: song.album ?? "Unknown Album",
            )
            .catchError((e) {
              if (kDebugMode) {
                debugPrint("Last.fm scrobble error: $e");
              }
            });
      }
    });
  }

  //============================================================================
  // STATE BROADCASTING
  //============================================================================

  //track last broadcast song to avoid redundant mediaItem updates
  int? _lastBroadcastSongId;

  void _broadcastState() {
    if (!_isInitialized) return;

    //safety: ensure initializing flag is cleared in stable playback states
    //this prevents stuck "Loading..." badge when state broadcast is triggered
    if (_isInitializing.value &&
        (_lifecycleState == PlayerLifecycleState.playing ||
            _lifecycleState == PlayerLifecycleState.paused ||
            _lifecycleState == PlayerLifecycleState.ready ||
            _lifecycleState == PlayerLifecycleState.idle)) {
      _isInitializing.value = false;
    }

    final playerState = _primaryPlayer.playerState;
    final isCurrentlyPlaying = playerState.playing && !_isCrossfading;
    final wasPlaying = _isPlaying.value;
    _isPlaying.value = isCurrentlyPlaying;

    //manage position save timer based on playing state
    if (isCurrentlyPlaying && !wasPlaying) {
      _startPositionSaveTimer();
    } else if (!isCurrentlyPlaying && wasPlaying) {
      _stopPositionSaveTimer();
    }

    final effectiveDuration =
        _primaryPlayer.duration ??
        _currentSong.value?.durationMsDuration() ??
        Duration.zero;
    _duration.value = effectiveDuration;

    final currentSong = _currentSong.value;

    //only update mediaItem when song changes
    if (currentSong != null && _lastBroadcastSongId != currentSong.id) {
      _lastBroadcastSongId = currentSong.id;
      final cached = _artworkCache.getArtwork(currentSong.id);
      final item =
          cached != null
              ? currentSong.toMediaItem().copyWith(artUri: cached)
              : currentSong.toMediaItem();
      mediaItem.add(item);
    }

    //normal active playback state
    final controls = [
      MediaControl.skipToPrevious,
      isCurrentlyPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _toAudioProcessingState(playerState.processingState),
        playing: isCurrentlyPlaying,
        updatePosition: _position.value,
        bufferedPosition: _position.value,
        speed: _currentSpeed.value,
        queueIndex:
            _queueManager.currentIndex >= 0 ? _queueManager.currentIndex : null,
      ),
    );
  }

  //============================================================================
  // CUSTOM ACTIONS
  //============================================================================

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'setPitch':
        if (extras != null && extras.containsKey('pitch')) {
          await setPitch(extras['pitch'] as double);
        }
        break;

      case 'loadSettings':
      case 'loadCrossfadeSettings':
        await loadSettings();
        break;

      case 'loadLastfmSettings':
        await loadLastfmSettings();
        break;

      case 'setSleepTimer':
        if (extras != null && extras.containsKey('duration_minutes')) {
          final minutes = extras['duration_minutes'] as int?;
          if (minutes != null && minutes > 0) {
            setSleepTimer(Duration(minutes: minutes));
          } else {
            setSleepTimer(null);
          }
        }
        break;

      case 'loadAlbumCoverRotationPreference':
        albumCoverRotationEnabled.value =
            await _librarySettings.getCoverRotationEnabled();
        break;

      case 'setPersistentSessionMode':
        //handled by preferences service directly
        break;
    }
  }

  //============================================================================
  // LIFECYCLE
  //============================================================================

  @override
  Future<void> onTaskRemoved() async {
    //called when app is swiped away from recents
    //check background playback setting
    final backgroundPlaybackEnabled =
        await _playbackSettings.getBackgroundPlaybackEnabled();

    if (kDebugMode) {
      debugPrint(
        'SonoPlayer: App removed from recents - backgroundPlayback=$backgroundPlaybackEnabled',
      );
    }

    //save state before stopping
    await savePlaybackSnapshot();

    if (!backgroundPlaybackEnabled) {
      //stop playback and service when background playback is disabled
      if (kDebugMode) {
        debugPrint(
          'SonoPlayer: Stopping service (background playback disabled)',
        );
      }
      await stop();
      super.onTaskRemoved();
    } else {
      //keep service alive when background playback is enabled
      if (kDebugMode) {
        debugPrint(
          'SonoPlayer: Keeping service alive (background playback enabled)',
        );
      }
      //DO NOT call super.onTaskRemoved() - it would stop the service
    }
  }

  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (kDebugMode) {
      debugPrint('SonoPlayer: Lifecycle changed to $state');
    }
    //no special handling needed - player continues normally
  }

  Future<void> dispose() async {
    _subscriptions.cancelAll();
    _crossfadeController?.dispose();
    _sleepTimer.dispose();
    _stateBroadcaster.dispose();
    _positionSaveTimer?.cancel();

    await _primaryPlayer.dispose();
    await _secondaryPlayer?.dispose();

    _currentSong.dispose();
    _isPlaying.dispose();
    _position.dispose();
    _duration.dispose();
    _isShuffleEnabled.dispose();
    _repeatMode.dispose();
    _currentSpeed.dispose();
    _currentPitch.dispose();
    _playbackContext.dispose();
    queueNotifier.dispose();
    albumCoverRotationEnabled.dispose();

    if (kDebugMode) {
      debugPrint('SonoPlayer disposed');
    }
  }

  //============================================================================
  // UTILITY CONVERTERS
  //============================================================================

  AudioProcessingState _toAudioProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _toAudioServiceRepeatMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return AudioServiceRepeatMode.none;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
    }
  }
}

//============================================================================
// SONG MODEL EXTENSION
//============================================================================

extension SongModelDurationExtension on SongModel {
  Duration durationMsDuration() {
    return Duration(milliseconds: duration ?? 0);
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: uri!,
      album: album ?? "Unknown Album",
      title: title,
      artist: artist ?? "Unknown Artist",
      duration:
          durationMsDuration() != Duration.zero ? durationMsDuration() : null,
      extras: <String, dynamic>{'songId': id},
    );
  }
}
