import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';

/// Skeleton loading animation widget
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.textPrimaryDark.withValues(alpha: 0.05),
                AppTheme.textPrimaryDark.withValues(alpha: 0.15),
                AppTheme.textPrimaryDark.withValues(alpha: 0.05),
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card for news/announcement items
class SkeletonNewsCard extends StatelessWidget {
  const SkeletonNewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.textPrimaryDark.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(
                  width: 120,
                  height: 24,
                  borderRadius: 16,
                ),
                SkeletonLoader(
                  width: 80,
                  height: 16,
                  borderRadius: 8,
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingSm),
            SkeletonLoader(
              width: double.infinity,
              height: 24,
              borderRadius: 8,
            ),
            SizedBox(height: 8),
            SkeletonLoader(
              width: 200,
              height: 24,
              borderRadius: 8,
            ),
            SizedBox(height: AppTheme.spacingSm),
            SkeletonLoader(
              width: double.infinity,
              height: 16,
              borderRadius: 8,
            ),
            SizedBox(height: 8),
            SkeletonLoader(
              width: double.infinity,
              height: 16,
              borderRadius: 8,
            ),
            SizedBox(height: 8),
            SkeletonLoader(
              width: 250,
              height: 16,
              borderRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list tile for settings pages
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SkeletonLoader(
            width: 40,
            height: 40,
            borderRadius: AppTheme.radiusSm,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 150,
                  height: 16,
                  borderRadius: 8,
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 200,
                  height: 14,
                  borderRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SkeletonLoader(
            width: 20,
            height: 20,
            borderRadius: 10,
          ),
        ],
      ),
    );
  }
}