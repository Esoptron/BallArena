param(
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Desktop\Программирование\Godot_v4.7.2-stable_win64.exe')
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Укажите путь к Godot через -GodotPath.' }
$buildDirectory = Join-Path $projectDirectory 'builds\android'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$apkPath = Join-Path $buildDirectory 'BallArena-test.apk'
$logPath = Join-Path $buildDirectory 'export.log'
# Import new assets first. SDK paths and debug signing are kept in Godot Editor Settings.
$engine = Start-Process -FilePath $GodotPath -WorkingDirectory $projectDirectory -ArgumentList '--headless --editor --path . --import' -WindowStyle Hidden -PassThru -Wait
if ($engine.ExitCode -ne 0) { throw 'Ошибка импорта ресурсов Godot.' }
$engine = Start-Process -FilePath $GodotPath -WorkingDirectory $projectDirectory -ArgumentList '--headless --path . --export-debug "Android Test" builds/android/BallArena-test.apk --log-file builds/android/export.log' -WindowStyle Hidden -PassThru -Wait
$log = Get-Content -LiteralPath $logPath -Raw
if ($engine.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:' -or -not (Test-Path -LiteralPath $apkPath)) { throw "Ошибка сборки. Журнал: $logPath" }
Write-Output "Готово: $apkPath"
