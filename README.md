# SabiTrak

**Smart tracking. Less waste.**

SabiTrak is a mobile food inventory management app designed for African students and young professionals. It helps reduce food waste through barcode scanning, expiry tracking, recipe recommendations based on what you have, and household collaboration.

**Design Mockups:** [View on Uizard](https://app.uizard.io/p/4f316171)

**Demo Video:** [Watch on Google Drive](https://drive.google.com/file/d/1A36YG-tz08lAD4LfKe_sV9lpNG_kJiCq/view?usp=drive_link)

**Download APK:** [SabiTrak-release.apk (Google Drive)](https://drive.google.com/file/d/1CjCq2bJPOt4qP2vWJrXwsTWxQY4K8R0r/view?usp=sharing)

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

## Testing

### One-time setup (generates mock files)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Run all tests at once

```bash
flutter test test/unit/ test/integration/ test/validation/ test/acceptance/
```

### Run a specific category

```bash
flutter test test/unit/
flutter test test/integration/
flutter test test/validation/
flutter test test/acceptance/
```

### Run a single file


```bash
flutter test test/unit/food_item_model_test.dart
```

### Run with verbose output (see each test name)

```bash
flutter test test/unit/ --reporter=expanded
```

### Run a specific test by name

```bash
flutter test test/unit/food_item_model_test.dart --name "isExpired"
```

### Test coverage

| Category | File | What it covers |
|----------|------|----------------|
| Unit | `test/unit/food_item_model_test.dart` | FoodItem properties, serialisation, round-trips |
| Unit | `test/unit/inventory_repository_test.dart` | Duplicate detection, filter logic |
| Unit | `test/unit/auth_bloc_test.dart` | Registration, sign-in, Google, forgot-password flows |
| Integration | `test/integration/auth_flow_integration_test.dart` | Full multi-step auth flows with mocked services |
| Validation | `test/validation/input_validation_test.dart` | Password rules, email format, quantity/date constraints |
| Acceptance | `test/acceptance/acceptance_test_report.dart` | AC-01–AC-06 core user journey acceptance criteria |

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

## Use Case Implementation (Input → Output Mapping)

This section maps each functional use case to its implementation, showing the inputs the system accepts and the outputs it produces.

---

### UC-01: User Registration

| | Detail |
|---|---|
| **Actor** | New user |
| **Input** | Full name, email address, password (min 8 chars, uppercase, number, special char), occupation, country |
| **Process** | Firebase Authentication creates account → email verification sent → user profile written to Firestore `users` collection |
| **Output** | Verified account created; user redirected to Household Setup screen |
| **Implemented in** | `lib/presentation/screens/auth/signup_screen.dart`, `lib/presentation/blocs/auth/auth_bloc.dart` |

---

### UC-02: User Login

| | Detail |
|---|---|
| **Actor** | Registered user |
| **Input** | Email + password **or** Google account selection |
| **Process** | Firebase Auth validates credentials → fetches user profile from Firestore → checks household membership |
| **Output** | User lands on Dashboard with their household inventory loaded |
| **Implemented in** | `lib/presentation/screens/auth/signin_screen.dart`, `lib/data/repositories/auth_repository.dart` |

---

### UC-03: Add Food Item (Manual Entry)

| | Detail |
|---|---|
| **Actor** | Authenticated user |
| **Input** | Item name, quantity, unit (kg/g/L/cups/pcs/bunches), storage location (Pantry/Fridge/Freezer), item type (Ingredient/Leftover/Product), expiry date |
| **Process** | Duplicate detection checks existing items by name → if duplicate found, shows merge/separate dialog → item written to Firestore `food_items` collection under the user's household |
| **Output** | Item appears in Inventory list under correct storage tab; expiry indicator colour-coded (green/orange/red) |
| **Implemented in** | `lib/presentation/screens/inventory/manual_entry_screen.dart`, `lib/data/repositories/inventory_repository.dart` |

---

### UC-04: Barcode Scanning

| | Detail |
|---|---|
| **Actor** | Authenticated user |
| **Input** | Product barcode (camera capture) |
| **Process** | ML Kit decodes barcode → queries Firestore community DB → falls back to Open Food Facts API → Go-UPC → UPCitemdb → GS1 prefix detection identifies product origin |
| **Output** | Manual entry form pre-filled with product name, category, and brand; user confirms and saves |
| **Implemented in** | `lib/presentation/screens/inventory/barcode_scanner_screen.dart` |

---

### UC-05: Expiry Date OCR

| | Detail |
|---|---|
| **Actor** | Authenticated user |
| **Input** | Product label image (camera capture) |
| **Process** | Google ML Kit Text Recognition extracts text from image → regex pattern matches date formats (DD/MM/YYYY, MM/YYYY, etc.) |
| **Output** | Manual entry form pre-filled with extracted expiry date; user confirms |
| **Implemented in** | `lib/presentation/screens/inventory/label_scanner_screen.dart` |

---

### UC-06: Expiry Alerts & Notifications

| | Detail |
|---|---|
| **Actor** | System (automated) + user |
| **Input** | Firestore food items with expiry dates |
| **Process** | Firebase Cloud Function (`functions/index.js`) runs scheduled check → identifies items expiring within 3 days → sends FCM push notification to device token |
| **Output** | Push notification delivered to user's device; dashboard expiry ring updates colour (green → orange → red as expiry approaches) |
| **Implemented in** | `lib/services/notification_service.dart`, `functions/index.js` |

---

### UC-07: Recipe Recommendations

| | Detail |
|---|---|
| **Actor** | Authenticated user |
| **Input** | Current pantry inventory (item names, quantities, expiry dates) |
| **Process** | Items passed to African Food Database (Railway) → recipes ranked by: expiry urgency weight, ingredient match %, African origin flag, cooking simplicity score → Gemini API used for contextual suggestions → TheMealDB as fallback |
| **Output** | Ranked list of recipe cards showing match percentage, missing ingredients, and cook time |
| **Implemented in** | `lib/services/recipe_service.dart`, `lib/presentation/screens/recipe/recipe_detail_screen.dart` |

---

### UC-08: Use Recipe (Pantry Deduction)

| | Detail |
|---|---|
| **Actor** | Authenticated user |
| **Input** | User confirms "I Used This Recipe" on a recipe detail screen |
| **Process** | Recipe ingredients matched against pantry items by name and unit → unit conversion applied where units differ (e.g. recipe in cups, pantry in kg) → quantities deducted from Firestore; items reaching 0 removed |
| **Output** | Pantry quantities updated; confirmation dialog shows which items were deducted and by how much |
| **Implemented in** | `lib/presentation/screens/recipe/recipe_detail_screen.dart` |

---

### UC-09: Household Collaboration

| | Detail |
|---|---|
| **Actor** | Household admin + members |
| **Input** | Household name (create) **or** 6-character invite code (join) |
| **Process** | Admin creates household → unique invite code generated and stored in Firestore `households` collection → member joins using code → all members share the same `food_items` subcollection |
| **Output** | Shared pantry visible to all household members; admin can view members, remove members, and transfer admin role |
| **Implemented in** | `lib/presentation/screens/household/`, `lib/presentation/screens/profile/members_screen.dart` |

---

### UC-10: Waste Tracking & Analytics

| | Detail |
|---|---|
| **Actor** | Authenticated user |
| **Input** | Items marked as "wasted" or "used" when logging a cooked meal |
| **Process** | Wasted items written to Firestore `waste_logs` collection with timestamp and estimated value → analytics aggregates data by week/month |
| **Output** | Dashboard waste ring shows % reduction; Analytics screen shows savings total, top wasted items bar chart, monthly trends |
| **Implemented in** | `lib/presentation/screens/analytics/analytics_screen.dart`, `lib/data/repositories/inventory_repository.dart` |

---

### UC-11: Offline Mode

| | Detail |
|---|---|
| **Actor** | Authenticated user with no internet |
| **Input** | App launch or navigation with no network connection |
| **Process** | Firestore offline persistence serves cached data → Hive local storage provides recipe and profile cache → connectivity check shown in UI |
| **Output** | Inventory and dashboard load from cache; write operations queued and synced when connection restored |
| **Implemented in** | `lib/main.dart` (Firestore offline settings), `lib/services/` |

---

## Testing Results

### Functionality Demonstrations

The following core functionalities were tested and demonstrated across different data values and device configurations:

| Feature | Test Strategy | Result |
|---------|--------------|--------|
| User Registration & Login | Unit + Integration tests | Pass — email/password and Google Sign-In verified |
| Inventory Management | Unit tests (FoodItem model, duplicate detection) | Pass — add, edit, delete, filter by storage type |
| Barcode Scanning | Manual device testing (Android physical device) | Pass — Open Food Facts API returns product details |
| Expiry Date OCR | Manual device testing with real product labels | Pass — ML Kit extracts dates from camera capture |
| Recipe Recommendations | Manual testing with varied inventory data | Pass — Gemini API returns African-cuisine recipes based on pantry |
| Waste Tracking | Manual testing with multiple food item types | Pass — wasted items logged and reflected in analytics |
| Household Collaboration | Manual testing with two accounts | Pass — invite codes, member management, shared pantry |
| Push Notifications | FCM integration test on physical Android device | Pass — expiry alerts delivered within expected window |
| Offline Caching | Manual network toggle test | Pass — inventory loads from cache when offline |
| Dark Mode | Manual UI testing | Pass — theme persists across sessions |

---

### Screenshots from Test Results

#### Unit Test
!<img width="1217" height="887" alt="image" src="https://github.com/user-attachments/assets/3aab2f1a-317f-4b81-907a-ba9d58d78ebc" />


#### Integration Test
<img width="756" height="261" alt="image" src="https://github.com/user-attachments/assets/5d616167-8e16-4239-a708-d7088893b828" />


#### Validation Test
<img width="598" height="437" alt="image" src="https://github.com/user-attachments/assets/6fe41acc-4803-4d95-888e-85d75f8b168e" />


#### Acceptance Testing
<img width="1038" height="531" alt="image" src="https://github.com/user-attachments/assets/64c562a2-7eb5-49df-8143-0e6ae2ae2454" />


---

### Performance

- Tested on **Android 12 (physical device)** and **Android 13 emulator**
- App cold start: under 3 seconds
- Firestore reads: under 1 second on 4G connection
- Barcode scan to result: under 2 seconds
- OCR label capture to date extraction: under 3 seconds

### Test Suite

103 automated tests across unit, integration, validation, and acceptance categories — all passing.

---

## Analysis

### Objectives Achieved

The project successfully delivered all core objectives outlined in the project proposal:

- **Food waste reduction** — Users can track expiry dates, receive alerts, and log waste. The analytics screen quantifies savings and waste trends over time.
- **Inventory visibility** — Items are categorised by storage location and type (Ingredient / Leftover / Product), giving users a clear picture of what they own.
- **Recipe recommendations** — The Gemini API integration surfaces relevant recipes using available pantry items, prioritising items close to expiry.
- **Household collaboration** — Multi-user households with invite codes and admin controls were fully implemented.
- **Offline capability** — Local caching ensures the app remains usable without an internet connection.

### Objectives Partially Met

- **Barcode scanning coverage** — The Open Food Facts API does not cover all African food products. Users may need to fall back to manual entry for local brands.
- **AI recipe accuracy** — Gemini API suggestions are generally relevant but occasionally recommend items not in the pantry; prompt engineering improvements are ongoing.

### Objectives Not Met

- **iOS deployment** — The app was configured for iOS but not submitted to the App Store due to Apple Developer account requirements. The iOS build compiles successfully locally.

---

## Discussion

### Milestone Impact

The project was developed in iterative milestones — authentication, inventory, scanning, recipes, analytics, and household management. Each milestone built on the previous, allowing incremental testing and refinement. The BLoC state management pattern kept UI and business logic cleanly separated, which reduced bugs during integration.

The most impactful feature for the target user group (African students and young professionals) proved to be **expiry tracking with push notifications** — directly addressing the common problem of forgetting food until it spoils.

### Key Decisions

- **Firebase** was chosen over a custom backend for speed of development and built-in scalability.
- **Gemini API** was selected for recipe recommendations due to its awareness of African cuisine and food context.
- **BLoC** was used over Provider or Riverpod for its testability and clear separation of concerns, which paid off during the testing phase.

---

## Recommendations

1. **Expand barcode database** — Integrate a secondary API or allow community contributions for African food products not covered by Open Food Facts.
2. **iOS release** — Publish to the App Store once an Apple Developer account is available to reach a wider audience.
3. **Meal planning** — Add a weekly meal planner that automatically deducts ingredients from the pantry when a plan is confirmed.
4. **Sharing pantry insights** — Allow household members to view waste analytics together to encourage collective accountability.
5. **Multi-language support** — Add French and Swahili interfaces to better serve francophone and East African users.
6. **Smarter AI prompts** — Refine Gemini prompts to strictly filter recipes by available ingredients and preferred cuisine tags set in user profile.

---

## License

This project is licensed under the MIT License.
