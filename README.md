# SabiTrak

**Smart tracking. Less waste.**

SabiTrak is a mobile food inventory management app for African students and young professionals. It reduces food waste through barcode scanning, expiry tracking, recipe recommendations, and household collaboration.

---

## Live Demo & Download

| Resource | Link |
|----------|------|
| **Download APK** | [SabiTrak-release.apk](https://drive.google.com/file/d/1CjCq2bJPOt4qP2vWJrXwsTWxQY4K8R0r/view?usp=sharing) |
| **Demo Video** | [Watch on Google Drive](https://drive.google.com/file/d/1ulhGcUdO65bLNxI_zObQT-PHgIYizrK-/view?usp=sharing) |
| **Design Mockups** | [View on Uizard](https://app.uizard.io/p/4f316171) |

> **To install the APK:** Download → Settings → Security → Allow unknown apps → Open the `.apk` file → Install.

---

## Features

- **Inventory Management** — Add items by type (Ingredient / Leftover / Product) with duplicate detection
- **Barcode Scanning** — Auto-fill item details via Open Food Facts API + ML Kit
- **Expiry Date OCR** — Capture expiry dates from product labels using the camera
- **Expiry Alerts** — Color-coded indicators (green/orange/red) with push notifications
- **Recipe Recommendations** — AI-powered suggestions prioritising expiring items, with African cuisine support
- **Household Collaboration** — Create/join households with invite codes; shared pantry
- **Waste Analytics** — Waste reduction ring, savings tracker, top wasted items chart
- **Offline Mode** — Firestore persistence + Hive local caching
- **Dark Mode** — Full dark/light theme toggle

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State Management | BLoC |
| Backend | Firebase (Auth, Firestore, Cloud Messaging) |
| Barcode Scanning | Open Food Facts API + ML Kit |
| OCR | Google ML Kit Text Recognition |
| Local Storage | SharedPreferences + Hive |
| AI Recipes | African Food API |

---

## Run from Source

```bash
git clone https://github.com/Lydia02/sabitrak.git
cd sabitrak
flutter pub get
flutter run
```

**Build release APK:**
```bash
flutter build apk --release
```

**Prerequisites:** Flutter SDK (stable), Android Studio or physical Android device, Node.js + Firebase CLI.

---

## Project Structure

```
lib/
├── main.dart
├── config/theme/             # Light + dark theme
├── data/
│   ├── models/               # FoodItem, UserModel, Recipe
│   └── repositories/         # InventoryRepository, AuthRepository
├── presentation/
│   ├── screens/              # Dashboard, Inventory, Recipe, Analytics, Auth, Household, Profile
│   └── blocs/                # Auth BLoC
└── services/                 # Firebase, Notification, Recipe services
```

---

## Testing

103 automated tests — all passing.

```bash
flutter test test/unit/ test/integration/ test/validation/ test/acceptance/
```

| Category | What it covers |
|----------|---------------|
| Unit | FoodItem model, duplicate detection, auth flows |
| Integration | Multi-step auth flows with mocked services |
| Validation | Password rules, email format, quantity/date constraints |
| Acceptance | Core user journey acceptance criteria (AC-01–AC-06) |

**Performance:** Cold start < 3s · Firestore reads < 1s on 4G · Barcode scan < 2s · OCR < 3s

---

## License

MIT License

## Author

**Lydia Ojoawo** — [GitHub](https://github.com/Lydia02)
