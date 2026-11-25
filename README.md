# TAMS Mobile

[![CI](https://github.com/Technical-Assets-Management-CS31A/tams-mobile/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/Technical-Assets-Management-CS31A/tams-mobile/actions/workflows/ci.yml)

The Flutter app for **TAMS**, the RFID-Based Technical Assets Management System built for the ACLC College of Mandaue laboratories (BS Computer Science capstone, 2026).

TAMS replaces the paper borrowing logbook with RFID kiosks, room check-in stations, a web admin portal and this mobile app. The app is used by:

| Role | What they do in the app |
| :--- | :--- |
| Instructor | Approve or decline borrow requests from the kiosk, watch the loans they approved, get alerts about late, misplaced or overdue items |
| Lab custodian | Run offline QR audits of a room and share the PDF report |
| Technical staff / admin | Run audits and sign off completed ones |

## Features

- **Approvals**: pending borrow requests with the student, items and checkout photo, a 120-second countdown, and approve (destination room, class length) or decline.
- **My Loans**: live status of each loan the instructor approved (At Counter, In Transit, Verified in Room, Anomaly, Overdue, Missing) with due-time countdowns and a detail view.
- **Alerts**: late arrival warnings, anomalies, overdue and missing items, with an unread badge. Push notifications through Firebase Cloud Messaging open the matching tab or loan.
- **Approval freeze**: a banner and disabled Approve button while an instructor is frozen.
- **Offline QR audit**: download a room's roster, scan asset QR labels with the camera with or without a connection, sync scans to the server without duplicates, see what's missing, submit, and open or share the PDF report.
- **Session**: tokens kept in secure storage and renewed automatically, so a long offline audit doesn't sign the user out.

The full scope and progress are tracked in [docs/mobile-phase-plan.md](docs/mobile-phase-plan.md).

## Tech stack

- Flutter 3.47.9 (Dart 3.13), Material 3
- [Riverpod](https://riverpod.dev) for state, [go_router](https://pub.dev/packages/go_router) for navigation
- [Dio](https://pub.dev/packages/dio) for the REST API, `flutter_secure_storage` for the session
- `sqflite` for the offline audit queue, `mobile_scanner` for QR scanning, `connectivity_plus` for online/offline detection
- Firebase Cloud Messaging for push notifications only. All data comes from the [TAMS backend](https://github.com/Technical-Assets-Management-CS31A/tams-backend) (ASP.NET Core + PostgreSQL).

## Getting started

### Prerequisites

- Flutter **3.47.9**, the version CI uses. It is pinned in [.fvmrc](.fvmrc), so `fvm install` sets it up if you use [FVM](https://fvm.app).
- Android Studio with an emulator, or an Android phone with USB debugging. iOS needs a Mac with Xcode.
- A running TAMS backend, either locally or the deployed one.

### Install and run

```sh
git clone https://github.com/Technical-Assets-Management-CS31A/tams-mobile.git
cd tams-mobile
make get        # flutter pub get --enforce-lockfile
make run        # debug build on the connected device or emulator
```

Run `make` on its own to list every shortcut. The Makefile uses `fvm flutter` when FVM is installed and `flutter` otherwise. If Flutter isn't on your `PATH`, point it at your SDK:

```sh
make run FLUTTER=~/path/to/flutter/bin/flutter DART=~/path/to/flutter/bin/dart
```

### Choosing the backend

By default the app calls a backend on your computer at port 5278 (`http://10.0.2.2:5278/api/v1` on the Android emulator, `http://localhost:5278/api/v1` elsewhere). To use a different one:

| Target | Command |
| :--- | :--- |
| Backend on another machine, or a real phone on the same Wi-Fi | `make run API_BASE_URL=http://192.168.1.10:5278/api/v1` |
| Deployed backend | `cp env/prod.example.json env/prod.json`, set `API_BASE_URL` in it, then `make run-prod` |
| A specific device | add `DEVICE=<id>` (see `make devices`) |

`env/prod.json` is git-ignored so the deployed URL stays out of this public repo. In VS Code, the **TAMS (local backend)** and **TAMS (deployed backend)** launch configurations do the same thing.

## Development

| Command | What it does |
| :--- | :--- |
| `make format` | Format `lib/` and `test/` |
| `make lint` | `flutter analyze` |
| `make test` | Run all tests |
| `make coverage` | Tests with coverage, written to `coverage/lcov.info` |
| `make check` | Format check, lint and tests, as CI runs them |
| `make build-apk` | Release APK at `build/app/outputs/flutter-apk/app-release.apk` |
| `make build-apk-prod` | Release APK pointed at the backend in `env/prod.json` |

Run `make check` before you push.

### Project structure

```
lib/
├── core/            shared code: API client, token refresh, storage, theme, widgets, utils
├── features/
│   ├── auth/        login and session
│   ├── approvals/   pending borrow requests
│   ├── loans/       My Loans and loan detail
│   ├── alerts/      alert list
│   ├── notifications/  push notifications (FCM)
│   ├── audit/       rooms, roster download, QR scanner, sync, summary and report
│   ├── shell/       bottom tab bar
│   └── splash/
├── routing/         go_router setup and redirects
├── app.dart
└── main.dart
test/                mirrors lib/, with shared fakes and fixtures in test/helpers/
docs/                PRD, phase plan, backend endpoints, audit plan
```

Each feature is split into `data/` (API and local data sources, repositories), `domain/` (models) and `presentation/` (screens, widgets, Riverpod providers).

### Branches and commits

- `develop` is the main branch. Work on a feature branch and open a pull request into `develop`.
- Commit messages are one line in the form `type(scope): title`, for example `fix(audit): drop saved rooms the server no longer lists`.

### CI

Every push to `develop` or `main` and every pull request runs [.github/workflows/ci.yml](.github/workflows/ci.yml):

- format check, `flutter analyze` and tests with coverage
- a release Android APK, uploaded as the `tams-mobile-apk` artifact so it can be installed on a test phone
- a dependency vulnerability scan (osv-scanner), a secret scan (gitleaks) and a workflow lint (actionlint)

The last three can also be run locally with `make audit`, `make secrets` and `make workflow-lint` if the tools are installed.

## Documentation

- [TAMS PRD](docs/TAMS%20PRD%20RFID-Based%20Technical%20Assets%20Management%20System.md): product requirements for the whole system
- [Mobile phase plan](docs/mobile-phase-plan.md): what is done and what is left in the app
- [Backend endpoints for mobile](docs/backend-endpoints-mobile.md): the API contract the app uses
- [Phase 4 audit plan](docs/phase-4-audit-plan.md): design of the offline QR audit

## Team

| Member | Role |
| :--- | :--- |
| Christian Dave Alicaba | Team Lead and Frontend Developer |
| Stanleigh Jeddro Morales | Backend and Database Developer |
| Marc Ejay Cortes | Embedded IoT and Hardware Specialist |
| Rajiemae Villa | Mobile Application Developer |
| John Cez Casupanan | Project Governance Lead, QA Lead and Mobile Application Developer |
