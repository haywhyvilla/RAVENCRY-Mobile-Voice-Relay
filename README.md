# RAVENCRY Voice Relay

RAVENCRY Voice Relay is an offline-first Flutter companion for preparing a
fictional missing-person sighting report. It is designed for Android and iOS,
stores reports on the device, and queues them for human review.

> If you are in immediate danger, call **112**. This demo does not contact
> emergency services, issue alerts, or deliver reports to a server.

## Included flow

1. Choose English, Hausa, Yoruba, Igbo, or Pidgin.
2. Confirm that reports require human review.
3. Record audio locally or use the text-only fallback.
4. Review the supplied fictional Hausa sighting fixture.
5. Queue the report locally and view it in the persistent offline outbox.
6. Run the local-only demo submission stub, which returns `DEMO-VOICE-001`
   with `queued_for_human_review`.

The app makes no network request and contains no API key, backend, or
production URL.

## Requirements

- Flutter `3.41.6` with Dart `3.11.4` or a compatible newer toolchain.
- Android SDK and an Android emulator/device for Android runs.
- Xcode and an iOS Simulator/device for iOS runs.
- A JDK supported by your Android Gradle Plugin (JDK 17–21 is recommended;
  JDK 25 is not compatible with this project's Gradle setup).

## Run locally

```bash
flutter pub get
flutter run
```

Choose a device explicitly when more than one is connected:

```bash
flutter devices
flutter run -d <device-id>
```

### Android

The app requests `RECORD_AUDIO` only when the user starts a local recording.
If permission is denied or the microphone is unavailable, the text-only path
remains available.

```bash
flutter build apk --debug
```

### iOS

The iOS target includes an `NSMicrophoneUsageDescription` entry. Use an
unsigned debug build for Simulator-oriented verification, or configure signing
in Xcode before deploying to a physical device.

```bash
flutter build ios --debug --no-codesign
```

## Verify

```bash
flutter analyze
flutter test
```

The widget test covers language/consent gating, text fallback, fixture review,
local queueing, simulated restart persistence, and the local submission stub.

## Demo data and contract

- Fictional fixture: `assets/fixtures/voice-relay-sighting.json`
- JSON Schema: `docs/voice-relay-contract.schema.json`
- Local outbox: `SharedPreferences` serializes `VoiceRelayReport` items on the
  device.

The submission adapter is intentionally replaceable. The only current adapter
is `LocalOnlySubmissionAdapter`; it returns the fixed demo result below and
does not change a report's queued status:

```json
{
  "status": "queued_for_human_review",
  "case_reference": "DEMO-VOICE-001",
  "message": "Saved for human review. This demo has not contacted emergency services."
}
```

## Project structure

```text
lib/main.dart                             App flow, local recording, outbox, and stub
assets/fixtures/voice-relay-sighting.json Fictional demo sighting
docs/voice-relay-contract.schema.json     Report and stub-result JSON Schema
test/widget_test.dart                     End-to-end widget test
android/                                  Android runner and microphone permission
ios/                                      iOS runner and microphone usage description
```

## Version control

Generated build output, platform caches, IDE settings, local signing files,
and service configuration files are excluded through `.gitignore`. Commit the
source, fixture, schema, and `pubspec.lock`; do not commit `build/`,
`.dart_tool/`, `ios/Pods/`, Android Gradle caches, `.env` files, signing keys,
or credentials.
