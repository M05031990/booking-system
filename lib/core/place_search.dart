import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'net.dart';

class PlaceSuggestion {
  const PlaceSuggestion({required this.title, required this.subtitle, required this.latLng});

  final String title;
  final String subtitle;
  final LatLng latLng;

  String get address => subtitle.isEmpty ? title : '$title, $subtitle';
}

/// Place search via Photon (OpenStreetMap, no key), biased towards [near].
class PlaceSearchService {
  PlaceSearchService(this._client);

  final http.Client _client;

  Future<List<PlaceSuggestion>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'limit': '10',
      'lang': 'en',
      if (near != null) ...{'lat': near.latitude.toString(), 'lon': near.longitude.toString()},
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final features = (jsonDecode(res.body) as Map<String, dynamic>)['features'] as List;
      return features.map(_fromFeature).whereType<PlaceSuggestion>().toList();
    } catch (e) {
      debugPrint('place search failed: $e');
      return const [];
    }
  }

  PlaceSuggestion? _fromFeature(Object? f) {
    final feature = f as Map<String, dynamic>;
    final props = feature['properties'] as Map<String, dynamic>;
    final coords = (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;

    final street = [props['housenumber'], props['street']].whereType<String>().join(' ').trim();
    final title = (props['name'] as String?) ?? street;
    if (title.isEmpty) return null;

    final rest = [
      street,
      props['district'],
      props['city'],
      props['state'],
    ].whereType<String>().where((s) => s.isNotEmpty && s != title).toSet();

    return PlaceSuggestion(
      title: title,
      subtitle: rest.join(', '),
      latLng: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
    );
  }
}

final placeSearchServiceProvider = Provider(
  (ref) => PlaceSearchService(ref.watch(httpClientProvider)),
);
