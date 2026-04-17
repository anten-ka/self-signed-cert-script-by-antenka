#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  XUIFAST — Professional 3X-UI Installer                                      ║
# ║  Version: 2.0                                                                 ║
# ║  Author: anten-ka                                                              ║
# ║  Features: Bilingual, IP/Domain modes, Stub sites, VLESS auto-setup           ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

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
API_COOKIE=""

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
#  LOCALIZATION
# ─────────────────────────────────────────────────────────────────────────────────
declare -A L

set_lang_ru() {
    L[welcome]="Добро пожаловать в XUIFAST — установщик 3X-UI"
    L[choose_lang]="Выберите язык / Choose language"
    L[russian]="Русский"
    L[english]="English"
    L[choose_mode]="Выберите режим работы"
    L[mode_ip]="По IP-адресу (самоподписной сертификат)"
    L[mode_domain]="По доменному имени (Let's Encrypt)"
    L[enter_domain]="Введите ваш домен (например: example.com)"
    L[checking_domain]="Проверка DNS-записи домена..."
    L[domain_ok]="Домен успешно направлен на этот сервер!"
    L[domain_fail]="Домен НЕ направлен на этот сервер."
    L[domain_ip_mismatch]="Домен указывает на IP: %s, но IP сервера: %s"
    L[domain_wait]="Хотите подождать и проверить снова?"
    L[yes]="Да"
    L[no]="Нет"
    L[installing_deps]="Установка зависимостей..."
    L[installing_xui]="Установка 3X-UI панели..."
    L[deploying_stub]="Развёртывание сайта-заглушки..."
    L[configuring_vless]="Настройка VLESS соединения..."
    L[creating_users]="Создание пользователей..."
    L[install_complete]="УСТАНОВКА ЗАВЕРШЕНА! ДАННЫЕ ДЛЯ ВХОДА:"
    L[username]="Имя пользователя"
    L[password]="Пароль"
    L[port]="Порт"
    L[panel_path]="Путь панели"
    L[login_url]="Ссылка для входа"
    L[save_warning]="ОБЯЗАТЕЛЬНО СОХРАНИТЕ ЭТИ ДАННЫЕ!"
    L[cert_info]="ИНФОРМАЦИЯ О СЕРТИФИКАТАХ:"
    L[cert_ip_info]="Сертификаты автоматически генерируются панелью на 6 дней\nи затем автоматически продлеваются каждые 6 дней.\nНичего вручную прописывать не нужно."
    L[cert_domain_info]="Сертификаты Let's Encrypt получены через 3X-UI.\nАвтоматическое обновление настроено.\nСрок действия: 90 дней с автопродлением."
    L[ready]="Можно сразу приступать к настройке!"
    L[download_happ]="СКАЧАЙТЕ ПРИЛОЖЕНИЕ-КЛИЕНТ"
    L[choose_platform]="На какой платформе будете тестировать?"
    L[ios]="iOS (iPhone/iPad)"
    L[android]="Android"
    L[scan_qr_app]="Отсканируйте QR-код для скачивания приложения Hiddify:"
    L[confirm_installed]="Приложение установлено? (да/нет)"
    L[test_connection]="ТЕСТИРОВАНИЕ СОЕДИНЕНИЯ"
    L[scan_qr_config]="Отсканируйте QR-код конфигурации первого клиента:"
    L[waiting_online]="Ожидание подключения клиента..."
    L[client_online]="Клиент подключен! Соединение работает."
    L[client_timeout]="Превышено время ожидания. Проверьте подключение вручную."
    L[final_message]="Теперь вы можете работать в панели управления.\nИмпортируйте остальных пользователей через QR-коды в панели."
    L[press_enter]="Нажмите [Enter], чтобы продолжить..."
    L[error_root]="Запустите скрипт от имени root (sudo)!"
    L[already_installed]="3X-UI уже установлена!"
    L[users_created]="пользователей создано"
    L[generating_names]="Генерация случайных имён..."
    L[stub_choice]="Выбран сайт-заглушка"
    L[checking_port]="Проверка доступности порта 443..."
    L[port_busy]="Порт 443 занят! Останавливаю конфликтующие сервисы..."
    L[nginx_installed]="Nginx установлен и настроен"
    L[waiting_dns]="Ожидание обновления DNS..."
    L[retry_seconds]="Повторная проверка через %s секунд..."
    L[attempt]="Попытка"
    L[of]="из"
    L[panel_lang_set]="Язык панели установлен"
    L[connection_info]="ИНФОРМАЦИЯ О ПОДКЛЮЧЕНИИ"
    L[all_users_info]="ДАННЫЕ ВСЕХ ПОЛЬЗОВАТЕЛЕЙ"
}

