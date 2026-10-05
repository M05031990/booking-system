import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/routing.dart';

enum BookingStatus {
  waiting('Finding a rider'),
  going('Rider on the way'),
  pickup('At pickup'),
  toDestination('On the way to drop-off'),
  arrived('Arrived'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;

  bool get isActive => this != arrived && this != cancelled;

  static BookingStatus fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => waiting);

  static List<String> get activeNames =>
      values.where((s) => s.isActive).map((s) => s.name).toList();
}

class Place {
  const Place(this.address, this.latLng);

  final String address;
  final LatLng latLng;
}

class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.pickup,
    required this.destination,
    required this.distanceKm,
    required this.fare,
    this.riderId,
    this.riderName,
    this.customerLocation,
    this.riderLocation,
    this.route = const [],
  });

  final String id;
  final String customerId;
  final String customerName;
  final String? riderId;
  final String? riderName;
  final BookingStatus status;
  final Place pickup;
  final Place destination;
  final double distanceKm;
  final double fare;
  final LatLng? customerLocation;
  final LatLng? riderLocation;

  /// Pickup to drop-off along roads; empty if routing failed.
  final List<LatLng> route;

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final pickup = d['pickup'] as Map<String, dynamic>;
    final dest = d['destination'] as Map<String, dynamic>;
    final pickupPos = pickup['position'] as Map<String, dynamic>;

    return Booking(
      id: doc.id,
      customerId: d['customerId'] as String,
      customerName: d['customerName'] as String? ?? 'Customer',
      riderId: d['riderId'] as String?,
      riderName: d['riderName'] as String?,
      status: BookingStatus.fromName(d['status'] as String?),
      pickup: Place(pickup['address'] as String, toLatLng(pickupPos['geopoint'])!),
      destination: Place(dest['address'] as String, toLatLng(dest['geopoint'])!),
      distanceKm: (d['distanceKm'] as num).toDouble(),
      fare: (d['fare'] as num).toDouble(),
      customerLocation: toLatLng(d['customerLocation']),
      riderLocation: toLatLng(d['riderLocation']),
      route: d['route'] is String ? decodePolyline(d['route'] as String) : const [],
    );
  }
}

LatLng? toLatLng(Object? value) =>
    value is GeoPoint ? LatLng(value.latitude, value.longitude) : null;

GeoPoint toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);
