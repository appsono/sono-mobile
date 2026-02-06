import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/services/utils/recents_service.dart';
import 'package:sono/services/utils/analytics_service.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:intl/intl.dart';

class RecentsPage extends StatefulWidget {
  const RecentsPage({super.key});

  @override
  State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final RecentsService _recentsService = RecentsService.instance;
  final SonoPlayer _sonoPlayer = SonoPlayer();

  late Future<List<Map<String, dynamic>>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _sessionsFuture = _loadListeningSessions();
    });
  }

  Future<List<Map<String, dynamic>>> _loadListeningSessions() async {
    try {
      final recentPlays = await _recentsService.getRecentPlays(limit: 100);

      if (recentPlays.isEmpty) {
        return [];
      }

      //get all songs
      final allSongs = await AudioFilterUtils.getFilteredSongs(_audioQuery);
      final songMap = {for (var song in allSongs) song.id: song};

      //group by listening sessions based on context and time gaps
      final sessions = <Map<String, dynamic>>[];
      String? currentContext;
      DateTime? lastPlayTime;
      List<SongModel> currentSessionSongs = [];

      for (final play in recentPlays) {
        final song = songMap[play.songId];
        if (song == null) continue;

        final context = play.context;
        final playTime = play.playedAt;

        //check if this is a new session
        //new session if: different context, or >30 min gap
        final isNewSession =
            currentContext == null ||
            context != currentContext ||
            (lastPlayTime != null &&
                playTime.difference(lastPlayTime).inMinutes.abs() > 30);

        if (isNewSession && currentSessionSongs.isNotEmpty) {
          //save previous session
          sessions.add({
            'context': currentContext,
            'songs': List<SongModel>.from(currentSessionSongs),
            'timestamp': lastPlayTime,
          });
          currentSessionSongs = [];
        }

        currentContext = context;
        lastPlayTime = playTime;
        currentSessionSongs.add(song);
      }

      //add final session
      if (currentSessionSongs.isNotEmpty) {
        sessions.add({
          'context': currentContext,
          'songs': currentSessionSongs,
          'timestamp': lastPlayTime,
        });
      }

      return sessions;
    } catch (e) {
      debugPrint('RecentsPage: Error loading sessions: $e');
      return [];
    }
  }

  String _formatSessionTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  String _getSessionTitle(String? context) {
    if (context == null || context.isEmpty) {
      return 'Individual Songs';
    }

    if (context.toLowerCase().startsWith('album:')) {
      return context.substring(6).trim();
    } else if (context.toLowerCase().startsWith('playlist:')) {
      return context.substring(9).trim();
    } else if (context.toLowerCase() == 'shuffle') {
      return 'Shuffle';
    } else {
      return context;
    }
  }

  IconData _getSessionIcon(String? context) {
    if (context == null || context.isEmpty) {
      return Icons.music_note_rounded;
    }

    if (context.toLowerCase().startsWith('album:')) {
      return Icons.album_rounded;
    } else if (context.toLowerCase().startsWith('playlist:')) {
      return Icons.queue_music_rounded;
    } else if (context.toLowerCase() == 'shuffle') {
      return Icons.shuffle_rounded;
    } else {
      return Icons.music_note_rounded;
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.elevatedSurfaceDark,
            title: Text('Clear History?', style: AppStyles.sonoHeading),
            content: Text(
              'This will permanently delete your listening history. This action cannot be undone.',
              style: AppStyles.sonoListItemSubtitle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withAlpha(179)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Clear',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _recentsService.clearAllHistory();
        if (mounted) {
          _loadSessions();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listening history cleared'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        AnalyticsService.logEvent('clear_history');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing history: $e'),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, AppTheme.backgroundDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: AppTheme.spacingXs),
                    Text('Listening History', style: AppStyles.sonoHeading),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white54,
                      ),
                      onPressed: _clearAllHistory,
                      tooltip: 'Clear history',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _sessionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.brandPink,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error loading history: ${snapshot.error}',
                            style: AppStyles.sonoListItemSubtitle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final sessions = snapshot.data ?? [];

                    if (sessions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 80,
                              color: Colors.white.withAlpha(51),
                            ),
                            SizedBox(height: AppTheme.spacing),
                            Text(
                              'No listening history yet',
                              style: AppStyles.sonoListItemTitle.copyWith(
                                color: Colors.white.withAlpha(128),
                              ),
                            ),
                            SizedBox(height: AppTheme.spacingXs),
                            Text(
                              'Your listening sessions will appear here',
                              style: AppStyles.sonoListItemSubtitle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final context = session['context'] as String?;
                        final songs = session['songs'] as List<SongModel>;
                        final timestamp = session['timestamp'] as DateTime?;

                        return ExpansionTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.elevatedSurfaceDark,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                            ),
                            child: Icon(
                              _getSessionIcon(context),
                              color: AppTheme.brandPink,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            _getSessionTitle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.sonoListItemTitle,
                          ),
                          subtitle: Text(
                            '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}${timestamp != null ? ' • ${_formatSessionTime(timestamp)}' : ''}',
                            style: AppStyles.sonoListItemSubtitle,
                          ),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                          childrenPadding: EdgeInsets.zero,
                          iconColor: AppTheme.brandPink,
                          collapsedIconColor: Colors.white54,
                          children:
                              songs.map((song) {
                                return ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 72.0,
                                    right: 16.0,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd,
                                    ),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: QueryArtworkWidget(
                                        id: song.id,
                                        type: ArtworkType.AUDIO,
                                        artworkFit: BoxFit.cover,
                                        artworkQuality: FilterQuality.medium,
                                        artworkBorder: BorderRadius.zero,
                                        size: 80,
                                        nullArtworkWidget: Container(
                                          color: Colors.grey.shade800,
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.white54,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyles.sonoListItemTitle.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    song.artist ?? 'Unknown Artist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyles.sonoListItemSubtitle
                                        .copyWith(fontSize: 12),
                                  ),
                                  onTap: () {
                                    _sonoPlayer.playNewPlaylist(
                                      songs,
                                      songs.indexOf(song),
                                      context:
                                          'recents_${_getSessionTitle(context)}',
                                    );
                                  },
                                );
                              }).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
