import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/location.dart';
import '../../core/place_search.dart';
import '../booking/booking.dart';

/// What the user picked on the search screen.
sealed class PlaceChoice {
  const PlaceChoice();
}

class PickedPlace extends PlaceChoice {
  const PickedPlace(this.place);
  final Place place;
}

class PickedCurrentLocation extends PlaceChoice {
  const PickedCurrentLocation();
}

class ChooseOnMap extends PlaceChoice {
  const ChooseOnMap();
}

class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, required this.title, this.near, this.initialText});

  final String title;
  final LatLng? near;
  final String? initialText;

  static Future<PlaceChoice?> open(
    BuildContext context, {
    required String title,
    LatLng? near,
    String? initialText,
  }) {
    return Navigator.of(context).push<PlaceChoice>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlaceSearchScreen(title: title, near: near, initialText: initialText),
      ),
    );
  }

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  late final _controller = TextEditingController(text: widget.initialText);
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final query = text.trim();
    _lastQuery = query;
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await ref.read(placeSearchServiceProvider).search(query, near: widget.near);
    // drop stale results
    if (!mounted || query != _lastQuery) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = _controller.text.trim().length >= 2;
    final canUseLocation = ref.watch(gpsPositionProvider).hasValue;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search for a place or address',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              children: [
                if (!hasQuery) ...[
                  if (canUseLocation)
                    ListTile(
                      leading: const Icon(Icons.my_location),
                      title: const Text('Use my current location'),
                      onTap: () => Navigator.pop(context, const PickedCurrentLocation()),
                    ),
                  ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: const Text('Choose on map'),
                    subtitle: const Text('Tap anywhere on the map to drop the pin'),
                    onTap: () => Navigator.pop(context, const ChooseOnMap()),
                  ),
                ],
                if (hasQuery && !_loading && _results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No places found. Try a different name, or choose on the map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                for (final r in _results)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: r.subtitle.isEmpty
                        ? null
                        : Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, PickedPlace(Place(r.address, r.latLng))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
