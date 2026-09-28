import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
