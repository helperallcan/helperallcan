param(
  [string]$BuildRoot = "$env:TEMP\zhao_bang_shou_mobile_bundle_build"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RepoRoot = Resolve-Path (Join-Path $ProjectRoot "..\..")
. (Join-Path $PSScriptRoot "android_build_helpers.ps1")

$Flutter = Resolve-ProjectFlutter -RepoRoot $RepoRoot
$EnvFile = Join-Path $ProjectRoot ".env.local"
$KeyProperties = Join-Path $ProjectRoot "android\key.properties"
$OutputDir = Join-Path $ProjectRoot "build\app\outputs\bundle\release"
$OutputBundle = Join-Path $OutputDir "app-release.aab"

if (-not (Test-Path -LiteralPath $EnvFile)) {
  throw "Missing $EnvFile"
}

if (-not (Test-Path -LiteralPath $KeyProperties)) {
  throw "Missing $KeyProperties. Run .\tool\setup_android_release_signing.ps1 first."
}

$vars = Get-Content -LiteralPath $EnvFile |
  Where-Object { $_ -match '^\s*[^#].+=' } |
  ConvertFrom-StringData

if ([string]::IsNullOrWhiteSpace($vars.SUPABASE_URL) -or
    [string]::IsNullOrWhiteSpace($vars.SUPABASE_ANON_KEY)) {
  throw "SUPABASE_URL and SUPABASE_ANON_KEY are required in $EnvFile"
}

if (Test-Path -LiteralPath $BuildRoot) {
  $resolvedBuildRoot = (Resolve-Path -LiteralPath $BuildRoot).Path
  if ($resolvedBuildRoot -ne $BuildRoot) {
    throw "Unexpected build root: $resolvedBuildRoot"
  }
  Remove-Item -LiteralPath $BuildRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $BuildRoot | Out-Null

robocopy $ProjectRoot $BuildRoot /E /XD build .dart_tool .idea /XF *.log | Out-Null
if ($LASTEXITCODE -gt 7) {
  throw "Failed to copy project to $BuildRoot"
}

try {
  Push-Location $BuildRoot
  try {
    Invoke-CheckedFlutter `
      -Flutter $Flutter `
      -Arguments @(
        "build",
        "appbundle",
        "--release",
        "--dart-define=SUPABASE_URL=$($vars.SUPABASE_URL)",
        "--dart-define=SUPABASE_ANON_KEY=$($vars.SUPABASE_ANON_KEY)"
      ) `
      -FailureMessage "Flutter Android app bundle build failed."
  } finally {
    Pop-Location
  }

  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $BuildRoot "build\app\outputs\bundle\release\app-release.aab") `
    -Destination $OutputBundle `
    -Force

  $result = Get-Item -LiteralPath $OutputBundle
  $result
} finally {
  if (Test-Path -LiteralPath $BuildRoot) {
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force
  }
}
