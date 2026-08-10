import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _soft = Color(0xFFEEF0F3);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 110 + bottomInset),
          children: [
            Text(
              'Updates',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status changes and neighborhood activity will show up here.',
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.4,
                color: _muted,
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 34,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No updates yet',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When reports near you move forward,\nyou’ll see them here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
