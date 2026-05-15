#!/bin/bash
# XUIFAST v3.0.0 — Russian translations
# shellcheck disable=SC2034,SC2148

# ── Common ─────────────────────────────────────────────────────────────
I18N[yes]="Да"
I18N[no]="Нет"
I18N[back]="« Назад"
I18N[exit]="Выход"
I18N[choose]="Выбор"
I18N[press_enter]="Нажмите Enter..."
I18N[press_enter_return]="Нажмите Enter для возврата в меню..."
I18N[invalid_choice]="Неверный выбор"
I18N[running]="работает"
I18N[stopped]="остановлен"
I18N[not_installed]="не установлен"
I18N[wait]="Подождите..."

# ── Banner ─────────────────────────────────────────────────────────────
I18N[banner_subtitle]="3X-UI + VLESS Reality / TLS"
I18N[banner_features]="Маскировка • Anti-DPI • XTLS-Vision"
I18N[credits_title]="Благодарности / Credits"

# ── Dependencies ───────────────────────────────────────────────────────
I18N[deps_installing]="Установка зависимостей: %s"
I18N[deps_installed]="Зависимости установлены"

# ── Main menu ──────────────────────────────────────────────────────────
I18N[dashboard_title]="Панель управления"
I18N[menu_proxy]="VPN              ▸"
I18N[menu_users]="Пользователи     ▸"
I18N[menu_stats]="Статистика       ▸"
I18N[menu_manage]="Управление       ▸"
I18N[menu_about]="О программе      ▸"
I18N[auto_refresh_30s]="Обновление через 30 сек"

# ── Status dashboard ───────────────────────────────────────────────────
I18N[svc_xui]="3X-UI"
I18N[svc_xray]="Xray"
I18N[svc_nginx]="nginx"
I18N[svc_site]="Сайт"
I18N[svc_ssl]="SSL"
I18N[ssl_until]="до %s"
I18N[net_ip]="IP:"
I18N[net_port]="Порт:"
I18N[net_mode]="Режим:"
I18N[net_domain]="Домен:"
I18N[net_users]="Польз.:"
I18N[vpn_not_configured]="VPN не настроен. Выберите пункт 1."
I18N[dashboard_xui_ver]="3X-UI:"

# ── Выбор версии 3X-UI ────────────────────────────────────────────────
I18N[xui_version_title]="Выберите версию панели 3X-UI"
I18N[xui_version_detecting]="Определяю последние версии..."
I18N[xui_version_new_gen]="Новое поколение"
I18N[xui_version_new_desc]="Vue 3 интерфейс, новый API, современный UI (рекомендуется)"
I18N[xui_version_legacy]="Legacy (стабильная)"
I18N[xui_version_legacy_desc]="Классический UI, проверенная стабильность"
I18N[xui_version_choice]="Ваш выбор [1/2]:"
I18N[xui_version_selected]="Выбрано: %s"
I18N[xui_installing_version]="Установка 3X-UI %s..."

# ── Выбор транспорта ───────────────────────────────────────────────────
I18N[transport_title]="Выберите транспортный протокол"
I18N[transport_tcp_desc]="Рекомендуется для большинства"
I18N[transport_xhttp_desc]="Попробуйте, если TCP не работает"
I18N[transport_grpc_desc]="Попробуйте, если TCP не работает"
I18N[transport_choice]="Ваш выбор [1/2/3]:"
I18N[transport_selected]="Транспорт: %s"
I18N[config_transport]="Транспорт:"

# ── Install flow ───────────────────────────────────────────────────────
I18N[install_select_mode]="🎭 Выберите режим маскировки:"
I18N[install_lite_title]="⚡ Lite — маскировка под чужой сайт (Reality)"
I18N[install_lite_desc1]="Быстро, без домена. Xray имитирует TLS"
I18N[install_lite_desc2]="выбранного сайта через протокол Reality."
I18N[install_lite_desc3]="DPI видит подключение к реальному сайту."
I18N[install_pro_title]="🛡  Pro — свой сайт + полная маскировка (TLS)"
I18N[install_pro_desc1]="nginx + Let's Encrypt + HTML-шаблон + 3X-UI."
I18N[install_pro_desc2]="DPI видит реальный сайт с реальным сертификатом."
I18N[install_pro_desc3]="Требует: домен, направленный на этот сервер."
I18N[install_mode_choice]="Выбор (1/2):"
I18N[install_lite_step]="Установка Lite-режима (Reality)"
I18N[install_pro_step]="Установка Pro-режима (TLS)"

