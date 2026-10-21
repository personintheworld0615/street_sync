import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'yolo_decode.dart';

class StreetDetector {
  StreetDetector._(this._interpreter);

  final Interpreter _interpreter;
  static StreetDetector? _instance;

  static const modelAsset = 'assets/models/urban_multi.tflite';

  static Future<StreetDetector> load() async {
    final existing = _instance;
    if (existing != null) return existing;
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: InterpreterOptions()..threads = 2,
    );
    final created = StreetDetector._(interpreter);
    _instance = created;
    return created;
  }

  Future<List<StreetDetection>> detectFile(File file) {
    return detectBytes(file.readAsBytesSync());
  }

  /// One still frame. The model input is NCHW float 0..1, letterboxed to 640.
  Future<List<StreetDetection>> detectBytes(Uint8List bytes) async {
    final decoded = im.decodeImage(bytes);
    if (decoded == null) return const [];
    final src = im.bakeOrientation(decoded);
    final fit = Letterbox.fit(src.width, src.height);
    final resized = im.copyResize(
      src,
      width: fit.resizedWidth,
      height: fit.resizedHeight,
      interpolation: im.Interpolation.linear,
    );
    final canvas = im.Image(width: 640, height: 640, numChannels: 3);
    im.fill(canvas, color: im.ColorRgb8(114, 114, 114));
    im.compositeImage(
      canvas,
      resized,
      dstX: fit.padX.round(),
      dstY: fit.padY.round(),
    );

    final input = Float32List(3 * 640 * 640);
    const plane = 640 * 640;
    for (var y = 0; y < 640; y++) {
      for (var x = 0; x < 640; x++) {
        final p = canvas.getPixel(x, y);
        final i = y * 640 + x;
        input[i] = p.r / 255.0;
        input[plane + i] = p.g / 255.0;
        input[2 * plane + i] = p.b / 255.0;
      }
    }

    final outShape = _interpreter.getOutputTensor(0).shape;
    final channels = outShape[outShape.length - 2];
    final anchors = outShape.last;
    final output = Float32List(channels * anchors);
    _interpreter.run(input.reshape([1, 3, 640, 640]), output.reshape([1, channels, anchors]));

    final raw = _interpreter.getOutputTensor(0).data;
    final floats = raw.buffer.asFloat32List(
      raw.offsetInBytes,
      raw.lengthInBytes ~/ 4,
    );

    return decodeYolo(
      output: floats,
      channels: channels,
      anchors: anchors,
      srcWidth: src.width,
      srcHeight: src.height,
      padX: fit.padX,
      padY: fit.padY,
      scale: fit.scale,
    );
  }
}
