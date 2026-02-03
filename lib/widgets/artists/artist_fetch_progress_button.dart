import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/artists/artist_fetch_progress_dialog.dart';

class ArtistFetchProgressButton extends StatelessWidget {
  const ArtistFetchProgressButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ArtistFetchProgressService>(
      builder: (context, progressService, child) {
        if (!progressService.isFetching &&
            progressService.currentProgress == 0) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 16,
          bottom: 160,
          child: GestureDetector(
            onTap: () {
              ArtistFetchProgressDialog.show(context);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurfaceDark,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppTheme.borderDark, width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: progressService.progress,
                      strokeWidth: 3,
                      backgroundColor: AppTheme.surfaceDark,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progressService.isFetching
                            ? AppTheme.info
                            : AppTheme.success,
                      ),
                    ),
                  ),
                  Icon(
                    progressService.isFetching
                        ? Icons.download_rounded
                        : Icons.check_rounded,
                    color:
                        progressService.isFetching
                            ? AppTheme.info
                            : AppTheme.success,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
