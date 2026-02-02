import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:sono/styles/text.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onWhatsNewTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onRecentsTap;
  final VoidCallback? onLogoutTap;
  final String userName;
  final String appVersion;
  final String? currentRoute;
  final String? profilePictureUrl;

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
    this.onLogoutTap,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: AppStyles.sonoButtonText.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
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
                Icon(icon, color: currentIconColor, size: 22),
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