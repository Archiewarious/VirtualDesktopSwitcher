# Build script for Virtual Desktop Switcher
# Usage:
#   .\build.ps1              — compile dist\VirtualDesktopSwitcher.exe
#   .\build.ps1 -UpdateDll   — download the latest VirtualDesktopAccessor.dll first

param(
    [switch]$UpdateDll,
    [string]$Ahk2Exe = "$PSScriptRoot\.tools\Compiler\Ahk2Exe.exe",
    [string]$AhkBase = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Ahk2Exe)) {
    Write-Error "Ahk2Exe not found at $Ahk2Exe. Download: https://github.com/AutoHotkey/Ahk2Exe/releases"
}
if (-not (Test-Path $AhkBase)) {
    Write-Error "AutoHotkey v2 base not found at $AhkBase. Install AutoHotkey v2: https://www.autohotkey.com/"
}

if ($UpdateDll) {
    Write-Host "Fetching latest VirtualDesktopAccessor.dll release..."
    $release = Invoke-RestMethod "https://api.github.com/repos/Ciantic/VirtualDesktopAccessor/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -eq "VirtualDesktopAccessor.dll" } | Select-Object -First 1
    if (-not $asset) { Write-Error "No VirtualDesktopAccessor.dll asset in the latest release ($($release.tag_name))" }
    Invoke-WebRequest $asset.browser_download_url -OutFile "$PSScriptRoot\VirtualDesktopAccessor.dll"
    Write-Host "DLL updated to $($release.tag_name)"
}

if (-not (Test-Path "$PSScriptRoot\VirtualDesktopAccessor.dll")) {
    Write-Error "VirtualDesktopAccessor.dll missing next to the script. Run with -UpdateDll to download it."
}

New-Item -ItemType Directory -Force "$PSScriptRoot\dist" | Out-Null

$proc = Start-Process -FilePath $Ahk2Exe -ArgumentList @(
    '/in',   "`"$PSScriptRoot\VirtualDesktop.ahk`"",
    '/out',  "`"$PSScriptRoot\dist\VirtualDesktopSwitcher.exe`"",
    '/base', "`"$AhkBase`"",
    '/silent', 'verbose'
) -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -ne 0 -or -not (Test-Path "$PSScriptRoot\dist\VirtualDesktopSwitcher.exe")) {
    Write-Error "Compilation failed (exit code $($proc.ExitCode))"
}
Write-Host "OK: dist\VirtualDesktopSwitcher.exe"
