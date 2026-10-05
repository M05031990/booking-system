import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/location.dart';

/// Spinner or error until the first location fix arrives.
class LocationGate extends ConsumerWidget {
  const LocationGate({super.key, required this.builder});

  final Widget Function(BuildContext context, LatLng here) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider);
    final here = position.value;
    if (here != null) return builder(context, here);

    if (position.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, size: 40),
                const SizedBox(height: 12),
                Text('${position.error}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(gpsPositionProvider),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location…'),
          ],
        ),
      ),
    );
  }
}
