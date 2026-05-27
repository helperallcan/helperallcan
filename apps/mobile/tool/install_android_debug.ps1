param(
  [string]$ApkPath = "build\app\outputs\flutter-apk\app-debug.apk"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RepoRoot = Resolve-Path (Join-Path $ProjectRoot "..\..")
$Adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$FullApkPath = Join-Path $ProjectRoot $ApkPath

if (-not (Test-Path -LiteralPath $Adb)) {
  throw "adb was not found at $Adb"
}

if (-not (Test-Path -LiteralPath $FullApkPath)) {
  throw "APK was not found at $FullApkPath. Run .\tool\build_android_debug.ps1 first."
}

$devices = & $Adb devices | Select-String -Pattern "`tdevice$"
if (-not $devices) {
  throw "No Android phone is connected. Enable Developer options and USB debugging, then reconnect the phone."
}

& $Adb install -r $FullApkPath
