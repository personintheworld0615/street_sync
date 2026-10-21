import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:street_sync/Confirmation.dart';
import 'package:street_sync/geocoding_utils.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/vision/class_map.dart';
import 'package:street_sync/vision/detection_overlay.dart';
import 'package:street_sync/vision/satellite_check_screen.dart';
import 'package:street_sync/vision/street_detector.dart';
import 'package:street_sync/vision/yolo_decode.dart';

class StreetVisionScreen extends StatefulWidget {
  const StreetVisionScreen({super.key});

  @override
  State<StreetVisionScreen> createState() => _StreetVisionScreenState();
}

class _StreetVisionScreenState extends State<StreetVisionScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF07080A);
  static const _sampleAsset = 'assets/demo/sample_street.jpg';

  CameraController? _camera;
  late final AnimationController _scan;
  String? _cameraError;
  bool _reading = false;
  File? _still;
  double _aspect = 1;
  List<StreetDetection> _detections = const [];
  int _selected = 0;
  String _copilot = '';
  String _copilotFull = '';
  Timer? _typewriter;

  double? _lat;
  double? _lng;
  String _place = 'Finding location…';
  bool? _inTown;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _openCamera();
    _locate();
    StreetDetector.load();
  }

  @override
  void dispose() {
    _typewriter?.cancel();
    _scan.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera on this device.');
        return;
      }
      final back = cameras.cast<CameraDescription?>().firstWhere(
            (c) => c!.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          )!;
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraError = 'Camera permission is required to scan.');
    }
  }

  Future<void> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _place = 'Location off');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final place = await translateLocation(pos.latitude, pos.longitude);
      final inTown = await isLocationInPlainsboro(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _place = place;
        _inTown = inTown;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _place = 'Location unavailable');
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _reading || !camera.value.isInitialized) return;
    setState(() => _reading = true);
    try {
      final shot = await camera.takePicture();
      await _read(File(shot.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _reading = false);
    }
  }

  Future<void> _useSample() async {
    if (_reading) return;
    setState(() => _reading = true);
    final data = await rootBundle.load(_sampleAsset);
    final file = File('${Directory.systemTemp.path}/street_sync_sample.jpg');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await _read(file);
  }

  Future<void> _read(File file) async {
    setState(() {
      _reading = true;
      _still = file;
      _detections = const [];
      _copilot = '';
    });
    await Future<void>.delayed(Duration.zero);
    try {
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final detector = await StreetDetector.load();
      final found = await detector.detectBytes(bytes);
      if (!mounted) return;
      setState(() {
        _aspect = decoded.width / decoded.height;
        _detections = found;
        _selected = 0;
        _reading = false;
        _copilotFull = _lineFor(found);
      });
      _playCopilot();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _copilotFull = 'The on-device model did not run. ${e.toString()}';
        _detections = const [];
      });
      _playCopilot();
    }
  }

  String _lineFor(List<StreetDetection> found) {
    if (found.isEmpty) return 'No clear defect in this frame.';
    final top = found.first;
    final severity = top.severity.toLowerCase();
    if (found.length == 1) {
      return '${top.label}. Marking this $severity and drafting the report.';
    }
    return '${found.length} issues in this frame. The leading one is ${top.label}, $severity.';
  }

  void _playCopilot() {
    _typewriter?.cancel();
    _copilot = '';
    var i = 0;
    _typewriter = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i += 1;
      if (i >= _copilotFull.length) {
        timer.cancel();
        setState(() => _copilot = _copilotFull);
        return;
      }
      setState(() => _copilot = _copilotFull.substring(0, i));
    });
  }

  void _retake() {
    _typewriter?.cancel();
    setState(() {
      _still = null;
      _detections = const [];
      _copilot = '';
      _reading = false;
    });
  }

  Future<void> _continue() async {
    final still = _still;
    final lat = _lat;
    final lng = _lng;
    if (still == null || _detections.isEmpty || lat == null || lng == null) {
      return;
    }
    final det = _detections[_selected.clamp(0, _detections.length - 1)];
    final place = await translateLocation(lat, lng);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Confirmation(
          category: det.category,
          location: place,
          title: UrbanClasses.titleFor(det.classId),
          description: UrbanClasses.descriptionFor(
            classId: det.classId,
            confidence: det.confidence,
            areaFraction: det.areaFraction,
          ),
          severity: det.severity,
          image: XFile(still.path),
          latitude: lat,
          longitude: lng,
        ),
      ),
    );
  }

  void _openOverhead() {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SatelliteCheckScreen(latitude: lat, longitude: lng),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final hasResult = still != null && !_reading;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (still != null)
            Center(
              child: Image.file(
                still,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            )
          else if (_camera != null && _camera!.value.isInitialized)
            CameraPreview(_camera!)
          else
            Center(
              child: Text(
                _cameraError ?? 'Opening camera…',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (still != null && _detections.isNotEmpty)
            DetectionOverlay(
              detections: _detections,
              imageAspect: _aspect,
              selectedIndex: _selected,
            ),
          if (still == null && _cameraError == null) ScanLine(animation: _scan),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: _placePill()),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: hasResult ? _resultPanel() : _shutterBar(),
          ),
        ],
      ),
    );
  }

  Widget _placePill() {
    final outside = _inTown == false;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          outside ? '$_place · outside Plainsboro' : _place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _shutterBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_reading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Reading the frame',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _reading ? null : _useSample,
                      child: const Text(
                        'Sample street',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _reading ? null : _capture,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _reading ? Colors.white24 : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel() {
    final empty = _detections.isEmpty;
    final det = empty ? null : _detections[_selected.clamp(0, _detections.length - 1)];
    final canContinue = det != null && _lat != null && _lng != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Color(0xF20B0D10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _copilot.isEmpty ? ' ' : _copilot,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (det != null) ...[
            const SizedBox(height: 12),
            Text(
              det.reason,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _detections.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _detections[index];
                  final selected = index == _selected;
                  final color = ReportCategories.color(item.category);
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = index;
                      _copilotFull = _lineFor([item]);
                      _playCopilot();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${(item.confidence * 100).round()}% ${item.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(onPressed: _retake, child: const Text('Retake', style: TextStyle(color: Colors.white70))),
              const Spacer(),
              if (!empty)
                TextButton(
                  onPressed: _lat == null ? null : _openOverhead,
                  child: const Text('Overhead'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canContinue ? _continue : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: Text(empty ? 'Need a detection' : 'Continue'),
              ),
            ],
          ),
          if (_inTown == false)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Submit stays blocked until the pin is inside Plainsboro.',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
