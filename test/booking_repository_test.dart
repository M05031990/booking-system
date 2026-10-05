import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_booking/core/geo.dart';
import 'package:ride_booking/core/routing.dart';
import 'package:ride_booking/features/auth/app_user.dart';
import 'package:ride_booking/features/booking/booking.dart';
import 'package:ride_booking/features/booking/booking_repository.dart';

void main() {
  const customer = AppUser(uid: 'c1', name: 'Ana', role: UserRole.customer);
  const riderA = AppUser(uid: 'r1', name: 'Ben', role: UserRole.rider);
  const riderB = AppUser(uid: 'r2', name: 'Carl', role: UserRole.rider);

  // two points in Makati, ~1.1 km apart
  const pickup = Place('Ayala Ave', LatLng(14.5547, 121.0244));
  const dropoff = Place('Greenbelt', LatLng(14.5528, 121.0145));

  late FakeFirebaseFirestore db;
  late BookingRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BookingRepository(db);
  });

  test('fare is \$1 per km, rounded to cents', () {
    expect(fareFor(3.456), 3.46);
    expect(fareFor(0), 0);
  });

  test('stepTowards stops exactly on the target', () {
    final moved = stepTowards(pickup.latLng, dropoff.latLng, 100);
    expect(metersBetween(pickup.latLng, moved), closeTo(100, 1));
    expect(stepTowards(pickup.latLng, dropoff.latLng, 1e6), dropoff.latLng);
  });

  test('create stores a waiting booking with the price fixed up front', () async {
    final id = await repo.create(customer: customer, pickup: pickup, destination: dropoff);
    final booking = await repo.watch(id).first;

    expect(booking!.status, BookingStatus.waiting);
    expect(booking.riderId, isNull);
    expect(booking.distanceKm, closeTo(1.08, 0.05));
    expect(booking.fare, fareFor(kmBetween(pickup.latLng, dropoff.latLng)));

    final raw = (await db.collection('bookings').doc(id).get()).data()!;
    expect(raw['pickup']['position']['geohash'], isA<String>());
  });

  test('only the first rider gets the booking', () async {
    final id = await repo.create(customer: customer, pickup: pickup, destination: dropoff);

    await repo.accept(id, riderA, pickup.latLng);
    await expectLater(repo.accept(id, riderB, pickup.latLng), throwsA(isA<BookingUnavailable>()));

    final booking = await repo.watch(id).first;
    expect(booking!.status, BookingStatus.going);
    expect(booking.riderName, 'Ben');
  });

  test('advance ignores stale transitions', () async {
    final id = await repo.create(customer: customer, pickup: pickup, destination: dropoff);
    await repo.accept(id, riderA, pickup.latLng);

    expect(await repo.advance(id, from: BookingStatus.going, to: BookingStatus.pickup), isTrue);
    // a second tick firing the same transition is a no-op
    expect(await repo.advance(id, from: BookingStatus.going, to: BookingStatus.pickup), isFalse);
    expect((await repo.watch(id).first)!.status, BookingStatus.pickup);
  });

  test('decodes a polyline', () {
    // example from Google's polyline docs
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, hasLength(3));
    expect(points.first.latitude, closeTo(38.5, 1e-5));
    expect(points.last.longitude, closeTo(-126.453, 1e-5));
  });

  test('fare uses road distance and stores the route when available', () async {
    final road = RoadRoute(
      points: [pickup.latLng, dropoff.latLng],
      distanceKm: 2.34,
      encoded: 'abc',
    );
    final id = await repo.create(
      customer: customer,
      pickup: pickup,
      destination: dropoff,
      route: road,
    );
    final raw = (await db.collection('bookings').doc(id).get()).data()!;
    expect(raw['fare'], 2.34);
    expect(raw['route'], 'abc');
  });

  test('customer can only cancel while waiting', () async {
    final id = await repo.create(customer: customer, pickup: pickup, destination: dropoff);
    await repo.accept(id, riderA, pickup.latLng);

    expect(await repo.cancel(id), isFalse);
  });
}
