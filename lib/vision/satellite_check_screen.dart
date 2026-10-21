import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:street_sync/vision/frame_diff.dart';
import 'package:street_sync/vision/tile_math.dart';

class SatelliteCheckScreen extends StatefulWidget {
  const SatelliteCheckScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<SatelliteCheckScreen> createState() => _SatelliteCheckScreenState();
}

class _EarlierPass {
  _EarlierPass({
    required this.asset,
    required this.captured,
    required this.source,
  });

  final String asset;
  final String captured;
  final String source;
}

class _SatelliteCheckScreenState extends State<SatelliteCheckScreen> {
  static const _bg = Color(0xFF07080A);
  Uint8List? _latest;
  Uint8List? _earlier;
  OverheadDiff? _diff;
  _EarlierPass? _pass;
  String? _error;
  bool _loading = true;
  late final SlippyTile _tile = slippyTile(widget.latitude, widget.longitude);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final latestResponse = await http
          .get(Uri.parse(_tile.esriUrl))
          .timeout(const Duration(seconds: 12));
      if (latestResponse.statusCode != 200 || latestResponse.bodyBytes.isEmpty) {
        throw StateError('Current overhead tile returned ${latestResponse.statusCode}.');
      }
      final pass = await _storedPass(_tile);
      OverheadDiff? diff;
      Uint8List? earlier;
      if (pass != null) {
        final data = await rootBundle.load(pass.asset);
        earlier = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        diff = diffOverhead(earlier, latestResponse.bodyBytes);
      }
      if (!mounted) return;
      setState(() {
        _latest = latestResponse.bodyBytes;
        _earlier = earlier;
        _pass = pass;
        _diff = diff;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('StateError: ', '');
        _loading = false;
      });
    }
  }

  Future<_EarlierPass?> _storedPass(SlippyTile tile) async {
    final raw = await rootBundle.loadString('assets/demo/earlier_manifest.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final tiles = json['tiles'] as List<dynamic>;
    for (final item in tiles) {
      final map = item as Map<String, dynamic>;
      if (map['z'] == tile.z && map['x'] == tile.x && map['y'] == tile.y) {
        return _EarlierPass(
          asset: map['asset'] as String,
          captured: map['captured'] as String,
          source: map['source'] as String,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Overhead check', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? _message(_error!)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      'Tile ${_tile.z} / ${_tile.x} / ${_tile.y}',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _diff == null
                          ? 'No earlier pass is stored for this block.'
                          : '${(_diff!.meanChange * 100).toStringAsFixed(1)}% mean brightness change',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _diff == null
                          ? 'The current Esri imagery is below. An earlier tile is only stored for the rehearsed Plainsboro blocks, and this pin is outside them.'
                          : 'Compared with the ${_pass!.source} pass from ${_pass!.captured}. '
                              '${(_diff!.changedFraction * 100).toStringAsFixed(0)}% of pixels moved past a small brightness threshold. '
                              'This is surface change in the overhead image. It does not measure a pothole.',
                      style: const TextStyle(color: Color(0xFFD1D5DB), height: 1.4, fontSize: 15),
                    ),
                    const SizedBox(height: 18),
                    if (_earlier != null) _frame('Earlier · ${_pass!.captured}', _earlier!),
                    if (_latest != null) _frame('Latest Esri imagery', _latest!),
                    if (_diff != null) _frame('Pixels that changed', _diff!.maskJpg),
                  ],
                ),
    );
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, style: const TextStyle(color: Colors.white, height: 1.4)),
    );
  }

  Widget _frame(String caption, Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}
