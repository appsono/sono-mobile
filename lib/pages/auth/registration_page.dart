import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/consent_dialog.dart';
import 'package:sono/pages/info/privacy_page.dart';
import 'package:sono/pages/info/terms_page.dart';

class RegistrationPage extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;
  final VoidCallback onNavigateToLogin;

  const RegistrationPage({
    super.key,
    required this.onRegistrationSuccess,
    required this.onNavigateToLogin,
  });

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  String _username = '';
  String _email = '';
  String _password = '';
  String _displayName = '';

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _performRegistration() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        //Step 1: Register the user
        await _apiService.registerUser(
          username: _username,
          email: _email,
          password: _password,
          displayName: _displayName.isNotEmpty ? _displayName : null,
        );

        //Step 2: Attempt to log in automatically
        try {
          await _apiService.login(_username, _password);

          //Step 3: Check consent (Privacy Policy and Terms of Service)
          if (mounted) {
            await _checkConsent();
          }

          //if login is successful => ApiService saves the token
          widget
              .onRegistrationSuccess(); //notify main that registration & auto login were successful
        } catch (loginError) {
          //handle auto login failure
          if (mounted) {
            setState(() {
              _errorMessage =
                  "Registration successful, but auto-login failed. Please log in manually. Error: ${loginError.toString().replaceFirst("Exception: ", "")}";
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        //handle registration failure
        if (mounted) {
          setState(() {
            _errorMessage = e.toString().replaceFirst("Exception: ", "");
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
          _isLoading = false;
        });
      }
      throw Exception('Privacy Policy not accepted');
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
          _isLoading = false;
        });
      }
      throw Exception('Terms of Service not accepted');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
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
                    'Create Account',
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
                    'Join Sono to start your music journey',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.font,
                      color: AppTheme.textSecondaryDark,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 30),

                  TextFormField(
                    decoration: _inputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.font,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 2 || value.length > 32) {
                        return 'Username must be 2 to 32 characters';
                      }
                      return null;
                    },
                    onSaved: (value) => _username = value!,
                  ),
                  SizedBox(height: AppTheme.spacing),

                  TextFormField(
                    decoration: _inputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icons.email_rounded,
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
                      final emailRegex = RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                      );
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value!,
                  ),
                  SizedBox(height: AppTheme.spacing),

                  TextFormField(
                    controller: _passwordController,
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
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      ),
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.font,
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onSaved: (value) => _password = value!,
                  ),
                  SizedBox(height: AppTheme.spacing),

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
                        onPressed:
                            () => setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            ),
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
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppTheme.spacing),

                  TextFormField(
                    decoration: _inputDecoration(
                      labelText: 'Display Name (Optional)',
                      prefixIcon: Icons.badge_rounded,
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.font,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (value.isEmpty || value.length > 50) {
                          return 'Display name must be 1 to 50 characters if provided';
                        }
                      }
                      return null;
                    },
                    onSaved: (value) => _displayName = value ?? '',
                  ),
                  SizedBox(height: AppTheme.spacingXl),

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
                        onPressed: _performRegistration,
                        child: Text(
                          'REGISTER',
                          style: TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: AppTheme.font,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  SizedBox(height: AppTheme.spacingLg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: AppTheme.fontBody,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onNavigateToLogin,
                        child: Text(
                          'Login Now',
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