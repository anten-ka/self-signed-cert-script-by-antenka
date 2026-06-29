#!/bin/bash
# goVLESS — Copyright (c) 2025-2026 anten-ka. All rights reserved.
# Licensed under the goVLESS Source-Available License (see the LICENSE file).
# Redistribution, mirroring, or republishing in any form — whole or partial,
# modified or not — is prohibited without prior written permission.

# goVLESS v3.0.0 — Core utilities
# Colors, logging, spinner, apt handling, IP/geo detection, JSON config

# ── Version & paths ─────────────────────────────────────────────────────
GOVLESS_VERSION="1.1-lite-club"
GOVLESS_SCHEMA="1"
GOVLESS_DIR="${GOVLESS_DIR:-/opt/govless}"
GOVLESS_CONFIG="${GOVLESS_CONFIG:-${GOVLESS_DIR}/config.json}"
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
CREDENTIALS_FILE="/root/.govless_credentials"
WEBSITE_ROOT="/var/www/html"
NGINX_SITE_CONF="/etc/nginx/sites-available/govless"
NGINX_SITE_LINK="/etc/nginx/sites-enabled/govless"
BACKUP_DIR="${GOVLESS_DIR}/backups"
TEMPLATES_CATALOG="${GOVLESS_DIR}/templates_catalog.json"

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
# All log functions write to stderr to avoid polluting stdout in $() captures
log_info()    { echo -e "  ${CYAN}ℹ${NC}  $*" >&2; }
log_success() { echo -e "  ${GREEN}✓${NC}  $*" >&2; }
log_warning() { echo -e "  ${YELLOW}⚠${NC}  $*" >&2; }
log_error()   { echo -e "  ${RED}✗${NC}  $*" >&2; }

# ── Compact terminal QR ─────────────────────────────────────────────────
# Renders a QR ~2x smaller (half the width) than the classic half-block by
# packing 2x2 modules into one quadrant-block glyph. Scanner-grade decoders
# (phone cameras / zxing) read it fine despite the terminal's 1:2 cell aspect
# (verified). qrencode is a preflight-required dep; if it is somehow missing,
# qr_print returns 1 (caller prints nothing) rather than erroring.
qr_print() {
    # Square, universally-scannable QR (classic half-block: 1 module wide per
    # char-col, 2 tall per char-row — renders ~square on a terminal whose cell
    # is taller than wide). qrencode's -m2 quiet zone is preserved.
    local data="$1"
    command -v qrencode >/dev/null 2>&1 || return 1
    qrencode -t UTF8 -m 2 "$data" 2>/dev/null
}

log_step()    { echo -e "\n  ${BOLD}${WHITE}▸ $*${NC}" >&2; }
log_dim()     { echo -e "  ${DIM}$*${NC}" >&2; }

# ─────────────────────────────────────────────────────────────────────────
# Robust network + progress helpers — installer must NEVER look frozen and
# never hang forever on a throttled link (common on RU servers where DPI
# stalls connections mid-transfer).
# ─────────────────────────────────────────────────────────────────────────