# ── Lite mode ──────────────────────────────────────────────────────────
I18N[lite_select_domain]="🌐 Выберите сайт для маскировки:"
I18N[lite_ru_domains]="Популярные российские сайты"
I18N[lite_int_domains]="Популярные международные сайты"
I18N[lite_detected_geo]="Определено: IP сервера — %s"
I18N[lite_testing_domain]="Проверка домена %s..."
I18N[lite_domain_ok]="Домен %s подходит для Reality"
I18N[lite_domain_fail]="Домен %s не подходит (нет TLSv1.3 или H2)"

# ── Pro mode ───────────────────────────────────────────────────────────
I18N[pro_enter_domain]="Введите ваш домен (например, example.com):"
I18N[pro_bad_domain]="Некорректный домен: %s"
I18N[pro_dns_mismatch]="Домен %s указывает на %s, а не на %s"
I18N[pro_continue_anyway]="Продолжить всё равно?"
I18N[pro_enter_email]="Email для SSL (Enter = без email):"

# ── 3X-UI installation ────────────────────────────────────────────────
I18N[xui_installing]="Установка 3X-UI..."
I18N[xui_installed]="3X-UI установлен"
I18N[xui_already_installed]="3X-UI уже установлен"
I18N[xui_install_failed]="Ошибка установки 3X-UI"
I18N[xui_starting]="Запуск 3X-UI..."
I18N[xui_started]="3X-UI запущен"
I18N[xui_stopped]="3X-UI остановлен"
I18N[xui_restarted]="3X-UI перезапущен"
I18N[xui_removing]="Удаление 3X-UI..."
I18N[xui_removed]="3X-UI удалён"

# ── API ────────────────────────────────────────────────────────────────
I18N[api_waiting]="Ожидание API панели..."
I18N[api_login_ok]="Авторизация в панели OK"
I18N[api_login_fail]="Ошибка авторизации в панели"
I18N[api_creating_inbound]="Создание VPN-подключения..."
I18N[api_inbound_created]="VPN-подключение создано (порт 443)"
I18N[api_inbound_failed]="Ошибка создания подключения"

# ── Users ──────────────────────────────────────────────────────────────
I18N[users_ask_count]="Сколько VPN-ключей создать?"
I18N[users_ask_count_hint]="(1-100, по умолчанию: 3)"
I18N[users_creating]="Создание %d пользователей..."
I18N[users_created]="Создано %d пользователей"
I18N[users_title]="👥 Пользователи VPN"
I18N[users_show_all]="Показать всех пользователей?"
I18N[user_online]="🟢 онлайн"
I18N[user_offline]="⚪ оффлайн"

# ── VLESS links & QR ──────────────────────────────────────────────────
I18N[vless_link_title]="🔗 Ссылка для подключения:"
I18N[qr_title]="📱 QR-код для %s:"
I18N[qr_scan_hint]="Отсканируйте в Hiddify / V2rayNG / Streisand"

# ── Credentials ────────────────────────────────────────────────────────
I18N[creds_title]="🔐 Данные для входа в панель 3X-UI"
I18N[creds_url]="URL:"
I18N[creds_user]="Логин:"
I18N[creds_pass]="Пароль:"
I18N[creds_saved]="Данные сохранены в %s"

# ── Connection test ────────────────────────────────────────────────────
I18N[test_title]="🔍 Проверка подключения"
I18N[test_checking]="Проверка пользователя %s..."
I18N[test_online]="✅ %s — подключён"
I18N[test_offline]="⏳ %s — ожидание подключения"
I18N[test_skip]="Нажмите Enter чтобы пропустить"

