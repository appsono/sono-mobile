import 'package:flutter/material.dart';
import 'package:sono/models/search/search_filter_options.dart';
import 'package:sono/styles/app_theme.dart';

class SearchFilterChips extends StatelessWidget {
  /// Current filter options
  final SearchFilterOptions filterOptions;

  /// Callback when filter options change
  final ValueChanged<SearchFilterOptions> onFilterChanged;

  /// Whether to show type filters (Songs, Albums, Artists)
  final bool showTypeFilters;

  const SearchFilterChips({
    super.key,
    required this.filterOptions,
    required this.onFilterChanged,
    this.showTypeFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildSortChip(),

            const SizedBox(width: AppTheme.spacingSm),

            if (showTypeFilters) ...[
              _buildDivider(),
              const SizedBox(width: AppTheme.spacingSm),
              ..._buildTypeFilterChips(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    return PopupMenuButton<SearchSortType>(
      initialValue: filterOptions.sortType,
      onSelected: (sortType) {
        onFilterChanged(filterOptions.copyWith(sortType: sortType));
      },
      color: AppTheme.elevatedSurfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      itemBuilder: (context) => [
        _buildMenuItem(
          SearchSortType.relevance,
          'Relevance',
          Icons.star_rounded,
        ),
        _buildMenuItem(
          SearchSortType.alphabetical,
          'A-Z',
          Icons.sort_by_alpha_rounded,
        ),
        _buildMenuItem(
          SearchSortType.reverseAlphabetical,
          'Z-A',
          Icons.sort_by_alpha_rounded,
        ),
        _buildMenuItem(
          SearchSortType.dateAdded,
          'Date Added',
          Icons.schedule_rounded,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: AppTheme.elevatedSurfaceDark,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 18,
              color: AppTheme.brandPink,
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Text(
              _getSortLabel(filterOptions.sortType),
              style: const TextStyle(
                fontSize: AppTheme.fontSm,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'VarelaRound',
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<SearchSortType> _buildMenuItem(
    SearchSortType type,
    String label,
    IconData icon,
  ) {
    final isSelected = filterOptions.sortType == type;
    return PopupMenuItem<SearchSortType>(
      value: type,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected
                ? AppTheme.brandPink
                : Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppTheme.brandPink : Colors.white,
              fontFamily: 'VarelaRound',
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check_rounded,
              size: 18,
              color: AppTheme.brandPink,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTypeFilterChips() {
    return [
      //not implemented yet, propably never will. Unless => requested.
      //songs filter
      //albums filter
      //artists filter
    ];
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  String _getSortLabel(SearchSortType sortType) {
    switch (sortType) {
      case SearchSortType.relevance:
        return 'Relevance';
      case SearchSortType.alphabetical:
        return 'A-Z';
      case SearchSortType.reverseAlphabetical:
        return 'Z-A';
      case SearchSortType.dateAdded:
        return 'Date Added';
    }
  }
}