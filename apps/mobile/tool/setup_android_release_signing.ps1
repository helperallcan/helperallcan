param(
  [string]$KeystoreDir = "$env:USERPROFILE\.zhao_bang_shou",
  [string]$Alias = "zhao-bang-shou"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$AndroidRoot = Join-Path $ProjectRoot "android"
$KeyProperties = Join-Path $AndroidRoot "key.properties"
$KeystorePath = Join-Path $KeystoreDir "android_upload_keystore.jks"
$Keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"

if (-not (Test-Path -LiteralPath $Keytool)) {
  throw "keytool was not found at $Keytool"
}

function New-SigningPassword {
  $bytes = New-Object byte[] 24
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($bytes)
  } finally {
    $rng.Dispose()
  }
  return ([Convert]::ToBase64String($bytes) -replace '[^a-zA-Z0-9]', '').Substring(0, 24)
}

New-Item -ItemType Directory -Path $KeystoreDir -Force | Out-Null

if (Test-Path -LiteralPath $KeystorePath) {
  throw "Keystore already exists at $KeystorePath. Move it or pass a different -KeystoreDir if you need a new key."
}

$storePassword = New-SigningPassword
$keyPassword = $storePassword

& $Keytool -genkeypair `
  -v `
  -keystore $KeystorePath `
  -storetype PKCS12 `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias $Alias `
  -storepass $storePassword `
  -keypass $keyPassword `
  -dname "CN=Zhao Bang Shou, OU=Mobile, O=HelperAllCan, L=Kuala Lumpur, ST=Kuala Lumpur, C=MY"

$normalizedKeystorePath = $KeystorePath.Replace("\", "/")
@"
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$Alias
storeFile=$normalizedKeystorePath
"@ | Set-Content -LiteralPath $KeyProperties -Encoding ASCII

Write-Host "Created keystore: $KeystorePath"
Write-Host "Created local signing config: $KeyProperties"
Write-Host "Back up both files. They are required to update the same Android app later."
