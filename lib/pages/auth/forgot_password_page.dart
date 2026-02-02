import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _requestPasswordReset() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await _apiService.requestPasswordReset(_email);
        if (mounted) {
          setState(() {
            _emailSent = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
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
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
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
            'Forgot Password?',
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
            'Enter your email address and we\'ll send you instructions to reset your password.',
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
              labelText: 'Email',
              prefixIcon: Icons.email_outlined,
            ),
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.font,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
            onSaved: (value) => _email = value!,
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
                  onPressed: _requestPasswordReset,
                  child: Text(
                    'SEND RESET LINK',
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.font,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
          SizedBox(height: AppTheme.spacingXl),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Back to Login',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: AppTheme.fontBody,
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
          Icons.mark_email_read_rounded,
          size: 80,
          color: Colors.green,
        ),
        SizedBox(height: AppTheme.spacingXl),
        Text(
          'Check Your Email',
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
          'If an account with that email exists, we\'ve sent password reset instructions.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.font,
            color: AppTheme.textSecondaryDark,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        SizedBox(height: AppTheme.spacingXl),
        Text(
          'Please check your inbox and follow the instructions to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontBody,
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
            'BACK TO LOGIN',
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.font,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacingLg),
        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _errorMessage = null;
            });
          },
          child: Text(
            'Try Again',
            style: TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: AppTheme.fontBody,
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