import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;

  const ResetPasswordPage({
    super.key,
    required this.token,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  String _newPassword = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTokenValid = false;
  bool _isCheckingToken = true;
  bool _passwordReset = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _verifyToken();
  }

  Future<void> _verifyToken() async {
    try {
      await _apiService.verifyResetToken(widget.token);
      if (mounted) {
        setState(() {
          _isTokenValid = true;
          _isCheckingToken = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTokenValid = false;
          _isCheckingToken = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await _apiService.resetPassword(
          token: widget.token,
          newPassword: _newPassword,
        );
        if (mounted) {
          setState(() {
            _passwordReset = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString().replaceFirst("Exception: ", "");
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: AppTheme.textPrimaryDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXl,
              vertical: AppTheme.spacing2xl,
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isCheckingToken) {
      return _buildLoadingView();
    } else if (!_isTokenValid) {
      return _buildInvalidTokenView();
    } else if (_passwordReset) {
      return _buildSuccessView();
    } else {
      return _buildFormView();
    }
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: Theme.of(context).primaryColor,
        ),
        SizedBox(height: AppTheme.spacingXl),
        Text(
          'Verifying reset link...',
          style: TextStyle(
            fontSize: AppTheme.font,
            color: AppTheme.textSecondaryDark,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildInvalidTokenView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 80,
          color: AppTheme.error,
        ),
        SizedBox(height: AppTheme.spacingXl),
        Text(
          'Invalid or Expired Link',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 28,
            color: AppTheme.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppTheme.spacingSm),
        Text(
          _errorMessage ?? 'This password reset link is invalid or has expired. Please request a new one.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.font,
            color: AppTheme.textSecondaryDark,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: EdgeInsets.symmetric(
              vertical: AppTheme.spacing,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            elevation: 3,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'BACK TO LOGIN',
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.font,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_reset_rounded,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          SizedBox(height: AppTheme.spacingXl),
          Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 28,
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            'Enter your new password below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.font,
              color: AppTheme.textSecondaryDark,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 40),
          TextFormField(
            decoration: _inputDecoration(
              labelText: 'New Password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppTheme.textTertiaryDark,
                  size: AppTheme.iconMd,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.font,
            ),
            obscureText: _obscurePassword,
            validator: _validatePassword,
            onSaved: (value) => _newPassword = value!,
            onChanged: (value) => _newPassword = value,
          ),
          SizedBox(height: AppTheme.spacingLg),
          TextFormField(
            decoration: _inputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppTheme.textTertiaryDark,
                  size: AppTheme.iconMd,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.font,
            ),
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _newPassword) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          SizedBox(height: AppTheme.spacingMd),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
            child: Text(
              'Password must contain:\n• At least 8 characters\n• One uppercase letter\n• One lowercase letter\n• One number\n• One special character',
              style: TextStyle(
                fontSize: AppTheme.fontSm,
                color: AppTheme.textTertiaryDark,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacingLg),
          if (_errorMessage != null)
            Padding(
              padding: EdgeInsets.only(bottom: AppTheme.spacing),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.error,
                  fontSize: AppTheme.fontBody,
                ),
              ),
            ),
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(
                      vertical: AppTheme.spacing,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _resetPassword,
                  child: Text(
                    'RESET PASSWORD',
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.font,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 80,
          color: Colors.green,
        ),
        SizedBox(height: AppTheme.spacingXl),
        Text(
          'Password Reset!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 28,
            color: AppTheme.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppTheme.spacingSm),
        Text(
          'Your password has been reset successfully. You can now log in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.font,
            color: AppTheme.textSecondaryDark,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: EdgeInsets.symmetric(
              vertical: AppTheme.spacing,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            elevation: 3,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            'GO TO LOGIN',
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.font,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: AppTheme.textTertiaryDark, fontSize: 15),
      hintText: labelText,
      hintStyle: TextStyle(color: AppTheme.textDisabledDark, fontSize: 15),
      prefixIcon: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacing,
          right: AppTheme.spacingMd,
        ),
        child: Icon(
          prefixIcon,
          color: AppTheme.textTertiaryDark,
          size: AppTheme.iconMd,
        ),
      ),
      suffixIcon: suffixIcon != null
          ? Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingMd,
                right: AppTheme.spacing,
              ),
              child: suffixIcon,
            )
          : null,
      filled: true,
      fillColor: AppTheme.textPrimaryDark.opacity10,
      contentPadding: EdgeInsets.symmetric(
        vertical: AppTheme.fontSubtitle,
        horizontal: AppTheme.spacingLg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: AppTheme.textPrimaryDark.opacity10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: AppTheme.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: AppTheme.error, width: 1.5),
      ),
      errorStyle: TextStyle(fontSize: AppTheme.fontSm),
    );
  }
}