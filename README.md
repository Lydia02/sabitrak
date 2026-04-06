# SabiTrak

**Smart food tracking for African households. Less waste, better meals.**

SabiTrak is an Android app that helps students and young professionals manage their food pantry — tracking expiry dates, suggesting recipes, and enabling household collaboration.

---

## Hosted Solution

| Resource | Link |
|----------|------|
| **Download APK** | [sabitrak-v1.apk](https://drive.google.com/file/d/1EeU0RCDaUSxPGYvpORXUkOTlv6AMvb51/view?usp=sharing) |
| **Demo Video** | [Watch on Google Drive](https://drive.google.com/file/d/1ulhGcUdO65bLNxI_zObQT-PHgIYizrK-/view?usp=sharing) |
| **Design Mockups** | [View on Uizard](https://app.uizard.io/p/4f316171) |

> **Install the APK:** Download → Settings → Security → Enable *Install unknown apps* → Open the `.apk` file → Install.

---

## Features

- **Inventory Tracking** — Add ingredients, leftovers, and packaged products with color-coded expiry alerts
- **Barcode Scanning** — Auto-fill item details via Open Food Facts API and ML Kit
- **Expiry Date OCR** — Read expiry dates from product labels using the device camera
- **Recipe Recommendations** — Suggests recipes that use items expiring soon, with African cuisine support
- **Household Collaboration** — Create or join a shared pantry using a 6-digit invite code
- **Waste Analytics** — Waste reduction ring, savings tracker, and top wasted items chart
- **Offline Mode** — Works without internet using Hive local cache; syncs when reconnected
- **Push Notifications** — Expiry and low-stock alerts via Firebase Cloud Messaging

---

## Prerequisites

Before running the project, make sure you have the following installed:

| Tool | Version | Download |
|------|---------|----------|
| Flutter SDK | 3.29.2 (stable) | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ^3.7.2 (bundled with Flutter) | Included with Flutter |
| Android Studio | Latest | [developer.android.com/studio](https://developer.android.com/studio) |
| Java JDK | 17+ | [adoptium.net](https://adoptium.net) |
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |
| Firebase CLI | Latest | `npm install -g firebase-tools` |

Verify your Flutter installation:
```bash
flutter doctor
```
All checkmarks should be green before proceeding.

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/Lydia02/sabitrak.git
cd sabitrak
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Firebase setup

This project uses Firebase. The `google-services.json` file is required for Android.

1. Go to [Firebase Console](https://console.firebase.google.com) and open the `sabitrak-63dc2` project (or create your own)
2. Download `google-services.json` from Project Settings → Your Android app
3. Place it in `android/app/google-services.json`
4. The `lib/firebase_options.dart` file is already configured

### 4. Run the app

Connect an Android device or start an emulator, then:

```bash
flutter run
```

For a specific device:
```bash
flutter devices              # list available devices
flutter run -d <device-id>
```

---

## Build APK

```bash
# Debug build (recommended for testing)
flutter build apk --debug

# Release build (requires signing config)
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

---

## Install Dependencies Explained

All dependencies are declared in `pubspec.yaml`. Key packages:

| Package | Purpose |
|---------|---------|
| `flutter_bloc` `bloc` | BLoC state management pattern |
| `firebase_core` `firebase_auth` | Firebase authentication |
| `cloud_firestore` | Firestore database (real-time sync) |
| `firebase_messaging` | Push notifications (FCM) |
| `firebase_storage` | Profile image storage |
| `google_sign_in` | Google OAuth sign-in |
| `mobile_scanner` | Barcode scanning |
| `google_mlkit_text_recognition` | OCR for expiry date reading |
| `hive` `hive_flutter` | Offline local cache |
| `shared_preferences` | Lightweight key-value storage |
| `go_router` | Declarative navigation |
| `http` `dio` | HTTP requests (Open Food Facts API) |
| `connectivity_plus` | Detect online/offline status |
| `image_picker` | Camera and gallery access |
| `intl` | Date formatting and localisation |
| `equatable` | Value equality for BLoC states |

Install all at once:
```bash
flutter pub get
```

---

## Running Tests

103 automated tests across four suites:

```bash
# Run all tests
flutter test

# Run a specific suite
flutter test test/unit/
flutter test test/validation/
flutter test test/integration/
flutter test test/acceptance/
```

| Suite | What it covers |
|-------|---------------|
| Unit | FoodItem model, duplicate detection, food intelligence service |
| Validation | Email, password, quantity, and date input rules |
| Integration | Auth flows and inventory repository with mocked Firebase |
| Acceptance | Core user journeys (AC-01 to AC-06) |

---

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── config/
│   └── theme/                  # Light and dark theme
├── data/
│   ├── models/                 # FoodItem, UserModel, HouseholdModel, Recipe
│   └── repositories/           # InventoryRepository, AuthRepository
├── presentation/
│   ├── screens/                # All app screens (auth, inventory, recipe, analytics, household)
│   └── blocs/                  # BLoC classes (events, states, bloc)
└── services/                   # Firebase, Notification, FoodIntelligence, Recipe services

functions/                      # Firebase Cloud Functions (Node.js)
test/
├── unit/
├── validation/
├── integration/
└── acceptance/
```

---

## CI/CD

GitHub Actions runs automatically on every push and pull request to `master`:

1. Install Flutter 3.29.2
2. `flutter pub get`
3. `dart format --set-exit-if-changed .` — enforce formatting
4. `flutter analyze` — static analysis
5. `flutter test` — all 103 tests

See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) for the full configuration.

---

## Author

**Lydia Ojoawo** — [github.com/Lydia02](https://github.com/Lydia02)
