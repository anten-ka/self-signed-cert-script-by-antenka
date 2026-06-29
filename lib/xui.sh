#!/bin/bash
# goVLESS — Copyright (c) 2025-2026 anten-ka. All rights reserved.
# Licensed under the goVLESS Source-Available License (see the LICENSE file).
# Redistribution, mirroring, or republishing in any form — whole or partial,
# modified or not — is prohibited without prior written permission.

# goVLESS v3.0.2 — 3X-UI installation and service management
# Install via expect, extract credentials, systemd management
# Supports both 3.x (New Generation) and 2.x (Legacy) branches

# ── 3X-UI version globals ──────────────────────────────────────────────
XUI_BRANCH=""          # "new" (3.x) or "legacy" (2.x)
XUI_INSTALL_VERSION="" # e.g. "v3.0.1" or "v2.9.4" or "" (latest)
XUI_LEGACY_FALLBACK="v2.9.4"  # hardcoded fallback if GitHub API unreachable



# ── Transport globals ──────────────────────────────────────────────────
XUI_TRANSPORT="tcp"    # "tcp", "xhttp", or "grpc"
XUI_FP="${GOVLESS_FP:-randomized}"   # uTLS fingerprint: randomized(default)/chrome/firefox/safari/ios/random

# ── Get latest 2.x version from GitHub API ─────────────────────────────
get_latest_2x_version() {
    local version=""
    # Query GitHub API for releases, find last 2.x
    version=$(curl -s --max-time 10 \
        "https://api.github.com/repos/MHSanaei/3x-ui/releases?per_page=30" 2>/dev/null \
        | python3 -c "
import json, sys
try:
    releases = json.load(sys.stdin)
    for r in releases:
        tag = r.get('tag_name', '')
        if tag.startswith('v2.') and not r.get('prerelease', False):
            print(tag)
            break
except:
    pass
" 2>/dev/null || true)

    if [[ "$version" =~ ^v2\.[0-9]+\.[0-9]+$ ]]; then
        echo "$version"
        return 0
    fi

    # Fallback to hardcoded
    echo "$XUI_LEGACY_FALLBACK"
}

# ── Get latest 3.x version from GitHub API ─────────────────────────────
get_latest_3x_version() {
    local version=""
    version=$(curl -s --max-time 10 \
        "https://api.github.com/repos/MHSanaei/3x-ui/releases?per_page=10" 2>/dev/null \
        | python3 -c "
import json, sys
try:
    releases = json.load(sys.stdin)
    for r in releases:
        tag = r.get('tag_name', '')
        if tag.startswith('v3.') and not r.get('prerelease', False):
            print(tag)
            break
except:
    pass
" 2>/dev/null || true)

    if [[ "$version" =~ ^v3\.[0-9]+\.[0-9]+$ ]]; then
        echo "$version"
        return 0
    fi

    # No version found — use latest (master branch)
    echo ""
}

# ── True if 3X-UI is already installed (binary + service) ─────────────
xui_already_installed() {
    [ -f "$XUI_BIN" ] && systemctl is-enabled "$XUI_SERVICE" &>/dev/null
}

# Load currently-installed XUI_BRANCH/VERSION from config (no prompt).
# Used when re-running govless on top of an existing install — we don't
# want the prompt to pretend the user can pick a new version when
# install_3xui will short-circuit and keep the existing binary.
load_xui_version_from_config() {
    XUI_BRANCH=$(config_get xui_branch "new")
    XUI_INSTALL_VERSION=$(config_get xui_version "")
}

# ── Interactive 3X-UI version picker ───────────────────────────────────
select_xui_version() {
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t xui_version_title)${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo "" >&2

    # Detect latest versions (with spinner)
    local legacy_ver new_ver
    log_dim "$(t xui_version_detecting)" >&2
    legacy_ver=$(get_latest_2x_version)
    new_ver=$(get_latest_3x_version)

    local new_label="3X-UI 3.x"
    [ -n "$new_ver" ] && new_label="3X-UI ${new_ver}"
    local legacy_label="3X-UI ${legacy_ver}"

    echo -e "  ${CYAN}1)${NC} ${BOLD}${new_label}${NC} — $(t xui_version_new_gen)" >&2
    echo -e "     ${DIM}$(t xui_version_new_desc)${NC}" >&2
    echo "" >&2
    echo -e "  ${CYAN}2)${NC} ${BOLD}${legacy_label}${NC} — $(t xui_version_legacy)" >&2
    echo -e "     ${DIM}$(t xui_version_legacy_desc)${NC}" >&2
    echo "" >&2

    local choice
    echo -ne "  $(t xui_version_choice) " >&2
    read -r choice

    case "$choice" in
        1)
            XUI_BRANCH="new"
            XUI_INSTALL_VERSION="${new_ver}"
            log_success "$(tf xui_version_selected "$new_label")" >&2
            ;;
        2)
            XUI_BRANCH="legacy"
            XUI_INSTALL_VERSION="${legacy_ver}"
            log_success "$(tf xui_version_selected "$legacy_label")" >&2
            ;;
        *)
            # Default to new
            XUI_BRANCH="new"
            XUI_INSTALL_VERSION="${new_ver}"
            log_dim "$(tf xui_version_selected "$new_label (default)")" >&2
            ;;
    esac
}

# ── Interactive transport picker (Lite mode only) ──────────────────────
# ── uTLS fingerprint picker ─────────────────────────────────────────────
# Sets the client TLS fingerprint baked into every key (fp=...). randomized is
# the default (a fresh random fingerprint, hardest to fingerprint-block); chrome
# /firefox/safari mimic a specific browser. random picks a real one at random
# in the rare case DPI blocks a specific fingerprint.
select_fingerprint() {
    # honour non-interactive override
    case "${GOVLESS_FP:-}" in
        chrome|firefox|safari|ios|android|edge|random|randomized) XUI_FP="$GOVLESS_FP"; return 0 ;;
    esac
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t fp_title)${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo -e "  ${CYAN}1)${NC} ${BOLD}randomized${NC} — $(t fp_randomized)" >&2
    echo -e "  ${CYAN}2)${NC} chrome — $(t fp_chrome)" >&2
    echo -e "  ${CYAN}3)${NC} firefox" >&2
    echo -e "  ${CYAN}4)${NC} safari" >&2
    echo -e "  ${CYAN}5)${NC} random — $(t fp_random)" >&2
    echo "" >&2
    local choice
    echo -ne "  $(t fp_choice) " >&2
    read -r choice
    case "$choice" in
        2) XUI_FP="chrome" ;;
        3) XUI_FP="firefox" ;;
        4) XUI_FP="safari" ;;
        5) XUI_FP="random" ;;
        *) XUI_FP="randomized" ;;
    esac
    log_success "$(tf fp_selected "$XUI_FP")" >&2
}

select_transport() {
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t transport_title)${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo "" >&2
    echo -e "  ${CYAN}1)${NC} ${BOLD}TCP${NC} — $(t transport_tcp_desc)" >&2
    echo -e "  ${CYAN}2)${NC} ${BOLD}XHTTP${NC} — $(t transport_xhttp_desc)" >&2
    echo -e "  ${CYAN}3)${NC} ${BOLD}gRPC${NC} — $(t transport_grpc_desc)" >&2
    echo "" >&2

    local choice
    echo -ne "  $(t transport_choice) " >&2
    read -r choice

    case "$choice" in
        1)
            XUI_TRANSPORT="tcp"
            log_success "$(tf transport_selected "TCP")" >&2
            ;;
        2)
            XUI_TRANSPORT="xhttp"
            log_success "$(tf transport_selected "XHTTP")" >&2
            ;;
        3)
            XUI_TRANSPORT="grpc"
            log_success "$(tf transport_selected "gRPC")" >&2
            ;;
        *)
            XUI_TRANSPORT="tcp"
            log_dim "$(tf transport_selected "TCP (default)")" >&2
            ;;
    esac
}

