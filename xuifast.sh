#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════╗
# ║  XUIFAST v3.0.0 — 3X-UI VPN installer with stealth masking  ║
# ║  Lite: VLESS + Reality (masquerade as popular site)          ║
# ║  Pro:  VLESS + TLS (your domain + real website)              ║
# ║                                                               ║
# ║  github.com/anten-ka • YouTube: anten-ka                     ║
# ╚═══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Resolve script directory ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ── Source modules ──────────────────────────────────────────────────────
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/i18n.sh"
source "${SCRIPT_DIR}/lib/xui.sh"
source "${SCRIPT_DIR}/lib/xui_api.sh"
source "${SCRIPT_DIR}/lib/reality_domains.sh"
source "${SCRIPT_DIR}/lib/website.sh"

# ── Cleanup trap ────────────────────────────────────────────────────────
trap cleanup_temp_files EXIT

# ── Root check ──────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "  ${RED}✗${NC} This script must be run as root / Запустите от root"
    exit 1
fi

# ── Detect or pick language ─────────────────────────────────────────────
init_language() {
    local lang
    lang=$(detect_language)
    if [ "$lang" = "en" ] && [ ! -f "${XUIFAST_DIR}/.language" ]; then
        # First run — ask user
        lang=$(pick_language_interactive)
    fi
    load_language "$lang"
    save_language "$lang"
}

# ═══════════════════════════════════════════════════════════════════════
# INSTALL FLOW — LITE MODE (Reality)
# ═══════════════════════════════════════════════════════════════════════
install_lite() {
    log_step "$(t install_lite_step)"

    local server_ip
    server_ip=$(get_server_ip) || { log_error "Cannot detect IP"; return 1; }

    # 1. Select masquerade domain
    local mask_domain
    mask_domain=$(select_reality_domain "$server_ip") || return 1

    # 2. Select 3X-UI version (Legacy 2.x or New 3.x)
    select_xui_version

    # 3. Select transport protocol (TCP / XHTTP / gRPC)
    select_transport

    # 4. Ask how many keys
    echo ""
    echo -ne "  $(t users_ask_count) $(t users_ask_count_hint): "
    local users_count_input
    read -r users_count_input
    local users_count="${users_count_input:-3}"
    # Validate: must be number 1-100
    if ! [[ "$users_count" =~ ^[0-9]+$ ]] || [ "$users_count" -lt 1 ] || [ "$users_count" -gt 100 ]; then
        users_count=3
    fi

    # 5. Show config summary (all choices visible before confirm)
    print_header "$(t config_title)"
    echo -e "  $(t config_ip)       ${CYAN}${server_ip}${NC}"
    echo -e "  $(t config_port)     ${CYAN}443${NC}"
    echo -e "  $(t config_mode)     ${CYAN}Lite (Reality)${NC}"
    echo -e "  $(t config_mask)     ${CYAN}${mask_domain}${NC}"
    echo -e "  $(t config_transport) ${CYAN}${XUI_TRANSPORT^^}${NC}"
    echo -e "  $(t config_users)    ${CYAN}${users_count}${NC}"
    echo ""

    confirm "$(t config_confirm)" || return 0

    # 7. Install dependencies
    install_dependencies || return 1

    # 8. Install 3X-UI (critical — must succeed)
    install_3xui || return 1

    # 9. Extract credentials & setup API (critical for panel access)
    extract_credentials
    save_credentials
    setup_api_base

    # === Auto-configuration (best-effort) ===
    # Panel is already installed and accessible at this point.
    # The following steps configure VPN automatically but are NOT fatal.
    local auto_ok=true

    # 10. Wait for API & login
    if run_with_spinner "$(t api_waiting)" wait_for_api 90 && api_login_with_retry; then
        api_set_language "$LANG_CODE"
    else
        log_warning "$(t api_login_fail_manual)"
        auto_ok=false
    fi

    # 11. Generate Reality keypair + users + inbound
    if $auto_ok; then
        if generate_reality_keypair && \
           generate_clients "$users_count" "lite" && \
           api_create_reality_inbound "$mask_domain"; then
            log_info "$(tf users_creating "$users_count")"
            # Restart x-ui so xray picks up the new inbound
            systemctl restart x-ui 2>/dev/null || true
            sleep 2
        else
            log_warning "$(t auto_config_fail)"
            auto_ok=false
        fi
    fi

    # 12. Generate VLESS links
    if $auto_ok; then
        generate_all_vless_links "lite" "$server_ip" "$mask_domain" || auto_ok=false
    fi

    # 13. Setup stub nginx (optional, for port 80)
    setup_lite_nginx || log_warning "$(t lite_nginx_optional_fail)"

    # 14. Save config
    config_set "mode" "lite"
    config_set "mask_domain" "$mask_domain"
    config_set "server_ip" "$server_ip"
    config_set "transport" "$XUI_TRANSPORT"
    config_set "xui_branch" "$XUI_BRANCH"
    [ -n "$XUI_INSTALL_VERSION" ] && config_set "xui_version" "$XUI_INSTALL_VERSION"
    config_set_int "port" 443
    config_set_int "users_count" "$users_count"
    config_set "version" "$XUIFAST_VERSION"
    config_set "installed_at" "$(date -Iseconds)"

    # Save Reality keys to config (if generated)
    [ -n "${REALITY_PRIVATE_KEY:-}" ] && config_set "reality_private_key" "$REALITY_PRIVATE_KEY"
    [ -n "${REALITY_PUBLIC_KEY:-}" ] && config_set "reality_public_key" "$REALITY_PUBLIC_KEY"

    # 15. Done!
    echo ""
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}${BOLD}  $(tf install_done "$XUIFAST_VERSION" "Lite")${NC}"
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo ""

    show_credentials

    if ! $auto_ok; then
        log_warning "$(t auto_config_incomplete)"
    fi

    post_install_flow "lite" "$server_ip" "$mask_domain"
}

