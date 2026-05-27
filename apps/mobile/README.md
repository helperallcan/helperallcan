# Helper Flutter App

## Run

```powershell
flutter pub get
flutter run `
  --dart-define=SUPABASE_URL=https://xzjyinsvpxgzdxbuluct.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Build Android Test APK

Recommended on Windows, especially when the repository path contains non-ASCII characters:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_debug.ps1
```

Manual build:

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL=https://xzjyinsvpxgzdxbuluct.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

APK output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Install Debug APK To Phone

1. Turn on Android Developer options.
2. Enable USB debugging.
3. Connect the phone with USB and allow debugging on the phone.
4. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\install_android_debug.ps1
```

## Release Signing

Create a local upload keystore and ignored `android/key.properties`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\setup_android_release_signing.ps1
```

Back up these two files somewhere safe:

```text
%USERPROFILE%\.helper\android_upload_keystore.jks
android/key.properties
```

Build a signed release APK:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
```

Release APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Build a signed Android App Bundle for store upload:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_appbundle.ps1
```

App Bundle output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Build Web

```powershell
flutter build web `
  --dart-define=SUPABASE_URL=https://xzjyinsvpxgzdxbuluct.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```
