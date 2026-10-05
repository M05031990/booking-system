import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/drive_simulator.dart';
import '../../core/geo.dart';
import '../../core/location.dart';
import '../../widgets/ride_map.dart';
import '../../widgets/ride_widgets.dart';
import '../booking/booking.dart';
import '../booking/booking_repository.dart';
import 'rider_providers.dart';

class TripScreen extends ConsumerWidget {
  const TripScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tripAutomationProvider(bookingId));
    return BookingLoader(
      bookingId: bookingId,
      builder: (b) => _TripView(booking: b),
    );
  }
}

class _TripView extends ConsumerStatefulWidget {
  const _TripView({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_TripView> createState() => _TripViewState();
}

class _TripViewState extends ConsumerState<_TripView> {
  bool _starting = false;

  Future<void> _startTrip() async {
    setState(() => _starting = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .advance(widget.booking.id, from: BookingStatus.pickup, to: BookingStatus.toDestination);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _toggleSimulation(LatLng? here) {
    final sim = ref.read(driveSimulatorProvider.notifier);
    if (sim.isRunning) return sim.stop();

    final b = widget.booking;
    // container, not ref: the timer outlives this widget
    final container = ProviderScope.containerOf(context, listen: false);
    sim.start(here ?? b.riderLocation ?? b.pickup.latLng, () {
      final current = container.read(bookingProvider(b.id)).value;
      return switch (current?.status) {
        BookingStatus.going || BookingStatus.pickup => current!.pickup.latLng,
        BookingStatus.toDestination => current!.destination.latLng,
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final me = ref.watch(positionProvider).value ?? b.riderLocation;
    final simulating = ref.watch(driveSimulatorProvider) != null;
    final beforePickup = b.status == BookingStatus.going || b.status == BookingStatus.pickup;
    final target = beforePickup ? b.pickup : b.destination;
    final toGo = me == null ? '' : formatDistance(metersBetween(me, target.latLng));

    final (title, subtitle) = switch (b.status) {
      BookingStatus.going => (
        'Head to pickup',
        '${toGo.isEmpty ? '' : '$toGo · '}'
            'arrives automatically within ${arrivalRadiusMeters.round()} m',
      ),
      BookingStatus.pickup => ('Pick up ${b.customerName}', 'Start the trip once they are in.'),
      BookingStatus.toDestination => ('Drive to drop-off', toGo.isEmpty ? '' : '$toGo to go'),
      BookingStatus.arrived => ('Trip complete', 'Fare ${formatMoney(b.fare)}'),
      BookingStatus.cancelled => ('Booking cancelled', 'The customer cancelled this ride.'),
      BookingStatus.waiting => ('Waiting', ''),
    };

    return MapLayout(
      map: RideMap(
        center: me ?? b.pickup.latLng,
        fitKey: b.status,
        paths: bookingPaths(ref, b, rider: me),
        pins: [
          MapPin.pickup(b.pickup.latLng),
          MapPin.dropoff(b.destination.latLng),
          if (me != null) MapPin.rider(me, 'You'),
          if (b.customerLocation != null && beforePickup)
            MapPin.customer(b.customerLocation!, b.customerName),
        ],
      ),
      overlay: const [MapBackButton(to: '/rider')],
      panel: [
        TripSummary(booking: b, title: title, subtitle: subtitle, fareLabel: b.customerName),
        if (b.status == BookingStatus.pickup)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: brandPurple),
            onPressed: _starting ? null : _startTrip,
            child: const Text('Start trip'),
          ),
        if (!b.status.isActive)
          FilledButton(onPressed: () => context.go('/rider'), child: const Text('Done')),
        if (kDebugMode && b.status.isActive && b.status != BookingStatus.pickup)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              icon: Icon(simulating ? Icons.stop : Icons.play_arrow),
              label: Text(simulating ? 'Stop simulated drive' : 'Simulate drive'),
              onPressed: () => _toggleSimulation(me),
            ),
          ),
      ],
    );
  }
}
