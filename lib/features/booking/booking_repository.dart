import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/geo.dart';
import '../../core/routing.dart';
import '../auth/app_user.dart';
import '../auth/auth_repository.dart';
import 'booking.dart';

class BookingUnavailable implements Exception {
  const BookingUnavailable();

  @override
  String toString() => 'This booking was already taken or cancelled.';
}

class BookingRepository {
  BookingRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');

  static const _timestampFor = {
    BookingStatus.going: 'acceptedAt',
    BookingStatus.pickup: 'pickedUpAt',
    BookingStatus.toDestination: 'startedAt',
    BookingStatus.arrived: 'arrivedAt',
    BookingStatus.cancelled: 'cancelledAt',
  };

  /// Fare is fixed here, from road distance if we have a route.
  Future<String> create({
    required AppUser customer,
    required Place pickup,
    required Place destination,
    RoadRoute? route,
  }) async {
    final km = route?.distanceKm ?? kmBetween(pickup.latLng, destination.latLng);
    final doc = await _bookings.add({
      'customerId': customer.uid,
      'customerName': customer.name,
      'riderId': null,
      'riderName': null,
      'status': BookingStatus.waiting.name,
      'pickup': {
        'address': pickup.address,
        'position': GeoFirePoint(toGeoPoint(pickup.latLng)).data,
      },
      'destination': {'address': destination.address, 'geopoint': toGeoPoint(destination.latLng)},
      'route': route?.encoded,
      'distanceKm': double.parse(km.toStringAsFixed(2)),
      'fare': fareFor(km),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<Booking?> watch(String id) =>
      _bookings.doc(id).snapshots().map((snap) => snap.exists ? Booking.fromDoc(snap) : null);

  /// The booking this user is currently part of, if any.
  Stream<Booking?> watchActive(AppUser user) => _bookings
      .where(user.isRider ? 'riderId' : 'customerId', isEqualTo: user.uid)
      .where('status', whereIn: BookingStatus.activeNames)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Booking.fromDoc(s.docs.first));

  Stream<List<Booking>> watchWaitingNear(LatLng center, double radiusKm) {
    return GeoCollectionReference(_bookings)
        .subscribeWithin(
          center: GeoFirePoint(toGeoPoint(center)),
          radiusInKm: radiusKm,
          field: 'pickup.position',
          geopointFrom: (data) =>
              (data['pickup'] as Map<String, dynamic>)['position']['geopoint'] as GeoPoint,
          queryBuilder: (q) => q.where('status', isEqualTo: BookingStatus.waiting.name),
          strictMode: true,
        )
        .map((docs) => docs.map(Booking.fromDoc).toList());
  }

  /// Transaction so two riders can't take the same booking.
  Future<void> accept(String id, AppUser rider, LatLng riderAt) {
    return _db.runTransaction((tx) async {
      final ref = _bookings.doc(id);
      final data = (await tx.get(ref)).data();
      if (data == null || data['status'] != BookingStatus.waiting.name || data['riderId'] != null) {
        throw const BookingUnavailable();
      }
      tx.update(ref, {
        'riderId': rider.uid,
        'riderName': rider.name,
        'status': BookingStatus.going.name,
        'riderLocation': toGeoPoint(riderAt),
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// No-op if the status is no longer [from], so repeated calls are safe.
  Future<bool> advance(
    String id, {
    required BookingStatus from,
    required BookingStatus to,
    LatLng? riderAt,
  }) {
    return _db.runTransaction((tx) async {
      final ref = _bookings.doc(id);
      final data = (await tx.get(ref)).data();
      if (data == null || data['status'] != from.name) return false;
      tx.update(ref, {
        'status': to.name,
        if (_timestampFor[to] != null) _timestampFor[to]!: FieldValue.serverTimestamp(),
        if (riderAt != null) 'riderLocation': toGeoPoint(riderAt),
      });
      return true;
    });
  }

  Future<bool> cancel(String id) =>
      advance(id, from: BookingStatus.waiting, to: BookingStatus.cancelled);

  /// Fire-and-forget; a missed write is covered by the next one.
  void shareLocation(String id, LatLng at, {required bool rider}) {
    _bookings
        .doc(id)
        .update({rider ? 'riderLocation' : 'customerLocation': toGeoPoint(at)})
        .catchError((Object e) => debugPrint('location write failed: $e'));
  }
}

final bookingRepositoryProvider = Provider(
  (ref) => BookingRepository(ref.watch(firestoreProvider)),
);

final bookingProvider = StreamProvider.autoDispose.family<Booking?, String>(
  (ref, id) => ref.watch(bookingRepositoryProvider).watch(id),
);

final activeBookingProvider = StreamProvider.autoDispose<Booking?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(bookingRepositoryProvider).watchActive(user);
});
