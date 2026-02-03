import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/data/models/playlist_model.dart' as db;
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';

/// Multi-song version => for adding multiple songs to a playlist
class AddToPlaylistDialog extends StatefulWidget {
  final List<int> songIds;

  const AddToPlaylistDialog({super.key, required this.songIds});

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

/// Single-song version (backward compatible) => wraps AddToPlaylistDialog
class AddToPlaylistSheet extends StatelessWidget {
  final SongModel song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return AddToPlaylistDialog(songIds: [song.id]);
  }
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  late Future<List<db.PlaylistModel>> _playlistsFuture;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _refreshPlaylists();
      _isInitialized = true;
    }
  }

  void _refreshPlaylists() {
    final playlistService = context.read<PlaylistService>();
    setState(() {
      _playlistsFuture = playlistService.getAllPlaylists();
    });
  }

  Future<void> _addToPlaylist(db.PlaylistModel playlist) async {
    final playlistService = context.read<PlaylistService>();

    try {
      //add all songs to the playlist
      for (final songId in widget.songIds) {
        await playlistService.addSongToPlaylist(playlist.id, songId);
      }

      if (mounted) {
        Navigator.of(context).pop();

        final songText =
            widget.songIds.length == 1
                ? 'Song'
                : '${widget.songIds.length} songs';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$songText added to "${playlist.name}"'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: $e"),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final playlistService = context.read<PlaylistService>();

    final created = await showSonoBottomSheet<bool>(
      context: context,
      title: 'Create New Playlist',
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
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
          onPressed: () => Navigator.of(context).pop(false),
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

                // ignore: use_build_context_synchronously
                Navigator.of(context).pop(true);
              } catch (e) {
                debugPrint('Error creating playlist: $e');
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to create playlist: $e"),
                    backgroundColor: AppTheme.error,
                  ),
                );
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop(false);
              }
            }
          },
        ),
      ],
    );

    if (created == true && mounted) {
      _refreshPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistService>(
      builder: (context, playlistService, child) {
        return SonoBottomSheet(
          title: "Add to a playlist",
          child: FutureBuilder<List<db.PlaylistModel>>(
            future: _playlistsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final playlists = snapshot.data ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Container(
                      width: AppTheme.artworkSm,
                      height: AppTheme.artworkSm,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: const Text(
                      'Create New Playlist',
                      style: TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: _showCreatePlaylistDialog,
                  ),
                  const Divider(color: AppTheme.borderDark, height: 1),
                  if (playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spacing2xl),
                      child: Text(
                        'No playlists yet. Create one to get started!',
                        style: TextStyle(color: AppTheme.textTertiaryDark),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...playlists.map(
                      (playlist) => ListTile(
                        leading: Container(
                          width: AppTheme.artworkSm,
                          height: AppTheme.artworkSm,
                          decoration: BoxDecoration(
                            color: AppTheme.elevatedSurfaceDark,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: AppTheme.textTertiaryDark,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () => _addToPlaylist(playlist),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
