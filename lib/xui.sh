#!/bin/bash
# XUIFAST v3.0.0 — 3X-UI installation and service management
# Install via expect, extract credentials, systemd management

# ── Install 3X-UI via expect ────────────────────────────────────────────
install_3xui() {
    log_step "$(t xui_installing)"

    if [ -f "$XUI_BIN" ]; then
        log_dim "$(t xui_already_installed)"
    fi

    local install_log="/tmp/xuifast_xui_install.log"

    # Run the official installer with expect for automated interaction
    expect << 'EXPECT_EOF' > "$install_log" 2>&1
set timeout 300
spawn bash -c "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)"

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
    -re "\\$" {
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

    # Save credentials file
    save_credentials
}

# ── Save credentials to file ───────────────────────────────────────────
save_credentials() {
    local ip
    ip=$(get_server_ip)

    cat > "$CREDENTIALS_FILE" << CREDS
# XUIFAST credentials — $(date -Iseconds)
USERNAME=$XUI_USER
PASSWORD=$XUI_PASS
PORT=$XUI_PORT
WEB_PATH=$XUI_WEB_PATH
URL=https://${ip}:${XUI_PORT}${XUI_WEB_PATH}
MODE=$(config_get mode "lite")
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

    REALITY_PRIVATE_KEY=$(echo "$output" | grep -i "private" | awk '{print $NF}')
    REALITY_PUBLIC_KEY=$(echo "$output" | grep -i "public" | awk '{print $NF}')

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
