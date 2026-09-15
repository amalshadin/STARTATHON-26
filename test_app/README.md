# HapticSync Test App

This is a login-free Flutter runner for testing the games, calibration flow, and ESP32 BLE connection. It reuses the production implementation from `../app` through a local path dependency.

## Setup

1. Install Flutter and ensure `flutter` is on `PATH`.
2. From this directory, run:

   ```sh
   flutter pub get
   ```

3. Optionally copy `.env.example` to `.env` and adjust the BLE UUIDs.
4. Generate native platform files if they are not present:

   ```sh
   flutter create --platforms android,ios .
   ```

## Run and test

```sh
flutter analyze
flutter test
flutter run
```

The app opens directly on the production `RootScaffold`; it does not display the login screen. Open the Home tab to scan for the glove, or use the existing mock connection from the BLE connection flow when hardware is unavailable.

Android and iOS still require Bluetooth permissions. The backend is optional for hardware and game testing. Analytics, profile data, and session uploads may show fallback/error states without an authenticated patient session.
