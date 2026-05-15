#!/bin/bash
# XUIFAST v3.0.0 — Core utilities
# Colors, logging, spinner, apt handling, IP/geo detection, JSON config

# ── Version & paths ─────────────────────────────────────────────────────
XUIFAST_VERSION="3.0.5"
XUIFAST_DIR="${XUIFAST_DIR:-/opt/xuifast}"
XUIFAST_CONFIG="${XUIFAST_CONFIG:-${XUIFAST_DIR}/config.json}"
XUI_DIR="/usr/local/x-ui"
XUI_BIN="${XUI_DIR}/x-ui"
get_xray_bin() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) arch="amd64" ;;
    esac
    local bin="${XUI_DIR}/bin/xray-linux-${arch}"
    # Fallback: find any xray binary
    if [ ! -f "$bin" ]; then
        bin=$(find "${XUI_DIR}/bin/" -name 'xray*' -type f 2>/dev/null | head -1)
    fi
    echo "${bin:-${XUI_DIR}/bin/xray-linux-amd64}"
}
XRAY_BIN="$(get_xray_bin)"
XUI_DB="/etc/x-ui/x-ui.db"
XUI_SERVICE="x-ui"
CREDENTIALS_FILE="/root/.xuifast_credentials"
WEBSITE_ROOT="/var/www/html"
NGINX_SITE_CONF="/etc/nginx/sites-available/xuifast"
NGINX_SITE_LINK="/etc/nginx/sites-enabled/xuifast"
BACKUP_DIR="${XUIFAST_DIR}/backups"
TEMPLATES_CATALOG="${XUIFAST_DIR}/templates_catalog.json"

# ── Security: restrict temp file permissions ───────────────────────────
umask 077

# ── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Logging ─────────────────────────────────────────────────────────────
log_info()    { echo -e "  ${CYAN}ℹ${NC}  $*"; }
log_success() { echo -e "  ${GREEN}✓${NC}  $*"; }
log_warning() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
log_error()   { echo -e "  ${RED}✗${NC}  $*"; }
log_step()    { echo -e "\n  ${BOLD}${WHITE}▸ $*${NC}"; }
log_dim()     { echo -e "  ${DIM}$*${NC}"; }

# ── Spinner ─────────────────────────────────────────────────────────────
SPINNER_PID=""
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

start_spinner() {
    local msg="${1:-}"
    (
        local i=0
        while true; do
            printf "\r  ${CYAN}%s${NC}  %s" "${SPINNER_FRAMES[$((i % ${#SPINNER_FRAMES[@]}))]}" "$msg" >&2
            sleep 0.1
            ((i++)) || true
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null
}

stop_spinner() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
    fi
    SPINNER_PID=""
    printf "\r\033[K" >&2
}

# run_with_spinner "message" command [args...]
run_with_spinner() {
    local msg="$1"; shift
    start_spinner "$msg"
    local rc=0
    "$@" || rc=$?
    stop_spinner
    return $rc
}

# ── Progress bar ────────────────────────────────────────────────────────
progress_bar() {
    local current=$1 total=$2 width=${3:-40}
    [ "$total" -eq 0 ] && return 0
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf "\r  ${CYAN}[${NC}" >&2
    [ "$filled" -gt 0 ] && printf "%0.s█" $(seq 1 $filled) >&2
    [ "$empty" -gt 0 ] && printf "%0.s░" $(seq 1 $empty) >&2
    printf "${CYAN}]${NC} %3d%%" "$pct" >&2
}

# ── User prompts ────────────────────────────────────────────────────────
# confirm "question" → returns 0 (yes) or 1 (no)
confirm() {
    local prompt="${1:-Continue?}"
    echo -ne "  ${WHITE}${prompt}${NC} [Y/n]: " >&2
    local answer
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[YyДд] ]]
}

# read_choice "prompt" min max → echoes chosen number
read_choice() {
    local prompt="$1" min="$2" max="$3"
    local choice
    echo -ne "  ${WHITE}${prompt}${NC} " >&2
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min" ] && [ "$choice" -le "$max" ]; then
        echo "$choice"
        return 0
    fi
    return 1
}

# ── OS & arch detection ─────────────────────────────────────────────────
get_os() {
    if [ -f /etc/os-release ]; then
        (. /etc/os-release && echo "${ID:-linux}")
    else
        uname -s | tr '[:upper:]' '[:lower:]'
    fi
}

get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7*|armhf)  echo "armv7" ;;
        *)             echo "$arch" ;;
    esac
}

get_pkg_manager() {
    if command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    else echo "unknown"
    fi
}

