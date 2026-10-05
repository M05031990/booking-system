import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app/theme.dart';
import '../core/geo.dart';
import '../core/routing.dart';
import '../features/booking/booking.dart';
import '../features/booking/booking_repository.dart';
import 'ride_map.dart';

/// Map on top, white panel underneath; [overlay] floats over the map.
class MapLayout extends StatelessWidget {
  const MapLayout({super.key, required this.map, this.overlay = const [], required this.panel});

  final Widget map;
  final List<Widget> overlay;
  final List<Widget> panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              map,
              Column(children: overlay),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 8,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: panel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MapTopBar extends StatelessWidget {
  const MapTopBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: children),
          ),
        ),
      ),
    );
  }
}

class MapBackButton extends StatelessWidget {
  const MapBackButton({super.key, required this.to});

  final String to;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(to),
          ),
        ),
      ),
    );
  }
}

/// Loads a booking and shows loading / missing / error states.
class BookingLoader extends ConsumerWidget {
  const BookingLoader({super.key, required this.bookingId, required this.builder});

  final String bookingId;
  final Widget Function(Booking booking) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: switch (ref.watch(bookingProvider(bookingId))) {
        AsyncData(value: final booking?) => builder(booking),
        AsyncData() => const Center(child: Text('Booking not found.')),
        AsyncError(:final error) => Center(child: Text('Something went wrong: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Trip route, plus the rider's route to pickup while they're on the way.
List<RoutePath> bookingPaths(WidgetRef ref, Booking b, {LatLng? rider}) {
  final approaching = rider != null && b.status == BookingStatus.going;
  return [
    b.route.length > 1
        ? RoutePath('trip', b.route, color: brandPurple)
        : RoutePath.between(
            'trip',
            b.pickup.latLng,
            b.destination.latLng,
            road: null,
            color: brandPurple,
          ),
    if (approaching)
      RoutePath.between(
        'approach',
        rider,
        b.pickup.latLng,
        road: ref.watch(roadRouteProvider((coarse(rider), b.pickup.latLng))).value,
        color: brandGreen,
      ),
  ];
}

/// Five-step bar: waiting → going → pickup → to destination → arrived.
class StatusProgress extends StatelessWidget {
  const StatusProgress({super.key, required this.status});

  final BookingStatus status;

  static const _steps = [
    BookingStatus.waiting,
    BookingStatus.going,
    BookingStatus.pickup,
    BookingStatus.toDestination,
    BookingStatus.arrived,
  ];

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(status);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? brandGreen : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          status.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: brandPurple,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// Status, headline, route and fare shown on both trip screens.
class TripSummary extends StatelessWidget {
  const TripSummary({
    super.key,
    required this.booking,
    required this.title,
    required this.subtitle,
    required this.fareLabel,
  });

  final Booking booking;
  final String title;
  final String subtitle;
  final String fareLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (booking.status != BookingStatus.cancelled) ...[
          StatusProgress(status: booking.status),
          const SizedBox(height: 12),
        ],
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle.isNotEmpty) Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        PlaceRow(label: 'Pickup', text: booking.pickup.address, color: brandGreen),
        const SizedBox(height: 8),
        PlaceRow(label: 'Drop-off', text: booking.destination.address, color: brandPurple),
        const SizedBox(height: 12),
        FareRow(label: fareLabel, fare: booking.fare),
        const SizedBox(height: 12),
      ],
    );
  }
}

class FareRow extends StatelessWidget {
  const FareRow({super.key, required this.label, required this.fare});

  final String label;
  final double fare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          formatMoney(fare),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.label,
    required this.text,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String text;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveRideBanner extends StatelessWidget {
  const ActiveRideBanner({super.key, required this.booking, required this.onOpen});

  final Booking booking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: brandPurple,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        onTap: onOpen,
        textColor: Colors.white,
        iconColor: Colors.white,
        leading: const Icon(Icons.directions_car_filled_outlined),
        title: const Text('Ride in progress'),
        subtitle: Text(booking.status.label),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
