import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'constants.dart';

double metersBetween(LatLng a, LatLng b) =>
    Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

double kmBetween(LatLng a, LatLng b) => metersBetween(a, b) / 1000;

double fareFor(double km) => double.parse((km * farePerKm).toStringAsFixed(2));

String formatDistance(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

String formatMoney(double amount) => '\$${amount.toStringAsFixed(2)}';

/// Moves [from] towards [to] by at most [meters] in a straight line.
LatLng stepTowards(LatLng from, LatLng to, double meters) {
  final total = metersBetween(from, to);
  if (total <= meters) return to;
  final t = meters / total;
  return LatLng(
    from.latitude + (to.latitude - from.latitude) * t,
    from.longitude + (to.longitude - from.longitude) * t,
  );
}

/// Rounds to ~100 m so a moving point doesn't change on every GPS tick.
LatLng coarse(LatLng p) =>
    LatLng((p.latitude * 1000).roundToDouble() / 1000, (p.longitude * 1000).roundToDouble() / 1000);