# ── APT lock handling ───────────────────────────────────────────────────
apt_lock_wait() {
    local timeout="${1:-120}"
    local elapsed=0
    while fuser /var/lib/dpkg/lock-frontend &>/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock &>/dev/null 2>&1; do
        if [ "$elapsed" -ge "$timeout" ]; then
            log_error "APT lock timeout (${timeout}s)"
            return 1
        fi
        [ "$elapsed" -eq 0 ] && log_dim "Waiting for APT lock..."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 0
}

apt_update() {
    apt_lock_wait || return 1
    apt-get update -qq 2>/dev/null
}

apt_install() {
    apt_lock_wait || return 1
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1
}

# ── Dependency management ───────────────────────────────────────────────
CRITICAL_DEPS=(curl jq openssl qrencode expect)
OPTIONAL_DEPS=(git nginx certbot)

install_dependencies() {
    local missing=()
    for cmd in "${CRITICAL_DEPS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            case "$cmd" in
                expect)   missing+=("expect") ;;
                qrencode) missing+=("qrencode") ;;
                *)        missing+=("$cmd") ;;
            esac
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_info "$(tf deps_installing "${missing[*]}")"
        apt_update || { log_error "apt-get update failed"; return 1; }
        apt_install "${missing[@]}" || {
            log_error "Failed to install: ${missing[*]}"
            return 1
        }
        log_success "$(t deps_installed)"
    fi
    return 0
}

# ── IP detection ────────────────────────────────────────────────────────
get_server_ip() {
    local raw_ip
    for svc in ifconfig.me api.ipify.org icanhazip.com ipinfo.io/ip; do
        raw_ip=$(curl -s --max-time 10 "$svc" 2>/dev/null | tr -d '[:space:]')
        if _valid_ip "$raw_ip"; then
            echo "$raw_ip"
            return 0
        fi
    done
    # Fallback to local interface
    raw_ip=$(ip -4 addr show scope global 2>/dev/null | grep -o 'inet [0-9.]*' | sed 's/inet //' | head -1)
    if _valid_ip "$raw_ip"; then
        echo "$raw_ip"
        return 0
    fi
    log_error "Cannot detect server IP"
    return 1
}

