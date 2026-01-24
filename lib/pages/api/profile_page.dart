import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/utils/error_handler.dart';
import 'package:sono/styles/app_theme.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final VoidCallback onLogout;
  final Future<void> Function() onProfileUpdate;

  const ProfilePage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.onProfileUpdate,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _localProfilePictureUrl;

  String get _username => widget.currentUser?['username'] ?? '';
  String get _email => widget.currentUser?['email'] ?? '';
  String get _displayName => widget.currentUser?['display_name'] ?? '';
  String get _bio => widget.currentUser?['bio'] ?? '';
  String? get _profilePictureUrl =>
      _localProfilePictureUrl ?? widget.currentUser?['profile_picture_url'];

  Future<void> _handleImagePick() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _isLoading = true);
      try {
        await _apiService.uploadProfilePicture(File(image.path));
        await widget.onProfileUpdate();

        //fetch updated user data to get the new profile picture URL
        final updatedUser = await _apiService.getCurrentUser();

        if (mounted) {
          setState(() {
            _localProfilePictureUrl = updatedUser['profile_picture_url'];
            _isLoading = false;
          });

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: AppTheme.spacingSm),
                  const Text('Profile picture updated!'),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          );
        }
      } catch (e, s) {
        if (mounted) {
          setState(() => _isLoading = false);
          ErrorHandler.showErrorSnackbar(
            context: context,
            message: "Failed to upload image",
            error: e,
            stackTrace: s,
          );
        }
      }
    }
  }

  void _showEditDialog() {
    final displayNameController = TextEditingController(text: _displayName);
    final bioController = TextEditingController(text: _bio);
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusXl),
            topRight: Radius.circular(AppTheme.radiusXl),
          ),
        ),
        padding: EdgeInsets.only(
          top: AppTheme.spacing,
          left: AppTheme.spacingXl,
          right: AppTheme.spacingXl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingXl,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiaryDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppTheme.spacingXl),
              TextFormField(
                controller: displayNameController,
                style: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                ),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  filled: true,
                  fillColor: AppTheme.textPrimaryDark.opacity10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppTheme.spacing),
              TextFormField(
                controller: bioController,
                style: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                ),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  prefixIcon: Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  filled: true,
                  fillColor: AppTheme.textPrimaryDark.opacity10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingXl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        await _apiService.updateCurrentUser(
                          displayName: displayNameController.text.trim(),
                          bio: bioController.text.trim(),
                        );
                        await widget.onProfileUpdate();
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white),
                                  SizedBox(width: AppTheme.spacingSm),
                                  const Text('Profile updated!'),
                                ],
                              ),
                              backgroundColor: Colors.green[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                          );
                        }
                      } catch (e, s) {
                        if (mounted && context.mounted) {
                          ErrorHandler.showErrorSnackbar(
                            context: context,
                            message: "Failed to update profile",
                            error: e,
                            stackTrace: s,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacing),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    'SAVE',
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.fontBody,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: AppTheme.textPrimaryDark,
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: AppTheme.textPrimaryDark),
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusXl),
                  bottomRight: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: _profilePictureUrl != null
                            ? NetworkImage(_profilePictureUrl!)
                            : null,
                        child: _profilePictureUrl == null
                            ? Text(
                                _displayName.isNotEmpty
                                    ? _displayName[0].toUpperCase()
                                    : _username[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryDark,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: Theme.of(context).primaryColor,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            onTap: _isLoading ? null : _handleImagePick,
                            customBorder: const CircleBorder(),
                            child: Container(
                              padding: EdgeInsets.all(AppTheme.spacingSm),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: AppTheme.textPrimaryDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacing),
                  Text(
                    _displayName.isNotEmpty ? _displayName : _username,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXs),
                  Text(
                    '@$_username',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textTertiaryDark,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  if (_bio.isNotEmpty) ...[
                    SizedBox(height: AppTheme.spacing),
                    Text(
                      _bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.fontBody,
                        color: AppTheme.textSecondaryDark,
                        fontFamily: AppTheme.fontFamily,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppTheme.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNT INFO',
                    style: TextStyle(
                      color: AppTheme.textTertiaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  _buildInfoTile(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: _email,
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  _buildInfoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Username',
                    value: _username,
                  ),
                  SizedBox(height: AppTheme.spacingXl),
                  Text(
                    'ACTIONS',
                    style: TextStyle(
                      color: AppTheme.textTertiaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onLogout();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.white),
                          SizedBox(width: AppTheme.spacingSm),
                          Text(
                            'LOGOUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: AppTheme.fontBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
          SizedBox(width: AppTheme.spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textTertiaryDark,
                    fontSize: 12,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXs),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: AppTheme.fontBody,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}