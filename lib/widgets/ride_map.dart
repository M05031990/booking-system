import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app/theme.dart';
import '../core/routing.dart';

class MapPin {
  const MapPin(this.id, this.position, {required this.hue, required this.title});

  final String id;
  final LatLng position;
  final double hue;
  final String title;

  const MapPin.pickup(LatLng at, {String title = 'Pickup'})
    : this('pickup', at, hue: BitmapDescriptor.hueGreen, title: title);
  const MapPin.dropoff(LatLng at)
    : this('dropoff', at, hue: BitmapDescriptor.hueViolet, title: 'Drop-off');
  const MapPin.rider(LatLng at, String title)
    : this('rider', at, hue: BitmapDescriptor.hueAzure, title: title);
  const MapPin.customer(LatLng at, String title)
    : this('customer', at, hue: BitmapDescriptor.hueOrange, title: title);
}

class RoutePath {
  const RoutePath(this.id, this.points, {required this.color, this.dashed = false});

  /// Road route when available, otherwise a dashed straight line.
  factory RoutePath.between(
    String id,
    LatLng from,
    LatLng to, {
    required RoadRoute? road,
    required Color color,
  }) {
    if (road == null || road.points.length < 2) {
      return RoutePath(id, [from, to], color: color, dashed: true);
    }
    return RoutePath(id, road.points, color: color);
  }

  final String id;
  final List<LatLng> points;
  final Color color;
  final bool dashed;
}

/// Re-fits the camera only when [fitKey] changes, so the user can pan freely.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    required this.center,
    this.pins = const [],
    this.paths = const [],
    this.radiusMeters,
    this.fitKey,
    this.showMyLocation = false,
    this.onTap,
  });

  final LatLng center;
  final List<MapPin> pins;
  final List<RoutePath> paths;
  final double? radiusMeters;
  final Object? fitKey;
  final bool showMyLocation;
  final ValueChanged<LatLng>? onTap;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(RideMap old) {
    super.didUpdateWidget(old);
    if (old.fitKey != widget.fitKey) _fit();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _fit() {
    final controller = _controller;
    if (controller == null) return;

    final points = [
      ...widget.pins.map((p) => p.position),
      for (final path in widget.paths) ...path.points,
    ];
    if (points.length < 2) {
      final target = points.isEmpty ? widget.center : points.first;
      controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
      return;
    }

    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points.skip(1)) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    // don't zoom in absurdly far when the pins overlap
    const minSpan = 0.003;
    if (north - south < minSpan) {
      south -= minSpan / 2;
      north += minSpan / 2;
    }
    if (east - west < minSpan) {
      west -= minSpan / 2;
      east += minSpan / 2;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.radiusMeters;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.center, zoom: 15),
      onMapCreated: (c) {
        _controller = c;
        // bounds need a laid-out map
        Future.delayed(const Duration(milliseconds: 300), _fit);
      },
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: widget.showMyLocation,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onTap: widget.onTap,
      markers: {
        for (final pin in widget.pins)
          Marker(
            markerId: MarkerId(pin.id),
            position: pin.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(pin.hue),
            infoWindow: InfoWindow(title: pin.title),
          ),
      },
      polylines: {
        for (final path in widget.paths)
          Polyline(
            polylineId: PolylineId(path.id),
            points: path.points,
            color: path.color,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: path.dashed ? [PatternItem.dash(20), PatternItem.gap(12)] : const [],
          ),
      },
      circles: {
        if (radius != null)
          Circle(
            circleId: const CircleId('radius'),
            center: widget.center,
            radius: radius,
            fillColor: brandGreen.withValues(alpha: 0.08),
            strokeColor: brandGreen.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
      },
    );
  }
}
