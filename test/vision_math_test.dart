import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:street_sync/vision/class_map.dart';
import 'package:street_sync/vision/frame_diff.dart';
import 'package:street_sync/vision/tile_math.dart';
import 'package:street_sync/vision/yolo_decode.dart';

void main() {
  test('Plainsboro center falls on the stored overhead tile', () {
    final tile = slippyTile(40.3334, -74.6004);
    expect(tile.z, 17);
    expect(tile.x, 38374);
    expect(tile.y, 49462);
    expect(tile.esriUrl, contains('/17/49462/38374'));
  });

  test('decode keeps a normalized box and drops a weak score', () {
    const anchors = 2;
    const channels = 14;
    final output = List<double>.filled(channels * anchors, 0);
    void setAnchor(int i, double cx, double cy, double w, double h, int classId, double score) {
      output[0 * anchors + i] = cx;
      output[1 * anchors + i] = cy;
      output[2 * anchors + i] = w;
      output[3 * anchors + i] = h;
      output[(4 + classId) * anchors + i] = score;
    }

    setAnchor(0, 0.5, 0.5, 0.2, 0.2, 1, 0.8);
    setAnchor(1, 0.5, 0.5, 0.2, 0.2, 1, 0.1);

    final found = decodeYolo(
      output: output,
      channels: channels,
      anchors: anchors,
      srcWidth: 640,
      srcHeight: 640,
      padX: 0,
      padY: 0,
      scale: 1,
    );
    expect(found, hasLength(1));
    expect(found.single.classId, 1);
    expect(found.single.category, 'Pothole');
    expect(found.single.severity, 'High');
    expect(found.single.box, const Rect.fromLTRB(0.4, 0.4, 0.6, 0.6));
  });

  test('severity drops a tiny litter box and bumps a large road box', () {
    expect(UrbanClasses.severity(5, 0.2), 'Medium');
    expect(UrbanClasses.severity(5, 0.02), 'Low');
    expect(UrbanClasses.severity(0, 0.02), 'Low');
  });

  test('overhead diff measures a real pixel change', () {
    final earlier = im.Image(width: 8, height: 8);
    final latest = im.Image(width: 8, height: 8);
    im.fill(earlier, color: im.ColorRgb8(0, 0, 0));
    im.fill(latest, color: im.ColorRgb8(0, 0, 0));
    latest.setPixelRgb(0, 0, 255, 255, 255);
    final diff = diffOverhead(
      Uint8List.fromList(im.encodePng(earlier)),
      Uint8List.fromList(im.encodePng(latest)),
      size: 8,
    );
    expect(diff.meanChange, greaterThan(0));
    expect(diff.changedFraction, greaterThan(0));
    expect(diff.changedFraction, lessThan(1));
  });
}
