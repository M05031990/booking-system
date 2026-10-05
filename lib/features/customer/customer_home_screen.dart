import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/geo.dart';
import '../../core/location.dart';
import '../../core/routing.dart';
import '../../widgets/location_gate.dart';
import '../../widgets/ride_map.dart';
import '../../widgets/ride_widgets.dart';
import '../auth/auth_repository.dart';
import '../booking/booking_repository.dart';
import 'customer_providers.dart';
import 'place_search_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    // pickup defaults to where the customer is
    ref.listenManual(positionProvider, (_, next) {
      final here = next.value;
      if (here != null && ref.read(bookingDraftProvider).pickup == null) {
        ref.read(bookingDraftProvider.notifier).setPoint(here, field: DraftField.pickup);
      }
    }, fireImmediately: true);
  }

  Future<void> _search(DraftField field) async {
    final notifier = ref.read(bookingDraftProvider.notifier);
    notifier.edit(field);

    final choice = await PlaceSearchScreen.open(
      context,
      title: field == DraftField.pickup ? 'Pickup' : 'Drop-off',
      near: ref.read(positionProvider).value,
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case PickedPlace(:final place):
        notifier.setPlace(place, field);
      case PickedCurrentLocation():
        final here = ref.read(positionProvider).value;
        if (here != null) notifier.setPoint(here, field: field);
      case ChooseOnMap():
        // field is already selected, so the next map tap sets it
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tap the map to place the pin.')));
    }
  }

  Future<void> _book() async {
    final draft = ref.read(bookingDraftProvider);
    final user = ref.read(currentUserProvider).value;
    if (!draft.isComplete || user == null) return;
    final route = ref
        .read(roadRouteProvider((draft.pickup!.latLng, draft.destination!.latLng)))
        .value;

    setState(() => _booking = true);
    try {
      final id = await ref
          .read(bookingRepositoryProvider)
          .create(
            customer: user,
            pickup: draft.pickup!,
            destination: draft.destination!,
            route: route,
          );
      ref.read(bookingDraftProvider.notifier).clearDestination();
      if (mounted) context.go('/customer/ride/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not book: $e')));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final draft = ref.watch(bookingDraftProvider);
    final active = ref.watch(activeBookingProvider).value;
    final notifier = ref.read(bookingDraftProvider.notifier);

    final theme = Theme.of(context);
    final pickup = draft.pickup;
    final destination = draft.destination;
    final ends = draft.isComplete ? (pickup!.latLng, destination!.latLng) : null;
    final routeAsync = ends == null ? null : ref.watch(roadRouteProvider(ends));
    final road = routeAsync?.value;
    final routing = routeAsync?.isLoading ?? false;
    final km = ends == null ? null : road?.distanceKm ?? kmBetween(ends.$1, ends.$2);

    return LocationGate(
      builder: (context, here) => Scaffold(
        body: MapLayout(
          map: RideMap(
            center: here,
            showMyLocation: true,
            onTap: notifier.setPoint,
            fitKey: (pickup?.latLng, destination?.latLng, road != null),
            paths: [
              if (ends != null)
                RoutePath.between('trip', ends.$1, ends.$2, road: road, color: brandPurple),
            ],
            pins: [
              if (pickup != null) MapPin.pickup(pickup.latLng),
              if (destination != null) MapPin.dropoff(destination.latLng),
            ],
          ),
          overlay: [
            MapTopBar(
              children: [
                const SizedBox(width: 8),
                Expanded(child: Text('Hi ${user?.name ?? ''}')),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
            if (active != null)
              ActiveRideBanner(
                booking: active,
                onOpen: () => context.go('/customer/ride/${active.id}'),
              ),
          ],
          panel: [
            Text('Where to?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Tap a field to search, or tap the map to drop a pin.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PlaceRow(
              label: 'Pickup',
              text: pickup?.address ?? 'Search pickup',
              color: brandGreen,
              selected: draft.editing == DraftField.pickup,
              onTap: () => _search(DraftField.pickup),
            ),
            const SizedBox(height: 8),
            PlaceRow(
              label: 'Drop-off',
              text: destination?.address ?? 'Where are you going?',
              color: brandPurple,
              selected: draft.editing == DraftField.destination,
              onTap: () => _search(DraftField.destination),
            ),
            const SizedBox(height: 16),
            if (km != null) ...[
              FareRow(
                label: routing ? 'Finding route…' : formatDistance(km * 1000),
                fare: fareFor(km),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: km == null || routing || active != null || _booking ? null : _book,
              child: Text(_booking ? 'Booking…' : 'Book ride'),
            ),
          ],
        ),
      ),
    );
  }
}
