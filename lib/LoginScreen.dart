import 'package:flutter/material.dart';
import 'package:street_sync/Mainshell.dart';

/// Placeholder login — UI only for now; continues into the app.
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
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _enterApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
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
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to sync with your community.',
                style: TextStyle(
                  fontSize: 15,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              _label('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
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
                  onPressed: _enterApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: _muted),
                  ),
                  GestureDetector(
                    onTap: _enterApp,
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
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