# ═══════════════════════════════════════════════════════════════════════
# INSTALL FLOW — PRO MODE (TLS)
# ═══════════════════════════════════════════════════════════════════════
install_pro() {
    log_step "$(t install_pro_step)"

    local server_ip
    server_ip=$(get_server_ip) || { log_error "Cannot detect IP"; return 1; }

    # 1. Ask for domain
    echo ""
    echo -ne "  $(t pro_enter_domain) "
    local domain
    read -r domain
    domain=$(echo "$domain" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

    if ! valid_domain "$domain"; then
        log_error "$(tf pro_bad_domain "$domain")"
        return 1
    fi

    # 2. DNS check
    if ! check_dns "$domain" "$server_ip"; then
        local resolved
        resolved=$(dig +short "$domain" A 2>/dev/null | tail -1)
        log_warning "$(tf pro_dns_mismatch "$domain" "${resolved:-N/A}" "$server_ip")"
        confirm "$(t pro_continue_anyway)" || return 0
    fi

    # 3. Email for SSL
    echo -ne "  $(t pro_enter_email) "
    local email
    read -r email
    email=$(echo "$email" | tr -d '[:space:]')

    # 4. Template selection (from 1800+ catalog or stub)
    local template_dir=""
    # Copy catalog to XUIFAST_DIR if it exists in script dir but not in data dir
    if [ -f "${SCRIPT_DIR}/templates_catalog.json" ] && [ ! -f "$TEMPLATES_CATALOG" ]; then
        mkdir -p "$XUIFAST_DIR"
        cp "${SCRIPT_DIR}/templates_catalog.json" "$TEMPLATES_CATALOG" 2>/dev/null
    fi
    if command -v jq &>/dev/null; then
        source "${SCRIPT_DIR}/lib/templates_catalog.sh" 2>/dev/null
        if type interactive_template_selection &>/dev/null; then
            template_dir=$(interactive_template_selection) || true
        fi
    fi

    # 5. Ask how many keys
    echo ""
    echo -ne "  $(t users_ask_count) $(t users_ask_count_hint): "
    local users_count_input
    read -r users_count_input
    local users_count="${users_count_input:-3}"
    if ! [[ "$users_count" =~ ^[0-9]+$ ]] || [ "$users_count" -lt 1 ] || [ "$users_count" -gt 100 ]; then
        users_count=3
    fi

    # 6. Select 3X-UI version (Legacy 2.x or New 3.x)
    select_xui_version

    # 6b. Select transport protocol (TCP / XHTTP / gRPC)
    select_transport

    # 7. Show config summary
    print_header "$(t config_title)"
    echo -e "  $(t config_ip)       ${CYAN}${server_ip}${NC}"
    echo -e "  $(t config_domain)   ${CYAN}${domain}${NC}"
    echo -e "  $(t config_port)     ${CYAN}443${NC}"
    echo -e "  $(t config_mode)     ${CYAN}Pro (TLS)${NC}"
    echo -e "  $(t config_transport) ${CYAN}${XUI_TRANSPORT^^}${NC}"
    echo -e "  $(t config_users)    ${CYAN}${users_count}${NC}"
    echo ""

    confirm "$(t config_confirm)" || return 0

    # 7. Install dependencies
    install_dependencies || return 1

    # 8. Free port 443 if occupied (but not xray — it might be our running VPN)
    local port443_proc
    port443_proc=$(ss -tlnp 'sport = :443' 2>/dev/null | grep -o 'users:(("[^"]*' | sed 's/users:(("//' | head -1) || true
    if [ -n "$port443_proc" ] && [ "$port443_proc" != "xray-linux-amd6" ] && [ "$port443_proc" != "xray-linux-arm6" ]; then
        kill_port 443
    fi

    # 8. Setup website + SSL first (needs port 80 and 443 free)
    if [ -n "$template_dir" ]; then
        setup_pro_website "$domain" "$template_dir" "$email" || return 1
    else
        # No template — deploy stub and get SSL
        install_nginx || return 1
        install_certbot || return 1
        deploy_stub_site
        obtain_ssl_certificate "$domain" "$email" || return 1
        generate_nginx_pro_config "$domain"
        systemctl restart nginx 2>/dev/null
        setup_ssl_auto_renewal
    fi

    # 9. Stop nginx on 443 — xray will take over
    # nginx stays on :80, xray takes :443 with fallback to :80

    # 10. Install 3X-UI (critical — must succeed)
    install_3xui || return 1

    # 11. Extract credentials & setup API (critical for panel access)
    extract_credentials
    save_credentials
    setup_api_base

    # === Auto-configuration (best-effort) ===
    # Panel is already installed and accessible at this point.
    local auto_ok=true

    # 12. Wait for API & login
    if run_with_spinner "$(t api_waiting)" wait_for_api 90 && api_login_with_retry; then
        api_set_language "$LANG_CODE"
    else
        log_warning "$(t api_login_fail_manual)"
        auto_ok=false
    fi

    # 13. Generate users + TLS inbound
    if $auto_ok; then
        local cert_file="/etc/letsencrypt/live/${domain}/fullchain.pem"
        local key_file="/etc/letsencrypt/live/${domain}/privkey.pem"
        if generate_clients "$users_count" "pro" && \
           api_create_tls_inbound "$domain" "$cert_file" "$key_file"; then
            log_info "$(tf users_creating "$users_count")"
            # Restart x-ui so xray picks up the new inbound
            systemctl restart x-ui 2>/dev/null || true
            sleep 2
        else
            log_warning "$(t auto_config_fail)"
            auto_ok=false
        fi
    fi

    # 14. Generate VLESS links
    if $auto_ok; then
        generate_all_vless_links "pro" "$domain" || auto_ok=false
    fi

    # 15. Save config
    config_set "mode" "pro"
    config_set "domain" "$domain"
    config_set "server_ip" "$server_ip"
    config_set "email" "$email"
    config_set "transport" "$XUI_TRANSPORT"
    config_set_int "port" 443
    config_set_int "users_count" "$users_count"
    config_set "version" "$XUIFAST_VERSION"
    config_set "installed_at" "$(date -Iseconds)"
    config_set "xui_branch" "$XUI_BRANCH"
    [ -n "$XUI_INSTALL_VERSION" ] && config_set "xui_version" "$XUI_INSTALL_VERSION"

    # 16. Done!
    echo ""
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}${BOLD}  $(tf install_done "$XUIFAST_VERSION" "Pro")${NC}"
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo ""

    show_credentials

    if ! $auto_ok; then
        log_warning "$(t auto_config_incomplete)"
    fi

    post_install_flow "pro" "$domain"
}