# gv_fetch <url> <outfile> [max_time_s] [extra curl args…]
# curl that always gives up instead of hanging: connect timeout, total cap,
# retries, and abort if the transfer stalls under 1 KB/s for 20s.
gv_fetch() {
    local url="$1" out="$2" maxt="${3:-180}"; shift $(( $# >= 3 ? 3 : $# ))
    curl -fL --connect-timeout 15 --max-time "$maxt" \
         --retry 3 --retry-delay 2 --retry-connrefused \
         --speed-limit 1024 --speed-time 20 \
         -o "$out" "$@" "$url"
}

# gv_step "label" command [args…]
# Run a long command with a live heartbeat (spinner + elapsed + last log line)
# so it never feels hung. Output captured; on failure the last lines are shown.
# NOTE: runs in a subshell — use for system/filesystem side effects
# (downloads, apt, git, systemctl), NOT for functions that must set shell vars.
gv_step() {
    local label="$1"; shift
    local logf; logf=$(mktemp /tmp/govless_step.XXXXXX 2>/dev/null || echo "/tmp/govless_step.$$")
    ( "$@" ) >"$logf" 2>&1 &
    local pid=$! t0=$SECONDS
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    if [ -t 2 ]; then
        while kill -0 "$pid" 2>/dev/null; do
            local c="${spin:i++%${#spin}:1}" last
            last=$(tail -n1 "$logf" 2>/dev/null | tr -d '\r\t' | tr -s ' ' | cut -c1-46)
            printf "\r\033[K  \033[0;36m%s\033[0m %s… \033[2m%ss  %s\033[0m" \
                   "$c" "$label" "$((SECONDS-t0))" "$last" >&2
            sleep 0.3
        done
    else
        while kill -0 "$pid" 2>/dev/null; do
            printf "  \xe2\x8f\xb3 %s… %ss\n" "$label" "$((SECONDS-t0))" >&2; sleep 10
        done
    fi
    wait "$pid"; local rc=$?
    if [ "$rc" -eq 0 ]; then
        printf "\r\033[K  \033[0;32m\xe2\x9c\x93\033[0m %s \033[2m(%ss)\033[0m\n" "$label" "$((SECONDS-t0))" >&2
    else
        printf "\r\033[K  \033[0;31m\xe2\x9c\x97\033[0m %s \033[2m(%ss)\033[0m\n" "$label" "$((SECONDS-t0))" >&2
        tail -n3 "$logf" 2>/dev/null | sed 's/^/      /' >&2
    fi
    rm -f "$logf" 2>/dev/null
    return $rc
}

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
    # Numeric confirmation (1 = yes/proceed, 2 = no/back). Numeric instead of
    # [Y/n] on purpose: a y/n regex with Cyrillic letters breaks under a non
    # UTF-8 locale (regcomp fails, =~ returns error) and silently treats "Y" as
    # "no", which aborted the install. Reads from the controlling terminal.
    local prompt="${1:-Continue?}"
    local yes_label="${2:-$(t confirm_yes)}"
    local no_label="${3:-$(t confirm_no)}"
    # Read from stdin: main() already points stdin at the controlling terminal
    # for interactive runs, and piped answers (automation) arrive on stdin too.
    local answer
    while true; do
        echo "" >&2
        echo -e "  ${WHITE}${prompt}${NC}" >&2
        echo -e "    ${CYAN}1)${NC} ${yes_label}" >&2
        echo -e "    ${CYAN}2)${NC} ${no_label}" >&2
        echo -ne "  ${BOLD}$(t confirm_choice)${NC} " >&2
        read -r answer || return 1
        answer="$(printf '%s' "$answer" | tr -d '[:space:]')"
        case "$answer" in
            1) return 0 ;;
            2) return 1 ;;
            *) log_warning "$(t invalid_choice)" ;;
        esac
    done
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
    # First try a normal refresh.
    if apt-get update -qq 2>/dev/null; then
        return 0
    fi
    # A non-zero exit is usually a single broken THIRD-PARTY repo (expired GPG
    # key, 404, etc.) — e.g. pkg.cloudflare.com. That must not block installing
    # our deps from the working Ubuntu mirrors. Retry while tolerating per-repo
    # errors; succeed as long as the base archive refreshed at least once.
    apt-get update -o APT::Update::Error-Mode=any -qq 2>/dev/null || true
    # Consider it OK if the main Ubuntu archive lists are present & fresh.
    if apt-cache policy 2>/dev/null | grep -qE "ubuntu|noble|jammy|debian|/(updates|security)"; then
        log_dim "$(t apt_thirdparty_repo_warn)"
        return 0
    fi
    return 1
}

apt_install() {
    apt_lock_wait || return 1
    # A broken third-party repo (expired GPG key, 404) can make apt refuse to
    # proceed. Our deps live in the Ubuntu archive, so try a normal install
    # first, then retry telling apt to ignore unauthenticated/unsigned repo
    # errors so the working mirrors are still usable.
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1 && return 0
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        -o Acquire::AllowInsecureRepositories=true \
        -o APT::Get::AllowUnauthenticated=true \
        "$@" >/dev/null 2>&1
}

