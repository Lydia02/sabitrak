# SabiTrak (SabiTrak)

## Description
SabiTrak is a mobile food inventory management application designed for African student and young professional contexts. It supports barcode scanning where available, manual item entry, expiry date tracking with alerts, household collaboration, recipe recommendations, and waste logging to support food waste reduction.

## GitHub Repository Link
<PASTE YOUR GITHUB REPO LINK HERE>

## Features
- Inventory tracking (Pantry/Fridge/Freezer)
- Barcode scanning (fallback to manual entry)
- Expiry date tracking + notifications
- Update Pantry (used/wasted tracking)
- Recipe recommendations based on inventory and expiry urgency
- Household collaboration (create/join household, shared inventory)
- Analytics/insights (waste reduction summary)

---

## Environment Setup

### Prerequisites
- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode (for emulator/simulator)
- Firebase project (Authentication + Firestore/Realtime DB + Cloud Messaging)

### Clone & Install
```bash
git clone <https://github.com/Lydia02/sabitrak.git>
cd <sabitrak>
flutter pub get


Firebase Configuration

Create a Firebase project

Enable:

Firebase Authentication (Email/Password)

Firestore or Realtime Database (whichever you used)

Firebase Cloud Messaging (for expiry alerts)

Download config files:

Android: google-services.json → place in android/app/

iOS: GoogleService-Info.plist → place in ios/Runner/

Run:

flutterfire configure

Run the App
flutter run

Designs

Figma Mockups: <PASTE FIGMA LINK HERE>

App Screenshots: See /docs/screenshots/

System Architecture / Flow Diagrams: See /docs/diagrams/

Deployment Plan
Android (Google Play Store)

Update package name + app icon + version (pubspec.yaml)

Build release:

flutter build appbundle


Upload the .aab file to Google Play Console

Use staged rollout (recommended)

iOS (Apple App Store)

Configure bundle identifier + signing in Xcode

Build:

flutter build ios --release


Archive in Xcode → upload to App Store Connect

Submit for review

Backend / Firebase Deployment

Use Firebase rules for household data access control

Enable analytics (optional) with explicit opt-in

Configure FCM for expiry alerts