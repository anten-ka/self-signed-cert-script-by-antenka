#!/bin/bash
# XUIFAST v3.0.2 — 3X-UI installation and service management
# Install via expect, extract credentials, systemd management
# Supports both 3.x (New Generation) and 2.x (Legacy) branches

# ── 3X-UI version globals ──────────────────────────────────────────────
XUI_BRANCH=""          # "new" (3.x) or "legacy" (2.x)
XUI_INSTALL_VERSION="" # e.g. "v3.0.1" or "v2.9.4" or "" (latest)
XUI_LEGACY_FALLBACK="v2.9.4"  # hardcoded fallback if GitHub API unreachable

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

# ── Install 3X-UI via expect ────────────────────────────────────────────
# Usage: install_3xui [version]
# version: "v3.0.1", "v2.9.4", or "" for latest
install_3xui() {
    local version="${1:-$XUI_INSTALL_VERSION}"
    log_step "$(t xui_installing)"

    if [ -f "$XUI_BIN" ]; then
        log_dim "$(t xui_already_installed)"
        return 0
    fi

    local install_log="/tmp/xuifast_xui_install.log"
    local install_cmd

    if [ -n "$version" ]; then
        # Pin to specific version
        log_info "$(tf xui_installing_version "$version")"
        install_cmd="VERSION=${version} && bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/\${VERSION}/install.sh) \${VERSION}"
    else
        # Latest (master branch)
        install_cmd="bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)"
    fi

    # Run the official installer with expect for automated interaction
    expect << EXPECT_EOF > "$install_log" 2>&1
set timeout 300
spawn bash -c "${install_cmd}"

# Accept any confirmation prompts
expect {
    -re "y/n|Y/N|y/N|yes/no" {
        sleep 1
        send "y\r"
        exp_continue
    }
    -re "Enter|enter|press" {
        sleep 1
        send "\r"
        exp_continue
    }
    -re "\\\\$" {
        # Shell prompt — installation finished
    }
    eof {}
    timeout {
        puts "TIMEOUT during 3x-ui installation"
        exit 1
    }
}
EXPECT_EOF

    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        log_error "$(t xui_install_failed)"
        [ -f "$install_log" ] && tail -20 "$install_log" >&2
        return 1
    fi

    # Verify installation
    if [ ! -f "$XUI_BIN" ]; then
        log_error "$(t xui_install_failed) — binary not found"
        return 1
    fi

    log_success "$(t xui_installed)"
    return 0
}

# ── Extract credentials from install log or sqlite ──────────────────────
extract_credentials() {
    local install_log="${1:-/tmp/xuifast_xui_install.log}"
    local username="" password="" port="" web_path=""

    # Method 1: parse install log
    if [ -f "$install_log" ]; then
        username=$(grep -oP '(?<=username:\s).*' "$install_log" 2>/dev/null | tail -1 | tr -d '[:space:]')
        password=$(grep -oP '(?<=password:\s).*' "$install_log" 2>/dev/null | tail -1 | tr -d '[:space:]')
        port=$(grep -oP '(?<=port:\s)\d+' "$install_log" 2>/dev/null | tail -1 | tr -d '[:space:]')
        web_path=$(grep -oP '(?<=webBasePath:\s)/[^\s]+' "$install_log" 2>/dev/null | tail -1 | tr -d '[:space:]')
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