_valid_ip() {
    local ip="$1"
    [[ -z "$ip" ]] && return 1
    local IFS='.'
    read -ra octets <<< "$ip"
    [[ ${#octets[@]} -ne 4 ]] && return 1
    for o in "${octets[@]}"; do
        [[ ! "$o" =~ ^[0-9]+$ ]] && return 1
        (( o < 0 || o > 255 )) && return 1
    done
    return 0
}

# ── IP geolocation (for Lite mode domain suggestions) ───────────────────
# Returns 2-letter country code: "RU", "US", "DE", etc.
get_ip_country() {
    local ip="${1:-}"
    local country=""

    # Try ipinfo.io first (lightweight, no key needed)
    if [ -n "$ip" ]; then
        country=$(curl -s --max-time 5 "https://ipinfo.io/${ip}/country" 2>/dev/null | tr -d '[:space:]"')
    else
        country=$(curl -s --max-time 5 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]"')
    fi

    # Validate: must be 2 uppercase letters
    if [[ "$country" =~ ^[A-Z]{2}$ ]]; then
        echo "$country"
        return 0
    fi

    # Fallback: ip-api.com
    if [ -n "$ip" ]; then
        country=$(curl -s --max-time 5 "http://ip-api.com/line/${ip}?fields=countryCode" 2>/dev/null | tr -d '[:space:]')
    else
        country=$(curl -s --max-time 5 "http://ip-api.com/line/?fields=countryCode" 2>/dev/null | tr -d '[:space:]')
    fi

    if [[ "$country" =~ ^[A-Z]{2}$ ]]; then
        echo "$country"
        return 0
    fi

    echo "US"  # default fallback
}

is_russian_ip() {
    local country
    country=$(get_ip_country "$1")
    [[ "$country" == "RU" ]]
}

# ── Domain validation ───────────────────────────────────────────────────
valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]
}

# DNS check: does domain point to our IP?
check_dns() {
    local domain="$1"
    local expected_ip="$2"
    local resolved
    resolved=$(dig +short "$domain" A 2>/dev/null)
    echo "$resolved" | grep -qFx "$expected_ip"
}

# ── JSON config management ──────────────────────────────────────────────
# Requires jq. Config stored in $XUIFAST_CONFIG
config_get() {
    local key="$1"
    local default="${2:-}"
    if [ -f "$XUIFAST_CONFIG" ] && command -v jq &>/dev/null; then
        local val
        val=$(jq -r ".${key} // empty" "$XUIFAST_CONFIG" 2>/dev/null)
        if [ -n "$val" ]; then
            echo "$val"
            return 0
        fi
    fi
    echo "$default"
}

config_set() {
    local key="$1"
    local value="$2"
    mkdir -p "$(dirname "$XUIFAST_CONFIG")"

    if [ ! -f "$XUIFAST_CONFIG" ]; then
        echo '{}' > "$XUIFAST_CONFIG"
    fi

    local tmp
    tmp=$(mktemp) || return 1
    if jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$XUIFAST_CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$XUIFAST_CONFIG"
        chmod 600 "$XUIFAST_CONFIG"
    else
        rm -f "$tmp"
        return 1
    fi
}

config_set_int() {
    local key="$1"
    local value="$2"
    mkdir -p "$(dirname "$XUIFAST_CONFIG")"

    if [ ! -f "$XUIFAST_CONFIG" ]; then
        echo '{}' > "$XUIFAST_CONFIG"
    fi

    local tmp
    tmp=$(mktemp) || return 1
    if jq --arg k "$key" --argjson v "$value" '. + {($k): $v}' "$XUIFAST_CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$XUIFAST_CONFIG"
        chmod 600 "$XUIFAST_CONFIG"
    else
        rm -f "$tmp"
        return 1
    fi
}

# ── Random generation ───────────────────────────────────────────────────
random_hex() {
    local len="${1:-16}"
    openssl rand -hex "$(( (len + 1) / 2 ))" 2>/dev/null | head -c "$len"
}

random_port() {
    local min="${1:-10000}" max="${2:-65000}"
    if command -v shuf &>/dev/null; then
        shuf -i "${min}-${max}" -n 1
    else
        echo $(( RANDOM % (max - min) + min ))
    fi
}

random_string() {
    local len="${1:-12}"
    openssl rand -base64 48 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c "$len"
}

# ── Port check ──────────────────────────────────────────────────────────
check_port() {
    local port="$1"
    ss -tlnp 2>/dev/null | grep -E ":${port}\b" | head -1
}

# ── Disk space check ───────────────────────────────────────────────────
check_disk_space() {
    local required_mb="${1:-500}"
    local available_mb
    available_mb=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$available_mb" ]; then
        log_warning "Cannot determine disk space"
        return 0
    fi
    if [ "$available_mb" -lt "$required_mb" ]; then
        return 1
    fi
    return 0
}

# ── Cleanup trap helper ────────────────────────────────────────────────
cleanup_temp_files() {
    rm -f /tmp/xuifast_cookie.txt /tmp/xuifast_login_resp.json /tmp/xuifast_api_resp.json /tmp/xuifast_payload.json 2>/dev/null
    rm -rf /tmp/xuifast_clone_* 2>/dev/null
    stop_spinner
}

# ── Safe credentials reader (no eval/source) ──────────────────────────
safe_read_credentials() {
    local file="${1:-$CREDENTIALS_FILE}"
    [ -f "$file" ] || return 1
    while IFS='=' read -r key value; do
        # Strip quotes
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        case "$key" in
            XUI_PORT) XUI_PORT="$value" ;;
            XUI_USER) XUI_USER="$value" ;;
            XUI_PASS) XUI_PASS="$value" ;;
            XUI_WEB_PATH) XUI_WEB_PATH="$value" ;;
        esac
    done < "$file"
}

# ── Safe process kill on port (fuser may not be installed) ─────────────
kill_port() {
    local port="$1"
    if command -v fuser &>/dev/null; then
        fuser -k "${port}/tcp" 2>/dev/null || true
    elif command -v lsof &>/dev/null; then
        lsof -ti :"$port" 2>/dev/null | xargs -r kill 2>/dev/null || true
    elif command -v ss &>/dev/null; then
        local pids
        pids=$(ss -tlnp "sport = :${port}" 2>/dev/null | grep -o 'pid=[0-9]*' | sed 's/pid=//' | sort -u)
        for pid in $pids; do kill "$pid" 2>/dev/null; done
    fi
}

# ── Banner ──────────────────────────────────────────────────────────────
print_banner() {
    local ver="$XUIFAST_VERSION"
    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}XUIFAST v${ver}${NC}                                      ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}                                                      ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  $(t banner_subtitle)  ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  $(t banner_features)     ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ── Print header (section separator) ───────────────────────────────────
print_header() {
    local title="$1"
    echo ""
    echo -e "  ${BOLD}${WHITE}${title}${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}"
}

# ── Credits ─────────────────────────────────────────────────────────────
show_credits() {
    echo ""
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}"
    echo -e "  ${MAGENTA}$(t credits_title)${NC}"
    echo -e "  ${DIM}3X-UI: github.com/MHSanaei/3x-ui${NC}"
    echo -e "  ${DIM}Xray-core: github.com/XTLS/Xray-core${NC}"
    echo -e "  ${DIM}XUIFAST: anten-ka${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}"
}
