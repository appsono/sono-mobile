/// Serializable snapshot of complete playback state for persistence.
/// Used to restore the exact playback state across app restarts.
class PlaybackSnapshot {
  ///S ong IDs in the queue (original order, not shuffled)
  final List<int> queueSongIds;

  /// Current index in the queue
  final int currentIndex;

  /// Playback position in milliseconds
  final int positionMs;

  /// Whether shuffle is enabled
  final bool shuffleEnabled;

  /// Repeat mode: 'off', 'all', or 'one'
  final String repeatMode;

  /// Playback speed (e.g., 1.0, 1.5, 2.0)
  final double playbackSpeed;

  /// Playback pitch (e.g., 1.0)
  final double playbackPitch;

  /// Playback context string (e.g. "Album: Rock Hits", "Playlist: Favorites")
  final String? playbackContext;

  /// Whether the player was actively playing when snapshot was taken
  final bool wasPlaying;

  /// Timestamp when snapshot was created (milliseconds since epoch)
  final int timestampMs;

  PlaybackSnapshot({
    required this.queueSongIds,
    required this.currentIndex,
    required this.positionMs,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.playbackSpeed,
    required this.playbackPitch,
    this.playbackContext,
    required this.wasPlaying,
    required this.timestampMs,
  });

  /// Creates a snapshot from JSON data loaded from preferences
  factory PlaybackSnapshot.fromJson(Map<String, dynamic> json) {
    return PlaybackSnapshot(
      queueSongIds:
          (json['queueSongIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      currentIndex: json['currentIndex'] as int? ?? 0,
      positionMs: json['positionMs'] as int? ?? 0,
      shuffleEnabled: json['shuffleEnabled'] as bool? ?? false,
      repeatMode: json['repeatMode'] as String? ?? 'off',
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      playbackPitch: (json['playbackPitch'] as num?)?.toDouble() ?? 1.0,
      playbackContext: json['playbackContext'] as String?,
      wasPlaying: json['wasPlaying'] as bool? ?? false,
      timestampMs: json['timestampMs'] as int? ?? 0,
    );
  }

  /// Converts snapshot to JSON for storage in preferences
  Map<String, dynamic> toJson() {
    return {
      'queueSongIds': queueSongIds,
      'currentIndex': currentIndex,
      'positionMs': positionMs,
      'shuffleEnabled': shuffleEnabled,
      'repeatMode': repeatMode,
      'playbackSpeed': playbackSpeed,
      'playbackPitch': playbackPitch,
      'playbackContext': playbackContext,
      'wasPlaying': wasPlaying,
      'timestampMs': timestampMs,
    };
  }

  /// Returns true if this snapshot is valid and can be restored
  bool get isValid {
    return queueSongIds.isNotEmpty &&
        currentIndex >= 0 &&
        currentIndex < queueSongIds.length &&
        positionMs >= 0 &&
        playbackSpeed > 0 &&
        playbackPitch > 0;
  }

  @override
  String toString() {
    return 'PlaybackSnapshot(songs: ${queueSongIds.length}, '
        'index: $currentIndex, position: ${positionMs}ms, '
        'shuffle: $shuffleEnabled, repeat: $repeatMode, '
        'wasPlaying: $wasPlaying)';
  }
}