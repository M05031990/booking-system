import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants.dart';
import '../../core/location.dart';
import '../../core/throttle.dart';
import '../booking/booking.dart';
import '../booking/booking_repository.dart';

enum DraftField { pickup, destination }

class BookingDraft {
  const BookingDraft({this.pickup, this.destination, this.editing = DraftField.pickup});

  final Place? pickup;
  final Place? destination;
  final DraftField editing;

  bool get isComplete => pickup != null && destination != null;

  Place? operator [](DraftField field) => field == DraftField.pickup ? pickup : destination;

  BookingDraft copyWith({Place? pickup, Place? destination, DraftField? editing}) => BookingDraft(
    pickup: pickup ?? this.pickup,
    destination: destination ?? this.destination,
    editing: editing ?? this.editing,
  );
}

class BookingDraftNotifier extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void edit(DraftField field) => state = state.copyWith(editing: field);

  void setPlace(Place place, DraftField field) {
    state = field == DraftField.pickup
        ? state.copyWith(pickup: place)
        : state.copyWith(destination: place);
    // drop-off is usually next
    if (field == DraftField.pickup && state.destination == null) {
      edit(DraftField.destination);
    }
  }

  /// Drops a pin now and fills in the address once the geocoder answers.
  Future<void> setPoint(LatLng point, {DraftField? field}) async {
    final target = field ?? state.editing;
    setPlace(Place('Finding address…', point), target);

    final address = await ref.read(locationServiceProvider).addressOf(point);
    if (state[target]?.latLng == point) setPlace(Place(address, point), target);
  }

  void clearDestination() => state = BookingDraft(pickup: state.pickup);
}

final bookingDraftProvider = NotifierProvider.autoDispose<BookingDraftNotifier, BookingDraft>(
  BookingDraftNotifier.new,
);

/// Shares the customer's location on the booking once a rider is assigned.
final customerLocationSyncProvider = Provider.autoDispose.family<void, String>((ref, bookingId) {
  final repo = ref.watch(bookingRepositoryProvider);
  final throttle = Throttle(locationWriteInterval);

  void push({bool force = false}) {
    final here = ref.read(positionProvider).value;
    final booking = ref.read(bookingProvider(bookingId)).value;
    if (here == null || booking == null) return;
    if (booking.status == BookingStatus.waiting || !booking.status.isActive) return;
    if (throttle(force: force)) repo.shareLocation(bookingId, here, rider: false);
  }

  // push once on status change, even if we're not moving
  ref.listen(
    bookingProvider(bookingId).select((b) => b.value?.status),
    (_, _) => push(force: true),
  );
  ref.listen(positionProvider, (_, _) => push(), fireImmediately: true);
});
