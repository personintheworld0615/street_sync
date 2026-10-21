import 'dart:typed_data';

import 'package:image/image.dart' as im;

class OverheadDiff {
  const OverheadDiff({
    required this.meanChange,
    required this.changedFraction,
    required this.maskJpg,
  });

  /// Average absolute RGB change, 0..1.
  final double meanChange;

  /// Share of pixels whose average channel change is above [changeThreshold].
  final double changedFraction;
  final Uint8List maskJpg;
}

/// Compares two overhead images. The percent is measured, not authored.
OverheadDiff diffOverhead(
  Uint8List earlierBytes,
  Uint8List latestBytes, {
  int size = 256,
  int changeThreshold = 28,
}) {
  final earlier = im.decodeImage(earlierBytes);
  final latest = im.decodeImage(latestBytes);
  if (earlier == null || latest == null) {
    throw StateError('Could not read one of the overhead images.');
  }
  final a = im.copyResize(earlier, width: size, height: size);
  final b = im.copyResize(latest, width: size, height: size);
  final mask = im.Image(width: size, height: size);
  var sum = 0.0;
  var changed = 0;
  final total = size * size;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final pa = a.getPixel(x, y);
      final pb = b.getPixel(x, y);
      final dr = (pa.r - pb.r).abs();
      final dg = (pa.g - pb.g).abs();
      final db = (pa.b - pb.b).abs();
      final delta = (dr + dg + db) / 3.0;
      sum += delta;
      if (delta > changeThreshold) {
        changed++;
        mask.setPixelRgb(x, y, 255, 96, 48);
      } else {
        mask.setPixelRgb(
          x,
          y,
          (pb.r * 0.35).round(),
          (pb.g * 0.35).round(),
          (pb.b * 0.35).round(),
        );
      }
    }
  }
  return OverheadDiff(
    meanChange: (sum / total) / 255.0,
    changedFraction: changed / total,
    maskJpg: Uint8List.fromList(im.encodeJpg(mask, quality: 85)),
  );
}
