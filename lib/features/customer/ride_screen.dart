import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/geo.dart';
import '../../core/location.dart';
import '../../widgets/ride_map.dart';
import '../../widgets/ride_widgets.dart';
import '../booking/booking.dart';
import '../booking/booking_repository.dart';
import 'customer_providers.dart';

class RideScreen extends ConsumerWidget {
  const RideScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(customerLocationSyncProvider(bookingId));
    return BookingLoader(
      bookingId: bookingId,
      builder: (b) => _RideView(booking: b),
    );
  }
}

class _RideView extends ConsumerWidget {
  const _RideView({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final rider = b.status.isActive ? b.riderLocation : null;
    final you = ref.watch(positionProvider).value ?? b.customerLocation;
    String away(Place p) => rider == null ? '' : formatDistance(metersBetween(rider, p.latLng));

    final (title, subtitle) = switch (b.status) {
      BookingStatus.waiting => (
        'Looking for a rider',
        'Riders within 1 km of your pickup can see this request.',
      ),
      BookingStatus.going => (
        '${b.riderName} is on the way',
        rider == null ? 'Waiting for location…' : '${away(b.pickup)} from your pickup',
      ),
      BookingStatus.pickup => ('${b.riderName} is here', 'Your rider is at the pickup point.'),
      BookingStatus.toDestination => (
        'Heading to drop-off',
        rider == null ? '' : '${away(b.destination)} to go',
      ),
      BookingStatus.arrived => ("You've arrived", 'Thanks for riding with ${b.riderName}.'),
      BookingStatus.cancelled => ('Booking cancelled', 'Riders can no longer see this request.'),
    };

    return MapLayout(
      map: RideMap(
        center: b.pickup.latLng,
        fitKey: (b.status, rider != null),
        paths: bookingPaths(ref, b, rider: rider),
        pins: [
          MapPin.pickup(b.pickup.latLng),
          MapPin.dropoff(b.destination.latLng),
          if (rider != null) MapPin.rider(rider, b.riderName ?? 'Rider'),
          if (you != null && b.status != BookingStatus.toDestination) MapPin.customer(you, 'You'),
        ],
      ),
      overlay: const [MapBackButton(to: '/customer')],
      panel: [
        TripSummary(
          booking: b,
          title: title,
          subtitle: subtitle,
          fareLabel: '${b.distanceKm.toStringAsFixed(1)} km',
        ),
        if (b.status == BookingStatus.waiting)
          OutlinedButton(
            onPressed: () => ref.read(bookingRepositoryProvider).cancel(b.id),
            child: const Text('Cancel booking'),
          ),
        if (!b.status.isActive)
          FilledButton(onPressed: () => context.go('/customer'), child: const Text('Done')),
      ],
    );
  }
}
