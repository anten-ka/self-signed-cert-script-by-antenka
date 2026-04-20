#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  XUIFAST — Professional 3X-UI Installer                                      ║
# ║  Version: 2.1                                                                 ║
# ║  Author: anten-ka                                                              ║
# ║  Features: Bilingual, IP/Domain modes, Stub sites, VLESS auto-setup           ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────────
#  GLOBALS
# ─────────────────────────────────────────────────────────────────────────────────
LANG_CHOICE=""
MODE=""            # ip | domain
DOMAIN=""
SERVER_IP=""
XUI_DB="/etc/x-ui/x-ui.db"
XUI_PORT=""
XUI_USER=""
XUI_PASS=""
XUI_PATH=""
XUI_URL=""
CERT_PATH=""
KEY_PATH=""
STUB_SITE=""
LOG_FILE="/tmp/xuifast_install.log"
API_BASE=""
CREDS_FILE="/root/.xuifast_credentials"

# Global arrays for users (set in api_create_inbound, used in test/show)
USER_NAMES=()
USER_UUIDS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────────
#  CLEANUP TRAP (Ctrl+C safety)
# ─────────────────────────────────────────────────────────────────────────────────
cleanup() {
    tput cnorm 2>/dev/null || true
    rm -f /tmp/stub_clone_$$ /tmp/xui_cookie.txt /tmp/xuifast_payload.json 2>/dev/null
    echo ""
    if [[ "$LANG_CHOICE" == "ru" ]]; then
        echo -e "  ${YELLOW}⚠${RESET}  Установка прервана пользователем."
    else
        echo -e "  ${YELLOW}⚠${RESET}  Installation interrupted by user."
    fi
    exit 130
}
trap cleanup INT TERM

# ─────────────────────────────────────────────────────────────────────────────────
#  LOCALIZATION
# ─────────────────────────────────────────────────────────────────────────────────
declare -A L

set_lang_ru() {
    L[welcome]="Добро пожаловать в XUIFAST — установщик 3X-UI"
    L[choose_lang]="Выберите язык / Choose language"
    L[russian]="Русский"
    L[english]="English"
    L[choose_mode]="Выберите режим работы"
    L[mode_ip]="По IP-адресу  (без домена, быстрая настройка)"
    L[mode_domain]="По доменному имени  (нужен свой домен)"
    L[mode_ip_hint]="Подходит если у вас нет домена. Сертификат выпускается автоматически."
    L[mode_domain_hint]="Более надёжный вариант. Нужен домен, направленный на этот сервер."
    L[enter_domain]="Введите ваш домен (например: example.com)"
    L[domain_empty]="Домен не может быть пустым! Попробуйте ещё раз."
    L[checking_domain]="Проверка домена..."
    L[domain_ok]="Домен успешно направлен на этот сервер!"
    L[domain_fail]="Домен НЕ направлен на этот сервер."
    L[domain_ip_mismatch]="Домен указывает на IP: %s, а IP сервера: %s"
    L[domain_how_to_fix]="Зайдите в панель управления вашего домена (GoDaddy, Namecheap, REG.RU и т.д.)\nи создайте A-запись, указывающую на IP: %s\nОбычно обновление занимает 5-15 минут."
    L[domain_wait]="Подождать и проверить снова?"
    L[yes]="Да"
    L[no]="Нет"
    L[installing_deps]="Установка необходимых программ..."
    L[installing_xui]="Установка панели 3X-UI (это займёт 3-5 минут)..."
    L[xui_install_failed]="Ошибка установки 3X-UI! Возможные причины:\n  1. Нет подключения к интернету\n  2. Сервер не на Ubuntu 20.04+\n  3. Недостаточно места на диске"
    L[deploying_stub]="Развёртывание сайта-маскировки..."
    L[configuring_vless]="Настройка VPN-соединения..."
    L[creating_users]="Создание пользователей..."
    L[install_complete]="УСТАНОВКА ЗАВЕРШЕНА!"
    L[login_title]="ДАННЫЕ ДЛЯ ВХОДА В ПАНЕЛЬ:"
    L[username]="Имя пользователя"
    L[password]="Пароль"
    L[port]="Порт"
    L[panel_path]="Путь панели"
    L[login_url]="Ссылка для входа"
    L[how_to_login]="Откройте ссылку в браузере и введите логин и пароль выше."
    L[save_warning]="ОБЯЗАТЕЛЬНО СОХРАНИТЕ ЭТИ ДАННЫЕ!"
    L[creds_saved]="Данные также сохранены в файл: %s"
    L[cert_info]="О СЕРТИФИКАТАХ:"
    L[cert_ip_info]="Сертификаты создаются автоматически на 6 дней\nи автоматически продлеваются. Ничего делать не нужно."
    L[cert_domain_info]="Сертификаты Let's Encrypt получены автоматически.\nСрок действия: 90 дней с автопродлением."
    L[ready]="Можно приступать к работе!"
    L[download_happ]="СКАЧАЙТЕ VPN-ПРИЛОЖЕНИЕ"
    L[choose_platform]="На каком устройстве будете использовать VPN?"
    L[ios]="iPhone / iPad"
    L[android]="Android-телефон"
    L[scan_qr_app]="Отсканируйте QR-код камерой телефона для скачивания:"
    L[confirm_installed]="Приложение установлено?"
    L[confirm_hint]="Введите 'да' когда установите приложение"
    L[test_connection]="ПРОВЕРКА VPN-СОЕДИНЕНИЯ"
    L[scan_qr_config]="Отсканируйте этот QR-код в приложении Hiddify:"
    L[waiting_online]="Ожидание подключения..."
    L[skip_hint]="(нажмите Enter чтобы пропустить)"
    L[client_online]="Подключение работает! Всё настроено."
    L[client_timeout]="Не удалось подтвердить подключение автоматически.\nЭто нормально — попробуйте вручную в приложении."
    L[final_message]="Всё готово! Вы можете войти в панель управления\nи добавить VPN остальным пользователям."
    L[press_enter]="Нажмите Enter..."
    L[error_root]="Запустите скрипт от имени root: sudo bash xuifast.sh"
    L[already_installed]="3X-UI уже установлена. Вот ваши данные:"
    L[creds_not_found]="Не удалось получить данные панели. Попробуйте:\n  sudo x-ui settings"
    L[users_created]="VPN-пользователей создано"
    L[stub_choice]="Сайт-маскировка установлен"
    L[port_busy]="Порт 443 занят, освобождаю..."
    L[nginx_installed]="Веб-сервер настроен"
    L[retry_seconds]="Повторная проверка через %s сек..."
    L[attempt]="Попытка"
    L[panel_lang_set]="Язык панели"
    L[all_users_info]="ВСЕ VPN-ПОЛЬЗОВАТЕЛИ"
    L[show_all_users_q]="Показать данные всех 10 пользователей?"
    L[invalid_input]="Неверный ввод. Попробуйте ещё раз."
    L[api_login_failed]="Не удалось подключиться к панели. Перезапускаю..."
    L[api_retry]="Повторная попытка подключения..."
    L[inbound_failed]="Ошибка создания VPN-соединения. Создайте вручную в панели."
}