# ── Dependency management ───────────────────────────────────────────────
CRITICAL_DEPS=(curl jq openssl qrencode sqlite3 python3)
OPTIONAL_DEPS=(git nginx certbot file expect dnsutils)

install_dependencies() {
    local missing=()
    for cmd in "${CRITICAL_DEPS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
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
    # Speed-up: enable BBR congestion control (best-effort, never fatal).
    enable_bbr
    return 0
}

# ── Preflight: verify + install everything the installer needs, up front ──
# Runs once at startup (before any mode is chosen) so a missing tool can never
# surface as a confusing mid-install failure. command -> apt package mapping;
# base-system tools (grep/sed/awk/tar/gzip/systemctl...) are assumed present.
preflight_deps() {
    declare -A _pkg_for=(
        [curl]=curl [jq]=jq [openssl]=openssl [qrencode]=qrencode
        [expect]=expect [sqlite3]=sqlite3 [dig]=dnsutils [python3]=python3
        [tar]=tar [gzip]=gzip
    )
    local need=() seen_pkg=""
    local cmd pkg
    for cmd in "${!_pkg_for[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            pkg="${_pkg_for[$cmd]}"
            case " $seen_pkg " in *" $pkg "*) : ;; *) need+=("$pkg"); seen_pkg="$seen_pkg $pkg" ;; esac
        fi
    done
    if [ ${#need[@]} -eq 0 ]; then
        log_success "$(t preflight_ok)"
        enable_bbr
        return 0
    fi
    _gv_preflight_apt() { apt_update && apt_install "$@"; }
    if ! gv_step "$(tf preflight_installing "${need[*]}")" _gv_preflight_apt "${need[@]}"; then
        log_error "$(tf preflight_failed "${need[*]}")"; return 1
    fi
    # Verify the criticals are now actually runnable.
    local cmd2 still=()
    for cmd2 in curl jq openssl qrencode expect sqlite3 python3; do
        command -v "$cmd2" >/dev/null 2>&1 || still+=("$cmd2")
    done
    if [ ${#still[@]} -gt 0 ]; then
        log_error "$(tf preflight_failed "${still[*]}")"
        return 1
    fi
    log_success "$(t preflight_ok)"
    enable_bbr
    return 0
}

# ── Enable BBR congestion control ───────────────────────────────────────
# BBR (+ fq qdisc) markedly improves TCP throughput on lossy / long-haul
# links — exactly the VLESS use-case. Idempotent, kernel-guarded, and
# never fatal to the install.
enable_bbr() {
    local cur_cc
    cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$cur_cc" = "bbr" ]; then
        log_success "$(t bbr_already)"
        return 0
    fi
    log_info "$(t bbr_enabling)"
    # bbr is built-in on kernel >= 4.9; otherwise try to load the module.
    if ! sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
        modprobe tcp_bbr 2>/dev/null || true
    fi
    if ! sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
        log_warning "$(t bbr_unsupported)"
        return 0
    fi
    # Persistent, idempotent drop-in.
    cat > /etc/sysctl.d/99-govless-bbr.conf <<'SYSCTL'
# goVLESS: BBR + buffer/MTU tuning for smoother VLESS, fewer stalls
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.core.netdev_max_backlog = 16384
SYSCTL
    sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-govless-bbr.conf >/dev/null 2>&1
    cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$cur_cc" = "bbr" ]; then
        log_success "$(t bbr_enabled)"
    else
        log_warning "$(t bbr_unsupported)"
    fi
}

# ── IP detection ────────────────────────────────────────────────────────
get_server_ip() {
    local raw_ip
    for svc in ifconfig.me api.ipify.org icanhazip.com ipinfo.io/ip; do
        raw_ip=$(curl -s --max-time 10 "$svc" 2>/dev/null | tr -d '[:space:]') || true
        if _valid_ip "$raw_ip"; then
            echo "$raw_ip"
            return 0
        fi
    done
    # Fallback to local interface
    raw_ip=$(ip -4 addr show scope global 2>/dev/null | grep -o 'inet [0-9.]*' | sed 's/inet //' | head -1) || true
    if _valid_ip "$raw_ip"; then
        echo "$raw_ip"
        return 0
    fi
    log_error "Cannot detect server IP"
    return 1
}


_valid_ip() {
    # Strict: rejects 127.x (loopback), 10.x / 172.16-31.x / 192.168.x
    # (RFC 1918), 169.254.x (link-local), 0.0.0.0, 255.255.255.255, and
    # multicast/reserved (>= 224). We never want to advertise these as
    # the VPN server address in a vless:// link.
    local ip="$1"
    [[ -z "$ip" ]] && return 1
    local IFS='.'
    read -ra o <<< "$ip"
    [[ ${#o[@]} -ne 4 ]] && return 1
    for x in "${o[@]}"; do
        [[ ! "$x" =~ ^[0-9]+$ ]] && return 1
        (( x < 0 || x > 255 )) && return 1
    done
    # Reject non-routable ranges
    (( o[0] == 0 ))                                    && return 1   # 0.0.0.0/8
    (( o[0] == 127 ))                                  && return 1   # loopback
    (( o[0] == 10 ))                                   && return 1   # private
    (( o[0] == 172 && o[1] >= 16 && o[1] <= 31 ))      && return 1   # private
    (( o[0] == 192 && o[1] == 168 ))                   && return 1   # private
    (( o[0] == 169 && o[1] == 254 ))                   && return 1   # link-local
    (( o[0] >= 224 ))                                  && return 1   # multicast + reserved
    return 0
}

# ── IP geolocation (for Lite mode domain suggestions) ───────────────────
# Returns 2-letter country code: "RU", "US", "DE", etc.
get_ip_country() {
    local ip="${1:-}"
    local country=""

    # Try ipinfo.io first (lightweight, no key needed)
    if [ -n "$ip" ]; then
        country=$(curl -s --max-time 5 "https://ipinfo.io/${ip}/country" 2>/dev/null | tr -d '[:space:]"') || true
    else
        country=$(curl -s --max-time 5 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]"') || true
    fi

    # Validate: must be 2 uppercase letters
    if [[ "$country" =~ ^[A-Z]{2}$ ]]; then
        echo "$country"
        return 0
    fi

    # Fallback: ip-api.com
    if [ -n "$ip" ]; then
        country=$(curl -s --max-time 5 "http://ip-api.com/line/${ip}?fields=countryCode" 2>/dev/null | tr -d '[:space:]') || true
    else
        country=$(curl -s --max-time 5 "http://ip-api.com/line/?fields=countryCode" 2>/dev/null | tr -d '[:space:]') || true
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
normalize_domain() {
    # Accept a pasted URL and reduce it to a bare hostname so validation passes:
    #   "https://Example.com:443/path?x=1#f"  ->  "example.com"
    # Strips control chars (stray arrow-key escapes), whitespace, scheme,
    # user:pass@, /path, ?query, #fragment, :port; lowercases.
    local d="$1"
    # lowercase FIRST so HTTPS:// / mixed-case schemes are stripped too
    d=$(printf '%s' "$d" | tr -d '[:cntrl:]' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    d="${d#https://}"; d="${d#http://}"
    d="${d##*@}"
    d="${d%%/*}"
    d="${d%%\?*}"
    d="${d%%#*}"
    d="${d%%:*}"
    printf '%s' "$d"
}

valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]
}

# DNS check: does domain point to our IP?
# Resolve all A records for a domain. Prefers `getent` (in glibc/musl,
# always present) over `dig` (needs dnsutils, which only lands after
# install_dependencies). Returns newline-separated IPs on stdout.
resolve_domain_a() {
    local domain="$1"
    local out
    # getent ahosts returns "IP STREAM domain" lines — filter v4 only
    if command -v getent >/dev/null 2>&1; then
        out=$(getent ahostsv4 "$domain" 2>/dev/null | awk '{print $1}' | sort -u)
        if [ -n "$out" ]; then
            echo "$out"
            return 0
        fi
    fi
    # Fallback to dig if dnsutils is installed
    if command -v dig >/dev/null 2>&1; then
        out=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [ -n "$out" ]; then
            echo "$out"
            return 0
        fi
    fi
    # Last resort: host (also part of dnsutils on most distros)
    if command -v host >/dev/null 2>&1; then
        out=$(host -t A "$domain" 2>/dev/null | awk '/has address/ {print $NF}')
        if [ -n "$out" ]; then
            echo "$out"
            return 0
        fi
    fi
    return 1
}

# True if expected_ip is in the A record set for domain (handles multi-A).
check_dns() {
    local domain="$1"
    local expected_ip="$2"
    local all
    all=$(resolve_domain_a "$domain") || return 1
    echo "$all" | grep -qFx "$expected_ip"
}

# ── JSON config management ──────────────────────────────────────────────
# Requires jq. Config stored in $GOVLESS_CONFIG
config_get() {
    local key="$1"
    local default="${2:-}"
    if [ -f "$GOVLESS_CONFIG" ] && command -v jq &>/dev/null; then
        local val
        val=$(jq -r ".${key} // empty" "$GOVLESS_CONFIG" 2>/dev/null)
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
    mkdir -p "$(dirname "$GOVLESS_CONFIG")"

    if [ ! -f "$GOVLESS_CONFIG" ]; then
        echo '{}' > "$GOVLESS_CONFIG"
    fi

    local tmp
    tmp=$(mktemp) || return 1
    if jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$GOVLESS_CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$GOVLESS_CONFIG"
        chmod 600 "$GOVLESS_CONFIG"
    else
        rm -f "$tmp"
        return 1
    fi
}

config_set_int() {
    local key="$1"
    local value="$2"
    mkdir -p "$(dirname "$GOVLESS_CONFIG")"

    if [ ! -f "$GOVLESS_CONFIG" ]; then
        echo '{}' > "$GOVLESS_CONFIG"
    fi

    local tmp
    tmp=$(mktemp) || return 1
    if jq --arg k "$key" --argjson v "$value" '. + {($k): $v}' "$GOVLESS_CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$GOVLESS_CONFIG"
        chmod 600 "$GOVLESS_CONFIG"
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
    if ! [[ "$available_mb" =~ ^[0-9]+$ ]]; then
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
    rm -f /tmp/govless_cookie.txt /tmp/govless_login_resp.json /tmp/govless_api_resp.json /tmp/govless_payload.json 2>/dev/null
    rm -rf /tmp/govless_clone_* 2>/dev/null
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
        pids=$(ss -tlnp "sport = :${port}" 2>/dev/null | grep -o 'pid=[0-9]*' | sed 's/pid=//' | sort -u) || true
        for pid in $pids; do kill "$pid" 2>/dev/null; done
    fi
}

# ── Banner ──────────────────────────────────────────────────────────────
# Frame-less by design: a 4-sided box requires the right edge to land on
# a fixed column, but our content (i18n + emoji + cyrillic) has variable
# DISPLAY width, so the box always broke. Bottom/top rules don't care.
print_banner() {
    local ver="$GOVLESS_VERSION"
    local rule
    rule="${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  $rule"
    echo -e "  ${BOLD}${YELLOW}goVLESS${NC}  ${DIM}v${ver}${NC}"
    echo -e "  ${DIM}$(t banner_subtitle)${NC}"
    echo -e "  ${DIM}$(t banner_features)${NC}"
    echo -e "  $rule"
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
    echo -e "  ${DIM}goVLESS: anten-ka${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}"
}

# ── DNS mismatch UX (Codex 019 tightening) ─────────────────────────────
# Args: $1=domain  $2=expected_ip
# Returns 0 if DNS resolved correctly during wait,
#         1 if user chose exit (or wait timed out without recovery).
#
# Env overrides (for tests & impatient ops):
#   GOVLESS_DNS_WAIT_SECONDS    total wait window (default 1800 = 30 min)
#   GOVLESS_DNS_CHECK_INTERVAL  recheck cadence in seconds (default 30)
#
# No "continue anyway" option — only Wait + Exit. Forcing past a real
# DNS mismatch in Pro mode guarantees LE cert failure.
dns_wait_or_choose() {
    local domain="$1"
    local expected_ip="$2"
    local total_sec="${GOVLESS_DNS_WAIT_SECONDS:-1800}"
    local interval="${GOVLESS_DNS_CHECK_INTERVAL:-30}"
    local wait_minutes=$((total_sec / 60))
    [ "$wait_minutes" -lt 1 ] && wait_minutes=1

    # Immediate re-check before showing menu — DNS may have settled
    local resolved
    if check_dns "$domain" "$expected_ip"; then
        log_success "$(tf dns_resolved_ok "$domain")"
        return 0
    fi
    # For display, show the first resolved IP (or N/A if none)
    resolved=$(resolve_domain_a "$domain" 2>/dev/null | head -1)

    while true; do
        log_warning "$(tf pro_dns_mismatch "$domain" "${resolved:-N/A}" "$expected_ip")"
        echo ""
        echo -e "  $(t dns_menu_title)"
        echo -e "    ${CYAN}1)${NC} $(tf dns_menu_wait "$wait_minutes")"
        echo -e "    ${CYAN}2)${NC} $(t dns_menu_exit)"
        echo -e "    ${DIM}$(t dns_set_record_hint)${NC}"
        echo -e "    ${DIM}A  ${domain}  →  ${expected_ip}${NC}"
        echo ""
        local choice
        read -rp "  ▸ " choice
        case "$choice" in
            1)
                # Cancellable wait via `read -t` — Enter cancels, otherwise polls
                log_info "$(tf dns_waiting_start "$wait_minutes")"
                local elapsed=0
                while [ "$elapsed" -lt "$total_sec" ]; do
                    local remaining=$((total_sec - elapsed))
                    local min=$((remaining / 60))
                    local sec=$((remaining % 60))
                    printf "  ${CYAN}⏱${NC}  $(tf dns_countdown "$min" "$sec")  ${DIM}$(t dns_cancel_hint)${NC}    "
                    if read -t "$interval" -r _cancel 2>/dev/null; then
                        echo ""
                        log_info "$(t dns_wait_cancelled)"
                        break
                    fi
                    elapsed=$((elapsed + interval))
                    # check_dns matches any A record (multi-A safe), getent-first (no dnsutils needed)
                    if check_dns "$domain" "$expected_ip"; then
                        echo ""
                        log_success "$(tf dns_resolved_ok "$domain")"
                        return 0
                    fi
                    resolved=$(resolve_domain_a "$domain" 2>/dev/null | head -1)
                done
                if [ "$elapsed" -ge "$total_sec" ]; then
                    echo ""
                    log_warning "$(tf dns_timeout_still_mismatch "$domain" "${resolved:-N/A}" "$expected_ip")"
                fi
                # Loop back to show menu — user can wait again or exit
                ;;
            2|0|"")
                log_info "$(t dns_user_exit)"
                return 1
                ;;
            *)
                log_warning "$(t invalid_choice)"
                ;;
        esac
    done
}
# ── Typed-confirm: user must type EXACT string (no yes/no) ─────────────
# Args: $1=expected_string  $2=prompt_text
# Returns 0 if user typed the string exactly, 1 otherwise.
# Used for destructive actions (remove, switch_mode, reset).
typed_confirm() {
    local expected="$1"
    local prompt_text="$2"
    echo ""
    log_warning "$prompt_text"
    echo -e "  $(t remove_typed_hint)  ${RED}${BOLD}${expected}${NC}"
    echo ""
    local input
    read -rp "  ▸ " input
    if [ "$input" = "$expected" ]; then
        return 0
    fi
    log_warning "$(t typed_confirm_cancelled)"
    return 1
}
# ── Disclaimer (legal RF-context + neutral EN) ──────────────────────────
# Two modes:
#   show_disclaimer            — info-only render (used by About menu)
#   show_disclaimer --gate     — print + require y/N; persists accept at
#                                $GOVLESS_DIR/.disclaimer-accepted; skipped
#                                on subsequent runs.
# Returns 0 if accepted/info-only, 1 if declined at gate.
#
# Content is i18n-keyed; sections:
#   intro → lawful uses (5) → legality+responsibility (5) → prohibited (4)
#   → anonymity-note → (gate only) accept prompt
show_disclaimer() {
    local gate=false
    [ "${1:-}" = "--gate" ] && gate=true

    # Already accepted? silently skip when gating
    if $gate && [ -f "${GOVLESS_DIR}/.disclaimer-accepted" ]; then
        return 0
    fi

    print_header "$(t disclaimer_title)"
    echo -e "  ${YELLOW}$(t disclaimer_intro)${NC}"
    echo ""
    echo -e "  ${BOLD}$(t disclaimer_uses_header)${NC}"
    echo -e "  ${DIM}$(t disclaimer_uses_1)${NC}"
    echo -e "  ${DIM}$(t disclaimer_uses_2)${NC}"
    echo -e "  ${DIM}$(t disclaimer_uses_3)${NC}"
    echo -e "  ${DIM}$(t disclaimer_uses_4)${NC}"
    echo -e "  ${DIM}$(t disclaimer_uses_5)${NC}"
    echo ""
    echo -e "  ${BOLD}$(t disclaimer_legal_header)${NC}"
    echo -e "  ${DIM}$(t disclaimer_legal_1)${NC}"
    echo -e "  ${DIM}$(t disclaimer_legal_2)${NC}"
    echo -e "  ${DIM}$(t disclaimer_legal_3)${NC}"
    echo -e "  ${DIM}$(t disclaimer_legal_4)${NC}"
    echo -e "  ${YELLOW}$(t disclaimer_legal_5)${NC}"
    echo ""
    echo -e "  ${BOLD}${RED}$(t disclaimer_prohibited_header)${NC}"
    echo -e "  ${DIM}$(t disclaimer_prohibited_1)${NC}"
    echo -e "  ${DIM}$(t disclaimer_prohibited_2)${NC}"
    echo -e "  ${DIM}$(t disclaimer_prohibited_3)${NC}"
    echo -e "  ${DIM}$(t disclaimer_prohibited_4)${NC}"
    echo ""
    echo -e "  ${YELLOW}$(t disclaimer_anonymity_note)${NC}"
    echo ""

    if ! $gate; then
        return 0  # info-only (About menu)
    fi

    # Gate: numbered choice (clearer than y/N + retries on bad input). Read from
    # the controlling terminal when stdin isn't one (e.g. run via curl|bash) so
    # the prompt sees the user's keystrokes; fall back to stdin for automated runs.
    local _src=/dev/stdin
    if [ ! -t 0 ] && [ -r /dev/tty ]; then _src=/dev/tty; fi
    echo ""
    echo -e "  ${BOLD}$(t disclaimer_accept_prompt)${NC}"
    echo -e "  ${CYAN}1)${NC} $(t disclaimer_agree)"
    echo -e "  ${CYAN}2)${NC} $(t disclaimer_decline)"
    local ans
    while true; do
        echo -ne "  ${BOLD}$(t disclaimer_choice)${NC} "
        read -r ans < "$_src" || ans=""
        ans="$(printf '%s' "$ans" | tr -d '[:space:]')"
        case "$ans" in
            1|[Yy]|[Yy][Ee][Ss]|[Дд]|[Дд][Аа])
                mkdir -p "$GOVLESS_DIR" 2>/dev/null
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${GOVLESS_DIR}/.disclaimer-accepted"
                echo -e "  ${DIM}$(tf disclaimer_accepted_marker_hint "${GOVLESS_DIR}/.disclaimer-accepted")${NC}"
                echo ""
                return 0 ;;
            2|[Nn]|[Nn][Oo]|[Нн]|[Нн][Ее][Тт]|"")
                log_warning "$(t disclaimer_declined)"
                return 1 ;;
            *)
                log_warning "$(t invalid_choice)" ;;
        esac
    done
}

