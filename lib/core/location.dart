import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'drive_simulator.dart';

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  final _geocoding = Geocoding();

  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Location services are turned off.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Location permission is blocked. Enable it in Settings.');
    }
  }

  Future<LatLng> current() async {
    final p = await Geolocator.getCurrentPosition();
    return LatLng(p.latitude, p.longitude);
  }

  Stream<LatLng> watch() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  ).map((p) => LatLng(p.latitude, p.longitude));

  Future<String> addressOf(LatLng point) async {
    try {
      final marks = await _geocoding.placemarkFromCoordinates(point.latitude, point.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final parts = [
          m.street,
          m.subLocality,
          m.locality,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).toSet().toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // geocoder fails offline and on some emulators
    }
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }
}

final locationServiceProvider = Provider((ref) => LocationService());

final gpsPositionProvider = StreamProvider<LatLng>((ref) async* {
  final service = ref.watch(locationServiceProvider);
  await service.ensurePermission();
  yield await service.current();
  yield* service.watch();
});

/// Current position: the demo drive if one is running, otherwise GPS.
final positionProvider = Provider<AsyncValue<LatLng>>((ref) {
  final simulated = ref.watch(driveSimulatorProvider);
  if (simulated != null) return AsyncData(simulated);
  return ref.watch(gpsPositionProvider);
});
