import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo.dart';
import 'routing.dart';

/// Fake GPS for demos, follows the road route to the current target.
class DriveSimulator extends Notifier<LatLng?> {
  static const _tick = Duration(seconds: 1);
  static const _metersPerTick = 25.0; // ~90 km/h

  Timer? _timer;
  LatLng? _target;
  List<LatLng> _path = [];

  @override
  LatLng? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  bool get isRunning => _timer != null;

  void start(LatLng from, LatLng? Function() target) {
    _timer?.cancel();
    _target = null;
    state = from;
    _timer = Timer.periodic(_tick, (_) {
      final to = target();
      if (to == null) return stop();
      if (to != _target) _planRoute(to);
      state = _advance(state ?? from);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _target = null;
    _path = [];
    state = null;
  }

  void _planRoute(LatLng to) {
    _target = to;
    _path = [to];
    final from = state;
    if (from == null) return;
    ref.read(routingServiceProvider).route(from, to).then((road) {
      if (road == null || _target != to || !isRunning) return;
      _path = [...road.points, to]; // route stops at the nearest road
    });
  }

  LatLng _advance(LatLng from) {
    var here = from;
    var left = _metersPerTick;
    while (left > 0 && _path.isNotEmpty) {
      final next = _path.first;
      final d = metersBetween(here, next);
      if (d > left) return stepTowards(here, next, left);
      here = next;
      left -= d;
      _path.removeAt(0);
    }
    return here;
  }
}

final driveSimulatorProvider = NotifierProvider<DriveSimulator, LatLng?>(DriveSimulator.new);
