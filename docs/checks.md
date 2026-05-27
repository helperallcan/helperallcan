# Repo Checks

Task 1 defines the checks that every feature PR should pass before merge.

On Windows PowerShell, use `npm.cmd` instead of `npm` if script execution policy
blocks `npm.ps1`.

## Admin

```powershell
npm --prefix apps/admin ci
npm --prefix apps/admin run lint
npm --prefix apps/admin run build
npm --prefix apps/admin audit --omit=dev
```

Shortcut:

```powershell
npm run check:admin
```

## Flutter

```powershell
cd apps/mobile
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

Shortcut:

```powershell
npm run check:mobile
```

## Flutter Platform Builds

CI also verifies the generated Web and Android projects can compile with safe
placeholder Supabase values:

```powershell
cd apps/mobile
flutter build web `
  --dart-define=SUPABASE_URL=https://example.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=ci-anon-key
flutter build apk --debug `
  --dart-define=SUPABASE_URL=https://example.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=ci-anon-key
```

Shortcut:

```powershell
npm run check:mobile:build
```

The Android shortcut uses `apps/mobile/tool/build_android_debug.ps1`, which
builds from a temporary English-path folder to avoid Windows path encoding
issues.

## Supabase SQL

Requires Docker and Supabase CLI.
RLS tests live in `supabase/tests/database`.

```powershell
supabase start
supabase db reset --local
supabase test db
supabase db lint --local
supabase stop --no-backup
```

Shortcut:

```powershell
npm run check:supabase
```

## GitHub Actions

`.github/workflows/ci.yml` runs three independent jobs:

- `Next.js Admin`: install, lint, build, audit
- `Flutter App`: pub get, analyze, test, build Web, build Android debug APK, upload short-lived build artifacts
- `Supabase SQL`: local Supabase start, migration replay, RLS database tests, database lint
