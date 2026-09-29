# Создаёт ключ подписи для RuStore и AppGallery (один раз!).
# Запуск в PowerShell:  .\tools\make_keystore.ps1
# Файл ключа и пароль обязательно сохрани в надёжном месте: без них приложение нельзя обновить.
param(
    [string]$Out = "$HOME\quietwaters-release.keystore",
    [string]$Alias = "quietwaters"
)
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue)
if (-not $keytool) {
    Write-Host "keytool не найден. Установи JDK 17 и добавь его в PATH." -ForegroundColor Red
    exit 1
}
keytool -genkeypair -v -keystore $Out -alias $Alias -keyalg RSA -keysize 2048 -validity 10000
Write-Host "Ключ создан: $Out (alias: $Alias)" -ForegroundColor Green
