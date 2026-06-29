# goVLESS — Anten-ka (Lite)

VPN на базе **3X-UI + Xray (VLESS Reality)** с маскировкой под чужой сайт: anti-DPI, XTLS-Vision, без домена. Это community-сборка — режим **Lite**. Pro-режим (свой домен + TLS, сайт-прикрытие, Telegram-бот и мини-приложение) доступен подписчикам **Anten-ka Club**.

## Требования
- Чистый VPS на **Ubuntu/Debian**, доступ **root** (через `sudo`).
- Рекомендуется сервер **без уже установленного 3X-UI** (если панель уже есть — см. ниже).

## Установка

```bash
sudo apt update && sudo apt install -y git curl openssl qrencode systemd && rm -rf ~/self-signed-cert-script-by-antenka && git clone https://github.com/anten-ka/self-signed-cert-script-by-antenka.git && cd self-signed-cert-script-by-antenka && chmod +x self_signed_cert.sh && sudo ./self_signed_cert.sh
```

Скрипт сам доустановит остальные зависимости (sqlite3, jq, python3), поставит 3X-UI + Xray, поднимет VLESS Reality и выдаст ключи и QR-коды.

## Что спросит установщик
1. **Язык** — русский / English.
2. **Дисклеймер** — принять (1).
3. **Режим** — *Lite (Reality)* по умолчанию (Pro/«Ленивый» показывают экран клуба).
4. **Сайт маскировки** — список из 100 RU / 100 международных сайтов (определяется по гео сервера), каждый проверен реальным Reality-хендшейком; можно ввести свой (пункт 0).
5. **Версия панели** — 3X-UI v3.4.1 (новая) или v2.9.4 (как во всех гайдах).
6. **Транспорт** — TCP (рекомендуется).
7. **Отпечаток** (fingerprint) и **число ключей**.

В конце — данные для входа в панель, ключи и QR. Сканируйте ключ в приложении **INCY** (iOS / Android).

## Управление после установки
Команда **`govless`** открывает меню:
- **VPN** — установить/обновить, перезапуск, логи
- **Пользователи** — список, ссылки, QR-коды
- **Управление** — бэкап/восстановление, удаление
- **⭐ Перейти на PRO** — сравнение Lite vs PRO + вступление в клуб
- **🏆 Правильный хостинг** — проверенные партнёры с промокодами
- **О программе**

## Если на сервере уже стоит 3X-UI
Установщик не тронет вашу панель, а предложит: открыть её, сбросить логин/пароль, удалить (с бэкапом) и поставить goVLESS, либо выйти.

## Ссылки
- YouTube: https://www.youtube.com/antenkaru
- Boosty: https://boosty.to/anten-ka
- Anten-ka Club: https://vk.cc/cUQNzV

© 2025–2026 anten-ka. Source-available (см. файл LICENSE).