# ═══════════════════════════════════════════════════════════════════════
# POST-INSTALL FLOW
# ═══════════════════════════════════════════════════════════════════════
post_install_flow() {
    local mode="$1"
    local server="$2"              # IP (lite) or domain (pro)
    local mask_domain="${3:-}"      # only for lite

    echo ""
    echo -ne "  $(t press_enter) "
    read -r

    # App download step
    show_app_download

    # Show first user's QR
    if [ -f /tmp/xuifast_links.json ]; then
        local first_name first_link
        first_name=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_links.json')); print(list(d.keys())[0])" 2>/dev/null)
        first_link=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_links.json')); print(list(d.values())[0])" 2>/dev/null)

        if [ -n "$first_name" ] && [ -n "$first_link" ]; then
            show_user_link "$first_name" "$first_link"
        fi
    fi

    # Connection test
    echo ""
    echo -e "  ${BOLD}$(t test_title)${NC}"
    echo -e "  ${DIM}$(t test_skip)${NC}"
    echo ""

    local test_timeout=120
    local elapsed=0
    local first_email
    first_email=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_users_map.json')); print(list(d.keys())[0])" 2>/dev/null)

    if [ -n "$first_email" ]; then
        while [ "$elapsed" -lt "$test_timeout" ]; do
            if check_client_online "$first_email"; then
                echo -e "  $(tf test_online "$first_email")"
                break
            fi
            local _msg
            _msg=$(tf test_offline "$first_email")
            printf "\r  %s (%ds)" "$_msg" "$elapsed" >&2
            read -t 5 -r </dev/tty 2>/dev/null && break || true  # Enter to skip
            elapsed=$((elapsed + 5))
        done
        echo ""
    fi

    # Ask to show all users
    echo ""
    if confirm "$(t users_show_all)"; then
        show_all_users_formatted
    fi

    echo ""
    echo -e "  $(t enjoy)"
    echo -e "  ${DIM}$(t install_done_hint)${NC}"
    echo ""
}

