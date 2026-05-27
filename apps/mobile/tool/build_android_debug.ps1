param(
  [string]$BuildRoot = "$env:TEMP\helper_mobile_build"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RepoRoot = Resolve-Path (Join-Path $ProjectRoot "..\..")
. (Join-Path $PSScriptRoot "android_build_helpers.ps1")

$Flutter = Resolve-ProjectFlutter -RepoRoot $RepoRoot
$EnvFile = Join-Path $ProjectRoot ".env.local"
$OutputDir = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"
$OutputApk = Join-Path $OutputDir "app-debug.apk"

if (-not (Test-Path -LiteralPath $EnvFile)) {
  throw "Missing $EnvFile"
}

$vars = Get-Content -LiteralPath $EnvFile |
  Where-Object { $_ -match '^\s*[^#].+=' } |
  ConvertFrom-StringData

if ([string]::IsNullOrWhiteSpace($vars.SUPABASE_URL) -or
    [string]::IsNullOrWhiteSpace($vars.SUPABASE_ANON_KEY)) {
  throw "SUPABASE_URL and SUPABASE_ANON_KEY are required in $EnvFile"
}

$resolvedBuildRoot = $null
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
        "apk",
        "--debug",
        "--dart-define=SUPABASE_URL=$($vars.SUPABASE_URL)",
        "--dart-define=SUPABASE_ANON_KEY=$($vars.SUPABASE_ANON_KEY)"
      ) `
      -FailureMessage "Flutter Android debug build failed."
  } finally {
    Pop-Location
  }

  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $BuildRoot "build\app\outputs\flutter-apk\app-debug.apk") `
    -Destination $OutputApk `
    -Force

  $result = Get-Item -LiteralPath $OutputApk
  $result
} finally {
  if (Test-Path -LiteralPath $BuildRoot) {
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force
  }
}
