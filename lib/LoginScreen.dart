import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:street_sync/ForgotPasswordScreen.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:street_sync/error_popup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
  bool _isLogin = true;
  bool _loading = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (AuthService.isConfigured) {
      _authSub = AuthService.auth.onAuthStateChange.listen((data) async {
        if (data.event != AuthChangeEvent.signedIn ||
            data.session == null ||
            !mounted) {
          return;
        }
        setState(() => _loading = true);
        final error = await ApiService.completeOAuthSession();
        if (!mounted) return;
        setState(() => _loading = false);
        if (ApiService.userId != null || error == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
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
    if (!_isLogin && (_nameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty)) {
      await showErrorPopup(context, 'Please enter your first and last name');
      return;
    }

    setState(() => _loading = true);

    String? error;
    if (_isLogin) {
      error = await ApiService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      if (_passwordCtrl.text.length < 8) {
        setState(() => _loading = false);
        await showErrorPopup(context, 'Password must be at least 8 characters');
        return;
      }
      error = await ApiService.signup(
        firstname: _nameCtrl.text.trim(),
        lastname: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      await showErrorPopup(context, error);
      return;
    }

    if (ApiService.userId != null || AuthService.isSignedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainShell(showAiTourOnStart: !_isLogin),
        ),
      );
    }
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

    // Native Google completes with a session immediately.
    if (AuthService.isSignedIn) {
      final syncError = await ApiService.completeOAuthSession();
      if (!mounted) return;
      setState(() => _loading = false);
      if (syncError != null && ApiService.userId == null) {
        await showErrorPopup(context, syncError);
        return;
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
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
                          _isLogin ? 'Sign in' : 'Sign up',
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
