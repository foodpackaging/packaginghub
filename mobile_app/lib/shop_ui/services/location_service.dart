import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Result returned after a successful location fetch.
class LocationResult {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? city;
  final String? state;
  final String? pincode;

  /// True if [formattedAddress] came from a real reverse-geocode match.
  /// False means the reverse-geocode call failed or returned nothing usable,
  /// and [formattedAddress] is just the raw "lat, lon" coordinate string —
  /// callers should surface this distinction to the user instead of silently
  /// presenting coordinates as if they were a resolved address.
  final bool resolved;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.city,
    this.state,
    this.pincode,
    this.resolved = false,
  });
}

class LocationService {
  /// Checks / requests permission and then returns the current GPS position.
  /// Throws a descriptive [String] on failure so callers can show it in a SnackBar.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please enable GPS and try again.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission was denied. Please allow location access to continue.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission is permanently denied. Please enable it in app settings.';
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  /// Reverse-geocodes [latitude]/[longitude] using the free OpenStreetMap
  /// Nominatim API (no API key required).
  /// Returns a human-readable address string, or a fallback coordinate string
  /// if the API call fails.
  Future<LocationResult> reverseGeocode(double latitude, double longitude) async {
    String formattedAddress = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    String? city;
    String? state;
    String? pincode;
    bool resolved = false;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'B2BStoreApp/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['address'] != null) {
          final addr = data['address'] as Map<String, dynamic>;

          // Build a clean address from structured fields (most specific to least)
          final parts = <String>[];

          // Building/house number
          final houseNumber = addr['house_number']?.toString();
          // Road/street
          final road = addr['road']?.toString() ?? addr['street']?.toString() ?? addr['pedestrian']?.toString();
          // Neighbourhood / suburb / locality
          final neighbourhood = addr['neighbourhood']?.toString() ?? addr['suburb']?.toString() ?? addr['locality']?.toString() ?? addr['residential']?.toString();
          // City/town/village
          final cityVal = addr['city']?.toString() ?? addr['town']?.toString() ?? addr['village']?.toString() ?? addr['county']?.toString() ?? addr['district']?.toString();
          final stateVal = addr['state']?.toString();
          final pincodeVal = addr['postcode']?.toString();

          if (houseNumber != null && road != null) {
            parts.add('$houseNumber, $road');
          } else if (road != null) {
            parts.add(road);
          }
          if (neighbourhood != null) parts.add(neighbourhood);
          if (cityVal != null) parts.add(cityVal);
          if (stateVal != null) parts.add(stateVal);
          if (pincodeVal != null) parts.add(pincodeVal);

          if (parts.isNotEmpty) {
            formattedAddress = parts.join(', ');
            resolved = true;
          }

          city = cityVal;
          state = stateVal;
          pincode = pincodeVal;
        }
      } else {
        debugPrint('Reverse geocoding failed: HTTP ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }

    return LocationResult(
      latitude: latitude,
      longitude: longitude,
      formattedAddress: formattedAddress,
      city: city,
      state: state,
      pincode: pincode,
      resolved: resolved,
    );
  }

  /// Convenience method — fetches GPS position AND reverse-geocodes it in one call.
  Future<LocationResult> getCurrentLocationWithAddress() async {
    final position = await getCurrentPosition();
    return await reverseGeocode(position.latitude, position.longitude);
  }

  /// Returns a standard Google Maps URL for navigation using precise coordinates.
  static String buildMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }
}
