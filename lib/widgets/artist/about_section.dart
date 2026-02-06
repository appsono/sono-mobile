import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/artist/page_skeletons.dart';

class AboutSection extends StatelessWidget {
  final String? bio;
  final int? monthlyListeners;
  final int? totalPlays;
  final String? artistUrl;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onViewMore;
  final VoidCallback? onLinkTap;

  const AboutSection({
    super.key,
    this.bio,
    this.monthlyListeners,
    this.totalPlays,
    this.artistUrl,
    this.isLoading = false,
    this.errorMessage,
    this.onViewMore,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AboutSectionSkeleton();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //title
          Text(
            'About',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.fontTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing),

          //stats row
          if (monthlyListeners != null || totalPlays != null) _buildStatsRow(),

          if (monthlyListeners != null || totalPlays != null)
            const SizedBox(height: AppTheme.spacing),

          //bio text or error
          if (errorMessage != null)
            _buildErrorState()
          else if (bio != null && bio!.isNotEmpty)
            _buildBioText()
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final numberFormat = NumberFormat.compact();

    return Row(
      children: [
        if (monthlyListeners != null) ...[
          _buildStat(
            value: numberFormat.format(monthlyListeners),
            label: 'monthly listeners',
          ),
          const SizedBox(width: AppTheme.spacingXl),
        ],
        if (totalPlays != null)
          _buildStat(
            value: numberFormat.format(totalPlays),
            label: 'total plays',
          ),
      ],
    );
  }

  Widget _buildStat({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimaryDark,
            fontSize: AppTheme.fontHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondaryDark,
            fontSize: AppTheme.fontSm,
          ),
        ),
      ],
    );
  }

  Widget _buildBioText() {
    //clean up bio html tags if present
    final cleanBio = _cleanBioText(bio!);
    final shouldShowViewMore = cleanBio.length > 150;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cleanBio,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondaryDark,
            fontSize: AppTheme.fontBody,
            height: 1.5,
          ),
        ),
        if (shouldShowViewMore) ...[
          const SizedBox(height: AppTheme.spacingSm),
          GestureDetector(
            onTap: onViewMore,
            child: const Text(
              'Show all',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textPrimaryDark,
                fontSize: AppTheme.fontBody,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          errorMessage!,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textTertiaryDark,
            fontSize: AppTheme.fontBody,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Text(
      'No biography available.',
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: AppTheme.textTertiaryDark,
        fontSize: AppTheme.fontBody,
      ),
    );
  }

  String _cleanBioText(String text) {
    //remove html link tags and extra whitespace
    return text
        .replaceAll(RegExp(r'<a[^>]*>'), '')
        .replaceAll('</a>', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
