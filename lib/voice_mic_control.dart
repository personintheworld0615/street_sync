import 'package:flutter/material.dart';

/// Concentric listening rings around the record button.
class VoiceMicControl extends StatelessWidget {
  const VoiceMicControl({
    super.key,
    required this.isRecording,
    required this.animation,
    required this.onTap,
    this.accent = const Color(0xFF111827),
    this.size = 268,
  });

  final bool isRecording;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = size * (138 / 268);
    final glassOuter = core + size * (42 / 268);
    final outline = size - 6;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final p = isRecording ? animation.value : 0.0;
            final rings = <Widget>[];

            for (var i = 1; i <= 4; i++) {
              final t = i / 4.0;
              rings.add(
                _rippleRing(
                  diameter: glassOuter + (outline - glassOuter) * t,
                  opacity: isRecording ? 0.10 : (0.18 - i * 0.028),
                  stroke: i == 4 ? 1.4 : 1.05,
                ),
              );
            }

            if (isRecording) {
              for (var i = 0; i < 3; i++) {
                final phase = (p + i / 3.0) % 1.0;
                rings.add(
                  _rippleRing(
                    diameter: glassOuter + (outline - glassOuter) * phase,
                    opacity: (1.0 - phase) * 0.42,
                    stroke: 1.5,
                  ),
                );
              }
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                ...rings,
                Container(
                  width: glassOuter,
                  height: glassOuter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.88),
                        const Color(0xFFE4E9F0).withValues(alpha: 0.62),
                        const Color(0xFFC9D2DE).withValues(alpha: 0.48),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF9AA7B5).withValues(alpha: 0.5),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(size * (12 / 268)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: core,
                  height: core,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.24),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                    size: core * (54 / 138),
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rippleRing({
    required double diameter,
    required double opacity,
    required double stroke,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF8A96A3)
              .withValues(alpha: opacity.clamp(0.0, 1.0)),
          width: stroke,
        ),
      ),
    );
  }
}
