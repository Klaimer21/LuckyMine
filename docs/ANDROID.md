# Сборка LuckyMine на Android (debug-APK по USB)

Нужно один раз подготовить компьютер. Эти шаги я не мог проверить: Godot у меня нет. Проверьте их по документации
Godot «Exporting for Android» (docs.godotengine.org), если шаг не сходится.

## Один раз
1. **Godot 4.4** (стандартная, не .NET) и **шаблоны экспорта**: в редакторе Editor → Manage Export Templates → Download.
2. **JDK 17** (например, Temurin 17).
3. **Android SDK**: проще всего поставить Android Studio, затем SDK Manager: Android SDK Platform-Tools,
   Command-line Tools, Build-Tools 34.0.0, Platform 34, NDK не нужен.
4. **Debug-ключ** (JDK):
   `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12`
5. В Godot: Editor → Editor Settings → Export → Android: укажите путь к Android SDK, JDK и debug.keystore
   (пользователь `androiddebugkey`, пароль `android`).

## Проект
1. Скопируйте `export_presets.android.example.cfg` в `export_presets.cfg` рядом с `project.godot`
   (или Проект → Экспорт → Add → Android и повторите настройки из примера).
   Важное в пресете: `arm64-v8a`, `package/unique_name`, разрешение `VIBRATE` (без него нет вибрации),
   иконка `res://icon.png`, исключены `tools/`, `docs/`, `tests/`.
2. Включите на телефоне «Режим разработчика» и «Отладка по USB», подключите кабелем, разрешите отладку.
3. В Godot справа вверху появится значок Android (Remote Debug): нажмите — игра соберётся и запустится на телефоне.
   Либо Проект → Экспорт → Export Project → `build/LuckyMine.apk` и `adb install -r build/LuckyMine.apk`.

## Что смотреть на телефоне
- **FPS**: Настройки → «Показывать FPS»; «Тест нагрузки» на 15 секунд для выбранного качества. Для телефона начните
  со «Среднее» и сглаживания «Авто» или MSAA 2x.
- **Кнопки и текст**: достаточно ли они крупны для пальца, не закрывает ли чёлка счётчик (интерфейс сдвигается
  в безопасную область экрана автоматически).
- **Экран не гаснет** (настройка «Не гасить экран»), сохранение при сворачивании, вибрация.
- Звук: музыка и эффекты, громкость отдельно.

## iPhone
Нужен Mac с Xcode и Apple Developer аккаунт (99 $/год). Godot экспортирует Xcode-проект (Проект → Экспорт → iOS),
дальше сборка и установка в Xcode, раздача тестерам через TestFlight. Для первой проверки сборки хватит бесплатного аккаунта
(установка на свой телефон на 7 дней).

## Публикация (позже)
Google Play: аккаунт 25 $ разово, подписанный **AAB** (Gradle-сборка, release-ключ), политика конфиденциальности,
согласие на данные (если будет реклама AdMob). Ключ хранить отдельно и не коммитить (поэтому `export_presets.cfg` в .gitignore).

## Реклама: что нужно до релиза
Сейчас в `scripts/ads.gd` окно-заглушка. Для настоящей рекламы:
1. Плагин AdMob для Godot 4 (Android), ID приложения и рекламных блоков (тестовые ID Google на время разработки).
2. Подключить показ в `Ads._show_video()`: награда выдаётся только в обратном вызове «просмотрено», закрытие раньше награды не даёт.
3. Согласие на данные (Google UMP) до первого показа, для ЕС/Великобритании обязательно; кнопка пересмотра согласия в настройках.
4. Политика конфиденциальности (ссылка в Google Play и в игре), анкета Data safety.
5. В пресете включены `INTERNET` и `ACCESS_NETWORK_STATE`; если рекламы не будет, выключите.
6. Кнопка «Назад» закрывает верхнее окно (`Modal`), приложение при этом не закрывается (`run/quit_on_go_back=false`).
