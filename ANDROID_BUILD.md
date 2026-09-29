# Сборка Android для Google Play

## Готовый пакет

Релиз собирается профилем **Android Play** в формате `.aab`. В нём включены ARMv7 и ARM64, минимальный API 24 и target API 36. Пакет подписывается upload-ключом; сам ключ не хранится в исходном проекте.

## Повторная сборка

1. Установите Godot 4.7.2 stable, JDK 17 и Android SDK с платформой Android 36, Build Tools 36.0.0 и NDK 28.1.13356709.
2. В редакторе Godot откройте **Editor → Editor Settings → Export → Android** и укажите каталоги JDK 17 и Android SDK.
3. Выберите **Project → Install Android Build Template**.
4. В **Project → Export** выберите профиль **Android Play** и задайте `keystore/release`, `keystore/release_user` и `keystore/release_password` из своего хранилища ключей.
5. Экспортируйте релиз в файл с расширением `.aab`.

Для сборки из командной строки Godot поддерживает переменные окружения `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` и `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Пароль не следует добавлять в проект или публиковать.

## Загрузка в Play Console

Создайте приложение в Google Play Console, укажите уникальный идентификатор пакета, заполните страницу магазина и обязательные декларации, затем загрузите AAB в тестовый или производственный трек. Для новых публикаций Google Play требует Android App Bundle. Целевой API 36 выбран с учётом срока действия требований API 36 с 31 августа 2026 года. Play App Signing управляет ключом подписи приложения, а созданный здесь upload-ключ используется для подтверждения загружаемых сборок.

Нынешний идентификатор `com.quietlake.fishing` может быть занят. Его нужно изменить до первой публикации, если Play Console не разрешит создать приложение с этим именем. Изменение идентификатора после первой публикации невозможно без создания отдельного приложения.