set_lang_en() {
    L[welcome]="Welcome to XUIFAST — 3X-UI Installer"
    L[choose_lang]="Выберите язык / Choose language"
    L[russian]="Русский"
    L[english]="English"
    L[choose_mode]="Choose setup mode"
    L[mode_ip]="By IP address  (no domain needed, quick setup)"
    L[mode_domain]="By domain name  (requires your own domain)"
    L[mode_ip_hint]="Best if you don't have a domain. Certificate is created automatically."
    L[mode_domain_hint]="More reliable option. Requires a domain pointed at this server."
    L[enter_domain]="Enter your domain (e.g.: example.com)"
    L[domain_empty]="Domain cannot be empty! Try again."
    L[checking_domain]="Checking domain..."
    L[domain_ok]="Domain is correctly pointed to this server!"
    L[domain_fail]="Domain is NOT pointed to this server."
    L[domain_ip_mismatch]="Domain resolves to: %s, but server IP is: %s"
    L[domain_how_to_fix]="Go to your domain provider (GoDaddy, Namecheap, Cloudflare, etc.)\nand create an A record pointing to: %s\nThis usually takes 5-15 minutes to update."
    L[domain_wait]="Wait and check again?"
    L[yes]="Yes"
    L[no]="No"
    L[installing_deps]="Installing required software..."
    L[installing_xui]="Installing 3X-UI panel (this takes 3-5 minutes)..."
    L[xui_install_failed]="3X-UI installation failed! Possible reasons:\n  1. No internet connection\n  2. Server not running Ubuntu 20.04+\n  3. Not enough disk space"
    L[deploying_stub]="Setting up camouflage website..."
    L[configuring_vless]="Configuring VPN connection..."
    L[creating_users]="Creating users..."
    L[install_complete]="INSTALLATION COMPLETE!"
    L[login_title]="PANEL LOGIN CREDENTIALS:"
    L[username]="Username"
    L[password]="Password"
    L[port]="Port"
    L[panel_path]="Panel path"
    L[login_url]="Login URL"
    L[how_to_login]="Open the link in your browser and enter the username/password above."
    L[save_warning]="MAKE SURE TO SAVE THESE CREDENTIALS!"
    L[creds_saved]="Credentials also saved to: %s"
    L[cert_info]="ABOUT CERTIFICATES:"
    L[cert_ip_info]="Certificates are auto-generated for 6 days\nand automatically renewed. No action needed."
    L[cert_domain_info]="Let's Encrypt certificates obtained automatically.\nValid for 90 days with auto-renewal."
    L[ready]="Ready to go!"
    L[download_happ]="DOWNLOAD VPN APP"
    L[choose_platform]="What device will you use VPN on?"
    L[ios]="iPhone / iPad"
    L[android]="Android phone"
    L[scan_qr_app]="Scan the QR code with your phone camera to download:"
    L[confirm_installed]="Is the app installed?"
    L[confirm_hint]="Type 'yes' when you've installed the app"
    L[test_connection]="VPN CONNECTION TEST"
    L[scan_qr_config]="Scan this QR code in the Hiddify app:"
    L[waiting_online]="Waiting for connection..."
    L[skip_hint]="(press Enter to skip)"
    L[client_online]="Connection works! Everything is set up."
    L[client_timeout]="Could not confirm connection automatically.\nThis is normal — try connecting manually in the app."
    L[final_message]="All done! You can log into the control panel\nand add VPN for more users."
    L[press_enter]="Press Enter..."
    L[error_root]="Run as root: sudo bash xuifast.sh"
    L[already_installed]="3X-UI is already installed. Here are your credentials:"
    L[creds_not_found]="Could not retrieve panel credentials. Try:\n  sudo x-ui settings"
    L[users_created]="VPN users created"
    L[stub_choice]="Camouflage website deployed"
    L[port_busy]="Port 443 is busy, freeing it..."
    L[nginx_installed]="Web server configured"
    L[retry_seconds]="Rechecking in %s sec..."
    L[attempt]="Attempt"
    L[panel_lang_set]="Panel language"
    L[all_users_info]="ALL VPN USERS"
    L[show_all_users_q]="Show all 10 user configs?"
    L[invalid_input]="Invalid input. Try again."
    L[api_login_failed]="Could not connect to panel. Restarting..."
    L[api_retry]="Retrying connection..."
    L[inbound_failed]="Failed to create VPN connection. Create it manually in the panel."
}

# ─────────────────────────────────────────────────────────────────────────────────
#  UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────────

spinner() {
    local pid=$1
    local msg=$2
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${frames[$i]}${RESET} %s" "$msg"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        printf "\r  ${GREEN}✓${RESET} %s\n" "$msg"
    else
        printf "\r  ${RED}✗${RESET} %s\n" "$msg"
    fi
    tput cnorm 2>/dev/null || true
    return $exit_code
}

print_header() {
    local text="$1"
    local width=60
    local text_len=${#text}
    # Clamp for long UTF-8 strings
    if [[ $text_len -gt $width ]]; then text_len=$width; fi
    local padding=$(( (width - text_len) / 2 ))
    echo ""
    printf "  ${PURPLE}╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗${RESET}\n"
    printf "  ${PURPLE}║${RESET}"
    printf '%*s' $padding ''
    printf "${BOLD}${WHITE}%s${RESET}" "$text"
    printf '%*s' $(( width - padding - text_len )) ''
    printf "${PURPLE}║${RESET}\n"
    printf "  ${PURPLE}╚"
    printf '═%.0s' $(seq 1 $width)
    printf "╝${RESET}\n"
    echo ""
}

print_separator() {
    printf "  ${DIM}"
    printf '─%.0s' $(seq 1 60)
    printf "${RESET}\n"
}

print_info() {
    printf "  ${CYAN}ℹ${RESET}  %s\n" "$1"
}

print_success() {
    printf "  ${GREEN}✓${RESET}  %s\n" "$1"
}

print_warning() {
    printf "  ${YELLOW}⚠${RESET}  %s\n" "$1"
}

print_error() {
    printf "  ${RED}✗${RESET}  %s\n" "$1"
}

wait_enter() {
    echo ""
    printf "  ${DIM}%s${RESET}" "${L[press_enter]}"
    read -r
}

# Read a choice with validation. Usage: read_choice "prompt" 1 3 → sets REPLY
read_choice() {
    local prompt="$1"
    local min="$2"
    local max="$3"
    while true; do
        printf "  ${CYAN}▸${RESET} "
        read -r REPLY
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && [[ "$REPLY" -ge "$min" ]] && [[ "$REPLY" -le "$max" ]]; then
            return 0
        fi
        print_warning "${L[invalid_input]:-Invalid input. Try again.}"
    done
}

# Confirm yes/no. Returns 0 for yes, 1 for no.
confirm_yes() {
    local answer
    read -r answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    case "$answer" in
        y|yes|да|д|1|ок|ok) return 0 ;;
        *) return 1 ;;
    esac
}