# ── Show app download ───────────────────────────────────────────────────
show_app_download() {
    print_header "$(t app_title)"
    echo -e "  ${CYAN}1)${NC} $(t app_ios)"
    echo -e "  ${CYAN}2)${NC} $(t app_android)"
    echo ""
    echo -ne "  $(t app_platform) "
    local platform
    read -r platform

    case "$platform" in
        1) echo -e "  ${GREEN}$(t app_ios_hint)${NC}"
           echo ""
           if command -v qrencode &>/dev/null; then
               echo -e "  ${DIM}App Store: Hiddify${NC}"
               qrencode -t UTF8 -m 2 "https://apps.apple.com/app/hiddify-proxy-vpn/id6596777532" 2>/dev/null
           fi
           ;;
        2) echo -e "  ${GREEN}$(t app_android_hint)${NC}"
           echo ""
           if command -v qrencode &>/dev/null; then
               echo -e "  ${DIM}Google Play: Hiddify${NC}"
               qrencode -t UTF8 -m 2 "https://play.google.com/store/apps/details?id=app.hiddify.com" 2>/dev/null
           fi
           ;;
    esac

    echo ""
    echo -ne "  $(t app_installed) [Y/n] "
    read -r
}

# ── Show all users formatted ────────────────────────────────────────────
show_all_users_formatted() {
    if [ ! -f /tmp/xuifast_links.json ]; then
        return 1
    fi

    print_header "$(t users_title)"

    while IFS='|' read -r num name link; do
        echo -e "  ${CYAN}${num})${NC} ${BOLD}${name}${NC}"
        echo -e "     ${GREEN}${link}${NC}"
        echo ""
    done < <(show_all_users)
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN MENU (interactive, after installation)
# ═══════════════════════════════════════════════════════════════════════
show_dashboard() {
    clear
    print_banner

    local mode xui_st nginx_st
    mode=$(config_get mode "N/A")
    xui_st=$(xui_status)
    nginx_st=$(nginx_status)

    # Status indicators
    local xui_icon nginx_icon
    case "$xui_st" in
        running) xui_icon="${GREEN}●${NC}" ;;
        stopped) xui_icon="${YELLOW}○${NC}" ;;
        *)       xui_icon="${RED}✗${NC}" ;;
    esac
    case "$nginx_st" in
        running) nginx_icon="${GREEN}●${NC}" ;;
        stopped) nginx_icon="${YELLOW}○${NC}" ;;
        *)       nginx_icon="${RED}✗${NC}" ;;
    esac

    echo -e "  ${BOLD}$(t dashboard_title)${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..50})${NC}"
    echo -e "  $(t svc_xui):  ${xui_icon} $(t "$xui_st")    $(t svc_nginx): ${nginx_icon} $(t "$nginx_st")"

    local ip domain mask
    ip=$(config_get server_ip "")
    domain=$(config_get domain "")
    mask=$(config_get mask_domain "")

    local xui_ver transport_cfg
    xui_ver=$(config_get xui_version "")
    transport_cfg=$(config_get transport "")

    echo -e "  $(t net_mode)    ${CYAN}${mode}${NC}"
    [ -n "$xui_ver" ] && echo -e "  $(t dashboard_xui_ver)  ${CYAN}${xui_ver}${NC}"
    [ -n "$transport_cfg" ] && echo -e "  $(t config_transport) ${CYAN}${transport_cfg^^}${NC}"
    [ -n "$ip" ] && echo -e "  $(t net_ip)      ${CYAN}${ip}${NC}"
    [ -n "$domain" ] && echo -e "  $(t net_domain)  ${CYAN}${domain}${NC}"
    [ -n "$mask" ] && echo -e "  $(t config_mask) ${CYAN}${mask}${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..50})${NC}"
}

