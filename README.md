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

> **Install:** Download the APK → Settings → Security → Enable *Install unknown apps* → Open file → Install.

---

## Features

- **Inventory Tracking** — Add ingredients, leftovers, and packaged products; color-coded expiry alerts
- **Barcode Scanning** — Auto-fill item details via Open Food Facts API and ML Kit
- **Expiry Date OCR** — Read expiry dates from product labels using the device camera
- **Recipe Recommendations** — Suggests recipes that use items expiring soon, with African cuisine support
- **Household Collaboration** — Create or join a shared household pantry using a 6-digit invite code
- **Waste Analytics** — Waste reduction ring, savings tracker, and top wasted items chart
- **Offline Mode** — Works without internet using Hive local cache; syncs when reconnected
- **Push Notifications** — Expiry and low-stock alerts via Firebase Cloud Messaging

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.29.2 (Dart) |
| State Management | BLoC (`flutter_bloc`) |
| Backend | Firebase Auth, Firestore, Cloud Functions, FCM |
| Barcode | Open Food Facts API + Google ML Kit |
| OCR | Google ML Kit Text Recognition |
| Local Cache | Hive + SharedPreferences |
| CI | GitHub Actions |

---

## Run Locally

**Prerequisites:** Flutter SDK (stable channel), Android Studio or physical Android device, Firebase CLI.

```bash
git clone https://github.com/Lydia02/sabitrak.git
cd sabitrak
flutter pub get
flutter run
```

---

## Tests

103 automated tests across four categories.

```bash
flutter test
```

| Suite | Covers |
|-------|--------|
| Unit | FoodItem model, duplicate detection, food intelligence service |
| Validation | Email, password, quantity, and date input rules |
| Integration | Auth flows, inventory repository with mocked Firebase |
| Acceptance | Core user journeys (AC-01 to AC-06) |

---

## Author

**Lydia Ojoawo** — [github.com/Lydia02](https://github.com/Lydia02)
