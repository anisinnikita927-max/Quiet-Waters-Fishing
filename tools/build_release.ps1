# Собирает подписанные APK для RuStore и AppGallery.
# Пример:
#   .\tools\build_release.ps1 -Godot "$HOME\Desktop\Godot_v4.7.2-stable_win64.exe" `
#       -Keystore "$HOME\quietwaters-release.keystore" -Alias quietwaters -Password "ПАРОЛЬ"
# Нужны: Godot 4.7.2 с установленными шаблонами экспорта, Android SDK и JDK 17,
# указанные в Editor > Editor Settings > Export > Android (см. ANDROID_BUILD.md).
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [Parameter(Mandatory = $true)][string]$Keystore,
    [Parameter(Mandatory = $true)][string]$Alias,
    [Parameter(Mandatory = $true)][string]$Password,
    [ValidateSet("rustore", "appgallery", "both")][string]$Target = "both"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
New-Item -ItemType Directory -Force -Path "build" | Out-Null

$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = (Resolve-Path $Keystore).Path
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $Alias
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $Password

& $Godot --headless --path $root --import
$jobs = @()
if ($Target -in @("rustore", "both")) { $jobs += ,@("Android RuStore APK", "build/QuietWaters-rustore.apk") }
if ($Target -in @("appgallery", "both")) { $jobs += ,@("Android AppGallery APK", "build/QuietWaters-appgallery.apk") }
foreach ($j in $jobs) {
    Write-Host "Экспорт: $($j[0])" -ForegroundColor Cyan
    & $Godot --headless --path $root --export-release $j[0] $j[1]
    if ($LASTEXITCODE -ne 0) { throw "Экспорт $($j[0]) завершился с ошибкой" }
}
Write-Host "Готово. Файлы лежат в папке build\" -ForegroundColor Green
