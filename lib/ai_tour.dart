import 'package:flutter/material.dart';

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

class _AiTourState extends State<AiTour> {
  int _currentStep = 0;
  int _missingFrames = 0;
  bool _waitingForTarget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentStep());
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
        _missingFrames = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentStep());
    } else {
      widget.onComplete();
    }
  }

  void _previous() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep--;
      _missingFrames = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentStep());
  }

  void _showCurrentStep() {
    if (!mounted || widget.steps.isEmpty) return;
    widget.steps[_currentStep].onShow?.call();
  }

  void _retryMissingTarget() {
    if (_waitingForTarget) return;
    _waitingForTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitingForTarget = false;
      if (!mounted) return;
      _missingFrames++;
      if (_missingFrames < 10) {
        setState(() {});
        return;
      }
      _missingFrames = 0;
      if (_currentStep < widget.steps.length - 1) {
        _next();
      } else {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final step = widget.steps[_currentStep];
    final renderBox =
        step.targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      _retryMissingTarget();
      return const SizedBox.shrink();
    }

    _missingFrames = 0;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final targetRect = Rect.fromLTWH(
      offset.dx - 6,
      offset.dy - 6,
      size.width + 12,
      size.height + 12,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: CustomPaint(
            painter: _TourScrimPainter(targetRect: targetRect),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned.fromRect(
          rect: targetRect,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 6,
          right: 8,
          child: TextButton(
            onPressed: widget.onComplete,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
        _buildCallout(step, targetRect),
      ],
    );
  }

  Widget _buildCallout(TourStep step, Rect targetRect) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    const side = 16.0;
    const gap = 28.0;
    final spaceAbove = targetRect.top - media.padding.top - gap;
    final spaceBelow =
        screen.height - targetRect.bottom - media.padding.bottom - gap;
    final placeBelow = spaceBelow >= 150 || spaceBelow >= spaceAbove;

    return Positioned(
      left: side,
      right: side,
      top: placeBelow ? targetRect.bottom + gap : null,
      bottom: placeBelow ? null : screen.height - targetRect.top + gap,
      child: _GuideBubble(
        step: step,
        stepIndex: _currentStep,
        stepCount: widget.steps.length,
        pointUp: placeBelow,
        targetCenterX: targetRect.center.dx - side,
        onBack: _currentStep > 0 ? _previous : null,
        onNext: _next,
      ),
    );
  }
}

class _GuideBubble extends StatelessWidget {
  const _GuideBubble({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.pointUp,
    required this.targetCenterX,
    required this.onBack,
    required this.onNext,
  });

  final TourStep step;
  final int stepIndex;
  final int stepCount;
  final bool pointUp;
  final double targetCenterX;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  static const _ink = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tailLeft = (targetCenterX - 9).clamp(
          64.0,
          constraints.maxWidth - 28,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24111827),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(68, 16, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        step.content,
                        key: ValueKey(step.content),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    if (step.actionLabel != null && step.onAction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: step.onAction,
                          child: Text(
                            step.actionLabel!,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: _ink,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (onBack != null)
                          IconButton(
                            onPressed: onBack,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: _ink,
                            ),
                          )
                        else
                          const SizedBox(width: 4),
                        _StepDots(index: stepIndex, count: stepCount),
                        const Spacer(),
                        TextButton(
                          onPressed: onNext,
                          style: TextButton.styleFrom(
                            foregroundColor: _ink,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                stepIndex == stepCount - 1 ? 'Done' : 'Next',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              if (stepIndex != stepCount - 1) ...[
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: tailLeft,
              top: pointUp ? -8 : null,
              bottom: pointUp ? null : -8,
              child: CustomPaint(
                size: const Size(18, 10),
                painter: _TailPainter(pointUp: pointUp),
              ),
            ),
            const Positioned(left: 12, top: -16, child: _GuideAvatar()),
          ],
        );
      },
    );
  }
}

class _GuideAvatar extends StatelessWidget {
  const _GuideAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x2E111827),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/tour_guide.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.15),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 5),
          width: on ? 14 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: on ? const Color(0xFF111827) : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter({required this.pointUp});

  final bool pointUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointUp) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) {
    return oldDelegate.pointUp != pointUp;
  }
}

class _TourScrimPainter extends CustomPainter {
  final Rect targetRect;

  _TourScrimPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = const Color(0xFF111827).withValues(alpha: 0.46),
    );
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
