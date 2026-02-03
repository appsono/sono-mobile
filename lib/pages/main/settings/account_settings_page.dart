import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/pages/auth/forgot_password_page.dart';
import 'package:sono/pages/info/announcements_changelog_page.dart';
import 'package:sono/pages/api/admin/admin_dashboard_page.dart';
import 'package:sono/pages/api/profile_page.dart';
import 'package:sono/utils/error_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AccountSettingsPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Future<void> Function()? onProfileUpdate;

  const AccountSettingsPage({
    super.key,
    this.currentUser,
    this.onProfileUpdate,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoadingExport = false;
  Map<String, dynamic>? _localUserData;

  Map<String, dynamic>? get _currentUserData =>
      _localUserData ?? widget.currentUser;

  Future<void> _handleExportData() async {
    setState(() => _isLoadingExport = true);
    try {
      final data = await _apiService.exportUserData();
      if (!mounted) return;

      setState(() => _isLoadingExport = false);

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final filename = 'sono_data_export_$timestamp.json';

      final directoryPath = await FilePicker.platform.getDirectoryPath();

      if (directoryPath == null) {
        return;
      }

      //save file to selected directory
      final file = File('$directoryPath/$filename');
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text('Data exported to:\n$directoryPath/$filename'),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      }
    } catch (e, s) {
      if (mounted) {
        setState(() => _isLoadingExport = false);
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: "Failed to export data",
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  void _handlePasswordReset() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  void _handleViewAnnouncements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnnouncementsChangelogPage(),
      ),
    );
  }

  void _handleAdminDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
    );
  }

  void _handleProfileNavigation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProfilePage(
              currentUser: _currentUserData,
              onLogout: () {
                Navigator.pop(context);
              },
              onProfileUpdate:
                  widget.onProfileUpdate ??
                  () async {
                    //default profile update handler
                  },
            ),
      ),
    );

    //refresh local user data
    if (mounted) {
      try {
        final updatedUser = await _apiService.getCurrentUser();
        setState(() {
          _localUserData = updatedUser;
        });
      } catch (e) {
        //silently fail => keep existing data
      }
    }
  }

  Future<void> _showConsentHistory() async {
    try {
      final consents = await _apiService.getUserConsents();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (context) => Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusXl),
                  topRight: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              padding: EdgeInsets.only(
                top: AppTheme.spacing,
                left: AppTheme.spacingXl,
                right: AppTheme.spacingXl,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppTheme.spacingXl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(bottom: AppTheme.spacing),
                      decoration: BoxDecoration(
                        color: AppTheme.textTertiaryDark,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Consent History',
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontTitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingLg),
                  consents.isEmpty
                      ? Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacingXl,
                        ),
                        child: Text(
                          'No consent records found.',
                          style: TextStyle(
                            color: AppTheme.textSecondaryDark,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      )
                      : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: consents.length,
                          separatorBuilder:
                              (context, index) => Divider(
                                color: AppTheme.textPrimaryDark.opacity10,
                              ),
                          itemBuilder: (context, index) {
                            final consent = consents[index];
                            final createdAt = consent['given_at'];

                            String formattedDate = 'N/A';
                            if (createdAt != null &&
                                createdAt.toString().isNotEmpty) {
                              try {
                                DateTime date;
                                if (createdAt.toString().contains('T')) {
                                  date = DateTime.parse(createdAt.toString());
                                } else {
                                  date = DateFormat(
                                    'yyyy-MM-dd HH:mm:ss',
                                  ).parse(createdAt.toString());
                                }
                                formattedDate = DateFormat(
                                  'MMM dd, yyyy',
                                ).format(date.toLocal());
                              } catch (e) {
                                debugPrint(
                                  'Failed to parse consent date: $createdAt, error: $e',
                                );
                                formattedDate = 'N/A';
                              }
                            }

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                consent['consent_type'] ?? 'Unknown',
                                style: TextStyle(
                                  color: AppTheme.textPrimaryDark,
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Version: ${consent['consent_version'] ?? 'N/A'}\n'
                                'Date: $formattedDate',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryDark,
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: AppTheme.fontSm,
                                ),
                              ),
                              trailing: Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: AppTheme.iconMd,
                              ),
                            );
                          },
                        ),
                      ),
                  SizedBox(height: AppTheme.spacing),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing,
                        ),
                        backgroundColor: AppTheme.textPrimaryDark.opacity10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        'CLOSE',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
    } catch (e, s) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: "Failed to load consent history",
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _currentUserData?['is_admin'] == true;
    final isSuperuser = _currentUserData?['is_superuser'] == true;
    final username = _currentUserData?['username'] ?? 'User';
    final displayName = _currentUserData?['display_name'] ?? username;
    final email = _currentUserData?['email'] ?? '';
    final profilePictureUrl = _currentUserData?['profile_picture_url'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Account Settings',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontTitle,
            color: AppTheme.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppTheme.spacing),
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleProfileNavigation,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                padding: EdgeInsets.all(AppTheme.spacing),
                decoration: BoxDecoration(
                  color: AppTheme.textPrimaryDark.opacity10,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor,
                          backgroundImage:
                              profilePictureUrl != null
                                  ? NetworkImage(profilePictureUrl)
                                  : null,
                          child:
                              profilePictureUrl == null
                                  ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: AppTheme.fontTitle,
                                      color: AppTheme.textPrimaryDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                        SizedBox(width: AppTheme.spacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: AppTheme.fontSubtitle,
                                  color: AppTheme.textPrimaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              ),
                              if (displayName != username)
                                Text(
                                  '@$username',
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSm,
                                    color: AppTheme.textTertiaryDark,
                                    fontFamily: AppTheme.fontFamily,
                                  ),
                                ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: AppTheme.fontBody,
                                    color: AppTheme.textSecondaryDark,
                                    fontFamily: AppTheme.fontFamily,
                                  ),
                                ),
                              if (isAdmin)
                                Container(
                                  margin: EdgeInsets.only(
                                    top: AppTheme.spacingXs,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSm,
                                    vertical: AppTheme.spacingXs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandPink.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: AppTheme.fontSm,
                                      color: AppTheme.brandPink,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_rounded,
                          color: AppTheme.textTertiaryDark,
                          size: AppTheme.iconMd,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacingXl),

          _buildSectionHeader('Security'),
          _buildSettingsTile(
            icon: Icons.lock_reset_rounded,
            title: 'Reset Password',
            subtitle: 'Request a password reset link',
            onTap: _handlePasswordReset,
          ),
          SizedBox(height: AppTheme.spacingXl),

          _buildSectionHeader('Privacy & Legal'),
          _buildSettingsTile(
            icon: Icons.policy_rounded,
            title: 'Consent History',
            subtitle: 'View your privacy and terms consents',
            onTap: _showConsentHistory,
          ),
          SizedBox(height: AppTheme.spacingSm),
          _buildSettingsTile(
            icon: Icons.download_rounded,
            title: 'Export My Data',
            subtitle: 'Download all your account data',
            onTap: _handleExportData,
            isLoading: _isLoadingExport,
          ),
          SizedBox(height: AppTheme.spacingXl),

          _buildSectionHeader('Information'),
          _buildSettingsTile(
            icon: Icons.campaign_rounded,
            title: 'News & Updates',
            subtitle: 'View announcements and changelog',
            onTap: _handleViewAnnouncements,
          ),
          SizedBox(height: AppTheme.spacingXl),

          if (isAdmin || isSuperuser) ...[
            _buildSectionHeader('Administration'),
            _buildSettingsTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Admin Dashboard',
              subtitle: 'Access to the admin panel',
              onTap: _handleAdminDashboard,
              iconColor: AppTheme.brandPink,
            ),
            SizedBox(height: AppTheme.spacingXl),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacingSm,
        bottom: AppTheme.spacingSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: AppTheme.fontSm,
          color: AppTheme.textTertiaryDark,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacing),
          decoration: BoxDecoration(
            color: AppTheme.textPrimaryDark.opacity10,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (iconColor ?? Theme.of(context).primaryColor)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? Theme.of(context).primaryColor,
                  size: AppTheme.iconMd,
                ),
              ),
              SizedBox(width: AppTheme.spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppTheme.font,
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppTheme.fontBody,
                        color: AppTheme.textSecondaryDark,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiaryDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