set_lang_en() {
    L[welcome]="Welcome to XUIFAST — 3X-UI Installer"
    L[choose_lang]="Выберите язык / Choose language"
    L[russian]="Русский"
    L[english]="English"
    L[choose_mode]="Choose operation mode"
    L[mode_ip]="By IP address (self-signed certificate)"
    L[mode_domain]="By domain name (Let's Encrypt)"
    L[enter_domain]="Enter your domain (e.g.: example.com)"
    L[checking_domain]="Checking domain DNS record..."
    L[domain_ok]="Domain is correctly pointed to this server!"
    L[domain_fail]="Domain is NOT pointed to this server."
    L[domain_ip_mismatch]="Domain resolves to IP: %s, but server IP is: %s"
    L[domain_wait]="Want to wait and check again?"
    L[yes]="Yes"
    L[no]="No"
    L[installing_deps]="Installing dependencies..."
    L[installing_xui]="Installing 3X-UI panel..."
    L[deploying_stub]="Deploying stub website..."
    L[configuring_vless]="Configuring VLESS connection..."
    L[creating_users]="Creating users..."
    L[install_complete]="INSTALLATION COMPLETE! LOGIN CREDENTIALS:"
    L[username]="Username"
    L[password]="Password"
    L[port]="Port"
    L[panel_path]="Panel path"
    L[login_url]="Login URL"
    L[save_warning]="MAKE SURE TO SAVE THESE CREDENTIALS!"
    L[cert_info]="CERTIFICATE INFORMATION:"
    L[cert_ip_info]="Certificates are auto-generated by the panel for 6 days\nand automatically renewed every 6 days.\nNo manual configuration needed."
    L[cert_domain_info]="Let's Encrypt certificates obtained via 3X-UI.\nAutomatic renewal is configured.\nValidity: 90 days with auto-renewal."
    L[ready]="Ready to start configuring connections!"
    L[download_happ]="DOWNLOAD THE CLIENT APP"
    L[choose_platform]="Which platform will you test on?"
    L[ios]="iOS (iPhone/iPad)"
    L[android]="Android"
    L[scan_qr_app]="Scan the QR code to download Hiddify app:"
    L[confirm_installed]="Is the app installed? (yes/no)"
    L[test_connection]="CONNECTION TEST"
    L[scan_qr_config]="Scan the QR code of the first client config:"
    L[waiting_online]="Waiting for client to connect..."
    L[client_online]="Client connected! Connection is working."
    L[client_timeout]="Timeout exceeded. Check the connection manually."
    L[final_message]="You can now work in the control panel.\nImport other users via QR codes in the panel."
    L[press_enter]="Press [Enter] to continue..."
    L[error_root]="Run this script as root (sudo)!"
    L[already_installed]="3X-UI is already installed!"
    L[users_created]="users created"
    L[generating_names]="Generating random names..."
    L[stub_choice]="Stub website selected"
    L[checking_port]="Checking port 443 availability..."
    L[port_busy]="Port 443 is busy! Stopping conflicting services..."
    L[nginx_installed]="Nginx installed and configured"
    L[waiting_dns]="Waiting for DNS update..."
    L[retry_seconds]="Rechecking in %s seconds..."
    L[attempt]="Attempt"
    L[of]="of"
    L[panel_lang_set]="Panel language set"
    L[connection_info]="CONNECTION INFORMATION"
    L[all_users_info]="ALL USERS DATA"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────────

# Spinner animation
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
    printf "\r  ${GREEN}✓${RESET} %s\n" "$msg"
    tput cnorm 2>/dev/null || true
    return $exit_code
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local pct=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "\r  ${CYAN}[${bar}]${RESET} ${WHITE}%3d%%${RESET}" "$pct"
}

