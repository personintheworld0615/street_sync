import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:street_sync/AccessSetupScreen.dart';
import 'package:street_sync/ForgotPasswordScreen.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/TermsScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:street_sync/error_popup.dart';
import 'package:street_sync/first_run.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.startAsCreateAccount = false});

  /// First open lands on account creation. Sign-out still opens sign-in.
  final bool startAsCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Match Home: charcoal as primary, grey secondary.
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF5E5D5D);
  static const _pageBg = Color(0xFFF7F8FA);
  static const _cta = Color(0xFF111827);

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _obscure = true;
  late bool _isLogin;
  bool _loading = false;
  bool _didRoute = false;
  String _passwordText = '';

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _emailLooksValid =>
      _emailPattern.hasMatch(_emailCtrl.text.trim());

  bool get _passwordLongEnough => _passwordText.length >= 8;
  bool get _passwordHasUpper => _passwordText.contains(RegExp(r'[A-Z]'));
  bool get _passwordHasLower => _passwordText.contains(RegExp(r'[a-z]'));
  bool get _passwordHasNumber => _passwordText.contains(RegExp(r'[0-9]'));
  bool get _passwordMeetsRules =>
      _passwordLongEnough &&
      _passwordHasUpper &&
      _passwordHasLower &&
      _passwordHasNumber;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startAsCreateAccount;
    if (AuthService.isConfigured) {
      _authSub = AuthService.auth.onAuthStateChange.listen((data) async {
        // Email signup finishes on the terms page. This listener is only for
        // the browser OAuth redirect, which sets [_loading] before it returns.
        if (!_loading ||
            data.event != AuthChangeEvent.signedIn ||
            data.session == null ||
            !mounted) {
          return;
        }
        setState(() => _loading = true);
        final error = await ApiService.completeOAuthSession();
        if (!mounted) return;
        setState(() => _loading = false);
        if (ApiService.userId != null || error == null) {
          await _finishAuth(firstRun: !_isLogin);
        } else {
          await showErrorPopup(context, error);
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      await showErrorPopup(context, 'Please fill in all fields');
      return;
    }
    if (!_emailLooksValid) {
      await showErrorPopup(context, 'Enter a valid email address');
      return;
    }
    if (!_isLogin && (_nameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty)) {
      await showErrorPopup(context, 'Please enter your first and last name');
      return;
    }
    if (!_isLogin && !_passwordMeetsRules) {
      await showErrorPopup(
        context,
        'Password needs 8+ characters, upper and lower case, and a number',
      );
      return;
    }

    if (!_isLogin) {
      final first = _nameCtrl.text.trim();
      final last = _lastNameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      final outcome = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => TermsAgreementScreen(
            onAgree: () => ApiService.signup(
              firstname: first,
              lastname: last,
              email: email,
              password: password,
            ),
          ),
        ),
      );
      if (!mounted || outcome == null) return;
      if (outcome == 'confirm-email') {
        setState(() => _isLogin = true);
        await showAppDialog(
          context,
          'We sent a confirmation link to $email. Open it, then sign in.',
        );
        return;
      }
      if (outcome == 'ok' &&
          (ApiService.userId != null || AuthService.isSignedIn)) {
        await _finishAuth(firstRun: true);
      }
      return;
    }

    setState(() => _loading = true);

    String? error;
    try {
      error = await ApiService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } catch (e) {
      error = 'Something went wrong. Try again.';
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error == 'confirm-email') {
      setState(() => _isLogin = true);
      if (!mounted) return;
      await showAppDialog(
        context,
        'We sent a confirmation link to ${_emailCtrl.text.trim()}. Open it, then sign in.',
      );
      return;
    }

    if (error != null) {
      await showErrorPopup(context, error);
      return;
    }

    if (ApiService.userId != null || AuthService.isSignedIn) {
      await _finishAuth(firstRun: !_isLogin);
    }
  }

  Future<void> _finishAuth({required bool firstRun}) async {
    if (_didRoute || !mounted) return;
    if (ApiService.userId == null && !AuthService.isSignedIn) return;
    _didRoute = true;
    await FirstRun.markSignedInBefore();
    if (!mounted) return;

    if (firstRun) {
      await FirstRun.markTourPending();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AccessSetupScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _forgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: _emailCtrl.text.trim()),
      ),
    );
  }

  Future<void> _oauth(OAuthProvider provider) async {
    if (!_isLogin) {
      final outcome = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const TermsAgreementScreen()),
      );
      if (!mounted || outcome != 'ok') return;
    }
    setState(() => _loading = true);

    final error = provider == OAuthProvider.google
        ? await AuthService.signInWithGoogle()
        : await AuthService.signInWithOAuth(provider);

    if (!mounted) return;

    if (error != null) {
      setState(() => _loading = false);
      await showErrorPopup(context, error);
      return;
    }

    // Browser OAuth returns before the redirect finishes. A session that is
    // already present (rare) can finish here; otherwise wait for auth state.
    if (AuthService.isSignedIn) {
      final syncError = await ApiService.completeOAuthSession();
      if (!mounted) return;
      setState(() => _loading = false);
      if (syncError != null && ApiService.userId == null) {
        await showErrorPopup(context, syncError);
        return;
      }
      await _finishAuth(firstRun: !_isLogin);
      return;
    }

    // Browser OAuth: keep spinner until onAuthStateChange fires (or timeout).
    Future<void>.delayed(const Duration(seconds: 90), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Big brand mark — tweak fontSize freely.
              const Text(
                'StreetSync',
                style: TextStyle(
                  fontSize: 65,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: 1.0,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 35),
              Text(
                _isLogin ? 'Welcome back' : 'Create account',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Sign in to continue to your account.'
                    : 'Join StreetSync to start making an impact.',
                style: const TextStyle(
                  fontSize: 15,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 36),
              if (!_isLogin) ...[
                _label('First Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration(hint: 'Alex'),
                ),
                const SizedBox(height: 18),
                _label('Last Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _lastNameCtrl,
                  decoration: _inputDecoration(hint: 'Rivera'),
                ),
                const SizedBox(height: 18),
              ],
              _label('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: _inputDecoration(hint: 'you@example.com'),
              ),
              const SizedBox(height: 18),
              _label('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                onChanged: (value) => setState(() => _passwordText = value),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _muted,
                    ),
                  ),
                ),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 10),
                _passwordRule('At least 8 characters', _passwordLongEnough),
                _passwordRule('One uppercase letter', _passwordHasUpper),
                _passwordRule('One lowercase letter', _passwordHasLower),
                _passwordRule('One number', _passwordHasNumber),
              ],
              SizedBox(height: 15),
              if (_isLogin)
                Row(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cta,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _cta.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Sign in' : 'Create account',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? "Don't have an account? "
                        : 'Already have an account? ',
                    style: const TextStyle(color: _muted),
                  ),
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'Create account' : 'Log in',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),
              _oauthButton(
                label: 'Sign in with Google',
                icon: SvgPicture.asset(
                  'assets/images/google_g.svg',
                  width: 22,
                  height: 22,
                ),
                onTap: _loading ? null : () => _oauth(OAuthProvider.google),
              ),
              const SizedBox(height: 12),
              _oauthButton(
                label: 'Sign in with Apple',
                icon: const Icon(Icons.apple, color: _ink, size: 22),
                onTap: _loading ? null : () => _oauth(OAuthProvider.apple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordRule(String label, bool met) {
    final color = _passwordText.isEmpty
        ? _muted
        : (met ? const Color(0xFF43A047) : const Color(0xFFE53935));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met && _passwordText.isNotEmpty
                ? Icons.check_circle
                : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _oauthButton({
    required String label,
    required Widget icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _muted.withValues(alpha: 0.7)),
      suffixIcon: suffix,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _ink, width: 1.5),
      ),
    );
  }
}
