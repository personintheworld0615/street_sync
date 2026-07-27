import 'dart:async';

import 'package:flutter/material.dart';
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
  static const _blue = Color(0xFF2196F3);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  static const _pageBg = Color(0xFFF4F7FB);

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
        // Must handle signedIn even while _loading is true (OAuth sets it).
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
    if (!_isLogin &&
        (_nameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty)) {
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
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@email.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
    if (email == null) return;
    if (email.isEmpty) {
      if (!mounted) return;
      await showErrorPopup(context, 'Enter the email for your account');
      return;
    }

    setState(() => _loading = true);
    final error = await AuthService.resetPassword(email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      await showErrorPopup(context, error);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check your email'),
        content: Text(
          'We sent a reset link to $email. Open it on this device to choose a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
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
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.map_rounded, color: _blue, size: 28),
              ),
              const SizedBox(height: 28),
              Text(
                _isLogin ? 'Welcome back' : 'Create account',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Sign in to sync with your community.'
                    : 'Join StreetSync to start making an impact.',
                style: const TextStyle(
                  fontSize: 15,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              if (!_isLogin) ...[
                _label('First Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration(
                    hint: 'Alex',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                _label('Last Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _lastNameCtrl,
                  decoration: _inputDecoration(
                    hint: 'Rivera',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _label('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: _inputDecoration(
                  hint: 'you@email.com',
                  icon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 18),
              _label('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: _inputDecoration(
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
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
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
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
                          _isLogin ? 'Log in' : 'Sign up',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _oauthButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      onTap: _loading
                          ? null
                          : () => _oauth(OAuthProvider.google),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _oauthButton(
                      label: 'Apple',
                      icon: Icons.apple,
                      onTap: _loading
                          ? null
                          : () => _oauth(OAuthProvider.apple),
                    ),
                  ),
                ],
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
                      _isLogin ? 'Sign up' : 'Log in',
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oauthButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: _ink, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _muted.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
    );
  }
}
