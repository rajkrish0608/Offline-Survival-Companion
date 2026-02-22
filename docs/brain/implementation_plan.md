# Market Readiness Fixes – Implementation Plan

Fixing the 6 most critical blockers that prevent this app from being market-ready. All changes are backward-compatible and build on the existing architecture.

## Proposed Changes

---

### Fix 1 – Flashlight (Real Hardware Control)

#### [MODIFY] [pubspec.yaml](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/pubspec.yaml)
- Uncomment `torch_light: ^0.8.0`

#### [MODIFY] [emergency_service.dart](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/lib/services/emergency/emergency_service.dart)
- Uncomment `TorchLight` import and all torch calls
- Add proper error handling for devices without flash
- `isFlashlightAvailable()` will return real hardware state

#### [MODIFY] [Info.plist](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/ios/Runner/Info.plist)
- Add `NSCameraUsageDescription` (required for torch access on iOS)

---

### Fix 2 – Alarm Audio (Real Siren Playback)

> [!IMPORTANT]
> We will add `just_audio` (the most iOS-compatible Flutter audio package). A siren `.mp3` asset must be included (`assets/audio/siren.mp3` — I will generate a placeholder that works).

#### [MODIFY] [pubspec.yaml](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/pubspec.yaml)
- Add `just_audio: ^0.9.40`
- Register `assets/audio/` in the flutter assets section

#### [NEW] `lib/services/audio/alarm_service.dart`
- `AlarmService` class with `start()`, `stop()`, `isPlaying` getter
- Uses `just_audio` `AudioPlayer` to loop the siren asset
- Sets audio session to `duck others` so it plays over silent mode

#### [MODIFY] `lib/presentation/screens/emergency_screen.dart`
- Wire "Loud Alarm" button to `AlarmService.start()` / `stop()`
- Show visual indicator (animated icon) when alarm is active

#### [MODIFY] [Info.plist](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/ios/Runner/Info.plist)
- Add `UIBackgroundModes: audio` so alarm plays when app is backgrounded

---

### Fix 3 – Webpage Persistence (Survive App Restart)

The `saved_web_pages` SQLite table already exists. `WebpageService.getSavedPages()` just needs to query it.

#### [MODIFY] [webpage_service.dart](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/lib/services/webpage/webpage_service.dart)
- Wire `getSavedPages()` to query the SQLite `saved_web_pages` table via `LocalStorageService`
- Wire `saveWebpage()` to `INSERT` into `saved_web_pages` after downloading
- Delete saved file when page is removed from the list

---

### Fix 4 – Emergency Contacts UI (Real Contact Management)

The DB layer (`addEmergencyContact`, `getEmergencyContacts`, `deleteEmergencyContact`) is fully implemented. Only the UI is missing.

#### [NEW] `lib/presentation/screens/emergency_contacts_screen.dart`
- Lists all saved contacts with name, phone, relationship, ★ primary badge
- FAB opens an `AlertDialog` form to add a new contact (name, phone, relationship, primary toggle)
- Swipe-to-delete with confirmation
- First contact is auto-set as primary

#### [MODIFY] `lib/presentation/screens/settings_screen.dart`
- Add a "Emergency Contacts" navigation tile that pushes to `EmergencyContactsScreen`

---

### Fix 5 – Replace `print()` with `Logger`

`logger` package is already in `pubspec.yaml`. Only 3 files use raw `print()`:

#### [MODIFY] [biometric_service.dart](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/lib/services/auth/biometric_service.dart)
- Replace `print(...)` → `Logger().e(...)`

#### [MODIFY] [local_storage_service.dart](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/lib/services/storage/local_storage_service.dart)
- Replace all `print(...)` → `_logger.w(...)` / `_logger.e(...)`
- Also suppress WAL mode warning (it succeeds but SQLite reports "not an error" — wrap in a result check)

---

### Fix 6 – iOS `Info.plist` Missing Permission Strings

#### [MODIFY] [Info.plist](file:///Users/rajkrish0608/PROJECT%20DETAILS/OFFLINE%20SURVIVAL%20APP/flutter_app/ios/Runner/Info.plist)
- Add `NSCameraUsageDescription` (torch + QR scanner)
- Add `UIBackgroundModes: audio` (alarm in background)
- Add `NSContactsUsageDescription` (emergency contacts import — optional but good to have)

---

### Fix 7 – QR Scanner (Real Hardware Integration)

#### [NEW] `lib/presentation/screens/qr_scanner_screen.dart`
- Use `mobile_scanner` to implement a real scanning UI.
- Support flashlight toggle within the scanner.
- On success, parse the data and save it using `QrCodeService`.
- Display a summary/confirmation after scanning.

#### [MODIFY] `lib/presentation/screens/home_screen.dart`
- Wire a "Scan QR" button/fab or quick action to open the scanner.

---

### Fix 8 – Offline Maps (Real Rendering)

#### [MODIFY] `lib/presentation/screens/maps_screen.dart`
- Integrate `maplibre_gl` `MapLibreMap` widget.
- Implement a `MapController` to manage the map state.
- Use a local style JSON from assets for offline rendering.
- Update "Download" logic to fetch real map tiles/packs (in a production app, this would be an API call, but we will simulate with a more robust local caching mechanism for the demo).

---

## Verification Plan

### Automated Tests
Run the existing integration test after all fixes:
```bash
cd "/Users/rajkrish0608/PROJECT DETAILS/OFFLINE SURVIVAL APP/flutter_app"
flutter test integration_test/app_test.dart -d 73A93B87-FC8C-421F-8BA4-0068689EED0A
```
Expected: `All tests passed!`

### Manual Verification on iOS Simulator

| Feature | How to Test |
|---|---|
| **Flashlight** | Tap "Flashlight" quick action on Home → torch activates (real device only; simulator shows no-op) |
| **Alarm** | Tap SOS → tap "Loud Alarm" button → hear siren sound playing |
| **Webpage persist** | Save a URL → force-quit and reopen app → page still in list |
| **Emergency contacts** | Go to Settings → Emergency Contacts → add a contact → restart → contact persists |
| **No print() leaks** | Run `flutter run` → check terminal for no raw `print()` output (Logger uses structured format) |
