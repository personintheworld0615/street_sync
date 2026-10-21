import 'dart:math' as math;
import 'dart:ui';

import 'package:street_sync/vision/class_map.dart';

class StreetDetection {
  const StreetDetection({
    required this.classId,
    required this.confidence,
    required this.box,
    required this.areaFraction,
  });

  final int classId;
  final double confidence;

  /// Box in the original photo, each edge in 0..1.
  final Rect box;
  final double areaFraction;

  String get label => UrbanClasses.label(classId);
  String get category => UrbanClasses.category(classId);
  String get severity => UrbanClasses.severity(classId, areaFraction);
  String get reason => UrbanClasses.reason(classId, areaFraction);
}

/// Decodes a YOLOv8 head of shape [channels, anchors] (channel-major).
///
/// The bundled graph emits xywh normalized to the 640 canvas. A raw PyTorch
/// head emits the same boxes in pixels. Values above 2 are treated as pixels.
List<StreetDetection> decodeYolo({
  required List<double> output,
  required int channels,
  required int anchors,
  required int srcWidth,
  required int srcHeight,
  required double padX,
  required double padY,
  required double scale,
  double canvas = 640,
  int classCount = 10,
  double confThresh = 0.35,
  double iouThresh = 0.45,
  int maxDetections = 8,
}) {
  if (srcWidth <= 0 || srcHeight <= 0 || scale <= 0) return const [];
  if (output.length < channels * anchors || channels < 5) return const [];

  var maxCoord = 0.0;
  final sample = math.min(anchors, 64);
  for (var c = 0; c < 4; c++) {
    for (var i = 0; i < sample; i++) {
      final v = output[c * anchors + i].abs();
      if (v > maxCoord) maxCoord = v;
    }
  }
  final pixels = maxCoord > 2;

  final candidates = <_Raw>[];
  for (var i = 0; i < anchors; i++) {
    var best = 0.0;
    var bestClass = 0;
    final classChannels = math.min(classCount, channels - 4);
    for (var c = 0; c < classChannels; c++) {
      final score = output[(4 + c) * anchors + i];
      if (score > best) {
        best = score;
        bestClass = c;
      }
    }
    if (best < confThresh) continue;

    var cx = output[0 * anchors + i];
    var cy = output[1 * anchors + i];
    var bw = output[2 * anchors + i];
    var bh = output[3 * anchors + i];
    if (!pixels) {
      cx *= canvas;
      cy *= canvas;
      bw *= canvas;
      bh *= canvas;
    }
    final x1 = ((cx - bw / 2) - padX) / scale;
    final y1 = ((cy - bh / 2) - padY) / scale;
    final x2 = ((cx + bw / 2) - padX) / scale;
    final y2 = ((cy + bh / 2) - padY) / scale;
    final left = (x1 / srcWidth).clamp(0.0, 1.0);
    final top = (y1 / srcHeight).clamp(0.0, 1.0);
    final right = (x2 / srcWidth).clamp(0.0, 1.0);
    final bottom = (y2 / srcHeight).clamp(0.0, 1.0);
    if (right - left < 0.01 || bottom - top < 0.01) continue;
    final box = Rect.fromLTRB(left, top, right, bottom);
    candidates.add(_Raw(bestClass, best, box));
  }

  candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <_Raw>[];
  for (final det in candidates) {
    final overlaps = kept.any(
      (other) => other.classId == det.classId && _iou(other.box, det.box) > iouThresh,
    );
    if (overlaps) continue;
    kept.add(det);
    if (kept.length >= maxDetections) break;
  }

  final detections = [
    for (final det in kept)
      StreetDetection(
        classId: det.classId,
        confidence: det.confidence,
        box: det.box,
        areaFraction: det.box.width * det.box.height,
      ),
  ];
  detections.sort((a, b) {
    final level = UrbanClasses.level(b.classId, b.areaFraction)
        .compareTo(UrbanClasses.level(a.classId, a.areaFraction));
    if (level != 0) return level;
    return b.confidence.compareTo(a.confidence);
  });
  return detections;
}

class _Raw {
  _Raw(this.classId, this.confidence, this.box);
  final int classId;
  final double confidence;
  final Rect box;
}

double _iou(Rect a, Rect b) {
  final left = math.max(a.left, b.left);
  final top = math.max(a.top, b.top);
  final right = math.min(a.right, b.right);
  final bottom = math.min(a.bottom, b.bottom);
  final w = math.max(0.0, right - left);
  final h = math.max(0.0, bottom - top);
  final inter = w * h;
  if (inter <= 0) return 0;
  final union = a.width * a.height + b.width * b.height - inter;
  if (union <= 0) return 0;
  return inter / union;
}

class Letterbox {
  const Letterbox({
    required this.scale,
    required this.padX,
    required this.padY,
    required this.resizedWidth,
    required this.resizedHeight,
  });

  final double scale;
  final double padX;
  final double padY;
  final int resizedWidth;
  final int resizedHeight;

  static Letterbox fit(int srcWidth, int srcHeight, {int canvas = 640}) {
    final scale = math.min(canvas / srcWidth, canvas / srcHeight);
    final resizedWidth = (srcWidth * scale).round();
    final resizedHeight = (srcHeight * scale).round();
    return Letterbox(
      scale: scale,
      padX: (canvas - resizedWidth) / 2,
      padY: (canvas - resizedHeight) / 2,
      resizedWidth: resizedWidth,
      resizedHeight: resizedHeight,
    );
  }
}
