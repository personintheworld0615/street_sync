import 'package:flutter/material.dart';
import 'package:street_sync/auth_service.dart';
import 'package:street_sync/error_popup.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _pageBg = Color(0xFFF7F8FA);
  static const _cta = Color(0xFF111827);

  late final TextEditingController _emailCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
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

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset password',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Enter your email and we'll send you a link to reset your password.",
                style: TextStyle(
                  fontSize: 15,
                  color: _muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) _sendLink();
                },
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: TextStyle(color: _muted.withValues(alpha: 0.7)),
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _ink, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendLink,
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
                      : const Text(
                          'Send reset link',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
