import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _center = const LatLng(40.3573, -74.6672);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _goToUser();
  }

  Future<void> _goToUser() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _ready = true);
      return;
    }

    final currentLocation = await Geolocator.getCurrentPosition();
    final userLatLng = LatLng(
      currentLocation.latitude,
      currentLocation.longitude,
    );

    setState(() {
      _center = userLatLng;
      _ready = true;
    });

    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(userLatLng, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 14),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        onMapCreated: (c) async {
          _controller = c;
          if (_ready) {
            await c.animateCamera(CameraUpdate.newLatLngZoom(_center, 15));
          }
        },
      ),
    );
  }
}
