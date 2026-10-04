# Направи своя версия или предложи промяна

1. Натисни **Fork**. Работиш в собствено копие; не е нужен достъп за запис в оригинала.
2. Клонирай fork-а и създай branch: `git switch -c feature/new-cyborgs`.
3. Следвай setup инструкциите в README и промени механика, визия или ниво.
4. Изпълни `python3 tools/project.py test`. При визуални промени направи desktop preview; при промени по жестове/VR — и Quest тест.
5. Commit и push към своя fork. За промяна в оригинала отвори **Pull Request** с описание, тестове и снимка/видео, ако променяш визията.

За самостоятелна версия смени Android package/name в `export_presets.cfg`, заглавието в `title_screen.gd`, името в `project.godot` и README. Запази MIT copyright/license notices и лицензите на външните компоненти. Публикувай свой APK в Releases на fork-а си.

## Практически правила

- Hand tracking е единственият вход в Quest build-а. Desktop demo не трябва да се активира на Android.
- `rules.gd` е отделен от рендера. Проверявай реално промененото поведение, особено стрелба без помпане и случайна пауза.
- Не качвай `.godot/`, Android/Gradle кешове, signing keys, локални пътища или APK в Git историята. APK се публикува като Release asset.
- Не представяй desktop/synthetic тест като физически тест. Посочи устройството и какво е проверено.
- Новите assets трябва да са твои или с подходящ лиценз; добави произхода в THIRD_PARTY.

## Локална конфигурация

Ползвай `GODOT`, `ADB`, `AAPT`, `JAVA_HOME`, `ANDROID_HOME`, или локален `.local-tools.json` с ключове `godot`, `adb`, `aapt`, `java_home`. Файлът е игнориран от Git. Не записвай абсолютни пътища от своя компютър в споделените scripts.
