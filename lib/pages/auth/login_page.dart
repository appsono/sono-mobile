import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/pages/auth/forgot_password_page.dart';
import 'package:sono/widgets/global/consent_dialog.dart';
import 'package:sono/pages/info/privacy_page.dart';
import 'package:sono/pages/info/terms_page.dart';

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

        //check if user has consented to privacy and terms
        if (mounted) {
          await _checkConsent();
        }

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

  Future<void> _checkConsent() async {
    const consentVersion = '2.0';

    //check privacy policy consent
    final privacyAccepted = await ConsentDialog.showIfNeeded(
      context: context,
      consentType: 'privacy_policy',
      consentVersion: consentVersion,
      title: 'Privacy Policy',
      content: '''
By using Sono, you agree to our Privacy Policy.

Key points:
• App can be used locally without any account - no data collection for local use
• Creating a Sono Account is OPTIONAL and enables uploading to CDN and cloud playlists
• Crash logs are optional and can be disabled in Settings
• Your data is never sold to third parties
• You have full GDPR rights (access, deletion, portability)

Age requirement for accounts: 13+ years old

Tap "Read Full Policy" below to view the complete Privacy Policy.
      ''',
      onViewFullDocument: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PrivacyPage()),
        );
      },
      onDeclined: () async {
        //logout if declined
        await _apiService.logout();
      },
    );

    if (privacyAccepted == null || !privacyAccepted) {
      //user declined, logout
      await _apiService.logout();
      if (mounted) {
        setState(() {
          _errorMessage = 'You must accept the Privacy Policy to use Sono';
        });
      }
      return;
    }

    //check terms of service consent
    if (!mounted) return;
    final termsAccepted = await ConsentDialog.showIfNeeded(
      context: context,
      consentType: 'terms_of_service',
      consentVersion: consentVersion,
      title: 'Terms of Service',
      content: '''
By using Sono, you agree to our Terms of Service.

Key terms:
• App can be used locally without any account for all basic features
• Creating a Sono Account is OPTIONAL and requires being 13+ years old
• Sono Accounts enable uploading songs to CDN and cloud playlists
• You must have legal rights to upload any content
• Do not violate copyright laws or abuse the service
• SAS sessions are peer-to-peer, no audio data stored on our servers

Operated by: Mathis Laarmanns, Germany
Contact: business@mail.sono.wtf

Tap "Read Full Terms" below to view the complete Terms of Service.
      ''',
      onViewFullDocument: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TermsPage()),
        );
      },
      onDeclined: () async {
        //logout if declined
        await _apiService.logout();
      },
    );

    if (termsAccepted == null || !termsAccepted) {
      //user declined, logout
      await _apiService.logout();
      if (mounted) {
        setState(() {
          _errorMessage = 'You must accept the Terms of Service to use Sono';
        });
      }
      return;
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: AppTheme.fontBody,
                        ),
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