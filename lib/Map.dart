import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'ReportDetails.dart';
import 'api_service.dart';
import 'config.dart';
import 'report_categories.dart';

enum IssueCategory {
  roadDamage,
  publicWorks,
  environmental,
  ada,
  other,
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.isActive = true, this.initialReportId});

  final bool? isActive;
  final int? initialReportId;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _center = const LatLng(40.3334, -74.6004); // Plainsboro, NJ
  bool _ready = false;
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _recentReports = [];
  bool _loadingReports = false;

  String? _selectedCategory;

  Future<void> _applyInitialSelection() async {
    final id = widget.initialReportId;
    if (id == null) return;

    dynamic match;
    for (final r in _recentReports) {
      if (r['id'] == id || r['id'].toString() == id.toString()) {
        match = r;
        break;
      }
    }
    if (match == null) return;

    await _selectReport(match, true);

    setState(() => _ready = true);
  }

  Map<String, dynamic>? _selectedReport;

  Future<void> _paintCachedReports() async {
    final cached = await ApiService.getCachedRecentReports();
    if (!mounted) return;
    if (cached == null || cached.isEmpty) return;

    _recentReports = List<dynamic>.from(cached);
    _updateMarkers();
  }

  BitmapDescriptor _getMarkerIcon(String category, bool isSelected) {
    final major = ReportCategories.majorCategoryOf(category) ?? category;
    switch (major) {
      case ReportCategories.streetsAndTransportation:
        return isSelected ? redLarge! : redSmall!;

      case ReportCategories.trashAndEnvironment:
        return isSelected ? orangeLarge! : orangeSmall!;

      case ReportCategories.natureAndWater:
        return isSelected ? greenLarge! : greenSmall!;

      case ReportCategories.buildingsAndPublicSpaces:
        return isSelected ? blueLarge! : blueSmall!;

      default:
        return isSelected ? purpleLarge! : purpleSmall!;
    }
  }

  BitmapDescriptor? redSmall, redLarge;
  BitmapDescriptor? orangeSmall, orangeLarge;
  BitmapDescriptor? greenSmall, greenLarge;
  BitmapDescriptor? blueSmall, blueLarge;
  BitmapDescriptor? purpleSmall, purpleLarge;

  String? _selectedMarkerId;

  Future<void> _loadMarkerIcons() async {
    redSmall = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(19, 24.5)),
      'assets/images/markers/Small_Red.png',
    );

    redLarge = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(25, 30)),
      'assets/images/markers/Big_Red.png',
    );

    orangeSmall = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(19, 24.5)),
      'assets/images/markers/Small_Orange.png',
    );

    orangeLarge = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(25, 30)),
      'assets/images/markers/Big_Orange.png',
    );

    greenSmall = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(19, 24.5)),
      'assets/images/markers/Small_Green.png',
    );

    greenLarge = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(25, 30)),
      'assets/images/markers/Big_Green.png',
    );

    blueSmall = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(19, 24.5)),
      'assets/images/markers/Small_Blue.png',
    );

    blueLarge = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(25, 30)),
      'assets/images/markers/Big_Blue.png',
    );

    purpleSmall = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(19, 24.5)),
      'assets/images/markers/Small_Purple.png',
    );

    purpleLarge = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(25, 30)),
      'assets/images/markers/Big_Purple.png',
    );
  }

  Future<void> _selectReport(dynamic report, bool zoom) async {
    _selectedMarkerId = report["id"].toString();
    _selectedReport = Map<String, dynamic>.from(report as Map);
    _updateMarkers();
    final lat = (report['latitude'] as num).toDouble();
    final lng = (report['longitude'] as num).toDouble();
    await _gotothingie(LatLng(lat, lng), zoom);
  }

  Future<void> _gotothingie(LatLng target, bool zoom) async {
    setState(() => _center = target);
    final currentZoom = await _controller?.getZoomLevel()??0;
    bool shouldzoom = false;
    if(zoom||currentZoom<16){
      shouldzoom = true;
    }
    await _controller?.animateCamera(
      shouldzoom ? CameraUpdate.newLatLngZoom(target, 16) : CameraUpdate.newLatLng(target)
    );
  }
  void _clearSelection() {
    if (_selectedMarkerId == null && _selectedReport == null) return;
    _selectedMarkerId = null;
    _selectedReport = null;
    _updateMarkers();
  }

  /// Show cache immediately (if any), then refresh from network in the background.
  /// On network failure, keep whatever markers are already on screen.
  Future<void> _loadRecentReports({bool paintCache = true}) async {
    if (_loadingReports) return;
    _loadingReports = true;
    try {
      if (paintCache) {
        await _paintCachedReports();
      }

      final reports = await ApiService.getRecentReports(amount: 100);
      if (!mounted) return;
      if (reports == null) return; // keep cache / in-memory markers

      _recentReports = reports;
      _updateMarkers();
    } finally {
      _loadingReports = false;
    }
  }

  void _updateMarkers() {

    if (redSmall == null ||
        redLarge == null ||
        orangeSmall == null ||
        orangeLarge == null ||
        greenSmall == null ||
        greenLarge == null ||
        blueSmall == null ||
        blueLarge == null ||
        purpleSmall == null ||
        purpleLarge == null) {
      return;
    }

    final reports = _selectedCategory == null
        ? _recentReports
        : _recentReports.where((report) {
            final category = report["category"] as String?;
            final major = ReportCategories.majorCategoryOf(category);
            if (_selectedCategory == ReportCategories.other) {
              return !ReportCategories.isPrimary(category);
            }

            return major == _selectedCategory;
          });

    setState(() {
      _markers = reports.map<Marker>((report) {
        final id = report["id"].toString();
        final isSelected = id == _selectedMarkerId;
        return Marker(
          markerId: MarkerId(id),
          position: LatLng(
            report["latitude"],
            report["longitude"],
          ),
          consumeTapEvents: true,
          onTap: () => _selectReport(report,false),
          icon: _getMarkerIcon(
            report["category"] as String,
            isSelected,
          ),
          zIndexInt: isSelected ? 10 : 0,
          anchor: const Offset(0.5, 1.0),
        );
      }).toSet();
    });
  }

  double _getMarkerColor(String category) {
    final major = ReportCategories.majorCategoryOf(category) ?? category;
    switch (major) {
      case ReportCategories.streetsAndTransportation:
        return BitmapDescriptor.hueRed;

      case ReportCategories.trashAndEnvironment:
        return BitmapDescriptor.hueOrange;

      case ReportCategories.natureAndWater:
        return BitmapDescriptor.hueGreen;

      case ReportCategories.buildingsAndPublicSpaces:
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
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            setState(() {
              _selectedCategory = category;
              _selectedMarkerId = null;
              _selectedReport = null;
            });
            _updateMarkers();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
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

    _loadMarkerIcons().then((_) {
      _goToUser();
    });
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == true && oldWidget.isActive != true) {
      _loadRecentReports();
    }
    if (widget.initialReportId != oldWidget.initialReportId) {
      if (widget.initialReportId != null) {
        _applyInitialSelection();
      } else {
        _clearSelection();
      }
    }
  }

  Future<void> _goToUser() async {

    await _loadRecentReports();

    if (widget.initialReportId != null) {
      await _applyInitialSelection();
      if (mounted && !_ready) setState(() => _ready = true);
      return;
    }

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
      CameraUpdate.newLatLngZoom(_center, 15),
    );
  }

  Future<void> _recenterOnUser() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final currentLocation = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(currentLocation.latitude, currentLocation.longitude),
        15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Nav dock sits over the map. Chips and the location button share one row above it.
    final aboveDock = bottomInset + 8.0;
    return Scaffold(        
      body: Stack(
        children: [
          GoogleMap(
            mapId: googleMapsMapId,
            padding: EdgeInsets.only(top: 130, bottom: aboveDock + 48),
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onTap: (_) => _clearSelection(),
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
                bottom: aboveDock + 58,
                left: 16,
                right: 16,
                child: _buildSelectedReportCard(_selectedReport!),
              ),
            Positioned(
              bottom: aboveDock,
              left: 12,
              right: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final category in [null, ...ReportCategories.all])
                            _categoryChip(
                              category == null
                                  ? 'All'
                                  : ReportCategories.shortLabel(category),
                              category,
                              category == null
                                  ? const Color(0xFF6B7280)
                                  : ReportCategories.color(category),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black26,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _recenterOnUser,
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          Icons.my_location,
                          size: 26,
                          color: Color(0xFF3C4043),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedReportCard(Map<String, dynamic> report) {
    final title = (report['title'] as String?)?.trim().isNotEmpty == true
        ? report['title'] as String
        : (report['description'] as String? ?? 'Report');
    final category = report['category']?.toString() ?? 'Other';
    final location = report['location']?.toString() ?? 'Unknown location';
    final imageUrl = report['image']?.toString();
    final categoryColor = ReportCategories.color(category);

    return Material(
      elevation: 10,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailsScreen(report: report),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPreviewThumb(imageUrl, category, categoryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          ReportCategories.icon(category),
                          size: 14,
                          color: categoryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _clearSelection,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 24, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 30,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewThumb(
    String? imageUrl,
    String category,
    Color categoryColor,
  ) {
    const size = 72.0;
    final hasNetworkImage = imageUrl != null &&
        imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: hasNetworkImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _thumbFallback(category, categoryColor),
              )
            : _thumbFallback(category, categoryColor),
      ),
    );
  }

  Widget _thumbFallback(String category, Color categoryColor) {
    return ColoredBox(
      color: categoryColor.withValues(alpha: 0.12),
      child: Icon(
        ReportCategories.icon(category),
        color: categoryColor,
        size: 28,
      ),
    );
  }
}