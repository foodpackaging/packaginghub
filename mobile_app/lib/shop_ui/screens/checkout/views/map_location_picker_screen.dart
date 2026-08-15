import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/services/location_service.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';

/// Minimum map zoom required before a location can be confirmed — prevents
/// confirming a "precise-looking" pin while zoomed out to city/state level.
const double _minConfirmZoom = 16.0;

/// How long to wait after the map stops moving before reverse-geocoding,
/// so rapid pans/zooms don't fire a burst of requests against Nominatim's
/// free-tier rate limit (1 req/sec).
const Duration _reverseGeocodeDebounce = Duration(milliseconds: 700);

class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({super.key});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  LatLng _currentCenter = const LatLng(19.0760, 72.8777); // Default: Mumbai
  double _currentZoom = 16.0;
  bool _isLoadingAddress = false;
  bool _isFetchingGPS = false;
  String _currentAddress = "Loading address...";
  LocationResult? _lastResult;

  Timer? _debounceTimer;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    // Start with GPS location if possible
    _fetchGPSLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchGPSLocation() async {
    setState(() => _isFetchingGPS = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = newCenter;
        _currentZoom = 16.0;
      });
      _mapController.move(newCenter, 16.0);
      _reverseGeocode(newCenter);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingGPS = false);
    }
  }

  void _scheduleReverseGeocode(LatLng position) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_reverseGeocodeDebounce, () => _reverseGeocode(position));
  }

  Future<void> _reverseGeocode(LatLng position) async {
    final requestId = ++_requestId;
    setState(() => _isLoadingAddress = true);
    try {
      final result = await _locationService.reverseGeocode(position.latitude, position.longitude);
      // Discard this result if a newer request has started since (avoids a
      // slow/stale response overwriting a more recent one).
      if (requestId != _requestId) return;
      if (mounted) {
        setState(() {
          _lastResult = result;
          _currentAddress = result.formattedAddress;
        });
      }
    } catch (e) {
      if (requestId != _requestId) return;
      if (mounted) {
        setState(() {
          _currentAddress = "Could not fetch address. Please move the pin.";
        });
      }
    } finally {
      if (requestId == _requestId && mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  bool get _canConfirm =>
      !_isLoadingAddress &&
      _lastResult != null &&
      _currentZoom >= _minConfirmZoom;

  void _onConfirm() {
    if (_lastResult == null) return;

    // Save coordinates but DO NOT go to checkout yet. Go to Address Details form.
    final cart = context.read<CartController>();
    cart.customLatitude = _lastResult!.latitude;
    cart.customLongitude = _lastResult!.longitude;
    cart.customDeliveryAddress = _lastResult!.formattedAddress; // pre-fill
    
    Navigator.pushReplacementNamed(context, addressDetailsScreenRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Delivery Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _isFetchingGPS ? null : _fetchGPSLocation,
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.0,
              onPositionChanged: (position, hasGesture) {
                _currentZoom = position.zoom;
                if (hasGesture && position.center != null) {
                  setState(() {
                    _currentCenter = position.center!;
                    _currentAddress = "Loading address...";
                  });
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _scheduleReverseGeocode(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.b2bstore.app',
              ),
            ],
          ),
          
          // Center Pin (Fixed in center of screen)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0), // Offset to point to exact center
              child: Icon(Icons.location_on, size: 40, color: primaryColor),
            ),
          ),

          // Bottom Address Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Location', style: TextStyle(color: mutedText, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: (_lastResult != null && !_lastResult!.resolved) ? warningColor : primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentAddress,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isLoadingAddress)
                          const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                      ],
                    ),
                    if (!_isLoadingAddress && _lastResult != null && !_lastResult!.resolved) ...[
                      const SizedBox(height: 6),
                      const Text(
                        "Couldn't verify an exact address for this spot — double-check it on the next screen before ordering.",
                        style: TextStyle(color: warningColor, fontSize: 11.5),
                      ),
                    ],
                    if (!_isLoadingAddress && _currentZoom < _minConfirmZoom) ...[
                      const SizedBox(height: 6),
                      const Text(
                        "Zoom in for a more precise location before confirming.",
                        style: TextStyle(color: mutedText, fontSize: 11.5),
                      ),
                    ],
                    const SizedBox(height: defaultPadding),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _canConfirm ? _onConfirm : null,
                        child: const Text('Confirm Location & Proceed'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
