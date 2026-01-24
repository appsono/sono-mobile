import 'package:flutter/material.dart';
import 'package:sono/services/utils/analytics_service.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onNavigateToRegister;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    required this.onNavigateToRegister,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  String _loginIdentifier = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    AnalyticsService.logScreenView('LoginPage');
  }

  Future<void> _performLogin() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        //pass _loginIdentifier as the username to the ApiService
        await _apiService.login(_loginIdentifier, _password);
        widget.onLoginSuccess();
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXl,
              vertical: AppTheme.spacing2xl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome Back',
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
                    'Login to continue to Sono',
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
                      labelText: 'Username / Email',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.font,
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter username or email';
                      }
                      return null;
                    },
                    onSaved:
                        (value) =>
                            _loginIdentifier =
                                value!, //save to _loginIdentifier
                  ),
                  SizedBox(height: AppTheme.spacingLg),

                  TextFormField(
                    decoration: _inputDecoration(
                      labelText: 'Password',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                    onSaved: (value) => _password = value!,
                  ),
                  SizedBox(height: AppTheme.spacingMd),
                  // TODO: Implement Forgot Password functionality
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
                        onPressed: _performLogin,
                        child: Text(
                          'LOGIN',
                          style: TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: AppTheme.font,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  SizedBox(height: AppTheme.spacingXl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: AppTheme.fontBody,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onNavigateToRegister,
                        child: Text(
                          'Register Now',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.fontBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      suffixIcon:
          suffixIcon != null
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