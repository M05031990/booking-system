# booking-system

A small ride booking demo in Flutter. Customers book a ride, nearby riders see
the request in real time, and once someone accepts, both sides watch each
other move on the map until drop-off. There's no payment; the point is the
live status flow.

**Stack:** Flutter (Android + iOS), Riverpod, Firebase Auth, Cloud Firestore
(snapshot listeners), Google Maps, geolocator, geoflutterfire_plus.

## How it works

- **Booking:** the customer searches for pickup and drop-off (or drops pins on
  the map). The fare is road distance × $1/km, fixed when the booking is
  created. Routes come from OSRM and place search from Photon, both free
  OpenStreetMap services, so no extra API keys.
- **Nearby riders:** riders who are online run a geohash query on
  `pickup.position` for `waiting` bookings within 1 km of them (2 km across).
  The query only re-centres after the rider moves about 150 m.
- **Accepting** runs in a transaction, so two riders can't take the same booking.
- **Live tracking:** each side writes its location to the booking at most
  every 3 s. Both apps listen to the same booking document.
- **Status flow:**

  ```
  waiting → going → pickup → toDestination → arrived
            accept   auto     "Start trip"     auto
  ```

  `pickup` and `arrived` are set automatically by the rider's phone once it is
  within 50 m of the target. A customer can cancel while the booking is still
  `waiting`.

Tunables are in [lib/core/constants.dart](lib/core/constants.dart).

## Setup

1. Create a Firebase project and enable **Email/Password** sign-in and
   **Cloud Firestore**.
2. Generate the Firebase config. This overwrites the placeholder
   `lib/firebase_options.dart`:

   ```bash
   flutterfire configure --platforms=android,ios
   ```

3. Deploy the rules and indexes:

   ```bash
   firebase deploy --only firestore
   ```

4. Get a Google Maps key with **Maps SDK for Android** and **Maps SDK for iOS**
   enabled, then:
   - Android: add `MAPS_API_KEY=...` to `android/local.properties`
   - iOS: copy `ios/Flutter/Secrets.xcconfig.example` to `Secrets.xcconfig`
     and fill in the key

   Both files are git-ignored.
5. Run `flutter run`.

## Trying it out

Use two devices or emulators: sign up as a customer on one and as a rider on
the other. Keep the pickup within 1 km of the rider.

You don't have to drive anywhere. In debug builds the rider's trip screen has
a **Simulate drive** button that moves the rider toward the pickup (and later
the drop-off) at about 90 km/h, so you can watch the automatic status changes
on both phones. The Android emulator's location *Routes* and Xcode's
*Simulate Location* also work.

## Layout

```
lib/
  app/          router (role-based redirects), theme
  core/         location, routing, place search, drive simulator, helpers
  features/
    auth/       sign in / sign up, user profile
    booking/    Booking model, Firestore repository
    customer/   booking form, ride tracking, customer location sync
    rider/      nearby requests, trip screen, trip automation
  widgets/      map + shared UI bits
```

Tests: `flutter test` (repository logic against `fake_cloud_firestore`).
