import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_repository.dart';
import '../features/auth/auth_screens.dart';
import '../features/customer/customer_home_screen.dart';
import '../features/customer/ride_screen.dart';
import '../features/rider/rider_home_screen.dart';
import '../features/rider/trip_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/signup';

      if (!auth.hasValue) return '/';
      if (auth.value == null) return onAuthPage ? null : '/login';

      final user = ref.read(currentUserProvider).value;
      if (user == null) return '/';

      final home = user.isRider ? '/rider' : '/customer';
      return loc.startsWith(home) ? null : home;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: '/customer',
        builder: (_, _) => const CustomerHomeScreen(),
        routes: [
          GoRoute(
            path: 'ride/:id',
            builder: (_, s) => RideScreen(bookingId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/rider',
        builder: (_, _) => const RiderHomeScreen(),
        routes: [
          GoRoute(
            path: 'trip/:id',
            builder: (_, s) => TripScreen(bookingId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});
