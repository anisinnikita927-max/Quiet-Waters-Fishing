# Публикация в RuStore и Huawei AppGallery

В папке `store/` лежит всё для карточек:

| Что | Где |
| --- | --- |
| Иконки 512×512 и 216×216 | `store/assets/` |
| Промо-картинки | `store/assets/banner_*.png` |
| Скриншоты 1920×1080 | `store/screenshots/` |
| Тексты для RuStore | `store/rustore/description_ru.md` |
| Тексты для AppGallery | `store/appgallery/description_ru.md` |
| Политика конфиденциальности | `store/privacy_policy_ru.md` |

## Сборка APK

1. Один раз создай ключ подписи: `.\tools\make_keystore.ps1` — сохрани файл и пароль. Он нужен для всех обновлений.
2. Установи Godot 4.7.2, шаблоны экспорта, JDK 17 и Android SDK (подробности в [ANDROID_BUILD.md](../ANDROID_BUILD.md)).
3. Выполни:

```
.\tools\build_release.ps1 -Godot "C:\путь\Godot_v4.7.2-stable_win64.exe" -Keystore "$HOME\quietwaters-release.keystore" -Alias quietwaters -Password "ПАРОЛЬ"
```

Получатся `build\QuietWaters-rustore.apk` и `build\QuietWaters-appgallery.apk`. Их можно собрать и из редактора: **Project → Export**, пресеты **Android RuStore APK** и **Android AppGallery APK**.

## Перед отправкой

- Идентификатор пакета `com.quietlake.fishing` должен совпадать с тем, что создан в консоли магазина. Если в консоли другой, поменяй `package/unique_name` в каждом пресете.
- Каждое обновление требует увеличить `version/code` в пресетах.
- Укажи в политике конфиденциальности свой e-mail и опубликуй её по ссылке.
