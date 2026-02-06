import 'package:flutter/material.dart';
import 'package:sono/models/search/recent_search_model.dart';
import 'package:sono/widgets/search/recent_search_chip.dart';
import 'package:sono/styles/app_theme.dart';

class SearchIdleState extends StatelessWidget {
  /// List of recent searches
  final List<RecentSearch> recentSearches;

  /// Callback when a recent search is tapped
  final ValueChanged<RecentSearch> onRecentSearchTap;

  /// Callback when a recent search delete is tapped
  final ValueChanged<RecentSearch> onRecentSearchDelete;

  /// Callback when "Clear All" is tapped
  final VoidCallback? onClearAll;

  const SearchIdleState({
    super.key,
    required this.recentSearches,
    required this.onRecentSearchTap,
    required this.onRecentSearchDelete,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: AppTheme.fontSubtitle,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'VarelaRound',
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (onClearAll != null)
                InkWell(
                  onTap: onClearAll,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                      vertical: 4,
                    ),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: AppTheme.fontSm,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brandPink,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingMd),

          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children:
                recentSearches.map((search) {
                  return RecentSearchChip(
                    search: search,
                    onTap: () => onRecentSearchTap(search),
                    onDelete: () => onRecentSearchDelete(search),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Search your library',
              style: TextStyle(
                fontSize: AppTheme.fontTitle,
                fontWeight: FontWeight.w600,
                fontFamily: 'VarelaRound',
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Search for songs, albums, and artists',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: Colors.white.withValues(alpha: 0.5),
                fontFamily: 'VarelaRound',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
