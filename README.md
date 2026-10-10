# Infinite Seva – Flutter app

Mobile version of the Infinite Seva web app (Node/Express/MySQL API + React). It talks to the same REST API.

## Setup

1. Install Flutter (https://docs.flutter.dev/get-started/install).
2. In this folder, generate the platform folders (keeps existing `lib/` and `pubspec.yaml`):

   ```
   flutter create --org com.infiniteseva --project-name infinite_seva .
   ```
3. Copy these images from the web app's `public/` or `src/assets` into `assets/images/`:
   `InfiniteSeva-Logo.png`, `RiceHRLogo.png`, `vel.png` (the app still runs without them).
4. Permissions

   **Android** – `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` (above `<application>`):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```
   If the build complains about SDK versions, set `minSdk = 23` in `android/app/build.gradle(.kts)`.

   **iOS** – `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key><string>Take a photo of your parayanam</string>
   <key>NSPhotoLibraryUsageDescription</key><string>Choose a photo of your parayanam</string>
   <key>NSLocationWhenInUseUsageDescription</key><string>Record where the parayanam was done</string>
   ```
5. Run:
   ```
   flutter pub get
   flutter run
   ```

## API address

Edit `lib/config.dart`. Default is `https://reactapi.ricehr.com/api`.
For a local backend use `http://10.0.2.2:3000/api` (Android emulator) or `http://<your-LAN-IP>:3000/api` (real phone; plain http also needs cleartext enabled on Android: `android:usesCleartextTraffic="true"`).

## Features

Home with live progress ring + sponsor ads · mobile + password login/signup · participate flow (individual/team, photo, location, timer, idempotent submit) · dashboard with history (swipe/list/grid) · admin ads management (ADMIN, SUPER_ADMIN, CAMPAIGN_MANAGER) · English/Tamil toggle.