# ── App download ───────────────────────────────────────────────────────
I18N[app_title]="📱 Скачайте VPN-приложение"
I18N[app_platform]="Выберите платформу:"
I18N[app_ios]="iOS (iPhone/iPad)"
I18N[app_android]="Android"
I18N[app_ios_hint]="Установите Hiddify из App Store"
I18N[app_android_hint]="Установите Hiddify из Google Play"
I18N[app_installed]="Приложение установлено?"

# ── Config summary ─────────────────────────────────────────────────────
I18N[config_title]="📋 Конфигурация:"
I18N[config_ip]="IP:"
I18N[config_port]="Порт:"
I18N[config_mode]="Режим:"
I18N[config_mask]="Маскировка:"
I18N[config_domain]="Домен:"
I18N[config_users]="Пользователей:"
I18N[config_confirm]="Установить VPN?"

# ── Website / Templates ────────────────────────────────────────────────
I18N[website_title]="🌐 Управление сайтом"
I18N[website_deploying]="Развёртывание шаблона сайта..."
I18N[website_deployed]="Шаблон сайта развёрнут"
I18N[website_only_pro]="Управление сайтом доступно только в pro-режиме"

# ── Каталог шаблонов ─────────────────────────────────────────────────
I18N[templates_categories]="Категории шаблонов сайтов:"
I18N[templates_custom_git]="🔗 Свой шаблон из Git (любой публичный репо)"
I18N[templates_random]="🎲 Случайный шаблон"
I18N[templates_count_fmt]="%s шаблонов"
I18N[templates_list]="Шаблоны в '%s':"
I18N[templates_cat_empty]="Категория пуста"
I18N[templates_preview_title]="Предпросмотр шаблона"
I18N[templates_name]="Название:"
I18N[templates_source]="Источник:"
I18N[templates_description]="Описание:"
I18N[templates_preview]="🔗 Превью:"
I18N[templates_preview_hint]="(откройте в браузере для просмотра)"
I18N[templates_repo]="Репозиторий:"
I18N[templates_thanks]="Спасибо %s за открытый шаблон!"
I18N[templates_install_this]="Установить этот шаблон?"
I18N[templates_downloading]="Скачиваю шаблон '%s'..."
I18N[templates_downloaded]="Шаблон '%s' скачан"
I18N[templates_downloaded_subfolder]="Шаблон '%s' скачан (из подпапки)"
I18N[templates_no_index]="В шаблоне нет index.html"
I18N[templates_path]="Путь: %s"
I18N[templates_catalog_not_found]="Каталог шаблонов не найден: %s"
I18N[custom_git_title]="Свой Git-шаблон"
I18N[custom_git_help_1]="Можно использовать любой публичный Git-репозиторий как шаблон сайта."
I18N[custom_git_help_2]="Репозиторий должен содержать index.html (в корне, dist/, public/ или build/)."
I18N[custom_git_help_3]="Папка с сайтом определяется автоматически."
I18N[custom_git_formats]="Форматы URL:"
I18N[custom_git_fmt_github]="  https://github.com/user/repo"
I18N[custom_git_fmt_gitlab]="  https://gitlab.com/user/repo"
I18N[custom_git_fmt_gitext]="  https://any-git-host.com/user/repo"
I18N[custom_git_fmt_branch]="  https://github.com/user/repo@branch-name"
I18N[custom_git_auto_detect]="Автоопределение:"
I18N[custom_git_auto_1]="  ✓ index.html в корне"
I18N[custom_git_auto_2]="  ✓ Папки dist/, public/, build/"
I18N[custom_git_auto_3]="  ✓ Вложенный index.html (до 4 уровней)"
I18N[custom_git_auto_4]="  ✓ Выбор ветки через @branch"
I18N[custom_git_requirements]="Требования:"
I18N[custom_git_req_1]="  • Публичный репозиторий (без авторизации)"
I18N[custom_git_req_2]="  • Должен содержать index.html"
I18N[custom_git_req_3]="  • Максимум 100 МБ"
I18N[custom_git_req_4]="  • Только HTTPS-ссылки"
I18N[custom_git_examples]="Примеры:"
I18N[custom_git_ex_1]="  https://github.com/html5up/phantom"
I18N[custom_git_ex_2]="  https://github.com/StartBootstrap/startbootstrap-agency@main"
I18N[custom_git_enter_url]="Введите Git URL:"
I18N[custom_git_empty]="URL не может быть пустым"
I18N[custom_git_bad_url]="Неверный URL (должен начинаться с https://)"
I18N[custom_git_cloning]="Клонирую репозиторий..."
I18N[custom_git_clone_failed]="Ошибка клонирования: %s"
I18N[custom_git_too_big]="Репозиторий слишком большой: %s (макс 100МБ)"
I18N[custom_git_scanning]="Ищу index.html..."
I18N[custom_git_no_index]="index.html не найден в репозитории"
I18N[custom_git_found_at]="Сайт найден в: %s"
I18N[custom_git_installed]="Свой шаблон установлен из %s"

