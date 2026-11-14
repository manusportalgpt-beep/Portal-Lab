# Portal Lab

Мобильный лаунчер Minecraft для **Android** и **iOS**: сборки, модпаки, моды с **Modrinth** и **CurseForge**, аккаунты **Microsoft** и **офлайн**. Одна кодовая база на Flutter, Material 3, десяток палитр и акцентных цветов.

![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## Возможности

- **Сборки (инстансы)** — создание с выбором версии Minecraft (релизы и снапшоты) и загрузчика: Vanilla, Fabric, Quilt, Forge, NeoForge. Управление модами, экспорт в zip.
- **Каталог модов** — поиск по Modrinth и CurseForge: моды, модпаки, ресурспаки, шейдеры. Фильтры по версии игры и загрузчику, сортировки, бесконечная прокрутка.
- **Установка в один тап** — совместимая версия мода подбирается автоматически под выбранную сборку.
- **Модпаки** — установка `.mrpack` (Modrinth) и CurseForge-архивов целиком: загрузчик, версия и все файлы разворачиваются в новую сборку.
- **Аккаунты** — вход Microsoft (OAuth device flow, публичный Client ID Prism Launcher, Xbox Live → XSTS → Minecraft Services), офлайн-аккаунты, скины, обновление токенов.
- **Загрузки** — очередь с прогрессом, ограничение параллельности, вкладка загрузок.
- **Оформление** — светлая/тёмная/чёрная (AMOLED) темы, 10 палитр, 16 акцентных цветов, RU/EN.

## Сборки

CI собирает приложение при каждом пуше (вкладка **Actions**):

- **Android** — подписанный APK (artifact `PortalLab-Android`)
- **iOS** — unsigned `.app` в zip (artifact `PortalLab-iOS`), для установки нужен свой Apple ID / подпись

Локально:

```bash
flutter create --platforms=android,ios --org dev.portallab --project-name portal_lab .
flutter pub get
flutter run
```

## Запуск игры

- **Android**: Java-версия Minecraft запускается через [PojavLauncher](https://play.google.com/store/apps/details?id=net.kdt.pojavlaunch) — экспортируйте сборку из Portal Lab и подключите её в Pojav.
- **iOS**: запуск Java-версии технически невозможен из-за ограничений платформы — Portal Lab используется как менеджер сборок и модов.

## Лицензии и ключи

- Код — GPL-3.0.
- Microsoft OAuth Client ID — публичный ID из открытых исходников [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher) (device flow).
- CurseForge API-ключ — публичный ключ из открытых исходников Prism Launcher (условия CurseForge 3rd Party API).
- Modrinth API используется согласно правилам [modrinth.com](https://modrinth.com).

<sub>Created with Perplexity</sub>
