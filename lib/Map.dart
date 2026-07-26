import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'api_service.dart';
import 'ReportDetails.dart';

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

  List<dynamic> _recentReports = [];

  String? _selectedCategory; // null = show all

  Map<String, dynamic>? _selectedReport;

  Future<void> _loadRecentReports() async {
  _recentReports = await ApiService.getRecentReports(amount: 100);

  print(_recentReports);

  _updateMarkers();
}

void _updateMarkers() {
  final reports = _selectedCategory == null
      ? _recentReports
      : _recentReports.where((report) {
          if (_selectedCategory == "Other") {
            return ![
              "Road Damage",
              "Public Works",
              "Environmental",
              "Accessibility",
            ].contains(report["category"]);
          }

          return report["category"] == _selectedCategory;
        });

  setState(() {
    _markers = reports.map<Marker>((report) {
      return Marker(
        markerId: MarkerId(report["id"].toString()),
        position: LatLng(
          report["latitude"],
          report["longitude"],
        ),
        onTap: () {
          setState(() {
            _selectedReport = report;
          });
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getMarkerColor(report["category"]),
        ),
      );
    }).toSet();
  });
}

double _getMarkerColor(String category) {
  switch (category) {
    case "Road Damage":
      return BitmapDescriptor.hueRed;

    case "Public Works":
      return BitmapDescriptor.hueOrange;

    case "Environmental":
      return BitmapDescriptor.hueGreen;

    case "Accessibility":
      return BitmapDescriptor.hueAzure;

    default:
      return BitmapDescriptor.hueViolet;
  }
}

Widget _categoryChip(
  String label,
  String? category,
  Color color,
) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          color: _selectedCategory == category
              ? Colors.white
              : Colors.black,
        ),
      ),
      selected: _selectedCategory == category,
      selectedColor: color,
      backgroundColor: Colors.white,
      checkmarkColor: Colors.white,
      onSelected: (_) {
        setState(() {
          _selectedCategory = category;
          _selectedReport = null;
        });

        _updateMarkers();
      },
    ),
  );
}

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

    await _loadRecentReports();

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
            if (_selectedReport != null)
              Positioned(
                bottom: 90,
                left: 20,
                right: 20,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          _selectedReport!["description"],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Category: ${_selectedReport!["category"]}",
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReportDetailsScreen(
                                      report: _selectedReport!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _categoryChip("All", null, Colors.grey),
                    _categoryChip("Road", "Road Damage", Colors.red),
                    _categoryChip("Public", "Public Works", Colors.orange),
                    _categoryChip("Environment", "Environmental", Colors.green),
                    _categoryChip("ADA", "Accessibility", Colors.blue),
                    _categoryChip("Other", "Other", Colors.purple),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}