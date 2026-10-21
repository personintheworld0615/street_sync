import 'package:flutter/material.dart';

import 'package:street_sync/report_categories.dart';
import 'package:street_sync/vision/yolo_decode.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.imageAspect,
    required this.selectedIndex,
  });

  final List<StreetDetection> detections;
  final double imageAspect;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BoxPainter(
        detections: detections,
        imageAspect: imageAspect,
        selectedIndex: selectedIndex,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({
    required this.detections,
    required this.imageAspect,
    required this.selectedIndex,
  });

  final List<StreetDetection> detections;
  final double imageAspect;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = _contain(size, imageAspect);
    for (var i = 0; i < detections.length; i++) {
      final det = detections[i];
      final color = ReportCategories.color(det.category);
      final rect = Rect.fromLTRB(
        fitted.left + det.box.left * fitted.width,
        fitted.top + det.box.top * fitted.height,
        fitted.left + det.box.right * fitted.width,
        fitted.top + det.box.bottom * fitted.height,
      );
      final selected = i == selectedIndex;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.5
        ..color = color.withValues(alpha: selected ? 1 : 0.75);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );
      final label = '${det.label} ${(det.confidence * 100).round()}%';
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: fitted.width);
      final tag = Rect.fromLTWH(
        rect.left,
        (rect.top - text.height - 10).clamp(fitted.top, fitted.bottom - 24),
        text.width + 16,
        text.height + 10,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tag, const Radius.circular(8)),
        Paint()..color = color.withValues(alpha: 0.92),
      );
      text.paint(canvas, Offset(tag.left + 8, tag.top + 5));
    }
  }

  Rect _contain(Size canvas, double aspect) {
    if (aspect <= 0) return Offset.zero & canvas;
    final canvasAspect = canvas.width / canvas.height;
    if (canvasAspect > aspect) {
      final width = canvas.height * aspect;
      return Rect.fromLTWH((canvas.width - width) / 2, 0, width, canvas.height);
    }
    final height = canvas.width / aspect;
    return Rect.fromLTWH(0, (canvas.height - height) / 2, canvas.width, height);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.imageAspect != imageAspect;
  }
}

class ScanLine extends StatelessWidget {
  const ScanLine({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _ScanPainter(animation.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x007DD3FC),
          const Color(0x667DD3FC),
          const Color(0x007DD3FC),
        ],
      ).createShader(Rect.fromLTWH(0, y - 28, size.width, 56));
    canvas.drawRect(Rect.fromLTWH(24, y - 1, size.width - 48, 2), paint);
    final corners = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.85);
    const len = 28.0;
    const inset = 22.0;
    final r = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    void corner(Offset start, Offset a, Offset b) {
      canvas.drawLine(start, start + a, corners);
      canvas.drawLine(start, start + b, corners);
    }
    corner(r.topLeft, const Offset(len, 0), const Offset(0, len));
    corner(r.topRight, const Offset(-len, 0), const Offset(0, len));
    corner(r.bottomLeft, const Offset(len, 0), const Offset(0, -len));
    corner(r.bottomRight, const Offset(-len, 0), const Offset(0, -len));
  }

  @override
  bool shouldRepaint(covariant _ScanPainter oldDelegate) => oldDelegate.t != t;
}
