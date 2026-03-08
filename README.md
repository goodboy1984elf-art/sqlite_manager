# SQLite Manager

A cross-platform SQLite database management app built with Flutter.

**Platforms:** Android · iOS · Windows

---

## Features

- 📂 Open any local `.db` / `.sqlite` file
- 📊 Browse table data with inline **insert / edit / delete**
- 🔍 Raw SQL query editor with result viewer
- ➕ Create and drop tables with a visual column builder
- 🔒 Encrypt / decrypt databases with SQLCipher
- 🗂️ Manage multiple databases simultaneously

---

## Quick Start (GitHub Codespaces)

1. Open this repo in Codespaces — environment sets up automatically
2. Wait for `setup.sh` to finish (~5 min on first run)
3. Start the app in Flutter Web mode:

```bash
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

Codespaces auto-forwards port 8080 — your browser opens automatically.

---

## Development Commands

```bash
# Run on Flutter Web (interactive, hot reload)
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0

# Run unit tests
flutter test test/unit/

# Run integration tests (SQLite file ops, Linux FFI)
flutter test test/integration/ -d linux

# Run all tests with coverage
flutter test --coverage

# Analyze code
flutter analyze

# Build Android APK
flutter build apk --release

# Build for Linux desktop
flutter build linux --release
```

---

## CI/CD (GitHub Actions)

Push to `main` triggers automatic builds for all three platforms.

| Platform | Runner | Output | Distribution |
|----------|--------|--------|-------------|
| Android | ubuntu-latest | `.apk` | Firebase App Distribution |
| iOS | macos-latest | `.ipa` | Firebase App Distribution |
| Windows | windows-latest | `.zip` (EXE) | GitHub Artifacts |

### Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `FIREBASE_ANDROID_APP_ID` | Android App ID from Firebase console |
| `FIREBASE_IOS_APP_ID` | iOS App ID from Firebase console |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase service account JSON |

---

## Project Structure

```
lib/
├── main.dart                        # Entry point
├── app_router.dart                  # go_router navigation
├── app_theme.dart                   # Material 3 theme
├── core/
│   ├── database/
│   │   ├── db_connection.dart       # Raw SQLite/SQLCipher operations
│   │   └── db_repository.dart       # Multi-DB state management (Riverpod)
│   └── models/
│       └── database_model.dart      # Data models
└── features/
    ├── db_manager/
    │   └── db_manager_screen.dart   # Home: list of databases
    ├── table_browser/
    │   ├── table_list_screen.dart   # Tables in a database
    │   └── table_browser_screen.dart # Row viewer + inline CRUD
    ├── table_manager/
    │   └── create_table_screen.dart # Visual table builder
    ├── query_editor/
    │   └── query_editor_screen.dart # Raw SQL editor
    └── shared/widgets/
        ├── password_dialog.dart
        └── confirm_dialog.dart

test/
├── unit/
│   └── db_connection_test.dart      # Core CRUD + schema tests
└── integration/
    └── sqlite_file_test.dart        # File persistence + large data tests

.devcontainer/
├── devcontainer.json                # Codespaces config
└── setup.sh                         # Flutter + Android SDK install

.github/workflows/
└── build.yml                        # Three-platform CI/CD
```

---

## iOS Setup Notes

iOS builds require an Apple Developer account ($99/year) for code signing.

Without a certificate, the Actions workflow builds with `--no-codesign`.  
To enable signed distribution via Firebase:

1. Add your provisioning profile and certificate to GitHub Secrets
2. Update `build.yml` to pass the signing identity to `flutter build ios`

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.24 (Dart) |
| SQLite | `sqlite3` + `sqlite3_flutter_libs` |
| Encryption | `sqlcipher_flutter_libs` |
| State | `flutter_riverpod` |
| Navigation | `go_router` |
| File picker | `file_picker` |
| CI/CD | GitHub Actions |
| Distribution | Firebase App Distribution |
