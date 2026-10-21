import 'dart:math' as math;

class SlippyTile {
  const SlippyTile(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  String get key => '${z}_${x}_$y';

  /// Esri World Imagery uses level / row / column, which is z / y / x.
  String get esriUrl =>
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x';
}

SlippyTile slippyTile(double latitude, double longitude, {int z = 17}) {
  final n = 1 << z;
  final x = ((longitude + 180.0) / 360.0 * n).floor();
  final latRad = latitude * math.pi / 180.0;
  final y = ((1.0 -
              math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
          2.0 *
          n)
      .floor();
  return SlippyTile(z, x.clamp(0, n - 1), y.clamp(0, n - 1));
}
