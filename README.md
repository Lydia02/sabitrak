# SabiTrak

**Smart tracking. Less waste.**

SabiTrak is a mobile food inventory management app designed for African students and young professionals. It helps reduce food waste through barcode scanning, expiry tracking, recipe recommendations based on what you have, and household collaboration.

**Design Mockups:** [View on Uizard](https://app.uizard.io/p/4f316171)

**Demo Video:** [Watch Initial Product Demo](https://drive.google.com/file/d/1fEGalPJlz8gyPdhFqUWo3lqrl8H0xaZE/view?usp=sharing)

---

## Features

- **Inventory Management** - Track items across Pantry, Fridge, and Freezer with color-coded expiry indicators
- **Barcode Scanning** - Scan products to auto-fill details via Open Food Facts API, with manual entry fallback
- **Expiry Date Tracking** - Get alerts for items expiring soon, with OCR capture for expiry dates
- **Recipe Recommendations** - Get recipe suggestions based on current inventory, prioritizing expiring items
- **Household Collaboration** - Create or join a household with invite codes, share inventory with family/roommates
- **Update Pantry** - Log used and wasted items after cooking to keep inventory accurate
- **Insights & Analytics** - View waste reduction summaries and savings

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | BLoC |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Messaging) |
| Barcode API | Open Food Facts |
| Local Storage | Hive, SharedPreferences |
| Navigation | GoRouter |

---

## Getting Started

### Prerequisites

- Flutter SDK (stable) - [Install Flutter](https://docs.flutter.dev/get-started/install)
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode (for emulator/simulator)
- Firebase CLI - `npm install -g firebase-tools`
- FlutterFire CLI - `dart pub global activate flutterfire_cli`

### Clone & Install

```bash
git clone https://github.com/Lydia02/sabitrak.git
cd sabitrak
flutter pub get
```

### Firebase Configuration

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable the following services:
   - **Authentication** (Email/Password)
   - **Cloud Firestore**
   - **Firebase Storage**
   - **Cloud Messaging** (for expiry alerts)
3. Configure FlutterFire:
   ```bash
   firebase login
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` automatically.

### Run the App

```bash
flutter run
```

---

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── config/
│   ├── routes/          # GoRouter configuration
│   └── theme/           # App theme, colors, typography
├── core/
│   ├── constants/
│   ├── utils/
│   └── errors/
├── data/
│   ├── models/          # FoodItem, Recipe, Household
│   ├── repositories/    # Data access layer
│   └── datasources/     # Local (Hive) & Remote (Firebase)
├── presentation/
│   ├── blocs/           # BLoC state management
│   ├── screens/         # App screens
│   └── widgets/         # Reusable UI components
└── services/            # Firebase, Barcode, Notifications
```

---

## App Flow

1. **Splash** - Animated logo reveal
2. **Welcome** - Create Account / Log In
3. **Registration** - Name, profile details, password, email verification
4. **Household Setup** - Create household, join with invite code, or go solo
5. **Dashboard** - Overview with expiry alerts, quick actions, smart suggestions
6. **Inventory** - Browse items by category (Pantry/Fridge/Freezer/Expiring Soon)
7. **Add Item** - Scan barcode, capture expiry with camera, or add manually
8. **Recipes** - Suggestions based on inventory, filtered by diet and expiry urgency
9. **Cooking Mode** - Step-by-step instructions, then update pantry with used/wasted items
10. **Profile** - Household management, notifications, data sync, analytics

---

## Deployment

### Android (Google Play Store)

```bash
flutter build appbundle
```

Upload the `.aab` file to Google Play Console.

### iOS (Apple App Store)

```bash
flutter build ios --release
```

Archive in Xcode and upload to App Store Connect.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
