import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'net.dart';

class RoadRoute {
  const RoadRoute({required this.points, required this.distanceKm, required this.encoded});

  final List<LatLng> points;
  final double distanceKm;

  /// Encoded polyline, compact enough to store on the booking.
  final String encoded;
}

/// Driving routes from the public OSRM demo server (OpenStreetMap, no key).
class RoutingService {
  RoutingService(this._client);

  final http.Client _client;

  /// Null on failure; callers fall back to a straight line.
  Future<RoadRoute?> route(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=polyline',
    );
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (body['code'] != 'Ok' || routes == null || routes.isEmpty) return null;

      final best = routes.first as Map<String, dynamic>;
      final encoded = best['geometry'] as String;
      return RoadRoute(
        points: decodePolyline(encoded),
        distanceKm: (best['distance'] as num) / 1000,
        encoded: encoded,
      );
    } catch (e) {
      debugPrint('route lookup failed: $e');
      return null;
    }
  }
}

/// Standard Google polyline decoding (precision 5).
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;

  int next() {
    var shift = 0, result = 0, b = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lng += next();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

final routingServiceProvider = Provider((ref) => RoutingService(ref.watch(httpClientProvider)));

final roadRouteProvider = FutureProvider.autoDispose.family<RoadRoute?, (LatLng, LatLng)>((
  ref,
  ends,
) async {
  final route = await ref.watch(routingServiceProvider).route(ends.$1, ends.$2);
  if (route != null) ref.keepAlive(); // same ends, same route
  return route;
});