main_menu() {
    while true; do
        show_dashboard

        echo ""
        echo -e "  ${CYAN}1)${NC} $(t menu_proxy)"
        echo -e "  ${CYAN}2)${NC} $(t menu_users)"
        echo -e "  ${CYAN}3)${NC} $(t menu_manage)"
        echo -e "  ${CYAN}4)${NC} $(t menu_about)"
        echo -e "  ${CYAN}0)${NC} $(t exit)"
        echo ""
        echo -e "  ${DIM}$(t auto_refresh_30s)${NC}"

        local choice
        read -t 30 -rp "  ▸ " choice || { echo ""; continue; }

        case "$choice" in
            1) submenu_proxy ;;
            2) show_all_users_formatted; echo -ne "  $(t press_enter_return) "; read -r ;;
            3) submenu_manage ;;
            4) submenu_about ;;
            0) echo -e "  $(t bye)"; exit 0 ;;
            *) ;;
        esac
    done
}

# ── Submenu: Proxy ──────────────────────────────────────────────────────
submenu_proxy() {
    print_header "$(t submenu_proxy_title)"
    echo -e "  ${CYAN}1)${NC} $(t proxy_install_update)"
    echo -e "  ${CYAN}2)${NC} $(t proxy_show_links)"
    echo -e "  ${CYAN}3)${NC} $(t proxy_show_qr)"
    echo -e "  ${CYAN}4)${NC} $(t proxy_restart)"
    echo -e "  ${CYAN}5)${NC} $(t proxy_logs)"
    echo -e "  ${CYAN}6)${NC} $(t proxy_change_mode)"
    echo -e "  ${CYAN}0)${NC} $(t back)"
    echo ""

    local choice
    read -rp "  ▸ " choice
    case "$choice" in
        1) select_and_install ;;
        2) show_all_users_formatted ;;
        3)
            if [ -f /tmp/xuifast_links.json ]; then
                while IFS='|' read -r num name link; do
                    show_user_link "$name" "$link"
                done < <(show_all_users)
            fi
            ;;
        4) restart_xui ;;
        5) xui_logs 50 ;;
        6) select_and_install ;;
        0) return ;;
    esac
    echo -ne "  $(t press_enter_return) "
    read -r
}

