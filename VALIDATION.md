# Validation performed — 26 October 2026

- SDK: Flutter stable checkout, Dart 3.13.7. Exact Flutter revision can be found in generated `.metadata`.
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 19 tests. Includes ten chart render cases with constant / negative / zero values, mobile layout (390 × 844), theme / range changes, explicit error-to-demo recovery, stale response rejection, API mapping, missing values, day grouping and temperature band boundaries.
- `flutter test tool/live_api_test.dart`: passed against the real Open-Meteo endpoint, returning and parsing 168 Cairo hourly readings across seven UTC days. This optional network check is outside deterministic CI tests.
- `flutter build web --release`: passed. Flutter also reported a successful Wasm dry run. This is a JS release build, not a separately tested Wasm deployment.
- Screenshot rendering: see `docs/dashboard.png` (synthetic Demo mode, clearly labeled).

## Platform limits

Android and iOS platform projects are included. No Android SDK or iOS toolchain/device was available locally, so local APK compilation and physical Android/iOS testing are **not** claimed. The CI workflow includes an Android debug APK build and artifact upload. Check the actual Actions run for that result. iOS requires a macOS build environment.

Initial local validation used Flutter's test engine. After deployment, the real GitHub Pages origin was tested in Chrome: the app loaded, fetched 168 real Cairo readings, switched to a 24-hour range, fetched London data on city selection, opened the hourly data table, and returned to the seven-day view. Demo mode remained off. Physical device testing is not claimed. No performance benchmark, continuous streaming, backend authentication, custom company data, or persistent cache is claimed.

SDK setup used `CI=true` to avoid cloud metadata auto-detection, and `FLUTTER_SUPPRESS_ANALYTICS=true` to suppress telemetry.

## Deployed web smoke test

- Live URL: https://asamiiii.github.io/flutter-charts-lab/
- Release build and Pages deployment succeeded: https://github.com/asamiiii/flutter-charts-lab/actions/runs/40282779831
- Rendering resources are hosted with the app (`--no-web-resources-cdn`).
