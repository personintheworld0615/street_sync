import 'package:flutter/material.dart';
import 'dart:ui';

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String content;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onShow;

  TourStep({
    required this.targetKey,
    required this.title,
    required this.content,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.onShow,
  });
}

class AiTour extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onComplete;

  const AiTour({super.key, required this.steps, required this.onComplete});

  @override
  State<AiTour> createState() => _AiTourState();
}

class _AiTourState extends State<AiTour> with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentStep());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
        _fadeController.forward(from: 0.35);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentStep());
    } else {
      _fadeController.reverse().then((_) => widget.onComplete());
    }
  }

  void _previous() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep--;
      _fadeController.forward(from: 0.35);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentStep());
  }

  void _skip() {
    _fadeController.reverse().then((_) => widget.onComplete());
  }

  void _showCurrentStep() {
    if (!mounted || widget.steps.isEmpty) return;
    widget.steps[_currentStep].onShow?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final step = widget.steps[_currentStep];
    final renderBox =
        step.targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || !renderBox.attached) {
      return _TourUnavailableOverlay(onSkip: _skip);
    }

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final targetRect = Rect.fromLTWH(
      offset.dx - 8,
      offset.dy - 8,
      size.width + 16,
      size.height + 16,
    );

    return FadeTransition(
      opacity: _fadeController,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _next,
            child: CustomPaint(
              painter: _TourScrimPainter(targetRect: targetRect),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final pulse = 1 + (_pulseController.value * 5);
                  return Container(
                    width: targetRect.width,
                    height: targetRect.height,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.32),
                          blurRadius: 12 + pulse,
                          spreadRadius: pulse,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Skip'),
            ),
          ),
          _buildTooltip(offset, size),
        ],
      ),
    );
  }

  Widget _buildTooltip(Offset targetOffset, Size targetSize) {
    final screen = MediaQuery.of(context).size;
    final isBottom = targetOffset.dy < screen.height / 2;
    final top = targetOffset.dy + targetSize.height + 18;
    final bottom = (screen.height - targetOffset.dy) + 18;

    return Positioned(
      left: 20,
      right: 20,
      top: isBottom ? top.clamp(80.0, screen.height - 280.0) : null,
      bottom: !isBottom ? bottom.clamp(80.0, screen.height - 280.0) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF152033).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.steps[_currentStep].title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'STREETSYNC AI GUIDE',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.steps[_currentStep].icon,
                            color: Colors.blue.shade300,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.steps[_currentStep].content,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.steps[_currentStep].actionLabel != null &&
                        widget.steps[_currentStep].onAction != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.steps[_currentStep].onAction,
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(widget.steps[_currentStep].actionLabel!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Text(
                          'Step ${_currentStep + 1}/${widget.steps.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_currentStep > 0) ...[
                          TextButton(
                            onPressed: _previous,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text('Back'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            _currentStep == widget.steps.length - 1
                                ? 'Finish'
                                : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 4. Floating Avatar guiding the user
          Positioned(
            top: -35,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFF152033),
                backgroundImage: NetworkImage('https://framerusercontent.com/images/YnshfS6D7v7C7f0Vq8z7N8vF6Y.png'), // Modern AI/Bot avatar
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourScrimPainter extends CustomPainter {
  final Rect targetRect;

  _TourScrimPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.68),
    );
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

class _TourUnavailableOverlay extends StatelessWidget {
  final VoidCallback onSkip;

  const _TourUnavailableOverlay({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: FilledButton(onPressed: onSkip, child: const Text('Close tour')),
      ),
    );
  }
}
