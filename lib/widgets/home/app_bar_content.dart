import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sono/widgets/global/time_based_greeting.dart';
import 'package:sono/styles/app_theme.dart';

class HomeAppBarContent extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onNewsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSettingsTap;
  final double toolbarHeight;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const HomeAppBarContent({
    super.key,
    this.onMenuTap,
    this.onNewsTap,
    this.onSearchTap,
    this.onSettingsTap,
    this.toolbarHeight = 70.0,
    this.currentUser,
    this.isLoggedIn = false,
  });

  String? get _userName {
    if (!isLoggedIn || currentUser == null) return null;
    return currentUser?['display_name'] as String? ??
        currentUser?['username'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final responsiveToolbarHeight = AppTheme.responsiveDimension(
      context,
      toolbarHeight,
    );

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: responsiveToolbarHeight,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.responsiveSpacing(context, 16),
        ),
        child: SizedBox(
          height: responsiveToolbarHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //left side: Avatar + Greeting
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProfileButton(context),
                  SizedBox(width: AppTheme.responsiveSpacing(context, 12)),
                  TimeBasedGreeting(userName: _userName),
                ],
              ),

              const Spacer(),

              //right side: Action buttons in pill container
              _ActionButtonsPill(
                onNewsTap: onNewsTap,
                onSearchTap: onSearchTap,
                onSettingsTap: onSettingsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final profileSize = AppTheme.responsiveDimension(context, 48);
    final borderWidth = AppTheme.responsiveDimension(context, 2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onMenuTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: profileSize,
          height: profileSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(30),
              width: borderWidth,
            ),
          ),
          child: ClipOval(child: _buildProfileContent(context)),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    if (!isLoggedIn) {
      return Container(
        color: AppTheme.surfaceDark,
        child: Icon(
          Icons.person_rounded,
          size: AppTheme.responsiveIconSize(context, 24, min: 20),
          color: Colors.white70,
        ),
      );
    }

    final profilePictureUrl = currentUser?['profile_picture_url'] as String?;

    if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: profilePictureUrl,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => Container(
              color: AppTheme.surfaceDark,
              child: Center(
                child: SizedBox(
                  width: AppTheme.responsiveDimension(context, 16),
                  height: AppTheme.responsiveDimension(context, 16),
                  child: CircularProgressIndicator(
                    strokeWidth: AppTheme.responsiveDimension(context, 2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        errorWidget: (context, url, error) => _buildFallbackAvatar(context),
      );
    }

    return _buildFallbackAvatar(context);
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    final displayName = _userName ?? 'U';

    return Container(
      color: AppTheme.elevatedSurfaceDark,
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: AppTheme.responsiveFontSize(context, 20, min: 16),
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}

/// Rounded pill container for action buttons
class _ActionButtonsPill extends StatelessWidget {
  final VoidCallback? onNewsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSettingsTap;

  const _ActionButtonsPill({
    this.onNewsTap,
    this.onSearchTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.responsiveSpacing(context, 4),
        vertical: AppTheme.responsiveSpacing(context, 4),
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withAlpha(40),
          width: AppTheme.responsiveDimension(context, 1.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillActionButton(
            icon: Icons.article_rounded,
            svgAsset: 'assets/icons/news.svg',
            onTap: onNewsTap,
            tooltip: 'Changelog',
          ),
          _PillActionButton(
            icon: Icons.search_rounded,
            svgAsset: 'assets/icons/search.svg',
            onTap: onSearchTap,
            tooltip: 'Search',
          ),
          _PillActionButton(
            icon: Icons.settings_rounded,
            svgAsset: 'assets/icons/settings.svg',
            onTap: onSettingsTap,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Individual action button inside the pill
class _PillActionButton extends StatelessWidget {
  final IconData icon;
  final String? svgAsset;
  final VoidCallback? onTap;
  final String tooltip;

  const _PillActionButton({
    required this.icon,
    this.svgAsset,
    this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.responsiveSpacing(context, 10)),
            child: _buildIcon(context),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final iconSize = AppTheme.responsiveIconSize(context, 22, min: 20);

    //to load SVG if asset exists => otherwise use Material icon
    if (svgAsset != null) {
      return SvgPicture.asset(
        svgAsset!,
        width: iconSize,
        height: iconSize,
        colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
        placeholderBuilder:
            (context) => Icon(icon, color: Colors.white70, size: iconSize),
      );
    }

    return Icon(icon, color: Colors.white70, size: iconSize);
  }
}