# ── Install 3X-UI (manual method — no expect) ─────────────────────────
# Usage: install_3xui [version]
# version: "v3.0.1", "v2.9.4", or "" for latest
#
# Manual install steps:
#   1. Detect arch → download tarball from GitHub releases
#   2. Extract to /usr/local/x-ui/
#   3. Generate random credentials (user/pass/port/webpath)
#   4. Initialize database via x-ui CLI
#   5. Install systemd service
#   6. Start service
#
# This replaces the previous expect-based approach which was unreliable
# with 3X-UI v3.x interactive prompts (timing/buffering caused wrong
# answers ~50% of the time).
# Validate a file is a real gzip without depending on `file` (absent on minimal
# images). gzip -t is authoritative; the 1f8b magic-byte read is the fallback.
_is_gzip() {
    local f="$1"
    [ -s "$f" ] || return 1
    if command -v gzip >/dev/null 2>&1; then
        gzip -t "$f" >/dev/null 2>&1 && return 0
        return 1
    fi
    # Fallback: first two bytes must be 0x1f 0x8b
    local magic
    magic=$(od -An -tx1 -N2 "$f" 2>/dev/null | tr -d ' \n')
    [ "$magic" = "1f8b" ]
}

install_3xui() {
    local version="${1:-$XUI_INSTALL_VERSION}"
    log_step "$(t xui_installing)"

    # Check both binary AND systemd service — a leftover binary without
    # a working service should trigger a re-install
    if [ -f "$XUI_BIN" ] && systemctl is-enabled "$XUI_SERVICE" &>/dev/null; then
        log_dim "$(t xui_already_installed)"
        return 0
    fi

    # Clean up orphaned binary if service is missing
    if [ -f "$XUI_BIN" ] && ! systemctl is-enabled "$XUI_SERVICE" &>/dev/null; then
        log_dim "Cleaning up incomplete previous installation..."
        systemctl stop "$XUI_SERVICE" 2>/dev/null
        rm -rf "$XUI_DIR" /usr/bin/x-ui 2>/dev/null
        rm -f /etc/systemd/system/x-ui.service 2>/dev/null
        systemctl daemon-reload 2>/dev/null
    fi

    local install_log="/tmp/govless_xui_install.log"
    > "$install_log"

    # ── 1. Detect architecture ────────────────────────────────────────
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l)        arch="armv7" ;;
        s390x)         arch="s390x" ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    # ── 2. Resolve version ────────────────────────────────────────────
    if [ -z "$version" ]; then
        version=$(curl -Ls --connect-timeout 15 --max-time 30 --retry 2 --retry-delay 2 "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
            | grep '"tag_name"' | head -1 | cut -d'"' -f4)
        if [ -z "$version" ]; then
            log_error "Failed to detect latest 3X-UI version"
            return 1
        fi
    fi
    log_info "$(tf xui_installing_version "$version")"

    # ── 3. Download and extract ───────────────────────────────────────
    local tarball_url="https://github.com/MHSanaei/3x-ui/releases/download/${version}/x-ui-linux-${arch}.tar.gz"
    local tarball="/tmp/x-ui-linux-${arch}.tar.gz"

    local download_ok=false
    for attempt in 1 2 3; do
        rm -f "$tarball" 2>/dev/null
        if gv_step "$(tf xui_downloading "$version" "$arch")" gv_fetch "$tarball_url" "$tarball" 300; then
            # Verify the tarball is a valid gzip. Do NOT depend on the `file`
            # command — it is absent on minimal images (Ubuntu 24.04 etc.), which
            # made this check fail even when the download succeeded. Prefer
            # `gzip -t` (gzip is always present); fall back to the magic bytes.
            if _is_gzip "$tarball"; then
                download_ok=true
                break
            fi
        fi
        [ "$attempt" -lt 3 ] && { log_dim "Download attempt $attempt failed, retrying..."; sleep 5; }
    done

    if [ "$download_ok" != "true" ]; then
        log_error "$(t xui_install_failed) — download failed after 3 attempts"
        rm -f "$tarball" 2>/dev/null
        return 1
    fi

    # Remove old install dir, extract fresh
    rm -rf "$XUI_DIR" 2>/dev/null

    # The tarball extracts to x-ui/ directory under /usr/local/
    if ! tar -xzf "$tarball" -C /usr/local/ 2>>"$install_log"; then
        log_error "$(t xui_install_failed) — extraction failed"
        rm -f "$tarball"
        return 1
    fi
    rm -f "$tarball"

    # Verify binary exists
    if [ ! -f "$XUI_BIN" ]; then
        # Try to find it
        local found_bin
        found_bin=$(find /usr/local/x-ui/ -name "x-ui" -type f -perm -u+x 2>/dev/null | head -1)
        if [ -z "$found_bin" ]; then
            log_error "$(t xui_install_failed) — binary not found after extraction"
            ls -la "$XUI_DIR/" >>"$install_log" 2>&1
            return 1
        fi
    fi

    # Make binaries executable
    chmod +x "$XUI_BIN" 2>/dev/null
    [ -f "$XRAY_BIN" ] && chmod +x "$XRAY_BIN"
    # Also handle arm64 xray binary
    local xray_alt="${XUI_DIR}/bin/xray-linux-${arch}"
    [ -f "$xray_alt" ] && chmod +x "$xray_alt"

    # Create database directory
    mkdir -p "$(dirname "$XUI_DB")"

    # ── 4. Generate random credentials ────────────────────────────────
    local rand_user rand_pass rand_port rand_webpath
    rand_user=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
    rand_pass=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
    rand_port=$(shuf -i 10000-65000 -n 1)
    rand_webpath="/$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 18)"

    # ── 5. Configure via x-ui CLI ─────────────────────────────────────
    # The x-ui binary supports these setting commands:
    #   x-ui setting -username X -password Y
    #   x-ui setting -port P
    #   x-ui setting -webBasePath /path
    #   x-ui setting -settingAutoSave true
    log_dim "Configuring 3X-UI credentials..."

    # Run setting commands — the binary initializes its DB on first run
    "$XUI_BIN" setting -username "$rand_user" -password "$rand_pass" >>"$install_log" 2>&1
    "$XUI_BIN" setting -port "$rand_port" >>"$install_log" 2>&1
    "$XUI_BIN" setting -webBasePath "$rand_webpath" >>"$install_log" 2>&1

    # Write credentials to install log in the same format as the official installer
    # (extract_credentials will parse this)
    cat >> "$install_log" << CREDLOG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Username: ${rand_user}
  Password: ${rand_pass}
  Port: ${rand_port}
  WebBasePath: ${rand_webpath}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREDLOG

    # ── 6. Install systemd service ────────────────────────────────────
    if ! systemctl cat "$XUI_SERVICE" &>/dev/null; then
        log_dim "Installing systemd service..."
        local service_file=""
        # Try service files included in the archive
        for sf in "$XUI_DIR/x-ui.service.debian" "$XUI_DIR/x-ui.service.rhel" "$XUI_DIR/x-ui.service"; do
            [ -f "$sf" ] && { service_file="$sf"; break; }
        done

        if [ -n "$service_file" ]; then
            cp "$service_file" /etc/systemd/system/x-ui.service
        else
            # Create a minimal service file
            cat > /etc/systemd/system/x-ui.service << 'SVCEOF'
