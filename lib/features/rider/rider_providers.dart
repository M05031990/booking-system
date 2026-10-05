import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../core/location.dart';
import '../../core/throttle.dart';
import '../booking/booking.dart';
import '../booking/booking_repository.dart';

class RiderOnline extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final riderOnlineProvider = NotifierProvider<RiderOnline, bool>(RiderOnline.new);

/// Geo query centre, only moves after ~150 m.
class QueryCenter extends Notifier<LatLng?> {
  static const _moveThreshold = 150.0;

  @override
  LatLng? build() {
    ref.listen(positionProvider, (_, next) {
      final here = next.value;
      if (here == null) return;
      final center = state;
      if (center == null || metersBetween(center, here) > _moveThreshold) state = here;
    });
    return ref.read(positionProvider).value;
  }
}

final queryCenterProvider = NotifierProvider<QueryCenter, LatLng?>(QueryCenter.new);

final nearbyBookingsProvider = StreamProvider.autoDispose<List<Booking>>((ref) {
  if (!ref.watch(riderOnlineProvider)) return Stream.value(const []);
  final center = ref.watch(queryCenterProvider);
  if (center == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).watchWaitingNear(center, riderSearchRadiusKm);
});

/// Shares rider location and auto-advances status near pickup and drop-off.
final tripAutomationProvider = Provider.autoDispose.family<void, String>((ref, bookingId) {
  final repo = ref.watch(bookingRepositoryProvider);
  final throttle = Throttle(locationWriteInterval);
  var advancing = false;

  ref.listen(bookingProvider(bookingId), (_, _) {}); // keep it alive

  ref.listen(positionProvider, (_, next) async {
    final here = next.value;
    final booking = ref.read(bookingProvider(bookingId)).value;
    if (here == null || booking == null || !booking.status.isActive) return;

    if (throttle()) repo.shareLocation(bookingId, here, rider: true);

    bool within(LatLng p) => metersBetween(here, p) <= arrivalRadiusMeters;
    final nextStatus = switch (booking.status) {
      BookingStatus.going when within(booking.pickup.latLng) => BookingStatus.pickup,
      BookingStatus.toDestination when within(booking.destination.latLng) => BookingStatus.arrived,
      _ => null,
    };
    if (nextStatus == null || advancing) return;

    advancing = true;
    try {
      await repo.advance(bookingId, from: booking.status, to: nextStatus, riderAt: here);
    } catch (e) {
      debugPrint('auto status update failed: $e');
    } finally {
      advancing = false;
    }
  }, fireImmediately: true);
});
