# SabiTrak

**Smart tracking. Less waste.**

SabiTrak is a mobile food inventory management app designed for African students and young professionals. It helps reduce food waste through barcode scanning, expiry tracking, recipe recommendations based on what you have, and household collaboration.

**Design Mockups:** [View on Uizard](https://app.uizard.io/p/4f316171)

**Demo Video:** [Watch on Google Drive](https://drive.google.com/file/d/1fEGalPJlz8gyPdhFqUWo3lqrl8H0xaZE/view?usp=sharing)

**Download APK:** [SabiTrak-release.apk (Google Drive)](https://drive.google.com/file/d/16Zl4Nd6DMCeq6lhG8_hCUTgyRPDuwsdx/view?usp=sharing)

---

## Features

- **Smart Inventory Management** - Add items with type classification (Ingredient / Leftover / Product); duplicate detection with merge or separate options
- **Leftover Tracking** - Log cooked food with automatic 3-day expiry and link back to the raw ingredient for stock deduction
- **Barcode Scanning** - Scan products to auto-fill details via Open Food Facts API, with manual entry fallback
- **Expiry Date OCR** - Capture expiry dates from product labels using the device camera
- **Expiry Alerts** - Color-coded indicators (green / orange / red) with push notifications for items expiring soon
- **Recipe Recommendations** - AI-powered suggestions based on current inventory, prioritizing expiring items, with African cuisine support
- **Household Collaboration** - Create or join a household with invite codes; manage members; admin controls
- **Update Pantry** - Log used and wasted items after cooking to keep inventory accurate
- **Analytics & Insights** - Waste reduction ring, savings tracker, top wasted items bar chart
- **Dark Mode** - Full dark/light theme toggle, persisted across sessions
- **Push Notifications** - Expiry reminders and household activity alerts via Firebase Cloud Messaging

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State Management | BLoC |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Messaging) |
| Barcode Scanning | Open Food Facts API + ML Kit |
| OCR | Google ML Kit Text Recognition |
| Notifications | Firebase Cloud Messaging (FCM) |
| Local Storage | SharedPreferences |
| AI Recipes | Gemini API (Google) |

---

## How to Install (APK — Android)

> No setup required. Just download and install.

1. Download the APK from the link above
2. On your Android phone, go to **Settings → Security → Install Unknown Apps** and allow your browser
3. Open the downloaded `.apk` file and tap **Install**
4. Launch **SabiTrak** from your app drawer

---

## How to Run from Source

### Prerequisites

- Flutter SDK (stable channel) — [Install Flutter](https://docs.flutter.dev/get-started/install)
- Android Studio (for Android emulator) or a physical Android device with USB debugging enabled
- Node.js + Firebase CLI — `npm install -g firebase-tools`

### Step 1 — Clone the Repository

```bash
git clone https://github.com/Lydia02/sabitrak.git
cd sabitrak
```

### Step 2 — Install Dependencies

```bash
flutter pub get
```

### Step 3 — Firebase Setup

The `lib/firebase_options.dart` file is already configured for the project Firebase instance. No additional setup is needed to run the app.

If you want to connect to your own Firebase project:

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

### Step 4 — Run the App

**On a connected Android device or emulator:**

```bash
flutter run
```

**Build a release APK:**

```bash
flutter build apk --release
```

The APK will be output to:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
lib/
├── main.dart                        # App entry point, theme setup
├── firebase_options.dart            # Firebase config
├── config/
│   └── theme/                       # AppTheme (light + dark), ThemeNotifier
├── data/
│   ├── models/                      # FoodItem (with ItemType), UserModel, Recipe
│   └── repositories/                # InventoryRepository, AuthRepository
├── presentation/
│   ├── screens/
│   │   ├── dashboard/               # Home overview, expiry ring, quick actions
│   │   ├── inventory/               # Inventory list, manual entry, barcode/label scanner
│   │   ├── recipe/                  # Recipe screen, recipe detail with cooking mode
│   │   ├── analytics/               # Waste reduction ring, savings, bar charts
│   │   ├── profile/                 # Profile, change password, members, notifications
│   │   ├── auth/                    # Sign in, sign up, email verification, forgot password
│   │   └── household/               # Create, join, solo setup
│   └── blocs/                       # Auth BLoC
└── services/                        # FirebaseService, NotificationService, RecipeService
```

---

## App Flow

1. **Splash** → Animated logo reveal, auto-navigate to sign-in or dashboard
2. **Welcome** → Create Account / Log In / Continue with Google
3. **Registration** → Name, occupation, country, password, email verification
4. **Household Setup** → Create household, join with invite code, or go solo
5. **Dashboard** → Overview: expiry ring, expiring items, quick-add, smart suggestions
6. **Inventory** → Browse by storage (Pantry / Fridge / Freezer) and filter by status
7. **Add Item** → Choose: scan barcode, capture expiry label, add manually, or log leftover
8. **Manual Entry** → Item type (Ingredient / Leftover / Product), duplicate check, merge dialog
9. **Leftover Flow** → Auto 3-day expiry, link to raw ingredient, deduct from stock
10. **Recipes** → AI suggestions filtered by available ingredients and expiry urgency
11. **Analytics** → Waste ring, savings, top wasted items, monthly trends
12. **Profile** → Theme toggle (dark/light), change password, household members, notifications, FAQ

---

## Deployment

### Android APK (Current)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

APK is hosted on Google Drive for distribution.

### Android App Bundle (Google Play)

```bash
flutter build appbundle --release
```

Upload the `.aab` file to Google Play Console.

### Firebase Hosting (Web — optional)

```bash
flutter build web
firebase deploy --only hosting
```

---

## Related Files

- `firestore.indexes.json` — Composite index definitions for Firestore queries
- `firestore.rules` — Firestore security rules
- `android/app/proguard-rules.pro` — R8 minification rules for release builds
- `functions/index.js` — Firebase Cloud Functions for scheduled expiry notifications

---

## License

This project is licensed under the MIT License.
