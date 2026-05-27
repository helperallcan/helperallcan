$ErrorActionPreference = "Stop"

function Resolve-ProjectFlutter {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $candidates = @()

  if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    $candidates += Join-Path $env:USERPROFILE "Desktop\HelperWork\.tools\flutter\bin\flutter.bat"
  }

  $candidates += Join-Path $RepoRoot ".tools\flutter\bin\flutter.bat"

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  $command = Get-Command flutter -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  throw "Flutter was not found. Install Flutter or create the HelperWork workspace link."
}

function Invoke-CheckedFlutter {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Flutter,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$FailureMessage
  )

  & $Flutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
}
