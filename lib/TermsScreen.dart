import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/PrivacyPolicyScreen.dart';
import 'package:street_sync/error_popup.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const contactEmail = 'aaravg.0615@gmail.com';

  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF5E5D5D);

  static const _sections = <(String, String)>[
    (
      '1. What Street Sync is',
      'Street Sync is a way to report public problems, such as a pothole, a broken sign, or a sidewalk issue. It is not an emergency service. If someone is in danger, call 911.',
    ),
    (
      '2. The township dashboard',
      'Plainsboro Township has agreed to use a dashboard to review reports. Sending a report does not promise that the township will fix it, or fix it by a certain time.',
    ),
    (
      '3. Who can use it',
      'You must be 13 or older. Street Sync is not for children under 13. If we learn an account belongs to someone under 13, we will delete it.',
    ),
    (
      '4. Your reports',
      'Only upload photos and text you have the right to share. Do not include threats, private information about a person, or accusations about a named neighbor or business. Do not include faces, children, license plates, or the inside of a home.',
    ),
    (
      '5. Permission to show a report',
      'You keep ownership of what you submit. You give Street Sync permission to show that report in the app and on the township dashboard, including the photo, description, and location.',
    ),
    (
      '6. Removing a report',
      'Street Sync can remove a report. Anyone can email $contactEmail and ask for a photo or report to be taken down. Include the report so we can find it.',
    ),
    (
      '7. The app is provided as-is',
      'We work to keep Street Sync accurate, but we do not guarantee that every report is correct or that a problem will be repaired. Street Sync is not responsible for a report the township does not act on.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.inter(
      fontSize: 15,
      height: 1.55,
      color: _ink,
    );
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _ink,
        title: Text(
          'Terms',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: _ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            'Street Sync Terms',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _ink,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: September 28, 2026',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'These terms are written in plain language for a student-made app. They are not a substitute for a lawyer’s review.',
            style: body,
          ),
          const SizedBox(height: 24),
          for (final section in _sections) ...[
            Text(
              section.$1,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(section.$2, style: body),
            const SizedBox(height: 22),
          ],
          Text(
            'Questions: $contactEmail',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after the create-account form. The account is created only when the
/// reader reaches the end and taps agree.
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key, this.onAgree});

  /// Runs the real signup. Return null on success, `signed-in-existing` when
  /// the email already had an account, or an error message. Omit to only
  /// record agreement.
  final Future<String?> Function()? onAgree;

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF5E5D5D);

  final _scroll = ScrollController();
  bool _atEnd = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final atEnd = position.maxScrollExtent <= 8 ||
        position.pixels >= position.maxScrollExtent - 32;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
  }

  Future<void> _agree() async {
    if (!_atEnd || _busy) return;
    final create = widget.onAgree;
    if (create == null) {
      Navigator.of(context).pop('ok');
      return;
    }
    setState(() => _busy = true);
    final error = await create();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      Navigator.of(context).pop('ok');
      return;
    }
    // Special outcome the login screen handles (not a plain error).
    if (error == 'signed-in-existing') {
      Navigator.of(context).pop(error);
      return;
    }
    await showErrorPopup(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.inter(
      fontSize: 15,
      height: 1.55,
      color: TermsScreen._ink,
    );
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _ink,
        title: Text(
          'Terms',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: _ink,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Text(
                  'Read this before your account is created',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your StreetSync account is only created after you scroll to the end and agree.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'These terms are written in plain language for a student-made app. They are not a substitute for a lawyer’s review.',
                  style: body,
                ),
                const SizedBox(height: 24),
                for (final section in TermsScreen._sections) ...[
                  Text(
                    section.$1,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(section.$2, style: body),
                  const SizedBox(height: 22),
                ],
                Text(
                  'Privacy',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'StreetSync stores the name and email on your account, and the reports you send, including photos and location. You can read the full policy before you agree.',
                  style: body,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _ink,
                    ),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'By agreeing you confirm you are 13 or older.',
                  style: body,
                ),
                const SizedBox(height: 12),
                Text(
                  'Questions: ${TermsScreen.contactEmail}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: _pageBg,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _atEnd
                      ? 'You’ve reached the end.'
                      : 'Scroll to the end to agree.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _atEnd && !_busy ? _agree : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _ink.withValues(alpha: 0.28),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'I agree',
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
        ],
      ),
    );
  }
}