# ── Submenu: Proxy ─────────────────────────────────────────────────────
I18N[submenu_proxy_title]="🚀 VPN"
I18N[proxy_install_update]="Установить / Обновить"
I18N[proxy_status_detail]="Статус подробно"
I18N[proxy_show_links]="Показать ссылки"
I18N[proxy_show_qr]="QR-коды"
I18N[proxy_restart]="Перезапуск"
I18N[proxy_logs]="Логи"
I18N[proxy_change_mode]="Сменить режим / шаблон"

# ── Submenu: Manage ────────────────────────────────────────────────────
I18N[submenu_manage_title]="⚙️  УПРАВЛЕНИЕ"
I18N[manage_backup]="Бекап"
I18N[manage_restore]="Восстановить"
I18N[manage_update]="Обновить 3X-UI"
I18N[manage_site_ssl]="Сайт / SSL"
I18N[manage_remove]="Удалить"
I18N[manage_language]="Язык / Language"

# ── Submenu: About ─────────────────────────────────────────────────────
I18N[submenu_about_title]="ℹ️  О ПРОГРАММЕ"
I18N[about_version_info]="Информация о версии"
I18N[about_promo]="Промо / Донат"
I18N[version_title]="🔍 Информация"

# ── Remove ─────────────────────────────────────────────────────────────
I18N[remove_title]="🗑  Удаление XUIFAST"
I18N[remove_xui_only]="Удалить только 3X-UI"
I18N[remove_all]="Удалить всё (3X-UI + nginx + настройки)"
I18N[remove_confirm]="Вы точно уверены?"
I18N[remove_done]="XUIFAST полностью удалён"

# ── Backup ─────────────────────────────────────────────────────────────
I18N[backup_title]="💾 Бекап"
I18N[backup_creating]="Создание бекапа..."
I18N[backup_created]="Бекап создан: %s (%s)"
I18N[backup_restored]="Бекап восстановлен"

# ── Errors ─────────────────────────────────────────────────────────────
I18N[err_need_root]="Запустите скрипт с sudo / от root"
I18N[err_os_unknown]="Не удалось определить ОС. Требуется Linux."
I18N[err_low_disk]="Мало места на диске: %sMB (нужно %sMB+)"
I18N[lite_nginx_optional_fail]="Не удалось настроить stub-сайт nginx (не критично, VPN работает)"
I18N[api_login_fail_manual]="Не удалось подключиться к API панели. VPN можно настроить вручную через панель."
I18N[auto_config_fail]="Автонастройка не удалась. Панель установлена — настройте VPN вручную."
I18N[auto_config_incomplete]="Автонастройка завершена не полностью. Панель доступна — можете завершить настройку вручную."
I18N[bye]="До встречи! 👋"

# ── Completion ─────────────────────────────────────────────────────────
I18N[install_done]="XUIFAST v%s установлен! (%s-режим)"
I18N[install_done_hint]="Команда для управления: xuifast"
I18N[enjoy]="Удачи! 🚀"
