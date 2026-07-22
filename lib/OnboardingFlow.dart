import 'package:flutter/material.dart';
import 'package:street_sync/LoginScreen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _blue = Color(0xFF2196F3);
  static const _muted = Color(0xFF5B677A);
  static const _pageBg = Color(0xFFF4F7FB);

  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      icon: Icons.camera_alt_rounded,
      title: 'Spot it. Report it.',
      body:
          'Snap a photo or use your voice to flag potholes, broken lights, and accessibility issues in seconds.',
      accent: Color(0xFF2196F3),
    ),
    _OnboardPage(
      icon: Icons.map_rounded,
      title: 'See your community',
      body:
          'Every report lands on a live map so neighbors and town crews can see what needs attention nearby.',
      accent: Color(0xFF1565C0),
    ),
    _OnboardPage(
      icon: Icons.groups_rounded,
      title: 'Make an impact together',
      body:
          'Climb the leaderboard, track your reports, and help make streets safer for everyone.',
      accent: Color(0xFF00897B),
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goLogin();
    }
  }

  void _goLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goLogin,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 22 : 8,
                        decoration: BoxDecoration(
                          color: active ? _blue : _blue.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Get started' : 'Next',
                        style: const TextStyle(
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
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: accent),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