# Box drawing
print_header() {
    local text="$1"
    local width=60
    local padding=$(( (width - ${#text}) / 2 ))
    echo ""
    printf "  ${PURPLE}╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗${RESET}\n"
    printf "  ${PURPLE}║${RESET}"
    printf '%*s' $padding ''
    printf "${BOLD}${WHITE}%s${RESET}" "$text"
    printf '%*s' $(( width - padding - ${#text} )) ''
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

print_box_line() {
    local icon="$1"
    local label="$2"
    local value="$3"
    printf "  ${DIM}│${RESET} %s ${WHITE}%-18s${RESET} ${BOLD}${GREEN}%s${RESET}\n" "$icon" "$label:" "$value"
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

# Animated text typing effect
type_text() {
    local text="$1"
    local delay="${2:-0.02}"
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
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
            "fox" "manul" "snowleopard" "cheetah" "ocelot"
            "albatross" "condor" "vulture" "peregrine" "harrier"
            "salamander" "newt" "axolotl" "gecko" "python"
            "narwhal" "beluga" "manatee" "dugong" "whale"
            "marmot" "chinchilla" "porcupine" "capybara" "tapir"
            "phoenix" "griffin" "unicorn" "dragon" "manticore"
        )
    fi

    local names=()
    local used=()

    while [ ${#names[@]} -lt "$count" ]; do
        local adj_idx=$(( RANDOM % ${#adjectives[@]} ))
        local ani_idx=$(( RANDOM % ${#animals[@]} ))
        local name="${adjectives[$adj_idx]}-${animals[$ani_idx]}"

        # Check uniqueness
        local dup=0
        for u in "${used[@]:-}"; do
            if [[ "$u" == "$name" ]]; then dup=1; break; fi
        done

        if [[ $dup -eq 0 ]]; then
            names+=("$name")
            used+=("$name")
        fi
    done

    printf '%s\n' "${names[@]}"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  STUB WEBSITES (3 variants from open-source template libraries)
#  Sources:
#    1) Dimension   — html5up.net (html5up/zce repo, CC BY 3.0)
#    2) Coffee Shop — learning-zone/website-templates (MIT)
#    3) Clean Blog  — StartBootstrap (MIT)
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

    # Pick random template (1-3)
    local pick=$(( RANDOM % ${#TEMPLATES[@]} ))
    local tpl="${TEMPLATES[$pick]}"

    IFS='|' read -r tpl_id tpl_name tpl_repo tpl_source tpl_path <<< "$tpl"
    STUB_SITE="$tpl_name"

    print_info "${L[deploying_stub]}: ${BOLD}${tpl_name}${RESET} (${tpl_source})"

    rm -rf "$tmp_clone"

    case "$tpl_source" in
        html5up)
            # html5up repo (zce/html5up) — mono-repo with folders per template
            git clone --depth 1 --filter=blob:none --sparse "$tpl_repo" "$tmp_clone" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                git clone --depth 1 "$tpl_repo" "$tmp_clone" >/dev/null 2>&1
            fi
            if [ -d "$tmp_clone" ]; then
                cd "$tmp_clone" && git sparse-checkout set "$tpl_path" 2>/dev/null
                if [ -d "$tmp_clone/$tpl_path" ]; then
                    rm -rf "${site_dir:?}"/*
                    cp -r "$tmp_clone/$tpl_path"/* "$site_dir/"
                fi
                cd - >/dev/null
            fi
            ;;

        learning-zone)
            # learning-zone/website-templates — mono-repo with folders
            git clone --depth 1 --filter=blob:none --sparse "$tpl_repo" "$tmp_clone" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                git clone --depth 1 "$tpl_repo" "$tmp_clone" >/dev/null 2>&1
            fi
            if [ -d "$tmp_clone" ]; then
                cd "$tmp_clone" && git sparse-checkout set "$tpl_path" 2>/dev/null
                if [ -d "$tmp_clone/$tpl_path" ]; then
                    rm -rf "${site_dir:?}"/*
                    cp -r "$tmp_clone/$tpl_path"/* "$site_dir/"
                fi
                cd - >/dev/null
            fi
            ;;

        startbootstrap)
            # StartBootstrap — each template is its own repo, dist/ has production files
            git clone --depth 1 "$tpl_repo" "$tmp_clone" >/dev/null 2>&1
            if [ -d "$tmp_clone" ]; then
                rm -rf "${site_dir:?}"/*
                if [ -f "$tmp_clone/dist/index.html" ]; then
                    cp -r "$tmp_clone/dist/"* "$site_dir/"
                elif [ -f "$tmp_clone/index.html" ]; then
                    cp -r "$tmp_clone/"* "$site_dir/"
                else
                    local found_idx
                    found_idx=$(find "$tmp_clone" -name "index.html" -type f 2>/dev/null | head -1)
                    if [ -n "$found_idx" ]; then
                        cp -r "$(dirname "$found_idx")"/* "$site_dir/"
                    fi
                fi
            fi
            ;;
    esac

    rm -rf "$tmp_clone"

    # Verify deployment
    if [ -f "$site_dir/index.html" ]; then
        chown -R www-data:www-data "$site_dir" 2>/dev/null || true
        chmod -R 755 "$site_dir"
        print_success "${L[stub_choice]}: $STUB_SITE"
    else
        # Fallback: create a minimal professional page if git clone failed
        print_warning "Git clone failed, deploying built-in fallback..."
        cat > "$site_dir/index.html" << 'FALLBACKEOF'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Welcome</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;display:flex;align-items:center;justify-content:center;min-height:100vh;text-align:center}
.c{max-width:600px;padding:2rem}h1{font-size:2.5rem;margin-bottom:1rem;background:linear-gradient(135deg,#6366f1,#a855f7);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
p{color:#94a3b8;line-height:1.8}</style></head><body><div class="c"><h1>Welcome</h1><p>This site is currently under construction. Please check back later.</p></div></body></html>
FALLBACKEOF
        STUB_SITE="Fallback (minimal)"
        print_success "${L[stub_choice]}: $STUB_SITE"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────────
#  NGINX SETUP
# ─────────────────────────────────────────────────────────────────────────────────

setup_nginx() {
    # Stop anything on port 443
    if ss -tlnp | grep -q ':443 '; then
        print_warning "${L[port_busy]}"
        systemctl stop nginx 2>/dev/null || true
        systemctl stop apache2 2>/dev/null || true
        fuser -k 443/tcp 2>/dev/null || true
        sleep 1
    fi

    apt-get install -y nginx >/dev/null 2>&1

    # Create nginx config for stub site
    if [[ "$MODE" == "domain" ]]; then
        local server_name="$DOMAIN"
    else
        local server_name="_"
    fi

    cat > /etc/nginx/sites-available/stub << NGINXEOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${server_name};
    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/stub /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    nginx -t >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    systemctl restart nginx

    print_success "${L[nginx_installed]}"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  DNS CHECK
# ─────────────────────────────────────────────────────────────────────────────────

check_dns() {
    local domain="$1"
    local max_attempts=10
    local attempt=1

    while true; do
        printf "\r  ${CYAN}◌${RESET} ${L[checking_domain]} (${L[attempt]} $attempt)"

        local resolved_ip
        resolved_ip=$(dig +short "$domain" A 2>/dev/null | head -1)

        if [[ "$resolved_ip" == "$SERVER_IP" ]]; then
            printf "\r  ${GREEN}✓${RESET} ${L[domain_ok]}                           \n"
            return 0
        fi

        if [[ -n "$resolved_ip" ]]; then
            printf "\n"
            print_warning "$(printf "${L[domain_ip_mismatch]}" "$resolved_ip" "$SERVER_IP")"
        else
            printf "\n"
            print_warning "${L[domain_fail]}"
        fi

        if [[ $attempt -ge $max_attempts ]]; then
            return 1
        fi

        echo ""
        printf "  ${YELLOW}?${RESET} ${L[domain_wait]} [${L[yes]}/${L[no]}]: "
        read -r answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        if [[ "$answer" == "n" ]] || [[ "$answer" == "no" ]] || [[ "$answer" == "нет" ]] || [[ "$answer" == "н" ]]; then
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
    print_info "${L[installing_xui]}"
    > "$LOG_FILE"

    # Determine ACME option based on mode
    if [[ "$MODE" == "domain" ]]; then
        # For domain mode: we'll get certs via 3x-ui ACME with domain
        expect << XEOF | tee "$LOG_FILE" > /dev/null 2>&1
set timeout 600
spawn bash -c "curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash"

expect "Confirm the installation"
sleep 1
send "y\r"

expect "customize the Panel Port settings"
sleep 1
send "n\r"

expect "Choose an option"
sleep 1
send "1\r"

expect "Please enter your domain name"
sleep 1
send "${DOMAIN}\r"

expect eof
XEOF
    else
        # For IP mode: self-signed certs (option 2 = self-signed)
        expect << XEOF | tee "$LOG_FILE" > /dev/null 2>&1
set timeout 600
spawn bash -c "curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash"

expect "Confirm the installation"
sleep 1
send "y\r"

expect "customize the Panel Port settings"
sleep 1
send "n\r"

expect "Choose an option"
sleep 1
send "2\r"

expect "Port to use for ACME"
sleep 1
send "\r"

expect eof
XEOF
    fi

    sleep 3
}

# ─────────────────────────────────────────────────────────────────────────────────
#  EXTRACT PANEL CREDENTIALS
# ─────────────────────────────────────────────────────────────────────────────────

extract_credentials() {
    # From database
    if [ -f "$XUI_DB" ]; then
        XUI_USER=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='username';" 2>/dev/null)
        XUI_PASS=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='password';" 2>/dev/null)
        XUI_PORT=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='port';" 2>/dev/null)
        XUI_PATH=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null)
    fi

    # Fallback to log
    if [[ -z "$XUI_USER" ]] || [[ -z "$XUI_PASS" ]]; then
        XUI_USER=$(grep "Username:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d '\r')
        XUI_PASS=$(grep "Password:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d '\r')
    fi

    if [[ ! "$XUI_PORT" =~ ^[0-9]+$ ]]; then
        XUI_PORT=$(grep -E "Port:[[:space:]]+[0-9]+" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d '\r')
    fi

    if [[ -z "$XUI_PATH" ]]; then
        XUI_PATH=$(grep "WebBasePath:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d '\r')
    fi

    XUI_PATH=$(echo "$XUI_PATH" | tr -d '"/')

    if [[ "$MODE" == "domain" ]]; then
        XUI_URL="https://${DOMAIN}:${XUI_PORT}/${XUI_PATH}/"
    else
        XUI_URL="https://${SERVER_IP}:${XUI_PORT}/${XUI_PATH}/"
    fi

    API_BASE="https://127.0.0.1:${XUI_PORT}/${XUI_PATH}"

    rm -f "$LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  3X-UI API FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────────

api_login() {
    local response
    response=$(curl -sk -c - "${API_BASE}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null)

    API_COOKIE=$(curl -sk -c - -D - "${API_BASE}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null | grep -i 'set-cookie' | head -1 | sed 's/.*: //' | sed 's/;.*//')

    # Save cookie to file for reuse
    curl -sk -c /tmp/xui_cookie.txt "${API_BASE}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${XUI_USER}&password=${XUI_PASS}" >/dev/null 2>&1
}

api_set_language() {
    local lang_code
    if [[ "$LANG_CHOICE" == "ru" ]]; then
        lang_code="ru"
    else
        lang_code="en"
    fi

    # Set panel language via settings API
    curl -sk -b /tmp/xui_cookie.txt "${API_BASE}/panel/setting/update" \
        -H "Content-Type: application/json" \
        -d "{\"webLang\": \"${lang_code}\"}" >/dev/null 2>&1
}

api_create_inbound() {
    local host
    if [[ "$MODE" == "domain" ]]; then
        host="$DOMAIN"
    else
        host="$SERVER_IP"
    fi

    # Get cert paths
    if [[ "$MODE" == "domain" ]]; then
        CERT_PATH="/root/cert/${DOMAIN}/fullchain.pem"
        KEY_PATH="/root/cert/${DOMAIN}/privkey.pem"

        # Wait for certs if they don't exist yet
        for i in $(seq 1 30); do
            if [[ -f "$CERT_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
                break
            fi
            # Check alternative paths
            if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
                CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
                KEY_PATH="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
                break
            fi
            sleep 2
        done
    else
        # Self-signed certs generated by 3x-ui
        CERT_PATH=""
        KEY_PATH=""
    fi

    # Generate clients JSON
    local clients_json="["
    local names
    names=$(generate_random_names 10)
    local name_array=()
    while IFS= read -r line; do
        name_array+=("$line")
    done <<< "$names"

    USER_NAMES=("${name_array[@]}")
    USER_UUIDS=()

    for i in $(seq 0 9); do
        local uuid
        uuid=$(cat /proc/sys/kernel/random/uuid)
        USER_UUIDS+=("$uuid")

        if [[ $i -gt 0 ]]; then
            clients_json+=","
        fi
        clients_json+="{
            \"id\": \"${uuid}\",
            \"flow\": \"xtls-rprx-vision\",
            \"email\": \"${name_array[$i]}\",
            \"limitIp\": 0,
            \"totalGB\": 0,
            \"expiryTime\": 0,
            \"enable\": true,
            \"tgId\": \"\",
            \"subId\": \"$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)\",
            \"reset\": 0
        }"
    done
    clients_json+="]"

    # Build stream settings
    local stream_settings
    if [[ "$MODE" == "domain" ]]; then
        stream_settings="{
            \"network\": \"tcp\",
            \"security\": \"tls\",
            \"tlsSettings\": {
                \"serverName\": \"${DOMAIN}\",
                \"minVersion\": \"1.2\",
                \"maxVersion\": \"1.3\",
                \"cipherSuites\": \"\",
                \"rejectUnknownSni\": false,
                \"disableSystemRoot\": false,
                \"enableSessionResumption\": false,
                \"certificates\": [{
                    \"certificateFile\": \"${CERT_PATH}\",
                    \"keyFile\": \"${KEY_PATH}\",
                    \"ocspStapling\": 3600
                }],
                \"alpn\": [\"h2\", \"http/1.1\"],
                \"settings\": {
                    \"allowInsecure\": false,
                    \"fingerprint\": \"chrome\"
                }
            },
            \"tcpSettings\": {
                \"acceptProxyProtocol\": false,
                \"header\": {\"type\": \"none\"}
            }
        }"
    else
        stream_settings="{
            \"network\": \"tcp\",
            \"security\": \"tls\",
            \"tlsSettings\": {
                \"serverName\": \"\",
                \"minVersion\": \"1.2\",
                \"maxVersion\": \"1.3\",
                \"cipherSuites\": \"\",
                \"rejectUnknownSni\": false,
                \"disableSystemRoot\": false,
                \"enableSessionResumption\": false,
                \"certificates\": [{
                    \"certificateFile\": \"\",
                    \"keyFile\": \"\",
                    \"ocspStapling\": 3600
                }],
                \"alpn\": [\"h2\", \"http/1.1\"],
                \"settings\": {
                    \"allowInsecure\": true,
                    \"fingerprint\": \"chrome\"
                }
            },
            \"tcpSettings\": {
                \"acceptProxyProtocol\": false,
                \"header\": {\"type\": \"none\"}
            }
        }"
    fi

    # Sniffing settings
    local sniffing="{
        \"enabled\": true,
        \"destOverride\": [\"http\", \"tls\", \"quic\", \"fakedns\"],
        \"metadataOnly\": false,
        \"routeOnly\": false
    }"

    local inbound_json="{
        \"up\": 0,
        \"down\": 0,
        \"total\": 0,
        \"remark\": \"VLESS-TCP-XTLS\",
        \"enable\": true,
        \"expiryTime\": 0,
        \"listen\": \"\",
        \"port\": 443,
        \"protocol\": \"vless\",
        \"settings\": \"{ \\\"clients\\\": $(echo "$clients_json" | sed 's/"/\\"/g'), \\\"decryption\\\": \\\"none\\\", \\\"fallbacks\\\": [{\\\"dest\\\": 80}] }\",
        \"streamSettings\": \"$(echo "$stream_settings" | tr -d '\n' | sed 's/"/\\"/g')\",
        \"tag\": \"inbound-443\",
        \"sniffing\": \"$(echo "$sniffing" | tr -d '\n' | sed 's/"/\\"/g')\"
    }"

    # Use the simpler direct approach - write to DB
    # First, let's use the API properly

    # Build properly escaped JSON for API
    local settings_escaped
    settings_escaped=$(cat << SETEOF
{
    "clients": $(echo "$clients_json"),
    "decryption": "none",
    "fallbacks": [{"dest": 80}]
}
SETEOF
    )

    local stream_escaped
    stream_escaped=$(echo "$stream_settings")

    local sniffing_escaped
    sniffing_escaped=$(echo "$sniffing")

    # Create the inbound via API
    local payload
    payload=$(python3 -c "
import json

clients = json.loads('''$(echo "$clients_json")''')

settings = {
    'clients': clients,
    'decryption': 'none',
    'fallbacks': [{'dest': 80}]
}

stream = json.loads('''$(echo "$stream_settings")''')

sniffing = {
    'enabled': True,
    'destOverride': ['http', 'tls', 'quic', 'fakedns'],
    'metadataOnly': False,
    'routeOnly': False
}

payload = {
    'up': 0,
    'down': 0,
    'total': 0,
    'remark': 'VLESS-TCP-XTLS',
    'enable': True,
    'expiryTime': 0,
    'listen': '',
    'port': 443,
    'protocol': 'vless',
    'settings': json.dumps(settings),
    'streamSettings': json.dumps(stream),
    'tag': 'inbound-443',
    'sniffing': json.dumps(sniffing)
}

print(json.dumps(payload))
")

    curl -sk -b /tmp/xui_cookie.txt "${API_BASE}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d "$payload" >/dev/null 2>&1

    print_success "${L[configuring_vless]}"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  GENERATE VLESS LINKS & QR
# ─────────────────────────────────────────────────────────────────────────────────

generate_vless_link() {
    local uuid="$1"
    local name="$2"
    local host

    if [[ "$MODE" == "domain" ]]; then
        host="$DOMAIN"
        echo "vless://${uuid}@${host}:443?type=tcp&security=tls&sni=${host}&fp=chrome&flow=xtls-rprx-vision#${name}"
    else
        host="$SERVER_IP"
        echo "vless://${uuid}@${host}:443?type=tcp&security=tls&sni=${host}&fp=chrome&flow=xtls-rprx-vision&allowInsecure=1#${name}"
    fi
}

show_qr() {
    local data="$1"
    qrencode -t ANSIUTF8 "$data"
}

# ─────────────────────────────────────────────────────────────────────────────────
#  CHECK CLIENT ONLINE STATUS
# ─────────────────────────────────────────────────────────────────────────────────

check_client_online() {
    local email="$1"
    local timeout=180  # 3 minutes
    local elapsed=0
    local check_interval=5

    while [[ $elapsed -lt $timeout ]]; do
        local response
        response=$(curl -sk -b /tmp/xui_cookie.txt "${API_BASE}/panel/api/inbounds/onlines" 2>/dev/null)

        if echo "$response" | grep -q "$email"; then
            return 0
        fi

        # Animated waiting
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        for ((f=0; f<check_interval*10; f++)); do
            local frame_idx=$(( f % ${#frames[@]} ))
            local remaining=$(( timeout - elapsed ))
            printf "\r  ${CYAN}${frames[$frame_idx]}${RESET} ${L[waiting_online]} ${DIM}(${remaining}s)${RESET}  "
            sleep 0.1
        done

        elapsed=$((elapsed + check_interval))
    done

    printf "\n"
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────────
#  DISPLAY CREDENTIALS
# ─────────────────────────────────────────────────────────────────────────────────

show_credentials() {
    clear
    echo ""
    printf "  ${GREEN}╔"
    printf '═%.0s' $(seq 1 58)
    printf "╗${RESET}\n"

    local title="${L[install_complete]}"
    local pad=$(( (58 - ${#title}) / 2 ))
    printf "  ${GREEN}║${RESET}"
    printf '%*s' $pad ''
    printf "${BOLD}${WHITE}%s${RESET}" "$title"
    printf '%*s' $(( 58 - pad - ${#title} )) ''
    printf "${GREEN}║${RESET}\n"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  👤 ${WHITE}%-18s${RESET} ${BOLD}%-30s${RESET}${GREEN}║${RESET}\n" "${L[username]}:" "$XUI_USER"
    printf "  ${GREEN}║${RESET}  🔑 ${WHITE}%-18s${RESET} ${BOLD}%-30s${RESET}${GREEN}║${RESET}\n" "${L[password]}:" "$XUI_PASS"
    printf "  ${GREEN}║${RESET}  🔌 ${WHITE}%-18s${RESET} ${YELLOW}%-30s${RESET}${GREEN}║${RESET}\n" "${L[port]}:" "$XUI_PORT"
    printf "  ${GREEN}║${RESET}  📁 ${WHITE}%-18s${RESET} %-30s${GREEN}║${RESET}\n" "${L[panel_path]}:" "/${XUI_PATH}/"
    printf "  ${GREEN}║${RESET}  🌐 ${WHITE}%-18s${RESET} ${GREEN}${UNDERLINE}%-30s${RESET}${GREEN}║${RESET}\n" "${L[login_url]}:" ""
    printf "  ${GREEN}║${RESET}     ${GREEN}${UNDERLINE}%-52s${RESET}${GREEN}║${RESET}\n" "$XUI_URL"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  ${YELLOW}⚠  ${BOLD}%-51s${RESET}${GREEN}║${RESET}\n" "${L[save_warning]}"

    printf "  ${GREEN}╠"
    printf '═%.0s' $(seq 1 58)
    printf "╣${RESET}\n"

    printf "  ${GREEN}║${RESET}  ${CYAN}ℹ  ${BOLD}%-51s${RESET}${GREEN}║${RESET}\n" "${L[cert_info]}"

    if [[ "$MODE" == "domain" ]]; then
        local cert_info="${L[cert_domain_info]}"
    else
        local cert_info="${L[cert_ip_info]}"
    fi

    while IFS= read -r line; do
        printf "  ${GREEN}║${RESET}     %-52s${GREEN}║${RESET}\n" "$line"
    done <<< "$(echo -e "$cert_info")"

    printf "  ${GREEN}║${RESET}%-58s${GREEN}║${RESET}\n" ""
    printf "  ${GREEN}║${RESET}  ${GREEN}✅ %-52s${RESET}${GREEN}║${RESET}\n" "${L[ready]}"

    printf "  ${GREEN}╚"
    printf '═%.0s' $(seq 1 58)
    printf "╝${RESET}\n"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────────
#  HAPP / HIDDIFY CLIENT DOWNLOAD
# ─────────────────────────────────────────────────────────────────────────────────

show_app_download() {
    print_header "${L[download_happ]}"

    echo ""
    printf "  ${YELLOW}?${RESET} ${L[choose_platform]}\n"
    printf "    ${WHITE}1)${RESET} ${L[ios]}\n"
    printf "    ${WHITE}2)${RESET} ${L[android]}\n"
    echo ""
    printf "  ${CYAN}▸${RESET} "
    read -r platform_choice

    local app_url_ios="https://apps.apple.com/app/hiddify-proxy-vpn/id6596777532"
    local app_url_android="https://play.google.com/store/apps/details?id=app.hiddify.com"

    echo ""
    print_separator

    if [[ "$platform_choice" == "1" ]]; then
        echo ""
        printf "  ${CYAN}📱 iOS — Hiddify (App Store):${RESET}\n\n"
        show_qr "$app_url_ios"
    else
        echo ""
        printf "  ${CYAN}📱 Android — Hiddify (Google Play):${RESET}\n\n"
        show_qr "$app_url_android"
    fi

    echo ""
    print_separator
    echo ""

    while true; do
        printf "  ${YELLOW}?${RESET} ${L[confirm_installed]} "
        read -r installed
        installed=$(echo "$installed" | tr '[:upper:]' '[:lower:]')
        if [[ "$installed" == "yes" ]] || [[ "$installed" == "y" ]] || [[ "$installed" == "да" ]] || [[ "$installed" == "д" ]]; then
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
    print_header "${L[test_connection]}"

    echo ""
    printf "  ${CYAN}${L[scan_qr_config]}${RESET}\n"
    echo ""

    local first_link
    first_link=$(generate_vless_link "${USER_UUIDS[0]}" "${USER_NAMES[0]}")

    show_qr "$first_link"

    echo ""
    print_separator
    printf "  ${DIM}VLESS link: ${first_link}${RESET}\n"
    print_separator
    echo ""

    # Refresh API cookie
    api_login

    if check_client_online "${USER_NAMES[0]}"; then
        printf "\r  ${GREEN}✓${RESET} ${BOLD}${GREEN}${L[client_online]}${RESET}                              \n"
    else
        print_warning "${L[client_timeout]}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────────
#  SHOW ALL USERS
# ─────────────────────────────────────────────────────────────────────────────────

show_all_users() {
    print_header "${L[all_users_info]}"

    for i in $(seq 0 9); do
        local link
        link=$(generate_vless_link "${USER_UUIDS[$i]}" "${USER_NAMES[$i]}")

        printf "  ${WHITE}%2d.${RESET} ${BOLD}${USER_NAMES[$i]}${RESET}\n" "$((i+1))"
        printf "      ${DIM}UUID: ${USER_UUIDS[$i]}${RESET}\n"
        printf "      ${DIM}Link: ${link}${RESET}\n"
        echo ""
    done
}

# ─────────────────────────────────────────────────────────────────────────────────
#  CONFIGURE NGINX AS FALLBACK (TLS termination by xray, HTTP fallback to nginx)
# ─────────────────────────────────────────────────────────────────────────────────

setup_fallback_nginx() {
    # Xray will listen on 443 with TLS
    # Fallback goes to nginx on port 80
    # Nginx serves the stub site on port 80

    cat > /etc/nginx/sites-available/stub << NGINXEOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Prevent access logging for health checks
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/stub /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t >/dev/null 2>&1
    systemctl restart nginx 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────────
#  MAIN FLOW
# ─────────────────────────────────────────────────────────────────────────────────

main() {
    # ── Root check ──
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗${RESET} ${L[error_root]:-Run as root!}"
        exit 1
    fi

    clear

    # ╔═══════════════════════════════════════╗
    # ║     WELCOME SCREEN & LANG SELECT      ║
    # ╚═══════════════════════════════════════╝

    echo ""
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
    echo ""
    printf "  ${DIM}──────────── 3X-UI Professional Installer v2.0 ────────────${RESET}\n"
    echo ""
    echo ""

    printf "  ${WHITE}Выберите язык / Choose language:${RESET}\n\n"
    printf "    ${CYAN}1)${RESET} 🇷🇺  Русский\n"
    printf "    ${CYAN}2)${RESET} 🇬🇧  English\n"
    echo ""
    printf "  ${CYAN}▸${RESET} "
    read -r lang_input

    if [[ "$lang_input" == "1" ]] || [[ "$lang_input" == "ru" ]]; then
        LANG_CHOICE="ru"
        set_lang_ru
    else
        LANG_CHOICE="en"
        set_lang_en
    fi

    print_success "${L[panel_lang_set]}: $([ "$LANG_CHOICE" == "ru" ] && echo "Русский" || echo "English")"
    echo ""

    # ── Get server IP ──
    SERVER_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 api.ipify.org 2>/dev/null || curl -s --max-time 10 icanhazip.com 2>/dev/null)

    # ╔═══════════════════════════════════════╗
    # ║        MODE SELECTION                  ║
    # ╚═══════════════════════════════════════╝

    print_header "${L[choose_mode]}"

    printf "    ${CYAN}1)${RESET} 🌐  ${L[mode_ip]}\n"
    printf "    ${CYAN}2)${RESET} 🔒  ${L[mode_domain]}\n"
    echo ""
    printf "  ${CYAN}▸${RESET} "
    read -r mode_input

    if [[ "$mode_input" == "2" ]]; then
        MODE="domain"
        echo ""
        printf "  ${CYAN}▸${RESET} ${L[enter_domain]}: "
        read -r DOMAIN

        # Strip protocol if user added it
        DOMAIN=$(echo "$DOMAIN" | sed 's|https\?://||' | sed 's|/.*||')

        echo ""
        if ! check_dns "$DOMAIN"; then
            print_error "${L[domain_fail]}"
            echo ""
            printf "  ${DIM}%s${RESET}\n" "$([ "$LANG_CHOICE" == "ru" ] && echo "Направьте домен A-записью на IP: $SERVER_IP и запустите скрипт снова." || echo "Point your domain A record to IP: $SERVER_IP and run the script again.")"
            echo ""
            exit 1
        fi
    else
        MODE="ip"
    fi

    echo ""

    # ╔═══════════════════════════════════════╗
    # ║        ALREADY INSTALLED CHECK         ║
    # ╚═══════════════════════════════════════╝

    if [ -f "/usr/local/x-ui/x-ui" ]; then
        print_warning "${L[already_installed]}"
        extract_credentials
        show_credentials
        exit 0
    fi

    # ╔═══════════════════════════════════════╗
    # ║        INSTALLATION                    ║
    # ╚═══════════════════════════════════════╝

    # ── Step 1: Dependencies ──
    print_info "${L[installing_deps]}"
    (
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq expect qrencode curl sqlite3 dnsutils nginx python3 git > /dev/null 2>&1
    ) &
    spinner $! "${L[installing_deps]}"

    # ── Step 2: Deploy stub site ──
    print_info "${L[deploying_stub]}"
    deploy_stub_site

    # ── Step 3: Setup nginx for stub ──
    setup_nginx

    # ── Step 4: Install 3x-ui ──
    install_3xui

    # ── Step 5: Extract credentials ──
    extract_credentials

    # ── Step 6: Wait for panel to be ready ──
    sleep 3

    # ── Step 7: API login & configure ──
    print_info "${L[configuring_vless]}"

    api_login

    # Set language
    api_set_language
    print_success "${L[panel_lang_set]}"

    # ── Step 8: Reconfigure nginx as fallback (port 80 only) ──
    setup_fallback_nginx

    # ── Step 9: Create VLESS inbound with 10 users ──
    print_info "${L[creating_users]}"
    api_create_inbound
    print_success "10 ${L[users_created]}"

    # ╔═══════════════════════════════════════╗
    # ║        RESULTS                         ║
    # ╚═══════════════════════════════════════╝

    show_credentials
    wait_enter

    # ── App download ──
    show_app_download

    # ── Connection test ──
    test_connection

    # ── Final message ──
    echo ""
    print_separator
    echo ""
    printf "  ${GREEN}${BOLD}"
    echo -e "${L[final_message]}"
    printf "${RESET}"
    echo ""
    print_separator

    # ── Show all users ──
    show_all_users

    # ── Duplicate credentials ──
    echo ""
    show_credentials

    # ── Cleanup ──
    rm -f /tmp/xui_cookie.txt

    echo ""
    printf "  ${DIM}$([ "$LANG_CHOICE" == "ru" ] && echo "Скрипт завершён. Удачи!" || echo "Script completed. Good luck!")${RESET}\n"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────────
main "$@"
