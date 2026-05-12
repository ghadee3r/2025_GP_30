import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

List<BoxShadow> get subtleShadow => [
  BoxShadow(
    color: dfNavyIndigo.withOpacity(0.04),
    blurRadius: 20,
    offset: const Offset(0, 8),
  ),
];

final supabase = sb.Supabase.instance.client;

class NewPassword extends StatefulWidget {
  const NewPassword({super.key});

  @override
  State<NewPassword> createState() => _NewPasswordState();
}

class _NewPasswordState extends State<NewPassword> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _currentUserEmail;
  // Three states: null = still checking, true = valid session, false = no session
  bool? _sessionValid;

  // Inline Validation States
  String? _passwordError;
  String? _confirmPasswordError;

  // ─── FIX: listen for the deep-link URI that carries the recovery token ───
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinkAndSession();
  }

  /// Tries to hydrate a Supabase recovery session from the deep-link URI.
  /// Works whether the app was cold-started by the link or was already running.
  Future<void> _initDeepLinkAndSession() async {
    // 1. Check if there is already a valid recovery session (app was already
    //    running and the auth state changed via onAuthStateChange).
    final existing = supabase.auth.currentSession;
    if (existing != null) {
      if (mounted) {
        setState(() {
          _currentUserEmail = existing.user.email;
          _sessionValid = true;
        });
      }
      return;
    }

    // 2. Try the initial / cold-start URI first.
    Uri? initialUri;
    try {
      initialUri = await _appLinks.getInitialLink();
    } catch (_) {}

    if (initialUri != null && _isRecoveryUri(initialUri)) {
      await _exchangeUri(initialUri);
      return;
    }

    // 3. Subscribe to incoming links (app already open).
    _linkSub = _appLinks.uriLinkStream.listen((uri) async {
      if (_isRecoveryUri(uri)) {
        await _exchangeUri(uri);
      }
    });

    // 4. Give it a short grace period, then mark session as invalid if nothing
    //    came through.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _sessionValid == null) {
      setState(() => _sessionValid = false);
    }
  }

  bool _isRecoveryUri(Uri uri) {
    // Matches  io.rikaz.app://reset-password  (with or without extra params)
    return uri.host == 'reset-password' ||
        uri.path.contains('reset-password') ||
        uri.fragment.contains('type=recovery') ||
        uri.queryParameters.containsKey('token') ||
        uri.toString().contains('access_token');
  }

  /// Calls Supabase to exchange the one-time token in the URI for a live session.
  Future<void> _exchangeUri(Uri uri) async {
    try {
      // getSessionFromUrl parses both the ?token_hash= query param (PKCE flow)
      // and the #access_token= fragment (implicit flow).
      final response = await supabase.auth.getSessionFromUrl(uri);
      if (mounted) {
        setState(() {
          _currentUserEmail = response.session.user.email;
          _sessionValid = true;
        });
      }
    } on sb.AuthException catch (e) {
      debugPrint('Session exchange error: ${e.message}');
      if (mounted) setState(() => _sessionValid = false);
    } catch (e) {
      debugPrint('Session exchange unknown error: $e');
      if (mounted) setState(() => _sessionValid = false);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- MINIMALIST BLURRED SPRING DIALOG ---
  Future<bool?> _showSpringDialog({
    required String title,
    required String message,
    bool isError = true,
    String confirmText = 'OK',
    String? cancelText,
    IconData? customIcon,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(color: dfNavyIndigo.withOpacity(0.2)),
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                          color: dfNavyIndigo.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        customIcon ??
                            (isError
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded),
                        color: isError ? errorIndicatorRed : dfNavyIndigo,
                        size: 64,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: dfNavyIndigo,
                            letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: secondaryTextGrey, fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          if (cancelText != null)
                            Expanded(
                              child: _InteractivePill(
                                onTap: () => Navigator.pop(context, false),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Center(
                                    child: Text(cancelText,
                                        style: const TextStyle(
                                            color: secondaryTextGrey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                ),
                              ),
                            ),
                          if (cancelText != null) const SizedBox(width: 16),
                          Expanded(
                            child: _InteractivePill(
                              onTap: () => Navigator.pop(context, true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: dfNavyIndigo,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: dfNavyIndigo.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5))
                                  ],
                                ),
                                child: Center(
                                  child: Text(confirmText,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Transform.scale(
            scale: Curves.easeOutBack.transform(anim.value),
            child: Opacity(opacity: anim.value, child: child));
      },
    );
  }

  void _showSuccessDialog(String message) async {
    await _showSpringDialog(
        title: 'Success',
        message: message,
        isError: false,
        confirmText: 'Continue');
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false);
    }
  }

  void _goBackToLogin() async {
    if (_newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty) {
      final shouldCancel = await _showSpringDialog(
        title: 'Cancel Reset?',
        message: 'Are you sure you want to cancel? Your progress will be lost.',
        isError: true,
        confirmText: 'Cancel Reset',
        cancelText: 'Continue',
        customIcon: Icons.warning_amber_rounded,
      );
      if (shouldCancel == true) _navigateToLogin();
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String? _validatePasswordRequirements(String password) {
    if (password.length < 8) return "Must be at least 8 characters.";
    if (!RegExp(r'[A-Z]').hasMatch(password))
      return "Must contain an uppercase letter.";
    if (!RegExp(r'[a-z]').hasMatch(password))
      return "Must contain a lowercase letter.";
    if (!RegExp(r'\d').hasMatch(password)) return "Must contain a number.";
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password))
      return "Must contain a special character.";
    return null;
  }

  Future<void> _updatePassword() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showSpringDialog(
          title: "Session Error",
          message:
              "No valid session found. Please request a new reset link.",
          isError: true);
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _passwordError = null;
      _confirmPasswordError = null;
    });

    bool hasValidationErrors = false;

    if (newPassword.isEmpty) {
      _passwordError = "Password is required.";
      hasValidationErrors = true;
    } else {
      final reqError = _validatePasswordRequirements(newPassword);
      if (reqError != null) {
        _passwordError = reqError;
        hasValidationErrors = true;
      }
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = "Please confirm your password.";
      hasValidationErrors = true;
    } else if (newPassword != confirmPassword) {
      _confirmPasswordError = "Passwords do not match.";
      hasValidationErrors = true;
    }

    if (hasValidationErrors) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        if (!mounted) return;
        _showSuccessDialog(
            'Your password has been updated successfully. You will be logged into your account.');
      }
    } on sb.AuthException catch (e) {
      if (!mounted) return;
      if (e.message.contains('password should be different') ||
          e.message.contains('same as old')) {
        setState(() {
          _passwordError =
              "Please choose a different password from your current one.";
        });
      } else {
        _showSpringDialog(
            title: "Update Error", message: e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSpringDialog(
          title: "Update Error",
          message: "An unexpected error occurred.",
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GLASSMORPHIC INPUT FIELD ---
  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? errorText,
  }) {
    final bool hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: subtleShadow,
          ),
          child: Row(
            children: [
              Icon(
                  icon,
                  color: hasError
                      ? errorIndicatorRed
                      : secondaryTextGrey.withOpacity(0.7),
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  autocorrect: false,
                  cursorColor: dfTealCyan,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: dfNavyIndigo),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                        color: secondaryTextGrey.withOpacity(0.6),
                        fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (val) {
                    if (hasError) {
                      setState(() {
                        if (controller == _newPasswordController)
                          _passwordError = null;
                        if (controller == _confirmPasswordController)
                          _confirmPasswordError = null;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                    obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: secondaryTextGrey.withOpacity(0.7),
                    size: 20),
                onPressed: onToggleVisibility,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: hasError ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 22,
            padding: const EdgeInsets.only(left: 16),
            child: Text(errorText ?? '',
                style: const TextStyle(
                    color: errorIndicatorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Still exchanging the token
    if (_sessionValid == null) {
      return Scaffold(
        backgroundColor: primaryBackground,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: dfTealCyan),
              SizedBox(height: 20),
              Text('Verifying secure session...',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextGrey)),
            ],
          ),
        ),
      );
    }

    // Token exchange failed — show a clear error instead of a broken form
    if (_sessionValid == false) {
      return Scaffold(
        backgroundColor: primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_off_rounded,
                    color: errorIndicatorRed, size: 64),
                const SizedBox(height: 24),
                const Text('Invalid or Expired Link',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: dfNavyIndigo,
                        letterSpacing: -0.5)),
                const SizedBox(height: 12),
                const Text(
                  'This reset link has already been used or has expired. Please request a new one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: secondaryTextGrey, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 36),
                _InteractivePill(
                  onTap: _navigateToLogin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: dfNavyIndigo,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: dfNavyIndigo.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: const Center(
                      child: Text('Back to Login',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Session valid — show the form
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)],
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: _InteractivePill(
              onTap: _goBackToLogin,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: subtleShadow,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: dfNavyIndigo, size: 24),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Hero(
                      tag: 'rikaz_logo',
                      child: Image.asset(
                        "assets/images/RikazLogo.png",
                        height: 120,
                        width: 120,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text('New Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: dfNavyIndigo,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 12),
                    Text(
                      _currentUserEmail != null
                          ? 'Enter a new password for $_currentUserEmail'
                          : 'Enter a new, secure password for your account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: secondaryTextGrey, height: 1.4),
                    ),
                    const SizedBox(height: 40),

                    _buildGlassInput(
                      controller: _newPasswordController,
                      hintText: "New Password",
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscureNewPassword,
                      errorText: _passwordError,
                      onToggleVisibility: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                    ),

                    _buildGlassInput(
                      controller: _confirmPasswordController,
                      hintText: "Confirm Password",
                      icon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirmPassword,
                      errorText: _confirmPasswordError,
                      onToggleVisibility: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),

                    const SizedBox(height: 16),

                    _InteractivePill(
                      onTap: _isLoading ? () {} : _updatePassword,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: dfNavyIndigo,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: dfNavyIndigo.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5))
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text("Update Password",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REUSABLE INTERACTIVE SQUISH COMPONENT
// =============================================================================
class _InteractivePill extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractivePill({required this.child, required this.onTap});

  @override
  State<_InteractivePill> createState() => _InteractivePillState();
}

class _InteractivePillState extends State<_InteractivePill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}