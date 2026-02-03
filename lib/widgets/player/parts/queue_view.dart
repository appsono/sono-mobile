import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:sono/widgets/global/cached_artwork_image.dart';

class QueueView extends StatefulWidget {
  final SonoPlayer sonoPlayer;
  const QueueView({super.key, required this.sonoPlayer});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  final ScrollController _scrollController = ScrollController();
  static const double _tileHeight = 72.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  void _jumpToCurrent() {
    final currentIndex = widget.sonoPlayer.currentIndex;
    if (_scrollController.hasClients &&
        currentIndex != null &&
        currentIndex >= 0) {
      _scrollController.animateTo(
        currentIndex * _tileHeight,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //drag handle
        Container(
          height: 4,
          width: 40,
          margin: EdgeInsets.symmetric(
            vertical: AppTheme.responsiveSpacing(context, AppTheme.spacingMd),
          ),
          decoration: BoxDecoration(
            color: AppTheme.textPrimaryDark.opacity30,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        //Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.responsiveSpacing(context, AppTheme.spacingLg),
            vertical: AppTheme.responsiveSpacing(context, AppTheme.spacingSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Queue',
                style: AppStyles.sonoPlayerTitle.copyWith(
                  fontSize: AppTheme.responsiveFontSize(
                    context,
                    AppTheme.fontTitle,
                    min: 18,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              ValueListenableBuilder<List<MediaItem>>(
                valueListenable: widget.sonoPlayer.queueNotifier,
                builder: (context, queue, _) {
                  return TextButton.icon(
                    icon: Icon(
                      Icons.my_location_rounded,
                      color: AppTheme.brandPink,
                      size: AppTheme.responsiveIconSize(
                        context,
                        AppTheme.iconMd,
                        min: 18,
                      ),
                    ),
                    label: Text(
                      'Current',
                      style: TextStyle(color: AppTheme.brandPink),
                    ),
                    onPressed: _jumpToCurrent,
                  );
                },
              ),
            ],
          ),
        ),

        Divider(color: AppTheme.textPrimaryDark.opacity10, height: 1),

        //queue list
        Expanded(
          child: ValueListenableBuilder<List<MediaItem>>(
            valueListenable: widget.sonoPlayer.queueNotifier,
            builder: (context, queue, child) {
              if (queue.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        color: AppTheme.textPrimaryDark.opacity30,
                        size: AppTheme.responsiveIconSize(
                          context,
                          AppTheme.iconHero,
                          min: 48,
                        ),
                      ),
                      SizedBox(
                        height: AppTheme.responsiveSpacing(
                          context,
                          AppTheme.spacing,
                        ),
                      ),
                      Text(
                        "The queue is empty",
                        style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: AppTheme.responsiveFontSize(
                            context,
                            AppTheme.font,
                            min: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                buildDefaultDragHandles: !SASManager().isInClientMode,
                scrollController: _scrollController,
                padding: EdgeInsets.only(
                  bottom: 100,
                  top: AppTheme.responsiveSpacing(context, AppTheme.spacingSm),
                ),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final mediaItem = queue[index];
                  final songId = mediaItem.extras?['songId'] as int?;
                  final isCurrent = index == widget.sonoPlayer.currentIndex;

                  return SizedBox(
                    key: ValueKey(mediaItem.id),
                    height: _tileHeight,
                    child: Dismissible(
                      key: ValueKey("${mediaItem.id}_dismissible"),
                      direction:
                          SASManager().isInClientMode
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(
                          right: AppTheme.responsiveSpacing(
                            context,
                            AppTheme.spacingLg,
                          ),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.error.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Icon(
                          Icons.delete_rounded,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                      onDismissed: (_) async {
                        await widget.sonoPlayer.removeQueueItem(mediaItem);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Removed '${mediaItem.title}' from queue",
                              ),
                              backgroundColor: AppTheme.brandPink,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Material(
                        color:
                            isCurrent
                                ? AppTheme.brandPink.opacity10
                                : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            //block queue navigation for clients
                            if (SASManager().isInClientMode) return;

                            widget.sonoPlayer.skipToQueueItem(index);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.responsiveSpacing(
                                context,
                                AppTheme.spacing,
                              ),
                              vertical: AppTheme.responsiveSpacing(
                                context,
                                AppTheme.spacingSm,
                              ),
                            ),
                            child: Row(
                              children: [
                                //artwork
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  child: SizedBox(
                                    width: AppTheme.responsiveArtworkSize(
                                      context,
                                      AppTheme.artworkMd,
                                    ),
                                    height: AppTheme.responsiveArtworkSize(
                                      context,
                                      AppTheme.artworkMd,
                                    ),
                                    child:
                                        songId != null
                                            ? CachedArtworkImage(
                                              id: songId,
                                              size:
                                                  AppTheme.responsiveArtworkSize(
                                                    context,
                                                    AppTheme.artworkMd,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusMd,
                                                  ),
                                            )
                                            : Container(
                                              color:
                                                  AppTheme.elevatedSurfaceDark,
                                              child: Icon(
                                                Icons.music_note_rounded,
                                                color:
                                                    AppTheme.textDisabledDark,
                                              ),
                                            ),
                                  ),
                                ),

                                SizedBox(
                                  width: AppTheme.responsiveSpacing(
                                    context,
                                    AppTheme.spacingMd,
                                  ),
                                ),

                                //song info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        mediaItem.title,
                                        style: AppStyles.sonoListItemTitle
                                            .copyWith(
                                              color:
                                                  isCurrent
                                                      ? AppTheme.brandPink
                                                      : AppTheme
                                                          .textPrimaryDark,
                                              fontWeight:
                                                  isCurrent
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        mediaItem.artist ?? 'Unknown Artist',
                                        style: AppStyles.sonoListItemSubtitle
                                            .copyWith(
                                              color:
                                                  isCurrent
                                                      ? AppTheme
                                                          .brandPink
                                                          .opacity70
                                                      : AppTheme
                                                          .textTertiaryDark,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(
                                  width: AppTheme.responsiveSpacing(
                                    context,
                                    AppTheme.spacingSm,
                                  ),
                                ),

                                //current indicator or drag handle
                                if (isCurrent)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppTheme.responsiveSpacing(
                                        context,
                                        AppTheme.spacingSm,
                                      ),
                                      vertical: AppTheme.responsiveSpacing(
                                        context,
                                        AppTheme.spacingXs,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandPink,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radius,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: AppTheme.textPrimaryDark,
                                          size: AppTheme.responsiveIconSize(
                                            context,
                                            AppTheme.iconSm,
                                            min: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Now',
                                          style: TextStyle(
                                            color: AppTheme.textPrimaryDark,
                                            fontSize:
                                                AppTheme.responsiveFontSize(
                                                  context,
                                                  11,
                                                  min: 10,
                                                ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (!SASManager().isInClientMode)
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: AppTheme.textDisabledDark,
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: 24,
                                  ), //spacer to maintain layout
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  widget.sonoPlayer.reorderQueueItem(oldIndex, newIndex);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