[Unit]
Description=x-ui
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SVCEOF
        fi
        systemctl daemon-reload 2>/dev/null
    fi

    # Install x-ui management script (the bash wrapper, not the binary)
    # The 3X-UI archive includes x-ui.sh — a management CLI
    if [ -f "${XUI_DIR}/x-ui.sh" ]; then
        cp "${XUI_DIR}/x-ui.sh" /usr/bin/x-ui 2>/dev/null
        chmod +x /usr/bin/x-ui 2>/dev/null
    elif [ ! -f /usr/bin/x-ui ]; then
        # Fallback: create a minimal management wrapper
        cat > /usr/bin/x-ui << 'MGMTEOF'
#!/bin/bash
# x-ui management script (installed by goVLESS)
red='\033[0;31m'; green='\033[0;32m'; yellow='\033[0;33m'; plain='\033[0m'
SERVICE="x-ui"
BIN="/usr/local/x-ui/x-ui"

show_status() {
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo -e "${green}x-ui is running${plain}"
    else
        echo -e "${red}x-ui is not running${plain}"
    fi
}

show_menu() {
    echo -e "
  ${green}x-ui management script${plain}
  ————————————————————
  ${green}0.${plain} Exit
  ${green}1.${plain} Start
  ${green}2.${plain} Stop
  ${green}3.${plain} Restart
  ${green}4.${plain} Status
  ${green}5.${plain} Show settings
  ${green}6.${plain} Show log
  "
    show_status
    echo ""
    read -rp "  Choose [0-6]: " choice
    case "$choice" in
        0) exit 0 ;;
        1) systemctl start "$SERVICE" && echo -e "${green}Started${plain}" ;;
        2) systemctl stop "$SERVICE" && echo -e "${green}Stopped${plain}" ;;
        3) systemctl restart "$SERVICE" && echo -e "${green}Restarted${plain}" ;;
        4) systemctl status "$SERVICE" --no-pager ;;
        5)
            if [ -f "$BIN" ]; then
                "$BIN" setting -show 2>/dev/null || true
            fi
            if [ -f /root/.govless_credentials ]; then
                echo ""
                echo "  goVLESS credentials:"
                cat /root/.govless_credentials | grep -v '^#'
            fi
            ;;
        6) journalctl -u "$SERVICE" --no-pager -n 50 ;;
        *) echo -e "${red}Invalid choice${plain}" ;;
    esac
}

# Support CLI arguments: x-ui start, x-ui stop, etc.
case "${1:-}" in
    start)    systemctl start "$SERVICE" ;;
    stop)     systemctl stop "$SERVICE" ;;
    restart)  systemctl restart "$SERVICE" ;;
    status)   systemctl status "$SERVICE" --no-pager ;;
    log)      journalctl -u "$SERVICE" --no-pager -n 50 ;;
    setting)  shift; "$BIN" setting "$@" ;;
    settings) "$BIN" setting -show 2>/dev/null ;;
    "")       show_menu ;;
    *)        "$BIN" "$@" ;;
esac
MGMTEOF
        chmod +x /usr/bin/x-ui 2>/dev/null
    fi

    # Install govless convenience command
    if [ ! -f /usr/local/bin/govless ] && [ -f "${SCRIPT_DIR:-/opt/govless-installer}/govless.sh" ]; then
        cat > /usr/local/bin/govless << goVLESSEOF
#!/bin/bash
exec bash "${SCRIPT_DIR:-/opt/govless-installer}/govless.sh" "\$@"
goVLESSEOF
        chmod +x /usr/local/bin/govless 2>/dev/null
    fi

    # ── 7. Enable and start ───────────────────────────────────────────
    systemctl enable "$XUI_SERVICE" 2>/dev/null
    systemctl start "$XUI_SERVICE" 2>/dev/null
    sleep 3

    if systemctl is-active --quiet "$XUI_SERVICE" 2>/dev/null; then
        log_success "$(t xui_installed)"
    else
        log_error "$(t xui_install_failed) — service failed to start"
        journalctl -u "$XUI_SERVICE" --no-pager -n 10 2>/dev/null >&2
        return 1
    fi

    return 0
}

