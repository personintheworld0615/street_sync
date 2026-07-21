import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum IssueCategory {
  roadDamage,
  publicWorks,
  environmental,
  ada,
  other,
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _center = const LatLng(40.3573, -74.6672);
  bool _ready = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _goToUser();
  }

  void _loadFakeReports() {
    setState(() {
      _markers = {
        // Road Damage - Red
        Marker(
          markerId: const MarkerId('road_damage_1'),
          position: const LatLng(40.3578, -74.6678),
          infoWindow: const InfoWindow(
            title: "Pothole",
            snippet: "Category: Road Damage",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),

        // Public Works - Orange
        Marker(
          markerId: const MarkerId('public_works_1'),
          position: const LatLng(40.3565, -74.6665),
          infoWindow: const InfoWindow(
            title: "Broken Streetlight",
            snippet: "Category: Public Works",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),

        // Environmental - Green
        Marker(
          markerId: const MarkerId('environmental_1'),
          position: const LatLng(40.3585, -74.6655),
          infoWindow: const InfoWindow(
            title: "Illegal Dumping",
            snippet: "Category: Environmental",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),

        // ADA - Yellow
        Marker(
          markerId: const MarkerId('ada_1'),
          position: const LatLng(40.3590, -74.6680),
          infoWindow: const InfoWindow(
            title: "Damaged Sidewalk Ramp",
            snippet: "Category: ADA",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),

        // Other - Blue
        Marker(
          markerId: const MarkerId('other_1'),
          position: const LatLng(40.3558, -74.6670),
          infoWindow: const InfoWindow(
            title: "Missing Sign",
            snippet: "Category: Other",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        ),
      };
    });
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

_loadFakeReports();

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
        markers: _markers,
      ),
    );
  }
}
