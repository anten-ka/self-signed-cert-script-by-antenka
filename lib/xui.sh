#!/bin/bash
# XUIFAST v3.0.2 — 3X-UI installation and service management
# Install via expect, extract credentials, systemd management
# Supports both 3.x (New Generation) and 2.x (Legacy) branches

# ── 3X-UI version globals ──────────────────────────────────────────────
XUI_BRANCH=""          # "new" (3.x) or "legacy" (2.x)
XUI_INSTALL_VERSION="" # e.g. "v3.0.1" or "v2.9.4" or "" (latest)
XUI_LEGACY_FALLBACK="v2.9.4"  # hardcoded fallback if GitHub API unreachable

# ── Transport globals ──────────────────────────────────────────────────
XUI_TRANSPORT="tcp"    # "tcp", "xhttp", or "grpc"

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

    local install_log="/tmp/xuifast_xui_install.log"
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
        version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
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

    log_dim "Downloading 3X-UI ${version} (${arch})..."
    local download_ok=false
    for attempt in 1 2 3; do
        rm -f "$tarball" 2>/dev/null
        if curl -Ls --retry 2 --retry-delay 3 -o "$tarball" "$tarball_url" 2>>"$install_log"; then
            # Verify tarball is valid gzip
            if file "$tarball" 2>/dev/null | grep -qi "gzip"; then
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
# x-ui management script (installed by XUIFAST)
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
            if [ -f /root/.xuifast_credentials ]; then
                echo ""
                echo "  XUIFAST credentials:"
                cat /root/.xuifast_credentials | grep -v '^#'
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

    # Install xuifast convenience command
    if [ ! -f /usr/local/bin/xuifast ] && [ -f "${SCRIPT_DIR:-/opt/xuifast-installer}/xuifast.sh" ]; then
        cat > /usr/local/bin/xuifast << XUIFASTEOF
#!/bin/bash
exec bash "${SCRIPT_DIR:-/opt/xuifast-installer}/xuifast.sh" "\$@"
XUIFASTEOF
        chmod +x /usr/local/bin/xuifast 2>/dev/null
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
    local install_log="${1:-/tmp/xuifast_xui_install.log}"
    local username="" password="" port="" web_path=""

    # Method 1: parse install log
    # v3.x format: "Username:    tiwcBwDS1y" (with ANSI color codes)
    # v2.x format: "username: admin"
    # Strip ANSI codes first, then parse case-insensitively
    if [ -f "$install_log" ]; then
        local clean_log
        clean_log=$(sed 's/\x1b\[[0-9;]*m//g' "$install_log" 2>/dev/null)
        username=$(echo "$clean_log" | grep -ioP '(?<=username:\s{0,10})\S+' 2>/dev/null | tail -1 | tr -d '[:space:]')
        password=$(echo "$clean_log" | grep -ioP '(?<=password:\s{0,10})\S+' 2>/dev/null | tail -1 | tr -d '[:space:]')
        port=$(echo "$clean_log" | grep -ioP '(?<=port:\s{0,10})\d+' 2>/dev/null | tail -1 | tr -d '[:space:]')
        # v3.x: "WebBasePath: lCb8E25Wh22wIp3HIJ" (no leading slash)
        # v2.x: "webBasePath: /abc"
        web_path=$(echo "$clean_log" | grep -ioP '(?<=webbasepath:\s{0,10})\S+' 2>/dev/null | tail -1 | tr -d '[:space:]')
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
}

# ── Save credentials to file ───────────────────────────────────────────
save_credentials() {
    local ip
    ip=$(get_server_ip)

    local mode
    mode=$(config_get mode "lite") || mode="lite"

    cat > "$CREDENTIALS_FILE" << CREDS
# XUIFAST credentials — $(date -Iseconds)
USERNAME=${XUI_USER}
PASSWORD=${XUI_PASS}
PORT=${XUI_PORT}
WEB_PATH=${XUI_WEB_PATH}
URL=https://${ip}:${XUI_PORT}${XUI_WEB_PATH}
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

# ── Full removal (3X-UI + nginx + config) ──────────────────────────────
remove_all() {
    remove_xui
    systemctl stop nginx 2>/dev/null
    rm -f "$NGINX_SITE_CONF" "$NGINX_SITE_LINK"
    rm -rf "$WEBSITE_ROOT"
    rm -rf "$XUIFAST_DIR"
    rm -f /usr/local/bin/xuifast
    log_success "$(t remove_done)"
}