# ── Extract credentials from install log or sqlite ──────────────────────
extract_credentials() {
    local install_log="${1:-/tmp/govless_xui_install.log}"
    local username="" password="" port="" web_path=""

    # Method 1: parse install log
    # v3.x format: "Username:    tiwcBwDS1y" (with ANSI color codes)
    # v2.x format: "username: admin"
    # Strip ANSI codes first, then parse case-insensitively
    # NOTE: avoid grep -P (PCRE) — variable-length lookbehinds fail on some systems
    if [ -f "$install_log" ]; then
        local clean_log
        clean_log=$(sed 's/\x1b\[[0-9;]*m//g' "$install_log" 2>/dev/null) || true
        username=$(echo "$clean_log" | grep -i 'username:' | tail -1 | sed 's/.*[Uu]sername:[[:space:]]*//' | tr -d '[:space:]') || true
        password=$(echo "$clean_log" | grep -i 'password:' | tail -1 | sed 's/.*[Pp]assword:[[:space:]]*//' | tr -d '[:space:]') || true
        port=$(echo "$clean_log" | grep -i 'port:' | grep -v 'webbasepath\|WebBasePath' | tail -1 | sed 's/.*[Pp]ort:[[:space:]]*//' | tr -d '[:space:]') || true
        web_path=$(echo "$clean_log" | grep -i 'webbasepath:' | tail -1 | sed 's/.*[Ww]eb[Bb]ase[Pp]ath:[[:space:]]*//' | tr -d '[:space:]') || true
    fi

    # Method 2: fallback to sqlite
    if { [ -z "$username" ] || [ -z "$password" ]; } && [ -f "$XUI_DB" ] && command -v sqlite3 &>/dev/null; then
        username=$(sqlite3 "$XUI_DB" "SELECT username FROM users LIMIT 1;" 2>/dev/null)
        password=$(sqlite3 "$XUI_DB" "SELECT password FROM users LIMIT 1;" 2>/dev/null)
    fi

    # Port from sqlite
    if [ -z "$port" ] && [ -f "$XUI_DB" ] && command -v sqlite3 &>/dev/null; then
        port=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null)
    fi

    # Web base path from sqlite
    if [ -z "$web_path" ] && [ -f "$XUI_DB" ] && command -v sqlite3 &>/dev/null; then
        web_path=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null)
    fi

    # Defaults
    [ -z "$username" ] && username="admin"
    [ -z "$password" ] && password="admin"
    [ -z "$port" ] && port="2053"
    [ -z "$web_path" ] && web_path="/"

    # Save to globals
    XUI_USER="$username"
    XUI_PASS="$password"
    XUI_PORT="$port"
    XUI_WEB_PATH="$web_path"

    # Normalize web_path: ensure leading /
    [[ "$XUI_WEB_PATH" != /* ]] && XUI_WEB_PATH="/${XUI_WEB_PATH}"
    return 0
}

# ── Save credentials to file ───────────────────────────────────────────
save_credentials() {
    local ip
    ip=$(get_server_ip)

    local mode
    mode=$(config_get mode "lite") || mode="lite"

    # Pro mode: show the panel URL on the domain (matches the domain cert).
    local host="$ip"
    if [ "$mode" = "pro" ]; then
        local _d
        _d=$(config_get domain 2>/dev/null || true)
        [ -n "$_d" ] && [ "$_d" != "null" ] && host="$_d"
    fi

    # Ensure trailing slash on web path (x-ui v3.x routes /<base>/ strictly)
    local web_path_norm="${XUI_WEB_PATH%/}/"

    cat > "$CREDENTIALS_FILE" << CREDS
# goVLESS credentials — $(date -Iseconds)
USERNAME=${XUI_USER}
PASSWORD=${XUI_PASS}
PORT=${XUI_PORT}
WEB_PATH=${XUI_WEB_PATH}
URL=https://${host}:${XUI_PORT}${web_path_norm}
MODE=${mode}
CREDS

    chmod 600 "$CREDENTIALS_FILE"
    log_dim "$(tf creds_saved "$CREDENTIALS_FILE")"
}

# ── Load credentials ───────────────────────────────────────────────────
load_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CREDENTIALS_FILE"
        XUI_USER="${USERNAME:-admin}"
        XUI_PASS="${PASSWORD:-admin}"
        XUI_PORT="${PORT:-2053}"
        XUI_WEB_PATH="${WEB_PATH:-/}"
        # Normalize: ensure leading /
        [[ "$XUI_WEB_PATH" != /* ]] && XUI_WEB_PATH="/${XUI_WEB_PATH}"
        return 0
    fi
    # Try from sqlite
    extract_credentials "/dev/null"
}

# ── Service management ──────────────────────────────────────────────────
is_xui_installed() {
    [ -f "$XUI_BIN" ]
}

xui_status() {
    if ! is_xui_installed; then
        echo "not_installed"
        return
    fi
    if systemctl is-active --quiet "$XUI_SERVICE" 2>/dev/null; then
        echo "running"
    elif systemctl is-enabled --quiet "$XUI_SERVICE" 2>/dev/null; then
        echo "stopped"
    else
        echo "disabled"
    fi
}

start_xui() {
    systemctl start "$XUI_SERVICE" 2>/dev/null
    sleep 2
    if systemctl is-active --quiet "$XUI_SERVICE" 2>/dev/null; then
        log_success "$(t xui_started)"
        return 0
    else
        log_error "3X-UI failed to start"
        journalctl -u "$XUI_SERVICE" --no-pager -n 10 2>/dev/null
        return 1
    fi
}

stop_xui() {
    if systemctl is-active --quiet "$XUI_SERVICE" 2>/dev/null; then
        systemctl stop "$XUI_SERVICE" 2>/dev/null
        log_success "$(t xui_stopped)"
    else
        log_dim "3X-UI already stopped"
    fi
}

restart_xui() {
    systemctl restart "$XUI_SERVICE" 2>/dev/null
    sleep 2
    if systemctl is-active --quiet "$XUI_SERVICE" 2>/dev/null; then
        log_success "$(t xui_restarted)"
        return 0
    else
        log_error "3X-UI failed to restart"
        return 1
    fi
}

enable_xui() {
    systemctl enable "$XUI_SERVICE" 2>/dev/null
}

xui_logs() {
    local lines="${1:-40}"
    journalctl -u "$XUI_SERVICE" --no-pager -n "$lines" 2>/dev/null
}

# ── Generate x25519 keypair for Reality ─────────────────────────────────
generate_reality_keypair() {
    local output
    if [ -f "$XRAY_BIN" ]; then
        output=$("$XRAY_BIN" x25519 2>/dev/null)
    else
        # Try common paths
        local xray_path
        for xray_path in /usr/local/x-ui/bin/xray-linux-amd64 /usr/local/x-ui/bin/xray-linux-arm64; do
            if [ -f "$xray_path" ]; then
                output=$("$xray_path" x25519 2>/dev/null)
                break
            fi
        done
    fi

    if [ -z "$output" ]; then
        log_error "Cannot generate x25519 keypair — xray binary not found"
        return 1
    fi

    REALITY_PRIVATE_KEY=$(echo "$output" | grep -i "private" | awk '{print $NF}' || true)
    REALITY_PUBLIC_KEY=$(echo "$output" | grep -i "public" | awk '{print $NF}' || true)

    if [ -z "$REALITY_PRIVATE_KEY" ] || [ -z "$REALITY_PUBLIC_KEY" ]; then
        log_error "Failed to parse x25519 output"
        return 1
    fi
    return 0
}

# ── Ensure every client has a stable 3X-UI subscription id ────────────────
ensure_client_subids() {
    [ -f "$XUI_DB" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    local result settings_changed normalized_changed
    if ! result=$(python3 - "$XUI_DB" <<'PYEOF'
import json, sqlite3, sys, time

db_path = sys.argv[1]
changed_settings = 0
changed_normalized = 0

try:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA busy_timeout = 5000")
    rows = conn.execute("SELECT id, settings FROM inbounds").fetchall()
    table_names = {r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()}
    client_cols = set()
    if "clients" in table_names:
        client_cols = {r[1] for r in conn.execute("PRAGMA table_info(clients)").fetchall()}

    now_ms = int(time.time() * 1000)
    for inbound_id, settings_raw in rows:
        try:
            settings = json.loads(settings_raw or "{}")
        except Exception:
            continue

        clients = settings.get("clients", [])
        if not isinstance(clients, list):
            continue

        touched_settings = False
        for client in clients:
            if not isinstance(client, dict):
                continue
            client_id = client.get("id") or client.get("uuid")
            email = client.get("email") or ""
            if not client_id:
                continue

            current_subid = client.get("subId") or ""
            # Fill missing subId and repair the legacy goVLESS shape where
            # subId followed the UUID. Preserve non-UUID custom subIds because
            # 3X-UI and the bot can intentionally rotate subscription URLs.
            uuid_like = False
            try:
                import re
                uuid_like = bool(re.match(
                    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
                    current_subid,
                ))
            except Exception:
                uuid_like = False

            sub_id = current_subid or client_id
            if uuid_like and current_subid.lower() != str(client_id).lower():
                sub_id = client_id
            if current_subid != sub_id:
                client["subId"] = sub_id
                changed_settings += 1
                touched_settings = True

            if "clients" in table_names and "sub_id" in client_cols:
                where = []
                where_params = []
                if "uuid" in client_cols:
                    where.append("uuid = ?")
                    where_params.append(client_id)
                if email:
                    where.append("email = ?")
                    where_params.append(email)
                if where:
                    select_cols = ["rowid", "sub_id"]
                    if "uuid" in client_cols:
                        select_cols.append("uuid")
                    if "flow" in client_cols:
                        select_cols.append("flow")
                    rows_norm = conn.execute(
                        f"SELECT {', '.join(select_cols)} FROM clients WHERE {' OR '.join(where)}",
                        where_params,
                    ).fetchall()

                    for row_norm in rows_norm:
                        row_data = dict(zip(select_cols, row_norm))
                        sets = []
                        params = []
                        if (row_data.get("sub_id") or "") != sub_id:
                            sets.append("sub_id = ?")
                            params.append(sub_id)
                        if "uuid" in client_cols and (row_data.get("uuid") or "") != client_id:
                            sets.append("uuid = ?")
                            params.append(client_id)
                        if "flow" in client_cols and "flow" in client and \
                                (row_data.get("flow") or "") != (client.get("flow") or ""):
                            sets.append("flow = ?")
                            params.append(client.get("flow") or "")
                        if sets:
                            if "updated_at" in client_cols:
                                sets.append("updated_at = ?")
                                params.append(now_ms)
                            params.append(row_data["rowid"])
                            conn.execute(
                                f"UPDATE clients SET {', '.join(sets)} WHERE rowid = ?",
                                params,
                            )
                            changed_normalized += 1

        if touched_settings:
            conn.execute(
                "UPDATE inbounds SET settings = ? WHERE id = ?",
                (json.dumps(settings, separators=(",", ":")), inbound_id),
            )

    conn.commit()
    print(f"{changed_settings} {changed_normalized}")
except Exception as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
finally:
    try:
        conn.close()
    except Exception:
        pass
PYEOF
    ); then
        log_warning "Could not backfill client subscription ids"
        return 1
    fi

    settings_changed="${result%% *}"
    normalized_changed="${result#* }"
    if [ "${settings_changed:-0}" -gt 0 ] 2>/dev/null || \
       [ "${normalized_changed:-0}" -gt 0 ] 2>/dev/null; then
        log_info "Backfilled subscription ids: settings=${settings_changed:-0}, clients=${normalized_changed:-0}"
    fi
    return 0
}

# ── Subscription server: random port + random path, persisted to config ──
# Why random: panel webPath is already random; sub URL should be at least as
# unguessable, otherwise scanning shows it on a public port and exposes the
# user list.
# Why both port AND path: port collision with the panel is the most common
# install bug; randomizing port avoids it without manual config.
configure_sub_server() {
    local mode="${1:-$(config_get mode "" 2>/dev/null || true)}"
    local domain="${2:-$(config_get domain "" 2>/dev/null || true)}"
    local sub_port sub_path
    sub_port=$(config_get sub_port "")
    sub_path=$(config_get sub_path "")

    # Generate once and persist; subsequent calls are no-ops if already set
    if [ -z "$sub_port" ] || ! [[ "$sub_port" =~ ^[0-9]+$ ]]; then
        # Random port 20000-65000, retry up to 5x if collides with panel
        local panel_port
        panel_port=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null | head -1)
        local try
        for try in 1 2 3 4 5; do
            sub_port=$((RANDOM % 45000 + 20000))
            [ "$sub_port" != "$panel_port" ] && [ "$sub_port" != "443" ] && break
        done
        config_set "sub_port" "$sub_port"
    fi
    if [ -z "$sub_path" ]; then
        # Random 16-char path, leading + trailing slash
        sub_path="/$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)/"
        config_set "sub_path" "$sub_path"
    fi

    local sub_cert=""
    local sub_key=""
    if [ "$mode" = "pro" ] && [ -n "$domain" ]; then
        sub_cert="/etc/letsencrypt/live/${domain}/fullchain.pem"
        sub_key="/etc/letsencrypt/live/${domain}/privkey.pem"
        if [ ! -f "$sub_cert" ] || [ ! -f "$sub_key" ]; then
            sub_cert=""
            sub_key=""
        fi
    fi

    # Write to x-ui.db settings (subEnable, subPort, subPath, subListen).
    # subListen=empty means bind all interfaces (we WANT this — subscription
    # URL is public-facing, unlike the panel which we hide behind random path).
    # In Pro mode, reuse the domain LE cert so subscription URLs are HTTPS.
    # NOTE: x-ui's `settings` table has no UNIQUE key on `key`, so INSERT OR
    # REPLACE APPENDS duplicate rows instead of updating. x-ui then may read a
    # stale/empty row — e.g. an empty subCertFile makes the sub server run plain
    # HTTP while the URL is https:// -> client TLS-cert error. Delete these keys
    # first, then insert exactly one row each.
    sqlite3 "$XUI_DB" <<SQL
DELETE FROM settings WHERE key IN ('subEnable','subPort','subPath','subListen','subCertFile','subKeyFile','subUpdates');
INSERT INTO settings(key, value) VALUES
  ('subEnable', 'true'),
  ('subPort', '${sub_port}'),
  ('subPath', '${sub_path}'),
  ('subListen', ''),
  ('subCertFile', '${sub_cert}'),
  ('subKeyFile',  '${sub_key}'),
  ('subUpdates', '12');
SQL
    if [ $? -ne 0 ]; then
        log_warning "Could not persist sub-server config — sub URLs may be unavailable"
        return 1
    fi
    ensure_client_subids || true

    log_info "Subscription server: port=${sub_port}, path=${sub_path%/}"
    return 0
}


# ── Backup goVLESS state (atomic, WAL-safe) ─────────────────────────────
# Common bug: tar czf x-ui.db without WAL checkpoint captures only the
# 4096-byte stub header (writes live in x-ui.db-wal). Restoring such a
# backup silently gives an empty DB.
#
# This function:
#  1. WAL-checkpoint TRUNCATE on both x-ui.db and state.db so all pending
#     writes flush to the main DB file.
#  2. Tar's the *.db, *.db-wal, *.db-shm together so even if checkpoint
#     missed pages, recovery is possible.
#  3. Includes config.json, bot.env, /root/.govless_credentials.
#
# Usage: backup_govless [output_dir]    (default: /root/govless-backups)
# Output: /root/govless-backups/govless-YYYYMMDDTHHMMSSZ.tgz
backup_govless() {
    local out_dir="${1:-/root/govless-backups}"
    local ts
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    local out_file="${out_dir}/govless-${ts}.tgz"

    mkdir -p "$out_dir" || { log_error "Cannot create backup dir $out_dir"; return 1; }

    log_step "Creating backup at $out_file"

    # 1. WAL checkpoint — flush pending writes into the main DB file
    if [ -f "$XUI_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$XUI_DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 ||             log_warning "x-ui.db checkpoint failed (continuing)"
    fi
    if [ -f /opt/govless/state.db ] && command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 /opt/govless/state.db "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 ||             log_warning "state.db checkpoint failed (continuing)"
    fi

    # 2. Tar with -wal/-shm sidecars (glob handles them being absent)
    local paths=()
    [ -f "$XUI_DB" ] && paths+=("$XUI_DB" "${XUI_DB}-wal" "${XUI_DB}-shm")
    [ -f /opt/govless/state.db ] && paths+=("/opt/govless/state.db" "/opt/govless/state.db-wal" "/opt/govless/state.db-shm")
    [ -f /opt/govless/config.json ] && paths+=("/opt/govless/config.json")
    [ -f /etc/govless/bot.env ] && paths+=("/etc/govless/bot.env")
    [ -f /etc/govless/tunnel.url ] && paths+=("/etc/govless/tunnel.url")
    [ -f /root/.govless_credentials ] && paths+=("/root/.govless_credentials")
    # Existing -wal/-shm files only — don't fail on missing
    local existing=()
    for p in "${paths[@]}"; do
        [ -e "$p" ] && existing+=("$p")
    done

    if [ ${#existing[@]} -eq 0 ]; then
        log_error "Nothing to backup — no goVLESS state files found"
        return 1
    fi

    if tar czf "$out_file" "${existing[@]}" 2>/dev/null; then
        local size
        size=$(du -h "$out_file" | cut -f1)
        log_success "Backup: $out_file ($size, $(echo "${existing[@]}" | wc -w) files)"
        # Show what's inside for confidence
        log_dim "  Contents:"
        tar tzf "$out_file" | sed 's/^/    /'
        return 0
    else
        log_error "tar failed"
        rm -f "$out_file"
        return 1
    fi
}

# ── Restore from backup_govless tgz ─────────────────────────────────────
# Usage: restore_govless <backup.tgz>
# Stops services → unpacks (overwriting) → restores perms → restarts.
restore_govless() {
    local backup="$1"
    [ -z "$backup" ] && { log_error "Usage: restore_govless <path/to/backup.tgz>"; return 1; }
    [ ! -f "$backup" ] && { log_error "Backup file not found: $backup"; return 1; }

    log_step "Restoring from $backup"

    # 1. Stop services
    systemctl stop govless-bot govlessctl 2>/dev/null || true
    systemctl stop "$XUI_SERVICE" 2>/dev/null || true

    # 2. Validate the archive, drop any stale live WAL (else SQLite would replay
    #    it on top of the restored DB), then unpack (paths in tar are absolute).
    tar tzf "$backup" >/dev/null 2>&1 || { log_error "Backup archive is corrupt/unreadable"; systemctl start "$XUI_SERVICE" 2>/dev/null || true; return 1; }
    rm -f "${XUI_DB}-wal" "${XUI_DB}-shm" /opt/govless/state.db-wal /opt/govless/state.db-shm 2>/dev/null
    tar xzf "$backup" -C / 2>&1 || { log_error "tar restore failed"; return 1; }

    # 3. Restore permissions
    [ -f /etc/govless/bot.env ] && chmod 600 /etc/govless/bot.env
    [ -f /root/.govless_credentials ] && chmod 600 /root/.govless_credentials
    [ -f /opt/govless/state.db ] && chmod 640 /opt/govless/state.db
    chown -R x-ui:x-ui /etc/x-ui 2>/dev/null || true

    # 4. Restart
    systemctl start "$XUI_SERVICE" 2>/dev/null || true
    sleep 3
    systemctl start govlessctl 2>/dev/null || true
    systemctl start govless-bot 2>/dev/null || true

    log_success "Restore complete. Run repair (Manage → Repair) if links look stale."
    return 0
}

# ── Remove 3X-UI ───────────────────────────────────────────────────────
remove_xui() {
    log_step "$(t xui_removing)"
    stop_xui
    systemctl disable "$XUI_SERVICE" 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service
    systemctl daemon-reload 2>/dev/null
    rm -rf "$XUI_DIR" /usr/bin/x-ui /etc/x-ui
    rm -f "$CREDENTIALS_FILE"
    log_success "$(t xui_removed)"
}

# ── Removal helper: try-and-record (Codex 022 P2: failure summary) ─────
# Args: $1=description  $2..=command to run
# Logs to /tmp/govless_remove_failures.log on non-zero, never aborts.
_REMOVE_FAIL_LOG="/tmp/govless_remove_failures.log"
remove_try() {
    local desc="$1"; shift
    if "$@" 2>/tmp/govless_remove_stderr.tmp; then
        return 0
    fi
    {
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] FAIL: $desc"
        echo "  cmd: $*"
        head -3 /tmp/govless_remove_stderr.tmp
        echo ""
    } >> "$_REMOVE_FAIL_LOG"
    return 0  # never propagate — we are best-effort
}

# Print + clear the failure log if any failures were recorded
_remove_report_failures() {
    if [ -s "$_REMOVE_FAIL_LOG" ]; then
        echo ""
        log_warning "Some cleanup steps failed (full log: $_REMOVE_FAIL_LOG):"
        grep -E '^\[.*FAIL:' "$_REMOVE_FAIL_LOG" | sed 's/^/  /'
        echo ""
    fi
}

# ── Granular removal helpers ────────────────────────────────────────────
# Three modes: site only / panel only / everything+traces

# Remove only the Pro website (nginx site config + webroot + LE certs scoped
# to the domain). Leaves 3X-UI, Xray, govless config, and Telegram bot intact.
#
# Safety guards (per Codex 022 P1 #2):
#  1. Refuse if mode=pro AND active inbound references the cert files —
#     would break live VPN.
#  2. Refuse to rm -rf $WEBSITE_ROOT unless our ownership marker is there
#     (.govless-owned file), to protect pre-existing sites.
#  3. Don't flip config mode — would lie about runtime state. User should
#     explicitly run mode_switch to change actual mode.
remove_site_only() {
    log_step "$(t remove_site_step)"

    local cur_mode pro_domain
    cur_mode=$(config_get "mode" 2>/dev/null || true)
    pro_domain=$(config_get "domain" 2>/dev/null || true)

    # Guard 1: would deleting the cert break a live VPN?
    if [ "$cur_mode" = "pro" ] && [ -n "$pro_domain" ] && [ -f "$XUI_DB" ]; then
        local cert_in_use
        cert_in_use=$(sqlite3 "$XUI_DB" \
            "SELECT 1 FROM inbounds WHERE enable=1 AND stream_settings LIKE '%letsencrypt/live/${pro_domain}/%' LIMIT 1;" \
            2>/dev/null)
        if [ -n "$cert_in_use" ]; then
            log_error "$(t remove_site_blocked_pro)"
            log_error "$(tf remove_site_use_switch_mode "$pro_domain")"
            return 1
        fi
    fi

    # Stop nginx (will be restarted at end if other sites remain)
    systemctl stop nginx 2>/dev/null || true

    # Always safe: our own nginx config + symlink
    rm -f "$NGINX_SITE_CONF" "$NGINX_SITE_LINK"

    # Guard 2: webroot — only if we marked it
    if [ -f "${WEBSITE_ROOT}/.govless-owned" ]; then
        rm -rf "$WEBSITE_ROOT"
        log_info "Removed ${WEBSITE_ROOT} (had .govless-owned marker)"
    elif [ -d "$WEBSITE_ROOT" ]; then
        log_warning "$(tf remove_site_skip_webroot "$WEBSITE_ROOT")"
    fi

    # LE cert — only if config says we provisioned for this domain
    if [ -n "$pro_domain" ] && [ -d "/etc/letsencrypt/live/$pro_domain" ]; then
        if command -v certbot &>/dev/null; then
            certbot delete --cert-name "$pro_domain" --non-interactive 2>&1 | tail -3
        else
            rm -rf "/etc/letsencrypt/live/$pro_domain" \
                   "/etc/letsencrypt/archive/$pro_domain" \
                   "/etc/letsencrypt/renewal/${pro_domain}.conf"
        fi
    fi

    # Restart nginx only if any other server blocks remain
    if [ -n "$(ls /etc/nginx/sites-enabled/ 2>/dev/null)" ]; then
        systemctl start nginx 2>/dev/null || true
    fi

    log_success "$(t remove_site_done)"
}

# Remove only the 3X-UI panel + Xray (keeps Pro site + cert + govless config).
remove_panel_only() {
    log_step "$(t remove_panel_step)"
    remove_xui
    log_success "$(t remove_panel_done)"
}

# Nuclear: panel + site + govless dir + bot + WebApp + tunnel + CLI symlink
# + logs + traces in journal + /tmp leftovers. Idempotent — won't fail if
# something is already gone.
remove_everything() {
    log_step "$(t remove_all_step)"
    : > "$_REMOVE_FAIL_LOG"  # reset failure log for this run

    # 1. Stop everything goVLESS-related (remove_try for failure summary)
    for svc in govless-bot govlessctl cloudflared-quick webapp-frontend \
               tunnel-health.timer govless-audit-prune.timer "$XUI_SERVICE"; do
        remove_try "stop $svc" systemctl stop "$svc"
        remove_try "disable $svc" systemctl disable "$svc"
    done

    # 2. Remove 3X-UI + Xray + creds (via remove_try for failure summary)
    remove_try "uninstall 3X-UI + Xray" remove_xui

    # 3. Remove Pro site + LE certs scoped to our domain
    systemctl stop nginx 2>/dev/null || true
    rm -f "$NGINX_SITE_CONF" "$NGINX_SITE_LINK"
    rm -rf "$WEBSITE_ROOT"
    local pro_domain
    pro_domain=$(config_get "domain" 2>/dev/null || true)
    if [ -n "$pro_domain" ]; then
        if command -v certbot &>/dev/null; then
            certbot delete --cert-name "$pro_domain" --non-interactive 2>/dev/null || true
        fi
        rm -rf "/etc/letsencrypt/live/$pro_domain"                "/etc/letsencrypt/archive/$pro_domain"                "/etc/letsencrypt/renewal/${pro_domain}.conf" 2>/dev/null
    fi

    # 4. Phase A systemd units (if installed)
    rm -f /etc/systemd/system/govless-bot.service           /etc/systemd/system/govlessctl.service           /etc/systemd/system/cloudflared-quick.service           /etc/systemd/system/cloudflared-url.service           /etc/systemd/system/cloudflared-url.path           /etc/systemd/system/tunnel-health.service           /etc/systemd/system/tunnel-health.timer           /etc/systemd/system/govless-audit-prune.service           /etc/systemd/system/govless-audit-prune.timer           /etc/systemd/system/webapp-frontend.service 2>/dev/null
    systemctl daemon-reload 2>/dev/null || true

    # 5. Application + data dirs
    rm -rf "$GOVLESS_DIR"          # /opt/govless (config, state.db, webapp)
    rm -rf /opt/govless-installer  # bootstrap.sh clone path
    rm -rf /etc/govless            # bot.env, tunnel.url
    # install.sh uses ${HOME}/goVLESS (typically /root/goVLESS under sudo) —
    # was missed in earlier cleanup (Codex 022 P2). Don't follow symlinks
    # in case user pointed it at something unexpected.
    [ -d "/root/goVLESS" ] && rm -rf "/root/goVLESS"
    if [ -n "${SUDO_USER:-}" ]; then
        local _sudo_home
        _sudo_home=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
        [ -n "$_sudo_home" ] && [ -d "${_sudo_home}/goVLESS" ] && rm -rf "${_sudo_home}/goVLESS"
    fi

    # 6. govless user (if Phase A created one)
    if id govless &>/dev/null; then
        userdel govless 2>/dev/null || true
    fi

    # 7. CLI symlinks
    rm -f /usr/local/bin/govless /usr/local/bin/govlessctl

    # 8. nginx WebApp config (Phase A)
    rm -f /etc/nginx/sites-enabled/govless-webapp.conf           /etc/nginx/sites-available/govless-webapp.conf
    if [ -n "$(ls /etc/nginx/sites-enabled/ 2>/dev/null)" ]; then
        systemctl start nginx 2>/dev/null || true
    fi

    # 9. Logs + journal traces (best-effort, not all distros support per-unit vacuum)
    for unit in govless-bot govlessctl cloudflared-quick tunnel-health                 govless-audit-prune webapp-frontend x-ui; do
        journalctl --rotate 2>/dev/null
        journalctl --vacuum-time=1s --unit="${unit}.service" 2>/dev/null || true
    done

    # 10. /tmp leftovers
    rm -f /tmp/govless_*.json /tmp/govless_*.txt /tmp/govless_cookie.txt           /tmp/govless_links.json /tmp/govless_users_map.json           /tmp/govless_payload.json /tmp/govless_api_resp.json           /tmp/govless_onlines.json 2>/dev/null

    # 11. acme.sh — only if it was installed for us (don't touch if user has their own)
    if [ -d /root/.acme.sh ] && grep -q "anten-ka\|govless" /root/.acme.sh/account.conf 2>/dev/null; then
        /root/.acme.sh/acme.sh --uninstall --no-cron 2>/dev/null || true
    fi

    _remove_report_failures
    log_success "$(t remove_all_done)"
}

# ── Legacy alias (kept for back-compat with any caller using old name) ──
remove_all() {
    remove_everything
}

# ── Configure panel TLS + sub-server-bind + UI language ─────────────────
# Called after install_3xui completes, before extract_credentials.
#
# Strategy:
#  1. Try Let's Encrypt shortlived cert for IP (~6 days, auto-renews via
#     acme.sh cron). This is the same mechanism 3X-UI's management script
#     uses via ssl_cert_issue_for_ip — we just call acme.sh directly so we
#     can run non-interactively.
#  2. If LE fails (rate limit, port 80 in use, network), fall back to a
#     long-lived (825-day) self-signed cert. Panel still gets HTTPS,
#     user accepts cert once in browser.
#
# Also fixes B3 ('webPort 0' warning) by writing settings directly via sqlite
# instead of partial API payload. Subscription server binding is owned by
# configure_sub_server below.
configure_panel_tls() {
    local lang_code="${1:-en}"
    local server_ip="${2:-}"
    # Pro mode: the panel should be reachable at https://<domain>:<port> with a
    # browser-valid certificate. Param 3 (or config domain) selects the domain's
    # Let's Encrypt cert; otherwise (Lite / no cert yet) fall back to IP self-signed.
    local domain="${3:-$(config_get domain 2>/dev/null || true)}"
    [ -z "$server_ip" ] && server_ip=$(get_server_ip 2>/dev/null) || true

    local lang_panel="en-US"
    [ "$lang_code" = "ru" ] && lang_panel="ru-RU"

    local crt key
    local le_crt="/etc/letsencrypt/live/${domain}/fullchain.pem"
    local le_key="/etc/letsencrypt/live/${domain}/privkey.pem"
    if [ -n "$domain" ] && [ -f "$le_crt" ] && [ -f "$le_key" ]; then
        # Pro: reuse the domain LE cert (same one VPN/sub use). Auto-renews via
        # certbot; x-ui re-reads it on restart (consistent with the sub server).
        crt="$le_crt"
        key="$le_key"
        log_dim "Panel TLS: using domain certificate for ${domain}"
    else
        # Lite / pre-cert: self-signed IP cert valid for the server IP.
        local cert_dir="/root/cert/ip"
        mkdir -p "$cert_dir"
        crt="${cert_dir}/${server_ip}.crt"
        key="${cert_dir}/${server_ip}.key"

        # Skip cert issuance if cert already exists and is still valid >24h
        local need_issue=true
        if [ -f "$crt" ] && [ -f "$key" ]; then
            if openssl x509 -in "$crt" -noout -checkend 86400 >/dev/null 2>&1; then
                log_dim "Reusing existing panel certificate at ${crt}"
                need_issue=false
            fi
        fi

        if $need_issue; then
            _govless_issue_panel_cert "$server_ip" "$crt" "$key" || {
                log_warning "Panel cert: LE shortlived failed → falling back to self-signed (825d)"
                openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
                    -keyout "$key" -out "$crt" \
                    -subj "/CN=goVLESS-panel" \
                    -addext "subjectAltName=IP:${server_ip},IP:127.0.0.1,DNS:localhost" \
                    2>/dev/null || {
                        log_error "Cert generation failed entirely — panel will stay HTTP"
                        return 1
                    }
                chmod 600 "$key"
                chmod 644 "$crt"
            }
        fi
    fi

    # Apply settings via sqlite (avoids partial-API-payload bug B3)
    if ! command -v sqlite3 &>/dev/null || [ ! -f "$XUI_DB" ]; then
        log_warning "sqlite3/x-ui.db missing — skip panel TLS config"
        return 1
    fi
    # NOTE: x-ui's `settings` table has no UNIQUE key on `key`, so INSERT OR
    # REPLACE APPENDS duplicate rows instead of updating, and x-ui may then read
    # a stale/empty row (e.g. empty webCertFile => panel stays HTTP). Delete
    # these keys first, then insert exactly one row each.
    sqlite3 "$XUI_DB" <<SQL
DELETE FROM settings WHERE key IN ('webCertFile', 'webKeyFile', 'webLang');
INSERT INTO settings (key, value) VALUES ('webCertFile', '${crt}');
INSERT INTO settings (key, value) VALUES ('webKeyFile',  '${key}');
INSERT INTO settings (key, value) VALUES ('webLang',     '${lang_panel}');
SQL

    # Enable subscription server (random port + random path) before the
    # post-install QR/subscription flow reads regenerated links.
    configure_sub_server 2>/dev/null || log_warning "sub-server config skipped"

    systemctl restart x-ui 2>/dev/null || true
    sleep 2

    log_success "Panel TLS active (HTTPS), subscription server configured, lang=${lang_panel}"
    return 0
}

# ── Internal: try Let's Encrypt shortlived cert for IP ────────────────
_govless_issue_panel_cert() {
    local server_ip="$1"
    local crt="$2"
    local key="$3"

    # Install acme.sh if missing (canonical method: curl | sh -s email=...)
    if [ ! -x "$HOME/.acme.sh/acme.sh" ]; then
        # On RU servers raw.githubusercontent.com is often throttled by DPI: the
        # connection opens but stalls at 0 bytes, and get.acme.sh's online
        # installer has no timeout, so the whole install would hang forever.
        # Bound it hard (live spinner so it never looks frozen); on
        # timeout/failure fall through to the self-signed cert.
        gv_step "Installing acme.sh (SSL auto-renew)" \
            timeout -k 10 90 bash -c 'curl -fsSL --connect-timeout 12 --max-time 80 https://get.acme.sh -o /tmp/getacme.sh && sh /tmp/getacme.sh "email=admin@govless.app"'
        local _arc=$?
        if [ $_arc -ne 0 ] || [ ! -x "$HOME/.acme.sh/acme.sh" ]; then
            pkill -f 'acme\.sh.*install-online' 2>/dev/null || true
            pkill -f 'raw\.githubusercontent\.com/acmesh' 2>/dev/null || true
            log_dim "acme.sh install failed/timed out (rc=$_arc) — see /tmp/govless_acme_install.log; using self-signed"
            return 1
        fi
    fi

    # Install socat for standalone mode
    command -v socat >/dev/null 2>&1 || apt-get install -y -qq socat >/dev/null 2>&1 || return 1

    # Free port 80 for HTTP-01 challenge: stop nginx temporarily
    local nginx_was_running=false
    if systemctl is-active --quiet nginx 2>/dev/null; then
        nginx_was_running=true
        systemctl stop nginx
    fi

    # Issue cert using LE shortlived profile (6-7 day validity, auto-renews)
    local acme_log=/tmp/govless_acme_issue.log
    "$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt >>"$acme_log" 2>&1
    # LE default profile rejects IP identifiers; must explicitly request the
    # 'shortlived' profile (6-day, auto-renews via acme.sh cron). Recipe mirrors
    # 3X-UI's own /usr/bin/x-ui ssl_cert_issue_for_ip function.
    "$HOME/.acme.sh/acme.sh" --issue -d "$server_ip" --standalone \
        --server letsencrypt \
        --certificate-profile shortlived \
        --days 6 \
        --httpport 80 \
        --keylength ec-256 \
        --pre-hook  "systemctl stop  nginx 2>/dev/null || true" \
        --post-hook "systemctl start nginx 2>/dev/null || true" \
        --force \
        >>"$acme_log" 2>&1
    local rc=$?

    $nginx_was_running && systemctl start nginx 2>/dev/null

    if [ $rc -ne 0 ]; then
        log_dim "LE issuance returned $rc — see $acme_log"
        return 1
    fi

    # Install cert files to known paths, register reload hook for renew
    "$HOME/.acme.sh/acme.sh" --install-cert -d "$server_ip" --ecc \
        --key-file       "$key" \
        --fullchain-file "$crt" \
        --reloadcmd      "systemctl restart x-ui" \
        >>"$acme_log" 2>&1 || return 1

    chmod 600 "$key"
    chmod 644 "$crt"
    log_success "Panel cert issued via Let's Encrypt for IP ${server_ip} (~6d, auto-renew)"
    return 0
}

# ── Repair: force re-detect IP, ensure sub-server, regen links ──────────
# Idempotent fix-it-all for the common "I changed IP/domain/network and
# nothing in goVLESS reflects it" complaint. Does NOT touch user data
# (clients, traffic, admins) — only the derived/cached state.
repair_user_facing() {
    log_step "Repairing goVLESS state..."

    # 1. Force re-detect public IP (ignore whatever's in config — may be stale)
    local fresh_ip cur_ip
    cur_ip=$(config_get server_ip "")
    fresh_ip=$(get_server_ip 2>/dev/null)
    if [ -n "$fresh_ip" ] && _valid_ip "$fresh_ip"; then
        if [ "$fresh_ip" != "$cur_ip" ]; then
            log_info "IP changed: ${cur_ip:-<none>} → ${fresh_ip}"
            config_set "server_ip" "$fresh_ip"
        else
            log_info "IP unchanged: ${fresh_ip}"
        fi
    else
        log_warning "Could not auto-detect public IP — set it manually with: govlessctl-fix-ip <ip>"
    fi

    # 2. Ensure subscription server is enabled with random port + path
    if command -v sqlite3 >/dev/null 2>&1 && [ -f "$XUI_DB" ]; then
        if configure_sub_server; then
            systemctl restart x-ui 2>/dev/null || log_warning "Could not restart x-ui after sub-server repair"
            sleep 2
        fi
    fi

    # 3. Regenerate links + subs from x-ui.db
    if regenerate_links_from_db; then
        local link_count sub_count
        link_count=$(python3 -c "import json; print(len(json.load(open('/tmp/govless_links.json'))))" 2>/dev/null || echo "0")
        sub_count=$(python3 -c "import json; print(len(json.load(open('/tmp/govless_subs.json'))))" 2>/dev/null || echo "0")
        log_success "Links: ${link_count}, subscription URLs: ${sub_count}"
    else
        log_error "Failed to regenerate links from x-ui.db"
        return 1
    fi

    log_success "Repair complete. Try (2) Users → (3) Show QR to verify."
    return 0
}
