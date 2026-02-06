import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/skeleton_loader.dart';

class PopularSongsSkeleton extends StatelessWidget {
  const PopularSongsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //section title skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
          child: const SkeletonLoader(width: 80, height: 22, borderRadius: 4),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        //song item skeletons
        ...List.generate(5, (index) => _buildSongSkeleton()),
      ],
    );
  }

  Widget _buildSongSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          //rank number
          const SkeletonLoader(width: 24, height: 20, borderRadius: 4),
          const SizedBox(width: AppTheme.spacingMd),
          //album artwork
          const SkeletonLoader(width: 48, height: 48, borderRadius: 4),
          const SizedBox(width: AppTheme.spacingMd),
          //song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                SkeletonLoader(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          //menu icon
          const SkeletonLoader(width: 20, height: 20, borderRadius: 10),
        ],
      ),
    );
  }
}

class AboutSectionSkeleton extends StatelessWidget {
  const AboutSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      margin: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //"About" title
          const SkeletonLoader(width: 80, height: 20, borderRadius: 4),
          const SizedBox(height: AppTheme.spacing),
          //stats row skeleton
          Row(
            children: [
              _buildStatSkeleton(),
              const SizedBox(width: AppTheme.spacingXl),
              _buildStatSkeleton(),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          //bio lines skeleton
          const SkeletonLoader(
            width: double.infinity,
            height: 14,
            borderRadius: 4,
          ),
          const SizedBox(height: 8),
          const SkeletonLoader(
            width: double.infinity,
            height: 14,
            borderRadius: 4,
          ),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 200, height: 14, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonLoader(width: 60, height: 24, borderRadius: 4),
        SizedBox(height: 4),
        SkeletonLoader(width: 80, height: 12, borderRadius: 4),
      ],
    );
  }
}

class ActionsRowSkeleton extends StatelessWidget {
  const ActionsRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          //left container skeleton
          const SkeletonLoader(width: 140, height: 48, borderRadius: 8),
          const Spacer(),
          //shuffle button skeleton
          const SkeletonLoader(width: 48, height: 48, borderRadius: 8),
          const SizedBox(width: AppTheme.spacingSm),
          //play button skeleton
          const SkeletonLoader(width: 48, height: 48, borderRadius: 8),
        ],
      ),
    );
  }
}
