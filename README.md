# Clinic Manager — Flutter App

A full-featured clinic management app with Firebase Firestore real-time sync, SQLite offline persistence, dynamic serial numbering, and PDF export.

---

## Features

| Feature | Details |
|---|---|
| 🏥 **Dashboard** | 3 tiles: Add Patient, Patient List, Manage Doctors |
| 👤 **Staff Name Prompt** | Captured on first launch; persisted via SharedPreferences |
| 🔥 **Firestore Sync** | Real-time multi-user sync across all devices |
| 📱 **SQLite Offline** | Patients added offline are auto-synced when back online |
| 🔢 **Dynamic Serial Numbers** | Auto-increment per doctor per date (resets daily) |
| 📄 **PDF Export** | Full patient list PDF with headers/footers/summary |
| 🖨️ **Print Tokens** | Individual patient token (A5 slip) with token number |
| 👨‍⚕️ **Doctor Management** | Add/edit/delete doctors; toggle availability on/off |
| 🔍 **Filtering** | Filter patients by name, doctor, date |

---

## Project Structure

```
lib/
├── main.dart                    # Entry point + staff name prompt
├── firebase_options.dart        # Firebase config (fill in your values)
├── models/
│   ├── doctor.dart
│   └── patient.dart
├── providers/
│   ├── doctor_provider.dart     # Riverpod state for doctors
│   └── patient_provider.dart   # Riverpod state for patients
├── services/
│   ├── firestore_service.dart   # Firestore CRUD + streams
│   ├── sqlite_service.dart      # Local SQLite database
│   └── sync_service.dart        # Offline ↔ online sync
├── screens/
│   ├── dashboard_screen.dart
│   ├── add_patient_screen.dart
│   ├── patient_list_screen.dart
│   └── manage_doctors_screen.dart
└── utils/
    └── pdf_service.dart         # PDF generation + printing
```

---

## Setup

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project
3. Enable **Cloud Firestore** in test mode (then apply security rules)
4. Enable **Firebase Authentication** → Anonymous sign-in (or Email/Password)

### 2. Register Your App

#### Android
1. Add Android app → package name: `com.example.clinic_app`
2. Download `google-services.json` → place in `android/app/`

#### iOS
1. Add iOS app → bundle ID: `com.example.clinicApp`
2. Download `GoogleService-Info.plist` → place in `ios/Runner/`

#### Web / Windows
1. Add web/windows app in Firebase Console
2. Copy config values

### 3. Update `firebase_options.dart`

Replace all `YOUR_*` placeholder values in [`lib/firebase_options.dart`](lib/firebase_options.dart) with your actual Firebase credentials.

> **Tip:** Run `flutterfire configure` after installing `flutterfire_cli` to auto-generate this file:
> ```
> dart pub global activate flutterfire_cli
> flutterfire configure
> ```

### 4. Deploy Firestore Rules & Indexes

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore
```

### 5. Install Dependencies & Run

```bash
flutter pub get
flutter run
```

---

## Serial Number Logic

Serial numbers are:
- **Per doctor + per date** (resets to 1 each new day)
- Generated using Firestore (online) or SQLite counter table (offline)
- Synchronized when coming back online

```
Doctor A — 2024-01-15: Patient #1, #2, #3 …
Doctor B — 2024-01-15: Patient #1, #2 …
Doctor A — 2024-01-16: Patient #1 (new day, resets)
```

---

## Offline Behaviour

1. Patient data is **always saved to SQLite first**
2. App tries to push to Firestore immediately
3. If offline, records are queued (`isSynced = 0`)
4. On next app start, the `SyncService` pushes all queued records
5. Firestore stream updates local cache when online

---

## PDF Export

- **Patient List PDF** — Full A4 table with header, footer, page numbers, gender summary
- **Patient Token** — A5 slip with token number, patient details, doctor name

Both are previewed in-app via the system print dialog (`printing` package).

---

## Dependencies

| Package | Purpose |
|---|---|
| `firebase_core` | Firebase initialization |
| `cloud_firestore` | Real-time database |
| `flutter_riverpod` | State management |
| `sqflite` | Local SQLite database |
| `shared_preferences` | Staff name persistence |
| `pdf` | PDF document generation |
| `printing` | Print preview & export |
| `intl` | Date/time formatting |
| `uuid` | Unique ID generation |

---

## Screenshots (Screens)

| Screen | Description |
|---|---|
| Staff Name Prompt | First-launch prompt to capture staff identity |
| Dashboard | 3 feature tiles + live stats strip |
| Add Patient | Form with doctor selector, serial auto-assigned |
| Patient List | Searchable list with filter + PDF export |
| Manage Doctors | Card list with active/inactive toggle + CRUD |

