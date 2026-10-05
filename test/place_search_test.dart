import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ride_booking/core/place_search.dart';

void main() {
  final photonResponse = {
    'features': [
      {
        'properties': {
          'name': 'Gaisano Capital Tisa',
          'street': 'Felimon Caburnay Street',
          'district': 'Tisa',
          'city': 'Cebu City',
          'state': 'Central Visayas',
        },
        'geometry': {
          'coordinates': [123.869331, 10.2995541],
        },
      },
      {
        // no name, falls back to the street
        'properties': {'housenumber': '90', 'street': 'Francisco Llamas St', 'city': 'Cebu City'},
        'geometry': {
          'coordinates': [123.88, 10.29],
        },
      },
      {
        // nothing usable
        'properties': {'city': 'Cebu City'},
        'geometry': {
          'coordinates': [123.9, 10.3],
        },
      },
    ],
  };

  test('parses Photon results and biases towards the given location', () async {
    late Uri requested;
    final service = PlaceSearchService(
      MockClient((req) async {
        requested = req.url;
        return http.Response(jsonEncode(photonResponse), 200);
      }),
    );

    final results = await service.search('gaisano', near: const LatLng(10.3, 123.87));

    expect(requested.queryParameters['q'], 'gaisano');
    expect(requested.queryParameters['lat'], '10.3');
    expect(results, hasLength(2));
    expect(results[0].title, 'Gaisano Capital Tisa');
    expect(results[0].subtitle, 'Felimon Caburnay Street, Tisa, Cebu City, Central Visayas');
    expect(results[0].latLng, const LatLng(10.2995541, 123.869331));
    expect(results[1].title, '90 Francisco Llamas St');
    expect(results[1].subtitle, 'Cebu City');
  });

  test('short queries and server errors return nothing', () async {
    final service = PlaceSearchService(MockClient((_) async => http.Response('oops', 500)));
    expect(await service.search('g'), isEmpty);
    expect(await service.search('gaisano'), isEmpty);
  });
}
