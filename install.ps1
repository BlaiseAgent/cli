<#
.SYNOPSIS
Installs the blaise CLI: the latest release, or the version given with -Version.

.DESCRIPTION
  irm https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.ps1 | iex
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.ps1))) -Version 2026.10.2

BLAISE_INSTALL_DIR chooses where blaise is installed (default: %LOCALAPPDATA%\Programs\blaise\bin).
BLAISE_RELEASE_BASE_URL overrides where releases are downloaded from (used by the tests).
#>
param(
  [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Fail([string]$Message) {
  throw "install.ps1: $Message"
}

$BaseUrl = if ($env:BLAISE_RELEASE_BASE_URL) { $env:BLAISE_RELEASE_BASE_URL } else { "https://github.com/BlaiseAgent/cli/releases" }
$InstallDir = if ($env:BLAISE_INSTALL_DIR) { $env:BLAISE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "Programs\blaise\bin" }

if ($BaseUrl -like "*BlaiseAgent/cli*") {
  Fail "this copy of the script was not published by a release; set BLAISE_RELEASE_BASE_URL"
}

# Accept 2026.10.2 and v2026.10.2.
$Version = $Version.TrimStart("v")
if ($Version -and $Version -notmatch '^[0-9.]+$') {
  Fail "`"$Version`" is not a version such as 2026.10.2"
}

# --- platform -----------------------------------------------------------------

if ($PSVersionTable.PSEdition -eq "Core" -and -not $IsWindows) {
  Fail "this is not Windows: use install.sh instead (see the README of this repository)"
}

$Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
switch ($Architecture) {
  # Windows on Arm runs the x64 binary through emulation.
  { $_ -in "X64", "Arm64" } { $Arch = "x64" }
  default { Fail "no blaise binary for Windows on $Architecture; see https://askblaise.com/docs/cli" }
}

# --- version ------------------------------------------------------------------

function Get-LatestVersion {
  # /latest redirects to /tag/v<version>; read the redirect rather than follow it.
  $location = $null
  try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/latest" -MaximumRedirection 0 -UseBasicParsing -ErrorAction Stop
    $location = $response.Headers["Location"]
  } catch {
    # Windows PowerShell 5.1 throws on a redirect it was told not to follow.
    $response = $_.Exception.Response
    if ($null -ne $response -and $null -ne $response.Headers) {
      $location = $response.Headers["Location"]
      if ($null -eq $location -and $response.Headers.Location) { $location = $response.Headers.Location.ToString() }
    }
  }
  if ($location -is [array]) { $location = $location[0] }
  if ($location -match '/tag/v([0-9.]+)$') { return $Matches[1] }
  Fail "could not find the latest release at $BaseUrl"
}

if (-not $Version) { $Version = Get-LatestVersion }

$Asset = "blaise-$Version-windows-$Arch.zip"
$ReleaseUrl = "$BaseUrl/download/v$Version"

# --- download and verify ------------------------------------------------------

$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("blaise-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Temp | Out-Null
try {
  Write-Host "Installing blaise $Version for windows-$Arch"
  try {
    Invoke-WebRequest -Uri "$ReleaseUrl/checksums.txt" -OutFile (Join-Path $Temp "checksums.txt") -UseBasicParsing
    Invoke-WebRequest -Uri "$ReleaseUrl/$Asset" -OutFile (Join-Path $Temp $Asset) -UseBasicParsing
  } catch {
    Fail "could not download from $ReleaseUrl ($($_.Exception.Message))"
  }

  $Expected = $null
  foreach ($line in Get-Content (Join-Path $Temp "checksums.txt")) {
    if ($line -match '^([0-9a-fA-F]{64}) [ *](.+)$' -and $Matches[2] -eq $Asset) { $Expected = $Matches[1].ToLowerInvariant() }
  }
  if (-not $Expected) { Fail "checksums.txt has no entry for $Asset" }
  $Actual = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $Temp $Asset)).Hash.ToLowerInvariant()
  if ($Expected -ne $Actual) {
    Fail "checksum mismatch for $Asset (expected $Expected, got $Actual); nothing was installed"
  }

  # --- install ----------------------------------------------------------------

  $Extract = Join-Path $Temp "extract"
  Expand-Archive -Path (Join-Path $Temp $Asset) -DestinationPath $Extract
  $Binary = Join-Path $Extract "blaise.exe"
  if (-not (Test-Path $Binary)) { Fail "$Asset does not contain blaise.exe" }

  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $Target = Join-Path $InstallDir "blaise.exe"
  # A running blaise.exe cannot be overwritten, but it can be renamed out of the way.
  if (Test-Path $Target) { Move-Item -Force $Target "$Target.old" -ErrorAction SilentlyContinue }
  Copy-Item -Force $Binary $Target
  Remove-Item -Force "$Target.old" -ErrorAction SilentlyContinue

  Write-Host "Installed blaise $Version to $Target"
  $OnPath = ($env:PATH -split ";") -contains $InstallDir
  if (-not $OnPath) {
    Write-Host ""
    Write-Host "$InstallDir is not on your PATH. Add it for your user with:"
    Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `"$InstallDir;`" + [Environment]::GetEnvironmentVariable('PATH', 'User'), 'User')"
  }
} finally {
  Remove-Item -Recurse -Force $Temp -ErrorAction SilentlyContinue
}
