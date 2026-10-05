import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../widgets/location_gate.dart';
import '../../widgets/ride_map.dart';
import '../../widgets/ride_widgets.dart';
import '../auth/auth_repository.dart';
import '../booking/booking.dart';
import '../booking/booking_repository.dart';
import 'rider_providers.dart';

class RiderHomeScreen extends ConsumerStatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  ConsumerState<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends ConsumerState<RiderHomeScreen> {
  String? _accepting;

  Future<void> _accept(Booking booking, LatLng here) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _accepting = booking.id);
    try {
      await ref.read(bookingRepositoryProvider).accept(booking.id, user, here);
      if (mounted) context.go('/rider/trip/${booking.id}');
    } on BookingUnavailable {
      _toast('Someone else already took that one.');
    } catch (e) {
      _toast('Could not accept: $e');
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _signOut() {
    ref.read(riderOnlineProvider.notifier).set(false);
    ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final online = ref.watch(riderOnlineProvider);
    final active = ref.watch(activeBookingProvider).value;
    final requests = ref.watch(nearbyBookingsProvider).value ?? const <Booking>[];
    final theme = Theme.of(context);

    return LocationGate(
      builder: (context, here) => Scaffold(
        body: MapLayout(
          map: RideMap(
            center: here,
            showMyLocation: true,
            radiusMeters: online ? riderSearchRadiusKm * 1000 : null,
            fitKey: online,
            pins: [
              for (final b in requests) MapPin.pickup(b.pickup.latLng, title: formatMoney(b.fare)),
            ],
          ),
          overlay: [
            MapTopBar(
              children: [
                const SizedBox(width: 8),
                Expanded(child: Text(user?.name ?? '')),
                Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: online ? brandGreen : theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(value: online, onChanged: ref.read(riderOnlineProvider.notifier).set),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: _signOut,
                ),
              ],
            ),
            if (active != null)
              ActiveRideBanner(
                booking: active,
                onOpen: () => context.go('/rider/trip/${active.id}'),
              ),
          ],
          panel: [
            Text('Nearby requests', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: _requestList(here, canAccept: active == null && _accepting == null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestList(LatLng here, {required bool canAccept}) {
    if (!ref.watch(riderOnlineProvider)) {
      return const _Hint('Go online to see ride requests within 1 km of you.');
    }
    final nearby = ref.watch(nearbyBookingsProvider);
    if (nearby.hasError) return _Hint('Could not load requests: ${nearby.error}');
    if (!nearby.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final requests = nearby.requireValue;
    if (requests.isEmpty) {
      return const _Hint('No requests nearby yet. New ones show up here automatically.');
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: requests.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = requests[i];
        return _RequestTile(
          booking: b,
          away: metersBetween(here, b.pickup.latLng),
          busy: _accepting == b.id,
          onAccept: canAccept ? () => _accept(b, here) : null,
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.booking,
    required this.away,
    required this.busy,
    required this.onAccept,
  });

  final Booking booking;
  final double away;
  final bool busy;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.pickup.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('to ${b.destination.address}', maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${formatDistance(away)} away · ${b.distanceKm.toStringAsFixed(1)} km trip',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(b.fare),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(84, 36),
                  backgroundColor: brandPurple,
                ),
                onPressed: onAccept,
                child: Text(busy ? '…' : 'Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
    );
  }
}
