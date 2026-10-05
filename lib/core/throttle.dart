/// Lets an action through at most once per [interval].
class Throttle {
  Throttle(this.interval);

  final Duration interval;
  DateTime _last = DateTime(0);

  bool call({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_last) < interval) return false;
    _last = now;
    return true;
  }
}
