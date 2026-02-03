import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/styles/app_theme.dart';

class ArtistFetchProgressDialog extends StatelessWidget {
  const ArtistFetchProgressDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ArtistFetchProgressDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXl),
          topRight: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context),
          const Divider(height: 1, color: AppTheme.borderDark),
          Expanded(child: _buildContent()),
          const Divider(height: 1, color: AppTheme.borderDark),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacingSm),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.borderDark,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        children: [
          const Icon(Icons.download_rounded, color: AppTheme.textPrimaryDark),
          const SizedBox(width: AppTheme.spacingSm),
          const Expanded(
            child: Text(
              'Artist Images Fetch Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppTheme.textSecondaryDark,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<ArtistFetchProgressService>(
      builder: (context, progressService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressSection(progressService),
              const SizedBox(height: AppTheme.spacing),

              _buildStatsSection(progressService),
              const SizedBox(height: AppTheme.spacing),

              _buildLogsSection(progressService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressSection(ArtistFetchProgressService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              service.statusText,
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(service.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: LinearProgressIndicator(
            value: service.progress,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceDark,
            valueColor: AlwaysStoppedAnimation<Color>(
              service.isFetching ? AppTheme.info : AppTheme.success,
            ),
          ),
        ),
        if (service.currentArtist != null) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Current: ${service.currentArtist}',
            style: const TextStyle(
              color: AppTheme.textTertiaryDark,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildStatsSection(ArtistFetchProgressService service) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total',
            service.totalArtists.toString(),
            AppTheme.textSecondaryDark,
          ),
          _buildStatItem(
            'Success',
            service.successCount.toString(),
            AppTheme.success,
          ),
          _buildStatItem(
            'Failed',
            service.failureCount.toString(),
            AppTheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textTertiaryDark,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLogsSection(ArtistFetchProgressService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Activity Log',
              style: TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (service.logs.isNotEmpty)
              TextButton(
                onPressed: service.clearLogs,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: AppTheme.textTertiaryDark,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurfaceDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child:
              service.logs.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(AppTheme.spacing),
                    child: Center(
                      child: Text(
                        'No logs yet',
                        style: TextStyle(
                          color: AppTheme.textTertiaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    itemCount: service.logs.length,
                    reverse: true,
                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                    itemBuilder: (context, index) {
                      final log = service.logs[service.logs.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          log,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryDark,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Consumer<ArtistFetchProgressService>(
      builder: (context, service, child) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
