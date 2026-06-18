import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_api_availability/google_api_availability.dart';

class AdaptiveMapView extends StatefulWidget {
  final double checkInLat;
  final double checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final double initialZoom;
  final String userAgentPackageName;
  final bool largeMarkers;

  const AdaptiveMapView({
    super.key,
    required this.checkInLat,
    required this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.initialZoom = 15.0,
    this.userAgentPackageName = 'com.joshua.socialworkFieldWork',
    this.largeMarkers = false,
  });

  @override
  State<AdaptiveMapView> createState() => _AdaptiveMapViewState();
}

class _AdaptiveMapViewState extends State<AdaptiveMapView> {
  bool _useGoogleMaps = false;
  bool _checkingServices = true;

  @override
  void initState() {
    super.initState();
    _determineMapSystem();
  }

  Future<void> _determineMapSystem() async {
    // Google Maps is only supported on mobile platforms in this app context.
    // Web falls back to FlutterMap to avoid any API billing.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      setState(() {
        _useGoogleMaps = false;
        _checkingServices = false;
      });
      return;
    }

    // On Android, verify that Google Play Services are available
    if (Platform.isAndroid) {
      try {
        final GooglePlayServicesAvailability availability = await GoogleApiAvailability.instance
            .checkGooglePlayServicesAvailability();
        if (availability != GooglePlayServicesAvailability.success) {
          debugPrint("Google Play Services not available: $availability. Falling back to FlutterMap.");
          setState(() {
            _useGoogleMaps = false;
            _checkingServices = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Error checking Google Play Services: $e. Falling back to FlutterMap.");
        setState(() {
          _useGoogleMaps = false;
          _checkingServices = false;
        });
        return;
      }
    }

    setState(() {
      _useGoogleMaps = true;
      _checkingServices = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingServices) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
      );
    }

    return _useGoogleMaps ? _buildGoogleMap() : _buildFlutterMap();
  }

  Widget _buildGoogleMap() {
    final gm.LatLng checkInLatLng = gm.LatLng(widget.checkInLat, widget.checkInLng);
    final gm.LatLng? checkOutLatLng = widget.checkOutLat != null && widget.checkOutLng != null
        ? gm.LatLng(widget.checkOutLat!, widget.checkOutLng!)
        : null;

    final Set<gm.Marker> markers = {
      gm.Marker(
        markerId: const gm.MarkerId('check_in'),
        position: checkInLatLng,
        infoWindow: const gm.InfoWindow(title: 'Check In'),
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
      ),
      if (checkOutLatLng != null)
        gm.Marker(
          markerId: const gm.MarkerId('check_out'),
          position: checkOutLatLng,
          infoWindow: const gm.InfoWindow(title: 'Check Out'),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
        ),
    };

    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: checkInLatLng,
        zoom: widget.initialZoom,
      ),
      markers: markers,
      mapToolbarEnabled: false,
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }

  Widget _buildFlutterMap() {
    final ll.LatLng checkInLatLng = ll.LatLng(widget.checkInLat, widget.checkInLng);
    final ll.LatLng? checkOutLatLng = widget.checkOutLat != null && widget.checkOutLng != null
        ? ll.LatLng(widget.checkOutLat!, widget.checkOutLng!)
        : null;

    final double containerSize = widget.largeMarkers ? 44.0 : 34.0;
    final double iconSize = widget.largeMarkers ? 38.0 : 28.0;

    return fm.FlutterMap(
      options: fm.MapOptions(
        initialCenter: checkInLatLng,
        initialZoom: widget.initialZoom,
        interactionOptions: const fm.InteractionOptions(
          flags: fm.InteractiveFlag.all,
        ),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: widget.userAgentPackageName,
        ),
        fm.MarkerLayer(
          markers: [
            fm.Marker(
              point: checkInLatLng,
              width: containerSize,
              height: containerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: containerSize,
                    height: containerSize,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.green,
                    size: iconSize,
                  ),
                ],
              ),
            ),
            if (checkOutLatLng != null)
              fm.Marker(
                point: checkOutLatLng,
                width: containerSize,
                height: containerSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.red,
                      size: iconSize,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
