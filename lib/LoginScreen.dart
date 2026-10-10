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
  const LoginScreen({
    super.key,
    this.startAsCreateAccount = false,
    this.startupNotice,
  });

  /// First open lands on account creation. Sign-out still opens sign-in.
  final bool startAsCreateAccount;

  /// Shown once after cold start (e.g. left Terms without finishing signup).
  final String? startupNotice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
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
  /// True while we are finishing an OAuth redirect (login or create).
  bool _oauthInFlight = false;
  /// Guards against double completion from redirect + already-signed-in path.
  bool _oauthCompleting = false;
  String _passwordText = '';
  Timer? _oauthTimeout;
  Timer? _oauthResumeCheck;
  /// Bumped to abort in-flight OAuth resume polls after cancel/dispose.
  int _oauthGeneration = 0;

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
    WidgetsBinding.instance.addObserver(this);
    _isLogin = !widget.startAsCreateAccount;
    if (AuthService.isConfigured) {
      _authSub = AuthService.auth.onAuthStateChange.listen((data) async {
        // Email signup finishes on the terms page. This listener is only for
        // the browser OAuth redirect, which sets [_oauthInFlight] first.
        if (!_oauthInFlight ||
            data.event != AuthChangeEvent.signedIn ||
            data.session == null ||
            !mounted) {
          return;
        }
        _cancelOauthTimers();
        await _completeOAuthAfterRedirect();
      });
    }
    final notice = widget.startupNotice;
    if (notice != null && notice.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showAppDialog(context, notice);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelOauthTimers();
    _authSub?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_oauthInFlight || _oauthCompleting || _didRoute) return;
    // Coming back from the browser: either the deep-link session is still
    // exchanging (can take several seconds) or the user hit X. Poll for a
    // session first — only treat as cancel after that window.
    _oauthResumeCheck?.cancel();
    _oauthResumeCheck = Timer(Duration.zero, _pollSessionAfterOauthResume);
  }

  /// After Google/Apple returns, wait for PKCE/session before giving up.
  Future<void> _pollSessionAfterOauthResume() async {
    final gen = _oauthGeneration;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || gen != _oauthGeneration) return;
      if (!_oauthInFlight || _didRoute || _oauthCompleting) return;
      if (AuthService.isSignedIn) {
        _cancelOauthTimers();
        await _completeOAuthAfterRedirect();
        return;
      }
    }
    // ~8s with no session → user cancelled (X) or deep link failed.
    if (!mounted || gen != _oauthGeneration) return;
    if (_oauthInFlight && !_oauthCompleting && !_didRoute) {
      _cancelOauth();
    }
  }

  void _cancelOauthTimers() {
    _oauthGeneration++;
    _oauthTimeout?.cancel();
    _oauthTimeout = null;
    _oauthResumeCheck?.cancel();
    _oauthResumeCheck = null;
  }

  /// Back to a normal login screen — no error toast (user cancelled).
  void _cancelOauth() {
    _cancelOauthTimers();
    _oauthInFlight = false;
    _oauthCompleting = false;
    if (mounted && _loading) setState(() => _loading = false);
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
      await _handleEmailCreate();
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

    if (error != null) {
      if (ApiService.isInvalidCredentials(error)) {
        final create = await _promptCreateAccount();
        if (!mounted) return;
        if (create) setState(() => _isLogin = false);
        return;
      }
      await showErrorPopup(context, error);
      return;
    }

    if (ApiService.userId != null) {
      await _finishAuth(firstRun: ApiService.needsAiTour);
    }
  }

  /// Create-account email: terms → signup. If the email already exists, sign in.
  Future<void> _handleEmailCreate() async {
    final first = _nameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final outcome = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TermsAgreementScreen(
          onAgree: () async {
            final error = await ApiService.signup(
              firstname: first,
              lastname: last,
              email: email,
              password: password,
            );
            if (ApiService.isAlreadyRegistered(error)) {
              final loginError = await ApiService.login(
                email: email,
                password: password,
              );
              if (loginError == null) return 'signed-in-existing';
              return 'That email already has an account. Try signing in.';
            }
            return error;
          },
        ),
      ),
    );
    if (!mounted || outcome == null) return;
    if (outcome == 'signed-in-existing' && ApiService.userId != null) {
      await _finishAuth(firstRun: ApiService.needsAiTour);
      return;
    }
    if (outcome == 'ok' && ApiService.userId != null) {
      await _finishAuth(firstRun: true);
    } else if (outcome != 'ok' && outcome != 'signed-in-existing') {
      await showErrorPopup(context, outcome);
    }
  }

  Future<bool> _promptCreateAccount() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'No account found for that email, or the password is wrong. Create an account if you\'re new.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: _muted,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Try again',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _finishAuth({required bool firstRun}) async {
    if (_didRoute || !mounted) return;
    if (ApiService.userId == null) return;
    _didRoute = true;
    _oauthInFlight = false;
    _cancelOauthTimers();
    await FirstRun.markSignedInBefore();
    if (!mounted) return;

    if (firstRun) {
      await FirstRun.markTourPending(userId: ApiService.userId);
      if (!mounted) return;
      final asked = await FirstRun.permissionsWereAsked();
      if (!mounted) return;
      final Widget next = asked
          ? const MainShell(showAiTourOnStart: true)
          : const AccessSetupScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => next,
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

  /// Google/Apple from login or create. Supabase Auth may exist after OAuth;
  /// the StreetSync users table is the real account (created only after terms).
  Future<void> _oauth(OAuthProvider provider) async {
    _cancelOauthTimers();
    setState(() {
      _loading = true;
      _oauthInFlight = true;
    });

    final error = provider == OAuthProvider.google
        ? await AuthService.signInWithGoogle()
        : await AuthService.signInWithOAuth(provider);

    if (!mounted) return;

    if (error == kOAuthCanceled) {
      _cancelOauth();
      return;
    }

    if (error != null) {
      _cancelOauth();
      await showErrorPopup(context, error);
      return;
    }

    // Native Google (or rare already-signed-in) — session is ready now.
    if (AuthService.isSignedIn) {
      _cancelOauthTimers();
      await _completeOAuthAfterRedirect();
      return;
    }

    // Safety net if the browser never returns a cancel/resume signal.
    _oauthTimeout = Timer(const Duration(seconds: 45), () async {
      if (!mounted || !_loading || !_oauthInFlight || _oauthCompleting) return;
      _cancelOauth();
      await showErrorPopup(
        context,
        'Sign-in took too long. Close the browser and try again.',
      );
    });
  }

  Future<void> _completeOAuthAfterRedirect() async {
    if (_didRoute || _oauthCompleting || !mounted) return;
    _oauthCompleting = true;
    _cancelOauthTimers();
    if (mounted) setState(() => _loading = true);

    try {
      // Brief wait — session can land a tick after the signedIn event.
      if (!AuthService.isSignedIn) {
        for (var i = 0; i < 10 && mounted && !AuthService.isSignedIn; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (!mounted) return;
      if (!AuthService.isSignedIn) {
        _oauthInFlight = false;
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Users table is source of truth — look up only; never invent a profile.
      final lookup =
          await ApiService.completeOAuthSession(createIfMissing: false);
      if (!mounted) return;

      if (lookup == 'user-not-found') {
        // Auth exists, no StreetSync account yet → terms, then create users row.
        setState(() => _loading = false);
        final outcome = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => TermsAgreementScreen(
              onAgree: () =>
                  ApiService.completeOAuthSession(createIfMissing: true),
            ),
          ),
        );
        if (!mounted) return;
        if (outcome == 'ok' && ApiService.userId != null) {
          await _finishAuth(firstRun: true);
        } else {
          _oauthInFlight = false;
          // Disagreed / backed out: delete orphan Auth so Google can redo it.
          await ApiService.abandonSignup();
          if (mounted) {
            setState(() => _loading = false);
            if (outcome != null && outcome != 'ok') {
              await showErrorPopup(context, outcome);
            }
          }
        }
        return;
      }

      if (lookup != null && ApiService.userId == null) {
        _oauthInFlight = false;
        if (mounted) setState(() => _loading = false);
        await ApiService.abandonSignup();
        if (mounted) await showErrorPopup(context, lookup);
        return;
      }

      if (ApiService.userId != null) {
        await _finishAuth(firstRun: ApiService.needsAiTour);
      } else {
        _oauthInFlight = false;
        if (mounted) setState(() => _loading = false);
        await ApiService.abandonSignup();
        if (mounted) {
          await showErrorPopup(
            context,
            'Could not finish sign-in. Try again.',
          );
        }
      }
    } finally {
      _oauthCompleting = false;
    }
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
