# ЧЗОГ — мобильное приложение участника

Flutter-приложение организации **ЧЗОГ** для сотрудников: личный кабинет, приказы,
объекты, смены, проходы, чат — в кармане.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=fff)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=fff)
![Firebase](https://img.shields.io/badge/Firebase-FCM-FFCA28?logo=firebase&logoColor=000)
![License](https://img.shields.io/badge/license-private-red)

## Возможности

- **Вход и безопасность:** логин/пароль + 2FA TOTP; PIN и биометрия (блокировка приложения).
- **Приказы:** поиск/фильтры, подпись/отложение, PDF.
- **Объекты:** карточки, фото, карта объектов.
- **Смены:** календарь-месяц, старт/сдача (отчёт с фото), замена.
- **Проходы:** QR-чекин + геолокация + статус «на объекте».
- **Инцидент:** шаблоны, фото (камера/галерея), GPS. **Заявка** — баг/идея/доступ.
- **Чат:** realtime (Centrifugo), комнаты отделов + DM, «кто онлайн», «печатает…».
- **Новости и уведомления** (колокольчик, push FCM).
- **Офлайн-очередь** действий, **авто-обновление** APK, тёмная тема.

## Стек

Flutter/Dart · Material 3 · без стейт-менеджмента (`StatefulWidget` + `FutureBuilder`).
Пакеты: `http`, `flutter_secure_storage`, `firebase_core`, `firebase_messaging`,
`flutter_local_notifications`, `mobile_scanner`, `geolocator`, `image_picker`,
`webview_flutter`, `url_launcher`, `package_info_plus`, `path_provider`, `open_filex`,
`shared_preferences`, `centrifuge`, `flutter_chat_ui`.

## Сборка и релиз

```bash
flutter build apk --release          # подпись: android/key.properties (в .gitignore)
# APK → uploads/app/chzog-<ver>.apk на сайте; авто-обновление по /api/app/version
gh release create vX.Y.Z build/app/outputs/flutter-apk/app-release.apk
```

`android/app/google-services.json` — вне репозитория (.gitignore), проект Firebase `iniproject-chzog`.

## API

`https://chzog.iniproject.ru/api/*` (Bearer-токен). См. `app/routers/app_api.py` в `chzog-v2`.

## Связанные репозитории

- [`chzog-v2`](https://github.com/SkilinPur/chzog-v2) — сайт и API (бэкенд)
- [`chzog-admin`](https://github.com/SkilinPur/chzog-admin) — админ-приложение
- [`chzog-bot`](https://github.com/SkilinPur/chzog-bot) — Telegram-бот
