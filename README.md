# ЧЗОГ — мобильное приложение участника

Flutter-приложение организации ЧЗОГ для сотрудников.

## Возможности
- Вход (логин/пароль + 2FA TOTP), профиль (данные, смена пароля, 2FA, часовой пояс, привязка Telegram, напоминание о смене).
- Приказы (поиск/фильтры, подпись/отклонение, PDF), объекты (карточки, фото, карта объектов), смены (календарь-месяц, старт/сдача с отчётом и фото, замена), проходы (QR + геолокация + «на объекте»), инцидент (шаблоны, фото, GPS), заявка, новости, уведомления (колокольчик).
- Офлайн-очередь действий, авто-обновление APK с GitHub, push (Firebase FCM), баннер уведомлений при открытом приложении.

## Стек
- Flutter/Dart, Material 3, тёмная тема; без стейт-менеджмента (`StatefulWidget` + `FutureBuilder`).
- Пакеты: `http`, `flutter_secure_storage`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `mobile_scanner`, `geolocator`, `image_picker`, `webview_flutter`, `url_launcher`, `package_info_plus`, `path_provider`, `open_filex`, `shared_preferences`.

## Сборка и релиз
```bash
flutter build apk --release          # подпись: android/key.properties (в .gitignore)
# APK → uploads/app/chzog-<ver>.apk на сайте; авто-обновление по /api/app/version
gh release create vX.Y.Z build/app/outputs/flutter-apk/app-release.apk
```
`android/app/google-services.json` — вне репозитория (.gitignore), проект Firebase `iniproject-chzog`.

## API
`https://chzog.iniproject.ru/api/*` (Bearer-токен). См. `app/routers/app_api.py` в chzog-v2.
