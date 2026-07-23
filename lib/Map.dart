import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

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
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _suggestions = [];

  final String apiKey = googleMapsApiKey;

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final location = locations.first;

        final newPosition = LatLng(
          location.latitude,
          location.longitude,
        );

        await _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15),
        );
      }
    } catch (e) {
      print("Location not found: $e");
    }
  }

  Future<void> _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/place/autocomplete/json"
      "?input=$input"
      "&key=$apiKey"
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        _suggestions = data['predictions'];
      });
    }
  }

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

        // Public Works - Cyan
        Marker(
          markerId: const MarkerId('public_works_1'),
          position: const LatLng(40.3565, -74.6665),
          infoWindow: const InfoWindow(
            title: "Broken Streetlight",
            snippet: "Category: Public Works",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRose,
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
            BitmapDescriptor.hueViolet,
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
            BitmapDescriptor.hueAzure,
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
      // _center = userLatLng;
      _ready = true;
    });

_loadFakeReports();

    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(_center, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(        
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14,
            ),
            myLocationEnabled: true,
            markers: _markers,
            onMapCreated: (c) {
              _controller = c;
            },
          ),

          Positioned(
            top: 70,
            left: 16,
            right: 16,
            child: SearchBar(
              controller: _searchController,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              side: const WidgetStatePropertyAll(
                BorderSide(color: Colors.transparent),
              ),
              hintText: 'Search for a location',
              constraints: const BoxConstraints(
                minHeight: 50,
                maxHeight: 50,
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 14),
              ),
              leading: const Icon(
                Icons.search,
                size: 20,
              ),
              onChanged: (value) {
                _getSuggestions(value);
              },
              onSubmitted: (value) {
                _searchLocation(value);

                setState(() {
                  _suggestions.clear();
                });
              },
            )
          ),
          if (_suggestions.isNotEmpty && _searchController.text.isNotEmpty)
            Positioned(
              top: 125,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index]['description']),
                      onTap: () async {
                        final selectedLocation =
                            _suggestions[index]['description'];

                        _searchController.text = selectedLocation;

                        await _searchLocation(selectedLocation);

                        if (!mounted) return;

                        setState(() {
                          _suggestions.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
