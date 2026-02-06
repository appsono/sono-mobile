import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sono/styles/app_theme.dart';

class GlobalPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String pageTitle;
  final VoidCallback? onMenuTap;
  final double toolbarHeight;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const GlobalPageHeader({
    super.key,
    required this.pageTitle,
    this.onMenuTap,
    this.toolbarHeight = 70.0,
    this.currentUser,
    this.isLoggedIn = false,
  });

  double _getResponsiveToolbarHeight(BuildContext context) {
    return AppTheme.responsiveDimension(context, toolbarHeight);
  }

  String? get _userName {
    if (!isLoggedIn || currentUser == null) return null;
    return currentUser?['display_name'] as String? ??
        currentUser?['username'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final responsiveToolbarHeight = _getResponsiveToolbarHeight(context);

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
              _buildProfileButton(context),
              SizedBox(width: AppTheme.responsiveSpacing(context, 12)),
              Text(
                pageTitle,
                style: TextStyle(
                  fontFamily: 'VarelaRound',
                  fontSize: AppTheme.responsiveFontSize(context, 22, min: 18),
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
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
        errorWidget: (context, url, error) => _buildFallbackAvatar(),
      );
    }

    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    final displayName = _userName ?? 'U';

    return Builder(
      builder: (context) {
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
      },
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}