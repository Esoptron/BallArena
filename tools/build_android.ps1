param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent

if (-not $GodotPath) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
}
if (-not $GodotPath) {
    # Preserve the existing workstation setup as a last-resort local fallback.
    $GodotPath = Join-Path $env:USERPROFILE 'Desktop\Программирование\Godot_v4.7.2-stable_win64.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot не найден. Укажите -GodotPath, GODOT_BIN или добавьте godot в PATH.'
}

$buildDirectory = Join-Path $projectDirectory 'builds\android'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$apkPath = Join-Path $buildDirectory 'BallArena-test.apk'

function Invoke-CheckedGodot([string]$Arguments, [string]$LogName) {
    $relativeLog = 'builds/android/' + $LogName
    $absoluteLog = Join-Path $buildDirectory $LogName
    # An old PASS/export log must never mask a failed current invocation.
    [System.IO.File]::WriteAllText($absoluteLog, '')
    $engineProcess = Start-Process -FilePath $GodotPath -WorkingDirectory $projectDirectory `
        -ArgumentList ($Arguments + ' --log-file ' + $relativeLog) -WindowStyle Hidden -PassThru -Wait
    $currentLog = Get-Content -LiteralPath $absoluteLog -Raw
    if ($engineProcess.ExitCode -ne 0 -or $currentLog -match 'SCRIPT ERROR:|ERROR:') {
        throw "Godot завершился с ошибкой. Журнал: $absoluteLog"
    }
}

# SDK paths and signing credentials remain in the local Godot Editor Settings.
Invoke-CheckedGodot '--headless --editor --path . --import' 'import.log'
Invoke-CheckedGodot '--headless --path . --export-debug "Android Test" builds/android/BallArena-test.apk' 'export.log'
if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) { throw 'Godot не создал APK.' }
Write-Output "Готово: $apkPath"
