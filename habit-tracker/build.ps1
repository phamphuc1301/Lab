<#
.SYNOPSIS
  Builds the Windows app (PyInstaller) and the installer (Inno Setup) into .\dist

.EXAMPLE
  .\build.ps1                 # app + portable zip + installer
  .\build.ps1 -SkipInstaller  # app + portable zip only
#>
param([switch]$SkipInstaller)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
Set-Location $root

function Invoke-Checked {
    # Uses $args (no named params) so flags like -e/-m pass straight through.
    # Native tools log to stderr; rely on the exit code instead of PowerShell's error stream.
    $exe, $rest = $args
    $ErrorActionPreference = "Continue"
    & $exe @rest
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $args" }
}

$venv = Join-Path $root ".venv-build"
$py = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host "Creating build environment..." -ForegroundColor Cyan
    Invoke-Checked python -m venv $venv
}
Write-Host "Installing dependencies..." -ForegroundColor Cyan
Invoke-Checked $py -m pip install --quiet --upgrade pip
Invoke-Checked $py -m pip install --quiet -e ".[build]"

$icon = Join-Path $root "src\habit_tracker\assets\icon.ico"
if (-not (Test-Path $icon)) { Invoke-Checked $py tools\make_icon.py }

$version = (& $py -c "import habit_tracker; print(habit_tracker.__version__)").Trim()
Write-Host "Building Habit Tracker $version..." -ForegroundColor Cyan

Invoke-Checked $py -m PyInstaller --noconfirm --clean --windowed `
    --name HabitTracker `
    --icon $icon `
    --add-data "$root\src\habit_tracker\assets;habit_tracker\assets" `
    --collect-data customtkinter `
    --hidden-import pystray._win32 `
    --distpath "$root\build\dist" --workpath "$root\build\work" --specpath "$root\build" `
    "$root\packaging\launcher.py"

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist "HabitTracker-$version-portable.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$root\build\dist\HabitTracker" -DestinationPath $zip
Write-Host "Portable build: $zip" -ForegroundColor Green

if ($SkipInstaller) { return }

$iscc = @(
    (Get-Command iscc.exe -ErrorAction SilentlyContinue | ForEach-Object Source),
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $iscc) {
    Write-Warning "Inno Setup 6 not found, so the installer was skipped."
    Write-Warning "Install it with:  winget install JRSoftware.InnoSetup   then run .\build.ps1 again."
    return
}
Invoke-Checked $iscc /Qp "/DAppVersion=$version" "$root\packaging\installer.iss"
Write-Host "Installer: $dist\HabitTrackerSetup-$version.exe" -ForegroundColor Green