# ── Submenu: Manage ─────────────────────────────────────────────────────
submenu_manage() {
    print_header "$(t submenu_manage_title)"
    echo -e "  ${CYAN}1)${NC} $(t manage_language)"
    echo -e "  ${CYAN}2)${NC} $(t proxy_restart)"
    echo -e "  ${CYAN}3)${NC} $(t manage_remove)"
    echo -e "  ${CYAN}0)${NC} $(t back)"
    echo ""

    local choice
    read -rp "  ▸ " choice
    case "$choice" in
        1)
            local new_lang
            new_lang=$(pick_language_interactive)
            load_language "$new_lang"
            save_language "$new_lang"
            ;;
        2) restart_xui ;;
        3)
            if confirm "$(t remove_confirm)"; then
                remove_all
            fi
            ;;
        0) return ;;
    esac
    echo -ne "  $(t press_enter_return) "
    read -r
}

# ── Submenu: About ──────────────────────────────────────────────────────
submenu_about() {
    print_header "$(t submenu_about_title)"
    echo -e "  XUIFAST:    v${XUIFAST_VERSION}"
    echo -e "  Engine:     3X-UI + Xray-core"
    echo -e "  Protocol:   VLESS + XTLS-Vision"
    echo -e "  Security:   Reality / TLS"
    echo -e "  Author:     anten-ka"
    echo -e "  GitHub:     github.com/anten-ka"
    echo -e "  YouTube:    youtube.com/@anten-ka"
    show_credits
    echo -ne "  $(t press_enter_return) "
    read -r
}

# ═══════════════════════════════════════════════════════════════════════
# MODE SELECTION
# ═══════════════════════════════════════════════════════════════════════
select_and_install() {
    print_header "$(t install_select_mode)"
    echo ""
    echo -e "  ${CYAN}1)${NC} ${BOLD}$(t install_lite_title)${NC}"
    echo -e "     ${DIM}$(t install_lite_desc1)${NC}"
    echo -e "     ${DIM}$(t install_lite_desc2)${NC}"
    echo -e "     ${DIM}$(t install_lite_desc3)${NC}"
    echo ""
    echo -e "  ${CYAN}2)${NC} ${BOLD}$(t install_pro_title)${NC}"
    echo -e "     ${DIM}$(t install_pro_desc1)${NC}"
    echo -e "     ${DIM}$(t install_pro_desc2)${NC}"
    echo -e "     ${DIM}$(t install_pro_desc3)${NC}"
    echo ""

    local mode_choice
    echo -ne "  $(t install_mode_choice) "
    read -r mode_choice

    case "$mode_choice" in
        1) install_lite ;;
        2) install_pro ;;
        *) log_error "$(t invalid_choice)"; return 1 ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════
main() {
    init_language
    print_banner

    # Check disk space
    if ! check_disk_space 500; then
        local avail
        avail=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}')
        log_error "$(tf err_low_disk "${avail:-?}" "500")"
        exit 1
    fi

    # If already installed — show menu
    if is_xui_installed && [ -f "$XUIFAST_CONFIG" ]; then
        load_credentials
        setup_api_base
        main_menu
    else
        # First run — install
        select_and_install
    fi
}

main "$@"
