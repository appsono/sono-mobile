import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:sono/widgets/global/time_based_greeting.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onWhatsNewTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onRecentsTap;
  final VoidCallback? onShuffleAllTap;
  final VoidCallback? onCreatePlaylistTap;
  final VoidCallback? onLogoutTap;
  final String userName;
  final String appVersion;
  final String? currentRoute;
  final String? profilePictureUrl;

  /// When true, shows main navigation items (Home, Search, Library, Settings)
  /// Used for permanent sidebar on desktop-sized screens
  final bool showNavItems;

  /// Current tab index for highlighting nav items in permanent mode
  final int currentTabIndex;

  /// Callback when a nav tab is tapped in permanent mode
  final ValueChanged<int>? onNavItemTap;

  /// When provided, shows a collapse/arrow button in the header
  final VoidCallback? onCollapseTap;

  const Sidebar({
    super.key,
    required this.userName,
    required this.appVersion,
    this.currentRoute,
    this.profilePictureUrl,
    this.onProfileTap,
    this.onWhatsNewTap,
    this.onSettingsTap,
    this.onRecentsTap,
    this.onShuffleAllTap,
    this.onCreatePlaylistTap,
    this.onLogoutTap,
    this.showNavItems = false,
    this.currentTabIndex = 0,
    this.onNavItemTap,
    this.onCollapseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
              child: GestureDetector(
                onTap: onProfileTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFFF4893),
                      backgroundImage:
                          profilePictureUrl != null
                              ? NetworkImage(profilePictureUrl!)
                              : null,
                      child:
                          profilePictureUrl == null
                              ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 30,
                              )
                              : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: showNavItems
                          ? TimeBasedGreeting(userName: userName)
                          : Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    if (onCollapseTap != null)
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: Colors.white38,
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onCollapseTap,
                        tooltip: 'Collapse sidebar',
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(
                color: Colors.white.withAlpha((255 * 0.1).round()),
                height: 20,
                thickness: 0.8,
              ),
            ),
            //navigation items (only in permanent sidebar mode)
            if (showNavItems) ...[
              _buildMenuItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                title: "Home",
                onTap: () => onNavItemTap?.call(0),
                isSelected: currentTabIndex == 0,
              ),
              _buildMenuItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search_rounded,
                title: "Search",
                onTap: () => onNavItemTap?.call(1),
                isSelected: currentTabIndex == 1,
              ),
              _buildMenuItem(
                icon: Icons.library_music_outlined,
                activeIcon: Icons.library_music_rounded,
                title: "Library",
                onTap: () => onNavItemTap?.call(2),
                isSelected: currentTabIndex == 2,
              ),
              _buildMenuItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                title: "Settings",
                onTap: () => onNavItemTap?.call(3),
                isSelected: currentTabIndex == 3,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Divider(
                  color: Colors.white.withAlpha((255 * 0.1).round()),
                  height: 20,
                  thickness: 0.8,
                ),
              ),
            ],
            //menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                children: [
                  _buildMenuItem(
                    icon: Icons.new_releases_rounded,
                    title: "Changelog",
                    onTap: onWhatsNewTap,
                    isSelected: currentRoute == "Changelog",
                  ),
                  if (!showNavItems)
                    _buildMenuItem(
                      icon: Icons.settings_rounded,
                      title: "Settings",
                      onTap: onSettingsTap,
                      isSelected: currentRoute == "Settings",
                    ),
                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: "Recents",
                    onTap: onRecentsTap,
                    isSelected: currentRoute == "Recents",
                  ),
                  if (showNavItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: Column(
                        children: [
                          _buildActionButton(icon: Icons.shuffle_rounded, label: 'Shuffle all', isDark: true, onTap: onShuffleAllTap),
                          const SizedBox(height: 8),
                          _buildActionButton(icon: Icons.add_rounded, label: 'Create Playlist', isDark: false, onTap: onCreatePlaylistTap),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(
                color: Colors.white.withAlpha((255 * 0.1).round()),
                height: 20,
                thickness: 0.8,
              ),
            ),
            _buildMenuItem(
              icon: Icons.logout_rounded,
              title: "Logout",
              onTap: onLogoutTap,
              isDestructive: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 20.0),
              child: Text(
                appVersion,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha((255 * 0.4).round()),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    IconData? activeIcon,
    required String title,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool isSelected = false,
  }) {
    final Color activeColor = const Color(0xFFFF4893);
    final Color defaultIconColor = Colors.white.withAlpha((255 * 0.85).round());
    final Color defaultTextColor = Colors.white;
    final Color destructiveColor = Colors.red.shade400;

    Color currentIconColor;
    Color currentTextColor;
    FontWeight currentFontWeight = FontWeight.w400;
    Color? itemBackgroundColor = Colors.transparent;

    if (isDestructive) {
      currentIconColor = destructiveColor;
      currentTextColor = destructiveColor;
    } else if (isSelected) {
      currentIconColor = activeColor;
      currentTextColor = activeColor;
      currentFontWeight = FontWeight.w600;
      itemBackgroundColor = activeColor.withAlpha((255 * 0.1).round());
    } else {
      currentIconColor = defaultIconColor;
      currentTextColor = defaultTextColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: itemBackgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onTap: onTap,
          splashColor: activeColor.withAlpha((255 * 0.15).round()),
          highlightColor: activeColor.withAlpha((255 * 0.1).round()),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(isSelected && activeIcon != null ? activeIcon : icon, color: currentIconColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: currentTextColor,
                      fontSize: 15,
                      fontWeight: currentFontWeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final backgroundColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final foregroundColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final borderColor = isDark ? Colors.white.withAlpha(25) : Colors.transparent;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(icon, color: foregroundColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'VarelaRound',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

mixin SidebarMixin<T extends StatefulWidget> on State<T> {
  bool _isSidebarOpen = false;
  bool _isBlurActive = false;
  Timer? _blurTimer;

  bool get isSidebarOpen => _isSidebarOpen;

  void toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _blurTimer?.cancel();
        _blurTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted && _isSidebarOpen) {
            setState(() {
              _isBlurActive = true;
            });
          }
        });
      } else {
        _blurTimer?.cancel();
        _isBlurActive = false;
      }
    });
  }

  void closeSidebar() {
    if (!_isSidebarOpen) return;
    setState(() {
      _isSidebarOpen = false;
      _blurTimer?.cancel();
      _isBlurActive = false;
    });
  }

  @override
  void dispose() {
    _blurTimer?.cancel();
    super.dispose();
  }

  Widget buildWithSidebar({
    required Widget child,
    required Sidebar sidebar,
    double customSidebarWidth = 320.0,
  }) {
    final double actualSidebarWidth = customSidebarWidth;
    const Duration animationDuration = Duration(milliseconds: 300);
    const Curve animationCurve = Curves.easeOutCubic;
    const double mainContentPushFactor = 0.6;
    const double blurSigma = 4.0;
    const double dimOpacity = 0.25;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: animationDuration,
          curve: animationCurve,
          left: _isSidebarOpen ? actualSidebarWidth * mainContentPushFactor : 0,
          right:
              _isSidebarOpen ? -actualSidebarWidth * mainContentPushFactor : 0,
          top: 0,
          bottom: 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (_isSidebarOpen)
                GestureDetector(
                  onTap: closeSidebar,
                  behavior: HitTestBehavior.opaque,
                  child:
                      _isBlurActive
                          ? BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: blurSigma,
                              sigmaY: blurSigma,
                            ),
                            child: Container(
                              color: Colors.black.withAlpha(
                                (255 * dimOpacity).round(),
                              ),
                            ),
                          )
                          : Container(
                            color: Colors.black.withAlpha(
                              (255 * dimOpacity).round(),
                            ),
                          ),
                ),
            ],
          ),
        ),
        AnimatedPositioned(
          duration: animationDuration,
          curve: animationCurve,
          left: _isSidebarOpen ? 0 : -actualSidebarWidth,
          top: 0,
          bottom: 0,
          width: actualSidebarWidth,
          child: Material(
            elevation: 8.0,
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: sidebar,
          ),
        ),
      ],
    );
  }
}
