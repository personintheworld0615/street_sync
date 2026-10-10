import 'package:geocoding/geocoding.dart';

/// StreetSync only accepts reports inside Plainsboro Township, NJ.
bool looksLikePlainsboro(String? value) {
  if (value == null) return false;
  return value.toLowerCase().contains('plainsboro');
}

bool isPlainsboroPlacemark(Placemark place) {
  return looksLikePlainsboro(place.locality) ||
      looksLikePlainsboro(place.subLocality) ||
      looksLikePlainsboro(place.subAdministrativeArea) ||
      looksLikePlainsboro(place.name);
}

/// Reverse-geocode [latitude]/[longitude] and check township name.
Future<bool> isLocationInPlainsboro(double latitude, double longitude) async {
  try {
    final places = await placemarkFromCoordinates(latitude, longitude);
    if (places.isEmpty) return false;
    return isPlainsboroPlacemark(places.first);
  } catch (_) {
    return false;
  }
}

/// Reverse-geocodes coordinates into a readable address (street + city).
Future<String> translateLocation(
  double latitude,
  double longitude, {
  bool includeRegion = false,
  String fallback = 'Pinned location',
}) async {
  try {
    final places = await placemarkFromCoordinates(latitude, longitude);
    if (places.isEmpty) return fallback;
    final formatted = formatPlacemark(
      places.first,
      includeRegion: includeRegion,
    );
    return formatted ?? fallback;
  } catch (_) {
    return fallback;
  }
}

String? formatPlacemark(Placemark place, {bool includeRegion = false}) {
  final street = _streetFrom(place);
  final city = _firstNonEmpty([
    place.locality,
    place.subLocality,
    place.subAdministrativeArea,
  ]);
  final region = place.administrativeArea?.trim() ?? '';

  final parts = <String>[];
  if (street != null && street != city) parts.add(street);
  if (city != null) parts.add(city);
  if (includeRegion && region.isNotEmpty && region != city) {
    parts.add(region);
  }
  if (parts.isEmpty) return null;
  return parts.join(', ');
}

String? _streetFrom(Placemark place) {
  final street = place.street?.trim();
  if (street != null && street.isNotEmpty) return street;

  final number = place.subThoroughfare?.trim() ?? '';
  final name = place.thoroughfare?.trim() ?? '';
  if (number.isNotEmpty && name.isNotEmpty) return '$number $name';
  if (name.isNotEmpty) return name;

  final fallback = place.name?.trim();
  if (fallback != null &&
      fallback.isNotEmpty &&
      fallback != place.locality?.trim()) {
    return fallback;
  }
  return null;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
