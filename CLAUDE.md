# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Flutter app (`gtk_flutter` in `pubspec.yaml`, branded "מועדון הכרמל") for managing tennis court reservations at the Carmel tennis club. UI is Hebrew/RTL. Backed by Firebase (Auth + Firestore + Hosting). Targets Android, iOS, web, macOS, Windows, Linux.

## Common commands

```bash
flutter pub get                      # install Dart deps
flutter run                          # run on default device
flutter run -d chrome                # run web build
flutter analyze                      # lint (uses analysis_options.yaml -> flutter_lints)
flutter test                         # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter build web                    # build web bundle into build/web
flutter build apk                    # Android release APK (signed via carmeltennis.jks; see android/)
firebase deploy --only hosting       # manual deploy fallback; CI handles this on push to main (see "Deployment" below)
```

The Python scripts at the repo root (`add_users_to_database_*.py`, `delete_all_reservations.py`, `import_users_from_excel.py`, `remove_duplicates.py`) are **one-off admin utilities** that talk to Firestore via `firebase_admin`. They are not part of the Flutter build. Do not assume they reflect current schema unless verified against `lib/`.

## Architecture

### Firebase project & data model

- Firebase project id: `mit-app-inventor-bff1c` (see `firebase.json`). `.firebaserc` points to a different alias (`potent-howl-228108`) — treat `firebase.json` as authoritative for app config; `.firebaserc` controls `firebase` CLI default project for hosting.
- Firestore collections used by the app:
  - `users_2024` — user records keyed by Firebase Auth UID. **Field names are Hebrew strings** (`מייל`, `שם פרטי`, `שם משפחה`). Also stores `isFirstLogin`, manager flag, and per-user prefs (dark mode, email notifications, last partners).
  - `reservations` — one doc per booked slot with `date` (yyyy-MM-dd string), `hour` (int, 7–21), `userName`, `partner`, court info.
  - `holidays` — date overrides that change `numberOfCourts` available for that day (default 2; can be overridden via `holidayType` such as 'חג').
  - TV-screen messages collection (see `tv_screen.dart` / `tv_message_editor.dart`).

### App entry & state

- `lib/main.dart` — bootstraps Firebase, primes `UserManager` mappings, builds light/dark Material 3 themes (Roboto via `google_fonts`, deepPurple seed), and configures `GoRouter` with routes: `/`, `/sign-in` (+ `forgot-password`), `/profile`, `/change-password`, `/tv`, `/tv-message`.
- `lib/app_state.dart` — `ApplicationState` is a **singleton `ChangeNotifier`** (private constructor, factory returns `_instance`) provided at the root via `provider`. Listens to `FirebaseAuth.userChanges()`, loads the user's Firestore doc, redirects first-login users to change-password, and caches `reservations` into `_courtsReserved`.
- `lib/theme_controller.dart` — separate `ChangeNotifier`-style controller listened to via `AnimatedBuilder` in `App.build` to switch theme mode without full rebuild.
- `lib/navigation_service.dart` — service used by `ApplicationState` to navigate outside the widget tree (e.g. force-redirect first-login users to change-password).

### User identity mapping

`UserManager` (`lib/user_manager.dart`) is a singleton that on first use loads **all** of `users_2024` into two in-memory maps: email→full name and full name→email. Reservations store the human-readable `userName` (Hebrew "first last"), not UID or email — so any feature that needs to relate auth identity to reservation rows MUST go through `UserManager.getUsernameByEmail` / `getEmailByUsername`. `main.dart` calls `fetchAndStoreUserMappings()` before `runApp` so the maps are warm at cold start.

### Reservation flow

- `home_page.dart` is the main screen (date selector + partner picker + grid). It owns auth subscriptions (`authStateChanges`, `idTokenChanges`), manager-flag resolution, and prefs loading. Note the explicit `_managerResolved` gate to avoid flashing the wrong UI before the role lookup completes.
- `booking_screen_v31.dart` (`BookingScreenV31` widget) is the booking grid for a given date. It resolves `numberOfCourts` per day via `numberOfCourtsFor` in `holiday_courts.dart` (default 2, changed for holidays via the `holidays` collection's `holidayType`), and renders slots through the shared `widgets/time_grid.dart` (`TimeGrid`) for hours 7–21 per court.
- `reservation_manager.dart::hasExistingReservation` enforces the "one booking per user per date" rule by querying `reservations` twice — once where the user is `userName`, once where they are `partner` — because the partner field counts as a participating booking.
- `email_service.dart` builds RTL Hebrew confirmation/cancellation HTML emails sent via `dio`. The reservation widget calls into it when a slot is booked or cancelled.

### TV display

`/tv` (`tv_screen.dart`) is a read-only kiosk view of the day's reservations showing full names; it renders the same `widgets/time_grid.dart` (`TimeGrid`) grid via a custom `slotBuilder`. `/tv-message` is the manager-only editor for the banner shown on `/tv`.

## Deployment notes

- **Web hosting is automated.** Two GitHub Actions workflows under `.github/workflows/` handle deploys for project `mit-app-inventor-bff1c`:
  - `deploy-live.yml` — runs on push to `main`, builds the web bundle, syncs into `public/`, and deploys to the live channel.
  - `deploy-preview.yml` — runs on PRs to `main` (from same-repo branches only), deploys to a per-PR preview channel and posts the URL as a PR comment.
  - Both authenticate via the `FIREBASE_SERVICE_ACCOUNT` repo secret (a service-account JSON with the **Firebase Hosting Admin** role on project `mit-app-inventor-bff1c`).
- `firebase.json` hosting block serves the **`public/`** folder. `public/` is gitignored — CI populates it from `build/web/` at deploy time. For a manual deploy, run `flutter build web && rm -rf public && mkdir public && cp -r build/web/. public/ && firebase deploy --only hosting`.
- `build/` is also gitignored. Flutter rebuilds it locally / in CI as needed.
- Android signing uses `carmeltennis.jks` at the repo root (referenced from `android/`).
- `bfg.jar` at repo root is the BFG repo-cleaner tool kept around for git history scrubs; it is not part of the build.

## Things to know before editing

- Firestore field names in `users_2024` are Hebrew literals — preserve them exactly when reading/writing (`'מייל'`, `'שם פרטי'`, `'שם משפחה'`).
- `ApplicationState` is a singleton: don't construct multiple instances or expect `init()` to run more than once cleanly. `Firebase.initializeApp` is also called in both `main.dart` and `ApplicationState.init`; the second call is a no-op but be aware if refactoring init order.
- There are stray duplicated platform folders (`ios 2`, `ios_new`, `.flutter-plugins 2`, `.flutter-plugins-dependencies 2`) — `ios/` is the live one, the others are leftovers. Don't edit the duplicates.
- `lib/` contains a couple of misplaced non-Dart files (`add_islogin.py`, `import firebase_admin.py`, `package.json`) — treat these as stray and ignore unless the user asks about them.
