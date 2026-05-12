# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**BabyGuard** — Flutter + Firebase baby monitor. Two devices, two roles:

- **Baby Unit**: anonymously signs in, generates a 6-char pair code, runs `NoiseMeter` in a foreground-service isolate, writes alert events to Firestore when sound crosses a threshold.
- **Parent Unit**: joins via code/QR, stores its FCM token on the pair doc, receives full-screen alerts.

A Firestore-trigger Cloud Function ([functions/index.js](functions/index.js)) is the **only** path that delivers a push from one phone to the other — phone-to-phone FCM is impossible without a server.

See [README.md](README.md) for the full Firebase Console + build-from-zero walkthrough.

## Environment

`JAVA_HOME`, `ANDROID_HOME`, and the related `PATH` entries (cmdline-tools, platform-tools) are exported from `~/.zshrc` on this machine — any fresh shell has `flutter`, `adb`, `java`, and `sdkmanager` on the PATH. If a Bash command from this session ever runs without them (e.g. a non-login shell), re-export:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Flutter 3.41.9 / Dart 3.11.5 is installed via Homebrew cask. Flutter expects Android SDK platform-36 and build-tools-36 — both are already installed.

## Commands

```bash
flutter pub get                          # after pubspec changes
flutter analyze --no-pub                 # lint — 0 errors expected, info-level lints ok
flutter test                             # smoke-builds the widget tree; no Firebase init
flutter test test/widget_test.dart       # single test file
flutter build apk --debug --dart-define-from-file=firebase-config.json
flutter run -d <device-id>  --dart-define-from-file=firebase-config.json
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Firebase config

Two gitignored files hold the project credentials. `firebase-config.example.json` (committed) shows the schema:

- `firebase-config.json` — values fed into [lib/firebase_options.dart](lib/firebase_options.dart) via `String.fromEnvironment`. Every build/run command **must** include `--dart-define-from-file=firebase-config.json` or `Firebase.initializeApp()` throws a `StateError` from the `_assertConfigured` guard.
- `android/app/google-services.json` — required on disk by the `com.google.gms.google-services` Gradle plugin. The plugin is already enabled in [android/app/build.gradle.kts](android/app/build.gradle.kts) — if the file is missing, the APK build fails at the Android assemble step, not at Dart compile.

## Architecture (non-obvious bits)

### Where the mic lives — main isolate, not the foreground-task isolate

The original design ran `noise_meter` inside `flutter_foreground_task`'s isolate, but the `audio_streamer` MethodChannel doesn't fire reliably there on Samsung One UI / Android 11 — the service started, the notification showed, but no dB readings ever came through. Verified against logcat: zero `AudioRecord` / `AudioFlinger` activity.

Current architecture:

- **Main UI isolate** owns `NoiseMeterService`, threshold detection, and the Firestore alert write. Lives in [lib/providers/monitoring_provider.dart](lib/providers/monitoring_provider.dart):`MonitoringNotifier`.
- **Foreground-task isolate** ([lib/services/background_service.dart](lib/services/background_service.dart):`_KeepAliveTaskHandler`) does **nothing** except keep the persistent "BabyGuard is monitoring" notification alive so the OS doesn't kill the app while screen is off. Don't add audio/Firebase logic to this handler — it won't fire on all OEMs.
- **FCM background handler** ([lib/services/fcm_service.dart](lib/services/fcm_service.dart):`firebaseMessagingBackgroundHandler`) is still a separate isolate spawned when push arrives while the app is killed. **Must reinit Firebase** on entry.
- The `@pragma('vm:entry-point')` annotation on `startMonitoringCallback`, `firebaseMessagingBackgroundHandler`, and `_onNotificationAction` is load-bearing — tree-shaking will strip them otherwise.

### Threshold debounce + cooldown

[lib/services/noise_meter_service.dart](lib/services/noise_meter_service.dart) fires only when dB stays above threshold for **800 ms continuously**, then locks for **10 s**. Both numbers were picked to suppress short coughs/door slams while still catching cries fast — change them with care.

### State management choice

Riverpod 2 (StateNotifierProvider, StreamProvider). Chosen because the foreground-task isolate and FCM background handler run **outside any widget tree**, so anything that needs `BuildContext` (e.g. `Provider.of`) is out. Service singletons like `FirebaseService.instance` / `NotificationService.instance` are used directly from isolates; Riverpod is only used in the UI isolate.

### Routing is role-driven, not URL-driven

[lib/core/router/app_router.dart](lib/core/router/app_router.dart):`initialRouteFor(PairingState)` reads the persisted role + pairId from `SharedPreferences` and lands the user on `babyMonitor` / `parentMonitor` / `babyPair` / `parentPair` / `onboarding` directly. There's no deep linking or nav stack history beyond Material's default.

### Notification stack

Two `AwesomeNotifications` channels in [lib/services/notification_service.dart](lib/services/notification_service.dart):

- `foreground_channel` (low priority) is the persistent "monitoring" notification owned by `flutter_foreground_task` — required by Android 14 for `FOREGROUND_SERVICE_MICROPHONE`.
- `alert_channel` (max + `defaultRingtoneType: Alarm` + `fullScreenIntent` + `criticalAlert`) plays the system alarm ringtone with no bundled audio asset. The `AlertScreen` adds an **independent** vibration loop on top for redundancy.

### Cloud Function contract

Baby writes `pairs/{pairId}/events/{eventId}` → [functions/index.js](functions/index.js):`onAlertEvent` reads `pairs/{pairId}.parentToken` → sends FCM with `data.type = "alert"`. The `firebaseMessagingBackgroundHandler` on Parent renders the local notification with `channelKey: alert_channel`. Modifying any of: the events subcollection path, the `data.type` value, or the channel key, breaks the chain across three files.

## Conventions specific to this repo

- **Commit style**: `SPT: <short description>` (no EGSDEV ticket on this personal project). No co-author trailer.
- **Build artifacts**: `build/`, `.dart_tool/`, `pubspec.lock` is committed (this is an app, not a library). `google-services.json` / `GoogleService-Info.plist` are gitignored.
- **`flutter create` regen**: Running `flutter create .` again will **not** clobber our `pubspec.yaml`, `AndroidManifest.xml`, or `lib/`. It only adds missing platform scaffolding.

## User preferences

- Use available skills (e.g. `devportal-tests`, `devportal-lint`) for testing/linting in projects that have them. This project doesn't — use `flutter test` / `flutter analyze` directly.
- Never use `pnpm test` or similar — Flutter projects use `flutter` CLI.