show_qr() {
    local data="$1"
    if command -v qrencode &>/dev/null; then
        qrencode -t ANSIUTF8 "$data" 2>/dev/null || {
            echo ""
            printf "  ${DIM}Link: %s${RESET}\n" "$data"
        }
    else
        echo ""
        printf "  ${YELLOW}⚠${RESET}  QR unavailable. Use link:\n"
        printf "  ${CYAN}%s${RESET}\n" "$data"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────────
#  RANDOM NAME GENERATOR (100 adjectives × 100 animals)
# ─────────────────────────────────────────────────────────────────────────────────

generate_random_names() {
    local count=$1

    if [[ "$LANG_CHOICE" == "ru" ]]; then
        local adjectives=(
            "быстрый" "храбрый" "весёлый" "тихий" "громкий"
            "хитрый" "дерзкий" "ленивый" "шустрый" "грозный"
            "мудрый" "яркий" "тёмный" "рыжий" "пушистый"
            "колючий" "скользкий" "прыткий" "задорный" "сонный"
            "голодный" "сытый" "дикий" "ручной" "смелый"
            "робкий" "гордый" "упрямый" "нежный" "суровый"
            "ловкий" "неуклюжий" "бодрый" "вялый" "резвый"
            "спокойный" "буйный" "свирепый" "кроткий" "лютый"
            "игривый" "серьёзный" "забавный" "угрюмый" "лучезарный"
            "полосатый" "пятнистый" "крылатый" "зубастый" "когтистый"
            "пузатый" "ушастый" "глазастый" "носатый" "хвостатый"
            "мохнатый" "гладкий" "шершавый" "блестящий" "матовый"
            "звонкий" "гулкий" "шипящий" "рычащий" "мурлыкающий"
            "парящий" "плывущий" "бегущий" "крадущийся" "прыгающий"
            "танцующий" "поющий" "дремлющий" "охотящийся" "играющий"
            "северный" "южный" "восточный" "западный" "полярный"
            "степной" "лесной" "горный" "морской" "речной"
            "древний" "юный" "вечный" "редкий" "легендарный"
            "магический" "таинственный" "славный" "отважный" "великий"
            "маленький" "огромный" "крохотный" "гигантский" "средний"
        )
        local animals=(
            "барсук" "жираф" "обезьяна" "лисица" "волк"
            "медведь" "тигр" "леопард" "рысь" "пума"
            "орёл" "сокол" "ястреб" "коршун" "филин"
            "дельфин" "касатка" "акула" "тюлень" "морж"
            "кролик" "заяц" "белка" "бурундук" "ёж"
            "олень" "лось" "бизон" "антилопа" "зебра"
            "пингвин" "фламинго" "пеликан" "журавль" "аист"
            "крокодил" "хамелеон" "игуана" "варан" "кобра"
            "панда" "коала" "кенгуру" "утконос" "вомбат"
            "выдра" "бобёр" "норка" "горностай" "соболь"
            "попугай" "тукан" "колибри" "павлин" "снегирь"
            "лемур" "шимпанзе" "горилла" "мандрил" "капуцин"
            "скат" "осьминог" "кальмар" "краб" "омар"
            "мустанг" "зубр" "як" "буйвол" "газель"
            "песец" "манул" "ирбис" "гепард" "оцелот"
            "альбатрос" "кондор" "гриф" "сапсан" "беркут"
            "саламандра" "тритон" "аксолотль" "гекон" "удав"
            "нарвал" "белуга" "ламантин" "каланг" "кит"
            "сурок" "шиншилла" "дикобраз" "капибара" "тапир"
            "феникс" "грифон" "единорог" "дракон" "мантикора"
        )
    else
        local adjectives=(
            "swift" "brave" "clever" "silent" "fierce"
            "mighty" "sneaky" "lazy" "agile" "bold"
            "wise" "bright" "dark" "golden" "fluffy"
            "spiky" "slick" "nimble" "jolly" "sleepy"
            "hungry" "wild" "tame" "fearless" "humble"
            "proud" "stubborn" "gentle" "harsh" "deft"
            "clumsy" "lively" "calm" "rowdy" "savage"
            "meek" "playful" "serious" "funny" "gloomy"
            "radiant" "striped" "spotted" "winged" "fanged"
            "clawed" "furry" "smooth" "shiny" "matte"
            "ringing" "hissing" "roaring" "purring" "soaring"
            "drifting" "running" "creeping" "jumping" "dancing"
            "singing" "dozing" "hunting" "northern" "southern"
            "eastern" "western" "polar" "steppe" "forest"
            "mountain" "marine" "river" "ancient" "young"
            "eternal" "rare" "legendary" "mystic" "arcane"
            "glorious" "valiant" "grand" "tiny" "huge"
            "colossal" "average" "crimson" "azure" "emerald"
            "amber" "ivory" "obsidian" "copper" "iron"
            "crystal" "phantom" "shadow" "thunder" "frost"
        )
        local animals=(
            "badger" "giraffe" "monkey" "fox" "wolf"
            "bear" "tiger" "leopard" "lynx" "puma"
            "eagle" "falcon" "hawk" "kite" "owl"
            "dolphin" "orca" "shark" "seal" "walrus"
            "rabbit" "hare" "squirrel" "chipmunk" "hedgehog"
            "deer" "moose" "bison" "antelope" "zebra"
            "penguin" "flamingo" "pelican" "crane" "stork"
            "crocodile" "chameleon" "iguana" "monitor" "cobra"
            "panda" "koala" "kangaroo" "platypus" "wombat"
            "otter" "beaver" "mink" "ermine" "sable"
            "parrot" "toucan" "hummingbird" "peacock" "robin"
            "lemur" "chimp" "gorilla" "mandrill" "capuchin"
            "ray" "octopus" "squid" "crab" "lobster"
            "mustang" "wisent" "yak" "buffalo" "gazelle"
            "arcticfox" "manul" "snowleopard" "cheetah" "ocelot"
            "albatross" "condor" "vulture" "peregrine" "harrier"
            "salamander" "newt" "axolotl" "gecko" "python"
            "narwhal" "beluga" "manatee" "dugong" "whale"
            "marmot" "chinchilla" "porcupine" "capybara" "tapir"
            "phoenix" "griffin" "unicorn" "dragon" "manticore"
        )
    fi

    local names=()
    local used_map=""
    local attempts=0

    while [[ ${#names[@]} -lt "$count" ]] && [[ $attempts -lt 200 ]]; do
        local adj_idx=$(( RANDOM % ${#adjectives[@]} ))
        local ani_idx=$(( RANDOM % ${#animals[@]} ))
        local name="${adjectives[$adj_idx]}-${animals[$ani_idx]}"
        attempts=$((attempts + 1))

        # Check uniqueness via string search
        if [[ "$used_map" != *"|${name}|"* ]]; then
            names+=("$name")
            used_map+="|${name}|"
        fi
    done

    printf '%s\n' "${names[@]}"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  STUB WEBSITES (3 variants from open-source template libraries)
# ─────────────────────────────────────────────────────────────────────────────────

TEMPLATES=(
    "h5up_dimension|Dimension|https://github.com/zce/html5up|html5up|dimension"
    "lz_coffee_shop|Coffee Shop|https://github.com/learning-zone/website-templates|learning-zone|coffee-shop-free-html5-template"
    "sb_clean_blog|Clean Blog|https://github.com/StartBootstrap/startbootstrap-clean-blog|startbootstrap|."
)

deploy_stub_site() {
    local site_dir="/var/www/html"
    local tmp_clone="/tmp/stub_clone_$$"

    mkdir -p "$site_dir"

    local pick=$(( RANDOM % ${#TEMPLATES[@]} ))
    local tpl="${TEMPLATES[$pick]}"

    IFS='|' read -r tpl_id tpl_name tpl_repo tpl_source tpl_path <<< "$tpl"
    STUB_SITE="$tpl_name"

    rm -rf "$tmp_clone"

    local clone_ok=0
    case "$tpl_source" in
        html5up)
            if git clone --depth 1 --filter=blob:none --sparse "$tpl_repo" "$tmp_clone" >/dev/null 2>&1 || \
               git clone --depth 1 "$tpl_repo" "$tmp_clone" >/dev/null 2>&1; then
                cd "$tmp_clone" && git sparse-checkout set "$tpl_path" 2>/dev/null; cd - >/dev/null
                if [[ -d "$tmp_clone/$tpl_path" ]]; then
                    rm -rf "${site_dir:?}"/*
                    cp -r "$tmp_clone/$tpl_path"/* "$site_dir/" 2>/dev/null
                    clone_ok=1
                fi
            fi
            ;;
        learning-zone)
            if git clone --depth 1 --filter=blob:none --sparse "$tpl_repo" "$tmp_clone" >/dev/null 2>&1 || \
               git clone --depth 1 "$tpl_repo" "$tmp_clone" >/dev/null 2>&1; then
                cd "$tmp_clone" && git sparse-checkout set "$tpl_path" 2>/dev/null; cd - >/dev/null
                if [[ -d "$tmp_clone/$tpl_path" ]]; then
                    rm -rf "${site_dir:?}"/*
                    cp -r "$tmp_clone/$tpl_path"/* "$site_dir/" 2>/dev/null
                    clone_ok=1
                fi
            fi
            ;;
        startbootstrap)
            if git clone --depth 1 "$tpl_repo" "$tmp_clone" >/dev/null 2>&1; then
                rm -rf "${site_dir:?}"/*
                if [[ -f "$tmp_clone/dist/index.html" ]]; then
                    cp -r "$tmp_clone/dist/"* "$site_dir/"
                elif [[ -f "$tmp_clone/index.html" ]]; then
                    cp -r "$tmp_clone/"* "$site_dir/"
                else
                    local found_idx
                    found_idx=$(find "$tmp_clone" -name "index.html" -type f 2>/dev/null | head -1)
                    [[ -n "$found_idx" ]] && cp -r "$(dirname "$found_idx")"/* "$site_dir/"
                fi
                clone_ok=1
            fi
            ;;
    esac

    rm -rf "$tmp_clone"

    # Verify or fallback
    if [[ $clone_ok -eq 1 ]] && [[ -f "$site_dir/index.html" ]]; then
        chown -R www-data:www-data "$site_dir" 2>/dev/null || true
        chmod -R 755 "$site_dir"
    else
        # Fallback
        cat > "$site_dir/index.html" << 'FALLBACKEOF'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Welcome</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;display:flex;align-items:center;justify-content:center;min-height:100vh;text-align:center}
.c{max-width:600px;padding:2rem}h1{font-size:2.5rem;margin-bottom:1rem;background:linear-gradient(135deg,#6366f1,#a855f7);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
p{color:#94a3b8;line-height:1.8}</style></head><body><div class="c"><h1>Welcome</h1><p>Site under construction.</p></div></body></html>
FALLBACKEOF
        STUB_SITE="Fallback"
    fi

    print_success "${L[stub_choice]}: $STUB_SITE"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  NGINX SETUP
# ─────────────────────────────────────────────────────────────────────────────────

setup_nginx() {
    # Free port 443 if occupied
    if ss -tlnp 2>/dev/null | grep -q ':443 '; then
        print_warning "${L[port_busy]}"
        systemctl stop nginx 2>/dev/null || true
        systemctl stop apache2 2>/dev/null || true
        fuser -k 443/tcp 2>/dev/null || true
        sleep 1
    fi

    apt-get install -y nginx >/dev/null 2>&1 || true

    local server_name="_"
    [[ "$MODE" == "domain" ]] && server_name="$DOMAIN"

    cat > /etc/nginx/sites-available/stub << NGINXEOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${server_name};
    root /var/www/html;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
    location = /favicon.ico { log_not_found off; access_log off; }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/stub /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    if nginx -t >/dev/null 2>&1; then
        systemctl enable nginx >/dev/null 2>&1
        systemctl restart nginx
        print_success "${L[nginx_installed]}"
    else
        print_warning "Nginx config error, trying to fix..."
        rm -f /etc/nginx/sites-enabled/*
        ln -sf /etc/nginx/sites-available/stub /etc/nginx/sites-enabled/
        systemctl restart nginx 2>/dev/null || true
    fi
}

# Reconfigure after xray takes port 443
setup_fallback_nginx() {
    cat > /etc/nginx/sites-available/stub << NGINXEOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
    location = /favicon.ico { log_not_found off; access_log off; }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/stub /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t >/dev/null 2>&1 && systemctl restart nginx 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────────
#  DNS CHECK
# ─────────────────────────────────────────────────────────────────────────────────

check_dns() {
    local domain="$1"
    local max_attempts=10
    local attempt=1

    while true; do
        printf "\r  ${CYAN}◌${RESET} ${L[checking_domain]} (${L[attempt]} %d)  " "$attempt"

        local resolved_ip=""
        resolved_ip=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1)

        if [[ "$resolved_ip" == "$SERVER_IP" ]]; then
            printf "\r  ${GREEN}✓${RESET} ${L[domain_ok]}                              \n"
            return 0
        fi

        printf "\n"
        if [[ -n "$resolved_ip" ]]; then
            print_warning "$(printf "${L[domain_ip_mismatch]}" "$resolved_ip" "$SERVER_IP")"
        else
            print_warning "${L[domain_fail]}"
        fi

        # Show how to fix
        echo ""
        printf "  ${DIM}"
        printf "${L[domain_how_to_fix]}" "$SERVER_IP"
        printf "${RESET}\n"

        if [[ $attempt -ge $max_attempts ]]; then
            return 1
        fi

        echo ""
        printf "  ${YELLOW}?${RESET} ${L[domain_wait]} [${L[yes]}/${L[no]}]: "
        if ! confirm_yes; then
            return 1
        fi

        local wait_time=30
        for ((i=wait_time; i>0; i--)); do
            printf "\r  ${DIM}$(printf "${L[retry_seconds]}" "$i")${RESET}   "
            sleep 1
        done
        printf "\r%60s\r" " "

        attempt=$((attempt + 1))
    done
}

# ─────────────────────────────────────────────────────────────────────────────────
#  3X-UI INSTALLATION
# ─────────────────────────────────────────────────────────────────────────────────

install_3xui() {
    > "$LOG_FILE"

    if [[ "$MODE" == "domain" ]]; then
        expect << XEOF 2>&1 | tee -a "$LOG_FILE" >/dev/null
set timeout 600
spawn bash -c "curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash"

expect {
    -re "(?i)confirm.*install" { sleep 1; send "y\r"; exp_continue }
    -re "(?i)customize.*panel.*port" { sleep 1; send "n\r"; exp_continue }
    -re "(?i)choose.*option|SSL certificate" { sleep 1; send "1\r"; exp_continue }
    -re "(?i)domain" { sleep 1; send "${DOMAIN}\r"; exp_continue }
    -re "(?i)email.*acme|email.*cert" { sleep 1; send "\r"; exp_continue }
    -re "(?i)reload.*cmd|reloadcmd" { sleep 1; send "n\r"; exp_continue }
    timeout { }
    eof { }
}
XEOF
    else
        expect << XEOF 2>&1 | tee -a "$LOG_FILE" >/dev/null
set timeout 600
spawn bash -c "curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash"

expect {
    -re "(?i)confirm.*install" { sleep 1; send "y\r"; exp_continue }
    -re "(?i)customize.*panel.*port" { sleep 1; send "n\r"; exp_continue }
    -re "(?i)choose.*option|SSL certificate" { sleep 1; send "2\r"; exp_continue }
    -re "(?i)port.*acme|port.*use" { sleep 1; send "\r"; exp_continue }
    -re "(?i)reload.*cmd|reloadcmd" { sleep 1; send "n\r"; exp_continue }
    timeout { }
    eof { }
}
XEOF
    fi

    # Verify installation succeeded
    sleep 3
    if [[ ! -f "/usr/local/x-ui/x-ui" ]]; then
        print_error "$(echo -e "${L[xui_install_failed]}")"
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────────
#  EXTRACT PANEL CREDENTIALS
# ─────────────────────────────────────────────────────────────────────────────────

extract_credentials() {
    # From database first
    if [[ -f "$XUI_DB" ]] && command -v sqlite3 &>/dev/null; then
        XUI_USER=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='username';" 2>/dev/null || true)
        XUI_PASS=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='password';" 2>/dev/null || true)
        XUI_PORT=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='port';" 2>/dev/null || true)
        XUI_PATH=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null || true)
    fi

    # Fallback to log
    if [[ -z "$XUI_USER" ]] || [[ -z "$XUI_PASS" ]]; then
        XUI_USER=$(grep -oP 'Username:\s*\K\S+' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '\r')
        XUI_PASS=$(grep -oP 'Password:\s*\K\S+' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '\r')
    fi

    if [[ ! "${XUI_PORT:-}" =~ ^[0-9]+$ ]]; then
        XUI_PORT=$(grep -oP 'Port:\s*\K[0-9]+' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '\r')
    fi

    if [[ -z "${XUI_PATH:-}" ]]; then
        XUI_PATH=$(grep -oP 'WebBasePath:\s*\K\S+' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '\r')
    fi

    XUI_PATH=$(echo "${XUI_PATH:-}" | tr -d '"/')

    # Validate we got something
    if [[ -z "$XUI_USER" ]] || [[ -z "$XUI_PASS" ]] || [[ -z "$XUI_PORT" ]]; then
        print_error "$(echo -e "${L[creds_not_found]}")"
        return 1
    fi

    if [[ "$MODE" == "domain" ]]; then
        XUI_URL="https://${DOMAIN}:${XUI_PORT}/${XUI_PATH}/"
    else
        XUI_URL="https://${SERVER_IP}:${XUI_PORT}/${XUI_PATH}/"
    fi

    API_BASE="https://127.0.0.1:${XUI_PORT}/${XUI_PATH}"

    # Save credentials to file for recovery
    cat > "$CREDS_FILE" << CREDEOF
# XUIFAST Panel Credentials (auto-saved)
USERNAME=$XUI_USER
PASSWORD=$XUI_PASS
PORT=$XUI_PORT
PATH=/${XUI_PATH}/
URL=$XUI_URL
MODE=$MODE
DOMAIN=$DOMAIN
IP=$SERVER_IP
CREDEOF
    chmod 600 "$CREDS_FILE"

    rm -f "$LOG_FILE"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────────
#  3X-UI API FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────────

# Wait for panel API to become available
wait_for_api() {
    local max_wait=60
    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if curl -sk --max-time 3 "${API_BASE}/login" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

api_login() {
    # Single clean login, save cookie to file
    local http_code
    http_code=$(curl -sk -w '%{http_code}' -o /dev/null -c /tmp/xui_cookie.txt \
        "${API_BASE}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null)

    if [[ "$http_code" != "200" ]] || [[ ! -f /tmp/xui_cookie.txt ]]; then
        return 1
    fi
    return 0
}

api_login_with_retry() {
    for attempt in 1 2 3; do
        if api_login; then
            return 0
        fi
        if [[ $attempt -lt 3 ]]; then
            print_info "${L[api_retry]} ($attempt/3)"
            systemctl restart x-ui 2>/dev/null || true
            sleep 5
        fi
    done
    print_error "${L[api_login_failed]}"
    return 1
}

api_set_language() {
    local lang_code="en"
    [[ "$LANG_CHOICE" == "ru" ]] && lang_code="ru"

    curl -sk -b /tmp/xui_cookie.txt "${API_BASE}/panel/setting/update" \
        -H "Content-Type: application/json" \
        -d "{\"webLang\": \"${lang_code}\"}" >/dev/null 2>&1 || true
}

api_create_inbound() {
    local host="$SERVER_IP"
    [[ "$MODE" == "domain" ]] && host="$DOMAIN"

    # Certificate paths
    if [[ "$MODE" == "domain" ]]; then
        CERT_PATH="/root/cert/${DOMAIN}/fullchain.pem"
        KEY_PATH="/root/cert/${DOMAIN}/privkey.pem"

        # Wait for certs
        local cert_wait=0
        while [[ $cert_wait -lt 60 ]]; do
            if [[ -f "$CERT_PATH" ]] && [[ -f "$KEY_PATH" ]]; then break; fi
            if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
                CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
                KEY_PATH="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
                break
            fi
            sleep 2
            cert_wait=$((cert_wait + 2))
        done

        if [[ ! -f "$CERT_PATH" ]]; then
            print_warning "Certificate not found, panel will use self-signed."
            CERT_PATH=""
            KEY_PATH=""
        fi
    else
        CERT_PATH=""
        KEY_PATH=""
    fi

    # Generate names
    local names
    names=$(generate_random_names 10)
    local name_array=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && name_array+=("$line")
    done <<< "$names"

    USER_NAMES=("${name_array[@]}")
    USER_UUIDS=()

    # Build clients JSON via python3 for safe escaping
    local clients_arr=""
    for i in $(seq 0 9); do
        local uuid
        uuid=$(cat /proc/sys/kernel/random/uuid)
        USER_UUIDS+=("$uuid")
        local sub_id
        sub_id=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)

        [[ $i -gt 0 ]] && clients_arr+=","
        clients_arr+="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"${name_array[$i]}\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true,\"tgId\":\"\",\"subId\":\"${sub_id}\",\"reset\":0}"
    done

    # Use python3 to build the payload safely (no triple-quote injection risk)
    local tls_sni="$host"
    local allow_insecure="false"
    local cert_file="${CERT_PATH}"
    local key_file="${KEY_PATH}"
    [[ "$MODE" == "ip" ]] && allow_insecure="true" && tls_sni=""

    python3 -c "
import json, sys

clients = json.loads('[${clients_arr}]')

settings = json.dumps({
    'clients': clients,
    'decryption': 'none',
    'fallbacks': [{'dest': 80}]
})

stream = json.dumps({
    'network': 'tcp',
    'security': 'tls',
    'tlsSettings': {
        'serverName': '${tls_sni}',
        'minVersion': '1.2',
        'maxVersion': '1.3',
        'cipherSuites': '',
        'rejectUnknownSni': False,
        'disableSystemRoot': False,
        'enableSessionResumption': False,
        'certificates': [{'certificateFile': '${cert_file}', 'keyFile': '${key_file}', 'ocspStapling': 3600}],
        'alpn': ['h2', 'http/1.1'],
        'settings': {'allowInsecure': ${allow_insecure}, 'fingerprint': 'chrome'}
    },
    'tcpSettings': {'acceptProxyProtocol': False, 'header': {'type': 'none'}}
})

sniffing = json.dumps({
    'enabled': True,
    'destOverride': ['http', 'tls', 'quic', 'fakedns'],
    'metadataOnly': False,
    'routeOnly': False
})

payload = {
    'up': 0, 'down': 0, 'total': 0,
    'remark': 'VLESS-TCP-XTLS',
    'enable': True, 'expiryTime': 0,
    'listen': '', 'port': 443, 'protocol': 'vless',
    'settings': settings,
    'streamSettings': stream,
    'tag': 'inbound-443',
    'sniffing': sniffing
}

json.dump(payload, open('/tmp/xuifast_payload.json', 'w'))
" || { print_error "${L[inbound_failed]}"; return 1; }

    local http_code
    http_code=$(curl -sk -w '%{http_code}' -o /dev/null \
        -b /tmp/xui_cookie.txt "${API_BASE}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/xuifast_payload.json 2>/dev/null)

    rm -f /tmp/xuifast_payload.json

    if [[ "$http_code" != "200" ]]; then
        print_error "${L[inbound_failed]} (HTTP $http_code)"
        return 1
    fi

    # Save user data for recovery
    {
        echo ""
        echo "# VPN Users"
        for i in $(seq 0 9); do
            echo "USER_${i}=${USER_NAMES[$i]}|${USER_UUIDS[$i]}"
        done
    } >> "$CREDS_FILE"

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────────
#  GENERATE VLESS LINKS & QR
# ─────────────────────────────────────────────────────────────────────────────────

generate_vless_link() {
    local uuid="$1"
    local name="$2"
    local host="$SERVER_IP"
    [[ "$MODE" == "domain" ]] && host="$DOMAIN"

    local link="vless://${uuid}@${host}:443?type=tcp&security=tls&sni=${host}&fp=chrome&flow=xtls-rprx-vision"
    [[ "$MODE" == "ip" ]] && link+="&allowInsecure=1"
    link+="#${name}"
    echo "$link"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  CHECK CLIENT ONLINE STATUS
# ─────────────────────────────────────────────────────────────────────────────────

check_client_online() {
    local email="$1"
    local timeout=120
    local elapsed=0

    echo ""
    printf "  ${DIM}${L[skip_hint]}${RESET}\n"
    echo ""

    while [[ $elapsed -lt $timeout ]]; do
        # Check if user pressed Enter (non-blocking read)
        if read -t 0.1 -r 2>/dev/null; then
            return 2  # skipped
        fi

        local response
        response=$(curl -sk -b /tmp/xui_cookie.txt "${API_BASE}/panel/api/inbounds/onlines" 2>/dev/null || true)

        if [[ -n "$response" ]] && echo "$response" | grep -q "$email" 2>/dev/null; then
            return 0
        fi

        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        for ((f=0; f<50; f++)); do
            local frame_idx=$(( f % ${#frames[@]} ))
            local remaining=$(( timeout - elapsed ))
            printf "\r  ${CYAN}${frames[$frame_idx]}${RESET} ${L[waiting_online]} ${DIM}(%ds)${RESET}  " "$remaining"
            sleep 0.1
        done

        elapsed=$((elapsed + 5))
    done

    printf "\n"
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────────
#  DISPLAY CREDENTIALS
# ─────────────────────────────────────────────────────────────────────────────────

show_credentials() {
    echo ""
    printf "  ${GREEN}╔"
    printf '═%.0s' $(seq 1 58)
    printf "╗${RESET}\n"

    printf "  ${GREEN}║${RESET}  ${BOLD}${WHITE}%-56s${RESET}${GREEN}║${RESET}\n" "${L[install_complete]}"
    printf "  ${GREEN}║${RESET}  ${BOLD}${WHITE}%-56s${RESET}${GREEN}║${RESET}\n" "${L[login_title]}"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  👤 %-16s ${BOLD}%-33s${RESET}${GREEN}║${RESET}\n" "${L[username]}:" "${XUI_USER}"
    printf "  ${GREEN}║${RESET}  🔑 %-16s ${BOLD}%-33s${RESET}${GREEN}║${RESET}\n" "${L[password]}:" "${XUI_PASS}"
    printf "  ${GREEN}║${RESET}  🔌 %-16s ${YELLOW}%-33s${RESET}${GREEN}║${RESET}\n" "${L[port]}:" "${XUI_PORT}"
    printf "  ${GREEN}║${RESET}  📁 %-16s %-33s${GREEN}║${RESET}\n" "${L[panel_path]}:" "/${XUI_PATH}/"
    printf "  ${GREEN}║${RESET}  🌐 %-16s ${RESET}${GREEN}║${RESET}\n" "${L[login_url]}:"
    printf "  ${GREEN}║${RESET}  ${GREEN}${UNDERLINE}%-56s${RESET}${GREEN}║${RESET}\n" "${XUI_URL}"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  ${CYAN}%-56s${RESET}${GREEN}║${RESET}\n" "${L[how_to_login]}"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  ${YELLOW}⚠  ${BOLD}%-53s${RESET}${GREEN}║${RESET}\n" "${L[save_warning]}"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  ${CYAN}ℹ  %-53s${RESET}${GREEN}║${RESET}\n" "${L[cert_info]}"

    local cert_info
    [[ "$MODE" == "domain" ]] && cert_info="${L[cert_domain_info]}" || cert_info="${L[cert_ip_info]}"

    while IFS= read -r line; do
        printf "  ${GREEN}║${RESET}     %-53s${GREEN}║${RESET}\n" "$line"
    done <<< "$(echo -e "$cert_info")"

    printf "  ${GREEN}║${RESET}%-58s${GREEN}║${RESET}\n" ""
    printf "  ${GREEN}║${RESET}  ${GREEN}✅ %-53s${RESET}${GREEN}║${RESET}\n" "${L[ready]}"

    printf "  ${GREEN}╚"
    printf '═%.0s' $(seq 1 58)
    printf "╝${RESET}\n"

    echo ""
    printf "  ${DIM}$(printf "${L[creds_saved]}" "$CREDS_FILE")${RESET}\n"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────────
#  APP DOWNLOAD
# ─────────────────────────────────────────────────────────────────────────────────

show_app_download() {
    print_header "${L[download_happ]}"

    printf "  ${WHITE}${L[choose_platform]}${RESET}\n\n"
    printf "    ${CYAN}1)${RESET} 📱  ${L[ios]}\n"
    printf "    ${CYAN}2)${RESET} 📱  ${L[android]}\n"
    echo ""
    read_choice "" 1 2
    local platform_choice="$REPLY"

    local app_url_ios="https://apps.apple.com/app/hiddify-proxy-vpn/id6596777532"
    local app_url_android="https://play.google.com/store/apps/details?id=app.hiddify.com"

    echo ""
    print_separator

    if [[ "$platform_choice" == "1" ]]; then
        printf "\n  ${CYAN}📱 iOS — Hiddify (App Store):${RESET}\n\n"
        show_qr "$app_url_ios"
    else
        printf "\n  ${CYAN}📱 Android — Hiddify (Google Play):${RESET}\n\n"
        show_qr "$app_url_android"
    fi

    echo ""
    print_separator
    echo ""

    printf "  ${DIM}${L[confirm_hint]}${RESET}\n"
    while true; do
        printf "  ${YELLOW}?${RESET} ${L[confirm_installed]} "
        if confirm_yes; then
            break
        fi
        print_info "${L[scan_qr_app]}"
    done

    print_success "OK!"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  CONNECTION TEST
# ─────────────────────────────────────────────────────────────────────────────────

test_connection() {
    # Ensure we have user data
    if [[ ${#USER_UUIDS[@]} -eq 0 ]] || [[ ${#USER_NAMES[@]} -eq 0 ]]; then
        print_warning "No user data available for testing."
        return
    fi

    print_header "${L[test_connection]}"

    printf "  ${CYAN}${L[scan_qr_config]}${RESET}\n\n"

    local first_link
    first_link=$(generate_vless_link "${USER_UUIDS[0]}" "${USER_NAMES[0]}")

    show_qr "$first_link"

    echo ""
    print_separator
    printf "  ${DIM}Link: %s${RESET}\n" "$first_link"
    print_separator

    # Refresh API cookie
    api_login 2>/dev/null || true

    local result
    check_client_online "${USER_NAMES[0]}"
    result=$?

    if [[ $result -eq 0 ]]; then
        printf "\r  ${GREEN}✓${RESET} ${BOLD}${GREEN}${L[client_online]}${RESET}                              \n"
    elif [[ $result -eq 2 ]]; then
        print_info "Skipped."
    else
        echo ""
        printf "  ${DIM}"
        echo -e "${L[client_timeout]}"
        printf "${RESET}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────────
#  SHOW ALL USERS
# ─────────────────────────────────────────────────────────────────────────────────

show_all_users() {
    if [[ ${#USER_UUIDS[@]} -eq 0 ]]; then return; fi

    echo ""
    printf "  ${YELLOW}?${RESET} ${L[show_all_users_q]} [${L[yes]}/${L[no]}]: "
    if ! confirm_yes; then
        return
    fi

    print_header "${L[all_users_info]}"

    for i in $(seq 0 $(( ${#USER_UUIDS[@]} - 1 )) ); do
        local link
        link=$(generate_vless_link "${USER_UUIDS[$i]}" "${USER_NAMES[$i]}")

        printf "  ${WHITE}%2d.${RESET} ${BOLD}%s${RESET}\n" "$((i+1))" "${USER_NAMES[$i]}"
        printf "      ${DIM}%s${RESET}\n" "$link"
        echo ""
    done
}

# ─────────────────────────────────────────────────────────────────────────────────
#  MAIN FLOW
# ─────────────────────────────────────────────────────────────────────────────────

main() {
    # ── Root check ──
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "\n  ${RED}✗${RESET}  Run as root: ${BOLD}sudo bash xuifast.sh${RESET}\n"
        exit 1
    fi

    clear

    # ╔═══════════════════════════════╗
    # ║   WELCOME & LANG SELECT       ║
    # ╚═══════════════════════════════╝

    echo ""
    printf "${PURPLE}"
    cat << 'BANNER'
    ██╗  ██╗██╗   ██╗██╗███████╗ █████╗ ███████╗████████╗
    ╚██╗██╔╝██║   ██║██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝
     ╚███╔╝ ██║   ██║██║█████╗  ███████║███████╗   ██║
     ██╔██╗ ██║   ██║██║██╔══╝  ██╔══██║╚════██║   ██║
    ██╔╝ ██╗╚██████╔╝██║██║     ██║  ██║███████║   ██║
    ╚═╝  ╚═╝ ╚═════╝ ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝
BANNER
    printf "${RESET}"
    printf "\n  ${DIM}──────────── 3X-UI Professional Installer v2.1 ────────────${RESET}\n\n"

    printf "  ${WHITE}Выберите язык / Choose language:${RESET}\n\n"
    printf "    ${CYAN}1)${RESET} 🇷🇺  Русский\n"
    printf "    ${CYAN}2)${RESET} 🇬🇧  English\n"
    echo ""
    read_choice "" 1 2

    if [[ "$REPLY" == "1" ]]; then
        LANG_CHOICE="ru"
        set_lang_ru
    else
        LANG_CHOICE="en"
        set_lang_en
    fi

    print_success "${L[panel_lang_set]}: $([ "$LANG_CHOICE" == "ru" ] && echo "Русский" || echo "English")"
    echo ""

    # ── Get server IP ──
    SERVER_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || \
                curl -s --max-time 10 api.ipify.org 2>/dev/null || \
                curl -s --max-time 10 icanhazip.com 2>/dev/null || echo "")
    SERVER_IP=$(echo "$SERVER_IP" | tr -d '[:space:]')

    if [[ -z "$SERVER_IP" ]]; then
        print_error "Cannot detect server IP. Check internet connection."
        exit 1
    fi

    # ╔═══════════════════════════════╗
    # ║     MODE SELECTION             ║
    # ╚═══════════════════════════════╝

    print_header "${L[choose_mode]}"

    printf "    ${CYAN}1)${RESET} 🌐  ${L[mode_ip]}\n"
    printf "       ${DIM}${L[mode_ip_hint]}${RESET}\n\n"
    printf "    ${CYAN}2)${RESET} 🔒  ${L[mode_domain]}\n"
    printf "       ${DIM}${L[mode_domain_hint]}${RESET}\n"
    echo ""
    read_choice "" 1 2

    if [[ "$REPLY" == "2" ]]; then
        MODE="domain"
        echo ""
        # Domain input with validation
        while true; do
            printf "  ${CYAN}▸${RESET} ${L[enter_domain]}: "
            read -r DOMAIN
            DOMAIN=$(echo "$DOMAIN" | sed 's|https\?://||' | sed 's|/.*||' | tr -d '[:space:]')
            if [[ -n "$DOMAIN" ]] && [[ "$DOMAIN" == *.* ]]; then
                break
            fi
            print_warning "${L[domain_empty]}"
        done

        echo ""
        if ! check_dns "$DOMAIN"; then
            print_error "${L[domain_fail]}"
            exit 1
        fi
    else
        MODE="ip"
    fi

    echo ""

    # ╔═══════════════════════════════╗
    # ║   ALREADY INSTALLED CHECK      ║
    # ╚═══════════════════════════════╝

    if [[ -f "/usr/local/x-ui/x-ui" ]]; then
        print_warning "${L[already_installed]}"
        if extract_credentials; then
            show_credentials
        fi
        exit 0
    fi

    # ╔═══════════════════════════════╗
    # ║       INSTALLATION             ║
    # ╚═══════════════════════════════╝

    # Step 1: Dependencies
    (
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq 2>/dev/null
        apt-get install -y -qq expect qrencode curl sqlite3 dnsutils nginx python3 git 2>/dev/null
    ) &
    spinner $! "${L[installing_deps]}" || {
        print_error "Dependencies installation failed"
        exit 1
    }

    # Step 2: Deploy stub site
    deploy_stub_site

    # Step 3: Setup nginx
    setup_nginx

    # Step 4: Install 3x-ui (with progress message)
    print_info "${L[installing_xui]}"
    install_3xui
    print_success "3X-UI installed"

    # Step 5: Extract credentials
    if ! extract_credentials; then
        exit 1
    fi

    # Step 6: Wait for API
    print_info "${L[configuring_vless]}"
    if ! wait_for_api; then
        print_warning "${L[api_login_failed]}"
        systemctl restart x-ui 2>/dev/null || true
        sleep 5
        wait_for_api || true
    fi

    # Step 7: API login & configure
    if api_login_with_retry; then
        api_set_language
        print_success "${L[panel_lang_set]}: $([ "$LANG_CHOICE" == "ru" ] && echo "Русский" || echo "English")"
    fi

    # Step 8: Reconfigure nginx as fallback
    setup_fallback_nginx

    # Step 9: Create VLESS inbound with 10 users
    print_info "${L[creating_users]}"
    if api_create_inbound; then
        print_success "10 ${L[users_created]}"
    fi

    # ╔═══════════════════════════════╗
    # ║         RESULTS                ║
    # ╚═══════════════════════════════╝

    show_credentials
    wait_enter

    # App download
    show_app_download

    # Connection test
    test_connection

    # Final
    echo ""
    print_separator
    printf "\n  ${GREEN}${BOLD}"
    echo -e "${L[final_message]}"
    printf "${RESET}\n"
    print_separator

    # Optional: show all users
    show_all_users

    # Repeat credentials one last time
    echo ""
    show_credentials

    # Cleanup
    rm -f /tmp/xui_cookie.txt

    printf "  ${DIM}$([ "$LANG_CHOICE" == "ru" ] && echo "Скрипт завершён. Удачи!" || echo "Done. Good luck!")${RESET}\n\n"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────────
main "$@"
