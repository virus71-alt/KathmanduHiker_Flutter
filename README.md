# Kathmandu Hiker — Flutter port

A cross-platform (iOS + Android) port of the Android app located in `../app/`. It reuses the **same Firebase project / Firestore schema** so both apps work against one backend.

## Folder layout

```
flutter_app/
├── lib/
│   ├── main.dart            # Firebase init + run app
│   ├── app.dart             # AuthGate + RootShell (bottom nav + routing)
│   ├── theme/app_theme.dart # Light-only Material 3 theme (no dark mode)
│   ├── utils/
│   │   ├── feedback.dart        # Haptics + system click sound
│   │   ├── ranking_manager.dart # XP rules (matches Kotlin RankingManager)
│   │   └── image_utils.dart     # JPEG compression for uploads
│   ├── models/              # Trail, HikeEvent, Comment, TrailPhoto, ...
│   ├── services/
│   │   ├── weather_service.dart       # OpenWeather API
│   │   └── hike_tracking_service.dart  # GPS distance tracker
│   └── screens/             # All 14 screens
└── pubspec.yaml
```

## One-time setup

You need Flutter ≥ 3.22 installed. Run from the `flutter_app/` directory.

### 1. Bootstrap native platform folders

This Flutter project ships only the `lib/` source. The `android/` and `ios/` platform folders should be generated locally so Flutter's tool versions match your machine:

```bash
flutter create --platforms=android,ios --org com.example .
flutter pub get
```

### 2. Wire Firebase

Install the FlutterFire CLI and connect to your existing Firebase project (the same one used by the Android app):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and drops the platform configs (`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`).

Then update `lib/main.dart` to use the generated options:

```dart
import 'firebase_options.dart';
// ...
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

### 3. Google Maps API key

**Android** — open `android/app/src/main/AndroidManifest.xml` and add inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_MAPS_API_KEY" />
```

**iOS** — open `ios/Runner/AppDelegate.swift` and add:

```swift
import GoogleMaps
// inside application(_:didFinishLaunchingWithOptions:)
GMSServices.provideAPIKey("YOUR_MAPS_API_KEY")
```

### 4. Permissions

**Android** — add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
```

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Track your hikes with GPS</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Track your hikes even when the app is in the background</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Upload trail photos</string>
<key>NSCameraUsageDescription</key>
<string>Take trail photos</string>
```

### 5. Optional siren asset

To enable the loud-siren button on the SOS sheet, drop an `assets/siren.mp3` file and register it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/siren.mp3
```

If the asset is missing, the SOS sheet still works — the siren button just shows a friendly snackbar.

## Run

```bash
flutter run                # use the connected device or simulator
flutter run -d ios
flutter run -d android
```

## What's covered

✅ Auth (login / signup with profile pic + DOB / password reset)
✅ Home — trail feed, search, difficulty filter, map view, SOS sheet
✅ Trail Detail — image carousel, GPS hike tracking, reviews, comments, group events, photo gallery, weather, friend invite, share
✅ Add Trail — guided multi-choice "Best season / Crowd / Hidden spot / Difficult part" questions
✅ Social — swipeable PageView between Community / Chats / Requests
✅ Chat — real-time messages
✅ Profile — edit profile, picture, clickable Achievements card
✅ Achievements — 13-level roadmap with locked/unlocked states
✅ Notifications — list with read/unread + clear all
✅ Admin — approve / reject pending trails
✅ Public Profile — view another user's profile
✅ Leaderboard — top 50 by XP

## Backend compatibility

Firestore collections + field names match the Android app exactly:

```
trails/{id}      ← name, difficulty, transportRoute, fare, food, description,
                   imageUrls, userRating, ratingScore, travelMode, busAccess,
                   duration, facilities, latitude, longitude, isApproved,
                   authorId, authorName
   .../reviews/{id}
   .../comments/{id}
   .../gallery/{id}

users/{uid}      ← displayName, dob, location, phone, insta, showPhone,
                   bio, profilePic, role, totalXP, hikerLevel,
                   favoriteTrails, friends, sentRequests, receivedRequests,
                   unreadChatIds
   .../notifications/{id}

events/{id}      ← trailId, trailName, creatorId, creatorName, dateText,
                   maxHikers, attendees, attendeeDetails, timestamp

chats/{chatId}/messages/{id}
hikes/{id}       ← userId, trailId, distanceKm, timestamp
activities/{id}  ← userId, userName, userPic, actionType, targetName,
                   targetId, timestamp
```

`chatId` is `${smallerUid}_${largerUid}`.

## Background GPS on Android

The included `HikeTrackingService` runs `Geolocator.getPositionStream` while the app is in the foreground. For locked-screen tracking, wrap the stream in `flutter_background_service` (already in `pubspec.yaml`) — see [the package docs](https://pub.dev/packages/flutter_background_service) for a 30-line foreground-service config.

## Differences vs the Android app

* Light theme only — dark mode was removed in both apps.
* The Android in-app foreground service notification is replaced by `flutter_local_notifications` (you'll see a hike-in-progress notification once you configure the channel — see `flutter_local_notifications`'s README for the iOS DARWIN setup).
* Emojis replaced inline material icons in the redesigned UI; behaviour and data flow are otherwise identical.
