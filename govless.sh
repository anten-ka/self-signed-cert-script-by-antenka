#!/bin/bash
# goVLESS — Copyright (c) 2025-2026 anten-ka. All rights reserved.
# Licensed under the goVLESS Source-Available License (see the LICENSE file).
# Redistribution, mirroring, or republishing in any form — whole or partial,
# modified or not — is prohibited without prior written permission.

# ╔═══════════════════════════════════════════════════════════════╗
# ║  goVLESS v${GOVLESS_VERSION} — 3X-UI VPN installer with stealth masking  ║
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
source "${SCRIPT_DIR}/lib/migrate.sh"

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
    if [ "$lang" = "en" ] && [ ! -f "${GOVLESS_DIR}/.language" ]; then
        # First run — ask user
        lang=$(pick_language_interactive)
    fi
    load_language "$lang"
    save_language "$lang"
    # Initialize state.db (idempotent)
    init_state_db 2>/dev/null || true
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

    # Select 3X-UI version (Legacy 2.x or New 3.x) — but only if not
    # already installed. Otherwise install_3xui will short-circuit and the
    # user's choice would silently mismatch the actual binary (Codex 012 P2).
    if xui_already_installed; then
        load_xui_version_from_config
        log_dim "3X-UI already installed (${XUI_BRANCH:-?} ${XUI_INSTALL_VERSION:-?}) — keeping it"
    else
        select_xui_version
    fi

    # 3. Select transport protocol (TCP / XHTTP / gRPC)
    select_transport
    select_fingerprint

    # 4. Ask how many keys
    echo ""
    echo -ne "  $(t users_ask_count) $(t users_ask_count_hint): "
    local users_count_input
    read -r users_count_input || users_count_input=""
    local users_count="${users_count_input:-3}"
    # Validate: must be number 1-100
    if ! [[ "$users_count" =~ ^[0-9]{1,3}$ ]] || [ "$users_count" -lt 1 ] || [ "$users_count" -gt 100 ]; then
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

    confirm "$(t config_confirm)" "$(t confirm_install)" "$(t confirm_back)" || return 0

    # 7. Install dependencies
    install_dependencies || return 1

    # Re-init state.db now that sqlite3 is guaranteed (first call in
    # init_language ran before deps install, may have been a no-op)
    init_state_db 2>/dev/null || true

    # 8. Install 3X-UI (critical — must succeed)
    install_3xui || return 1

    # B1/B2/B3 fix: enable panel TLS + bind sub server + lang via sqlite
    configure_panel_tls "${LANG_CODE:-en}" || log_warning "Panel TLS partially failed"


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
        :  # API ready — language set earlier via configure_panel_tls (sqlite)
    else
        log_warning "$(t api_login_fail_manual)"
        auto_ok=false
    fi

    # 11. Generate Reality keypair + users + inbound
    if $auto_ok; then
        if generate_reality_keypair && generate_clients "$users_count" "lite"; then
            # Create the inbound. v2.9.4's API can return non-zero even when the
            # row IS committed, so don't trust the rc — verify by result below.
            api_create_reality_inbound "$mask_domain" || log_dim "$(t auto_config_api_note)"
            log_info "$(tf users_creating "$users_count")"
            # Restart x-ui so it regenerates config.json from the DB, then verify
            # xray is actually serving Reality on :443 (retry — v2 can be slow).
            local _serve=false _try
            for _try in 1 2 3; do
                systemctl restart x-ui 2>/dev/null || true
                sleep 3
                if reality_inbound_serving; then _serve=true; break; fi
            done
            $_serve || { log_warning "$(t auto_config_fail)"; auto_ok=false; }
        else
            log_warning "$(t auto_config_fail)"
            auto_ok=false
        fi
    fi

    # 12. Generate VLESS links
    if $auto_ok; then
        generate_all_vless_links "lite" "$server_ip" "$mask_domain" || auto_ok=false
    fi

    # 14. Save config
    config_set "mode" "lite"
    config_set "mask_domain" "$mask_domain"
    config_set "server_ip" "$server_ip"
    config_set "transport" "$XUI_TRANSPORT"
    config_set "fingerprint" "$XUI_FP"
    config_set "xui_branch" "$XUI_BRANCH"
    [ -n "$XUI_INSTALL_VERSION" ] && config_set "xui_version" "$XUI_INSTALL_VERSION"
    config_set_int "port" 443
    config_set_int "users_count" "$users_count"
    config_set "version" "$GOVLESS_VERSION"
    config_set_int "schema" "$GOVLESS_SCHEMA"
    config_set "installed_at" "$(date -Iseconds)"

    # Save Reality keys to config (if generated)
    [ -n "${REALITY_PRIVATE_KEY:-}" ] && config_set "reality_private_key" "$REALITY_PRIVATE_KEY"
    [ -n "${REALITY_PUBLIC_KEY:-}" ] && config_set "reality_public_key" "$REALITY_PUBLIC_KEY"

    # 15. Done!
    echo ""
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}${BOLD}  $(tf install_done "$GOVLESS_VERSION" "Lite")${NC}"
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo ""

    show_credentials

    if ! $auto_ok; then
        log_warning "$(t auto_config_incomplete)"
    fi

    post_install_flow "lite" "$server_ip" "$mask_domain"
}

# ═══════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════
post_install_flow() {
    local mode="$1"
    local server="$2"              # IP (lite) or domain (pro)
    local mask_domain="${3:-}"      # only for lite
    # Interactive post-install phase (prompts, QR, bot setup): a fallible display
    # step must not abort the script under errexit.
    set +e

    echo ""
    echo -ne "  $(t press_enter) "
    read -r

    # App download step
    show_app_download

    # Show first user's QR — regen from DB first, prefer subscription URL
    regenerate_links_from_db 2>/dev/null
    if [ -s /tmp/govless_links.json ]; then
        local first_name first_link first_sub
        first_name=$(python3 -c "import json; d=json.load(open('/tmp/govless_links.json')); print(list(d.keys())[0])" 2>/dev/null)
        first_link=$(python3 -c "import json; d=json.load(open('/tmp/govless_links.json')); print(list(d.values())[0])" 2>/dev/null)
        first_sub=""
        if [ "$mode" = "pro" ] && [ -s /tmp/govless_subs.json ]; then
            first_sub=$(python3 -c "import json, sys; d=json.load(open('/tmp/govless_subs.json')); print(d.get(sys.argv[1],''))" "$first_name" 2>/dev/null)
        fi

        if [ -n "$first_name" ] && [ -n "$first_link" ]; then
            show_user_link_choice "$first_name" "$first_link" "$first_sub"
        fi
    fi

    # Connection test
    echo ""
    echo -e "  ${BOLD}$(t test_title)${NC}"
    echo -e "  ${DIM}$(t test_skip)${NC}"
    echo ""

    # 30s default (was 120s) — Layer 3 traffic-stats fallback in
    # check_client_online catches connects within seconds now, so longer
    # wait is unnecessary noise. Override via GOVLESS_CONNTEST_TIMEOUT.
    local test_timeout="${GOVLESS_CONNTEST_TIMEOUT:-30}"
    local poll_interval="${GOVLESS_CONNTEST_INTERVAL:-3}"
    local elapsed=0
    local first_email
    [ -s /tmp/govless_users_map.json ] || regenerate_links_from_db 2>/dev/null
    first_email=$(python3 -c "import json; d=json.load(open('/tmp/govless_users_map.json')); print(list(d.keys())[0])" 2>/dev/null)

    if [ -n "$first_email" ]; then
        while [ "$elapsed" -lt "$test_timeout" ]; do
            if check_client_online "$first_email"; then
                printf "\r%80s\r" " "
                echo -e "  $(tf test_online "$first_email")"
                break
            fi
            local _msg
            _msg=$(tf test_offline "$first_email")
            # Show skip-hint INLINE on the wait line so user sees it
            printf "\r  %s (%ds)  ${DIM}[%s]${NC}    " "$_msg" "$elapsed" "$(t test_skip)" >&2
            read -t "$poll_interval" -r </dev/tty 2>/dev/null && { echo ""; break; } || true
            elapsed=$((elapsed + poll_interval))
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
    read -r platform || platform=""

    case "$platform" in
        1) echo -e "  ${GREEN}$(t app_ios_hint)${NC}"
           echo ""
           if command -v qrencode &>/dev/null; then
               echo -e "  ${DIM}App Store: INCY${NC}"
               qr_print "https://apps.apple.com/us/app/incy/id6756943388"
           fi
           ;;
        2) echo -e "  ${GREEN}$(t app_android_hint)${NC}"
           echo ""
           if command -v qrencode &>/dev/null; then
               echo -e "  ${DIM}Google Play: INCY${NC}"
               qr_print "https://play.google.com/store/apps/details?id=llc.itdev.incy"
           fi
           ;;
    esac

    echo ""
    echo -ne "  $(t app_installed) "
    read -r
}

# ── Show all users formatted ────────────────────────────────────────────
show_all_users_formatted() {
    regenerate_links_from_db 2>/dev/null
    if [ ! -s /tmp/govless_links.json ]; then
        return 1
    fi

    print_header "$(t users_title)"

    while IFS=$'\t' read -r num name_b64 link_b64; do
        local name link
        name=$(python3 -c 'import base64,sys; print(base64.b64decode(sys.argv[1]).decode())' "$name_b64" 2>/dev/null)
        link=$(python3 -c 'import base64,sys; print(base64.b64decode(sys.argv[1]).decode())' "$link_b64" 2>/dev/null)
        echo -e "  ${CYAN}${num})${NC} ${BOLD}${name}${NC}"
        echo -e "     ${GREEN}${link}${NC}"
        echo ""
    done < <(show_all_users)
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN MENU (interactive, after installation)
# ═══════════════════════════════════════════════════════════════════════
show_dashboard() {
    clear 2>/dev/null || true
    print_banner

    local mode xui_st
    mode=$(config_get mode "N/A")
    xui_st=$(xui_status)

    # Status indicators
    local xui_icon
    case "$xui_st" in
        running) xui_icon="${GREEN}●${NC}" ;;
        stopped) xui_icon="${YELLOW}○${NC}" ;;
        *)       xui_icon="${RED}✗${NC}" ;;
    esac

    echo -e "  ${BOLD}$(t dashboard_title)${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..50})${NC}"
    echo -e "  $(t svc_xui):  ${xui_icon} $(t "$xui_st")"

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


# ── Anten-ka Club gate — Pro / Lazy Pro are club-only in this edition ──
show_club_gate() {
    local url="https://vk.cc/cUQNzV"
    print_header "Anten-ka Club"
    if [ "$LANG_CODE" = "ru" ]; then
        echo -e "  ${YELLOW}${BOLD}🔒 Режимы «Pro» и «Ленивый Pro» — для подписчиков Anten-ka Club.${NC}"
        echo ""
        echo -e "  ${BOLD}Что внутри клуба:${NC}"
        echo -e "    ${GREEN}•${NC} Pro-скрипты (домен + TLS, маскировка под реальный сайт)"
        echo -e "    ${GREEN}•${NC} ИИ-боты-помощники"
        echo -e "    ${GREEN}•${NC} Сообщество 1300+ человек: поддержка, гайды, обмен опытом"
        echo -e "    ${GREEN}•${NC} Закрытые обновления и новые фишки раньше всех"
        echo ""
        echo -e "  ${BOLD}Вступить:${NC} ${CYAN}${url}${NC}"
    else
        echo -e "  ${YELLOW}${BOLD}🔒 'Pro' and 'Lazy Pro' modes are for Anten-ka Club members.${NC}"
        echo ""
        echo -e "  ${BOLD}Inside the club:${NC}"
        echo -e "    ${GREEN}•${NC} Pro scripts (domain + TLS, real-site masquerade — zero hassle)"
        echo -e "    ${GREEN}•${NC} AI helper bots"
        echo -e "    ${GREEN}•${NC} 1300+ community: support, guides, shared experience"
        echo -e "    ${GREEN}•${NC} Early access to private updates & features"
        echo ""
        echo -e "  ${BOLD}Join:${NC} ${CYAN}${url}${NC}"
    fi
    echo ""
    command -v qrencode >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qrencode >/dev/null 2>&1
    qr_print "$url"
    echo ""
    local msg
    if [ "$LANG_CODE" = "ru" ]; then msg="Нажмите Enter для возврата…"; else msg="Press Enter to return…"; fi
    echo -ne "  $msg "
    read -r
    return 0
}

# ── Recommended hosting (partners) ──────────────────────────────────────
show_hosting() {
    local h1="https://vk.cc/ct29NQ" h2="https://vk.cc/cUxAhj"
    if [ "$LANG_CODE" = "ru" ]; then
        print_header "Правильный хостинг"
        echo -e "  ${DIM}Проверенные партнёры — серверы, на которых goVLESS работает отлично.${NC}"
        echo ""
        echo -e "  ${BOLD}${WHITE}Хостинг #1${NC}   ${CYAN}${h1}${NC}"
        echo -e "      ${GREEN}OFF60${NC}      — 60% скидка на первый месяц"
        echo -e "      ${GREEN}antenka20${NC}  — 20% + 3% при оплате за 3 месяца"
        echo -e "      ${GREEN}antenka6${NC}   — 15% + 5% при оплате за 6 месяцев"
        echo ""
        qr_print "$h1"
        echo ""
        echo -e "  ${BOLD}${WHITE}Хостинг #2${NC}   ${CYAN}${h2}${NC}"
        echo -e "      ${GREEN}OFF60${NC}      — 60% скидка на первый месяц"
        echo ""
        qr_print "$h2"
    else
        print_header "Recommended hosting"
        echo -e "  ${DIM}Vetted partners — servers where goVLESS runs great.${NC}"
        echo ""
        echo -e "  ${BOLD}${WHITE}Hosting #1${NC}   ${CYAN}${h1}${NC}"
        echo -e "      ${GREEN}OFF60${NC}      — 60% off the first month"
        echo -e "      ${GREEN}antenka20${NC}  — 20% + 3% when paying for 3 months"
        echo -e "      ${GREEN}antenka6${NC}   — 15% + 5% when paying for 6 months"
        echo ""
        qr_print "$h1"
        echo ""
        echo -e "  ${BOLD}${WHITE}Hosting #2${NC}   ${CYAN}${h2}${NC}"
        echo -e "      ${GREEN}OFF60${NC}      — 60% off the first month"
        echo ""
        qr_print "$h2"
    fi
    echo ""
    local msg; [ "$LANG_CODE" = "ru" ] && msg="Нажмите Enter для возврата…" || msg="Press Enter to return…"
    echo -ne "  $msg "; read -r; return 0
}

# ── Upgrade to PRO (Lite vs PRO table + club CTA) ────────────────────────
show_pro_upgrade() {
    local url="https://vk.cc/cUQNzV"
    if [ "$LANG_CODE" = "ru" ]; then
        print_header "Перейти на PRO"
        echo -e "  ${YELLOW}${BOLD}Максимальная защита:${NC} сайт + Telegram-бот + Telegram веб-апп"
    else
        print_header "Upgrade to PRO"
        echo -e "  ${YELLOW}${BOLD}Maximum protection:${NC} website + Telegram bot + Telegram web app"
    fi
    echo ""
    LC="$LANG_CODE" python3 -c '
import os
ru=os.environ.get("LC","ru")=="ru"
G="\033[0;32m"; Dim="\033[2m"; Bld="\033[1m"; N="\033[0m"
rows=[("Reality-маскировка под чужой сайт","Reality masquerade (foreign SNI)",1),
 ("Свой домен + TLS-сертификат","Own domain + TLS certificate",0),
 ("Сайт-прикрытие (nginx, реальный сайт)","Cover website (nginx, real site)",0),
 ("Telegram-бот управления","Telegram management bot",0),
 ("Telegram мини-приложение (веб-апп)","Telegram mini-app (web app)",0),
 ("Прокси для API Telegram (RU egress)","Telegram-API proxy (RU egress)",0),
 ("«Ленивый Pro» — всё автоматически","Lazy Pro — fully automatic",0),
 ("ИИ-боты-помощники + сообщество 1300+","AI helper bots + 1300+ community",0)]
W=40
hf="Возможность" if ru else "Feature"
print("  "+Bld+hf.ljust(W)+"Lite   PRO"+N)
print("  "+Dim+"─"*(W+10)+N)
for fr,fe,l in rows:
    f=fr if ru else fe
    lm=(G+"✓"+N) if l else (Dim+"—"+N)
    print("  "+f.ljust(W)+" "+lm+"     "+G+"✓"+N)
'
    echo ""
    if [ "$LANG_CODE" = "ru" ]; then
        echo -e "  ${BOLD}PRO доступен подписчикам Anten-ka Club:${NC} ${CYAN}${url}${NC}"
    else
        echo -e "  ${BOLD}PRO is available to Anten-ka Club members:${NC} ${CYAN}${url}${NC}"
    fi
    echo ""
    qr_print "$url"
    echo ""
    local msg; [ "$LANG_CODE" = "ru" ] && msg="Нажмите Enter для возврата…" || msg="Press Enter to return…"
    echo -ne "  $msg "; read -r; return 0
}

main_menu() {
    while true; do
        show_dashboard

        echo ""
        echo -e "  ${CYAN}1)${NC} $(t menu_proxy)"
        echo -e "  ${CYAN}2)${NC} $(t menu_users)"
        echo -e "  ${CYAN}3)${NC} $(t menu_manage)"
        echo -e "  ${CYAN}4)${NC} $(t menu_pro)"
        echo -e "  ${CYAN}5)${NC} $(t menu_hosting)"
        echo -e "  ${CYAN}6)${NC} $(t menu_about)"
        echo -e "  ${CYAN}0)${NC} $(t exit)"
        echo ""
        echo -e "  ${DIM}$(t auto_refresh_30s)${NC}"

        local choice
        read -t 30 -rp "  ▸ " choice || { echo ""; continue; }

        case "$choice" in
            1) submenu_proxy ;;
            2) submenu_users ;;
            3) submenu_manage ;;
            4) show_pro_upgrade ;;
            5) show_hosting ;;
            6) submenu_about ;;
            0) echo -e "  $(t bye)"; exit 0 ;;
            *)
                # Stay in main menu — re-render dashboard + options
                log_warning "$(t invalid_choice)"
                sleep 1
                ;;
        esac
    done
}

# ── Submenu: Proxy ──────────────────────────────────────────────────────
# Looping submenu — invalid input stays here (does NOT pop to main menu).
# Only `0` returns to the caller (main menu).
submenu_proxy() {
    while true; do
        print_header "$(t submenu_proxy_title)"
        echo -e "  ${CYAN}1)${NC} $(t proxy_install_update)"
        echo -e "  ${CYAN}2)${NC} $(t proxy_restart)"
        echo -e "  ${CYAN}3)${NC} $(t proxy_logs)"
        echo -e "  ${CYAN}0)${NC} $(t back)"
        echo ""

        local choice
        read -rp "  ▸ " choice || { echo ""; return; }
        case "$choice" in
            1) select_and_install ;;
            2) restart_xui ;;
            3) xui_logs 50 ;;
            0) return ;;
            *)
                log_warning "$(t invalid_choice)"
                sleep 1
                continue
                ;;
        esac
        echo -ne "  $(t press_enter_return) "
        read -r
    done
}

# ── Submenu: Users (NEW — owns links/QR, was scattered in Proxy) ────────
submenu_users() {
    while true; do
        print_header "$(t submenu_users_title)"
        echo -e "  ${CYAN}1)${NC} $(t users_show_list)"
        echo -e "  ${CYAN}2)${NC} $(t users_show_links_action)"
        echo -e "  ${CYAN}3)${NC} $(t users_show_qr_action)"
        echo -e "  ${CYAN}4)${NC} $(t users_regen_links)"
        echo -e "  ${CYAN}0)${NC} $(t back)"
        echo ""

        local choice
        read -rp "  ▸ " choice || { echo ""; return; }
        case "$choice" in
            1) show_all_users_formatted ;;
            2)
                # All VLESS links as plain text (good for SSH copy-paste)
                regenerate_links_from_db 2>/dev/null
                if [ -s /tmp/govless_links.json ]; then
                    python3 -c "
import json
d = json.load(open('/tmp/govless_links.json'))
for name, link in d.items():
    print(f'{name}:')
    print(f'  {link}')
    print()
"
                else
                    log_warning "$(t users_no_links)"
                fi
                ;;
            3)
                # Per-user QR: list users and let the operator PICK which one (loop to pick more).
                regenerate_links_from_db 2>/dev/null
                if [ ! -s /tmp/govless_links.json ]; then
                    log_warning "$(t users_no_links)"
                else
                    local -a _qnames=()
                    while IFS= read -r _qn; do [ -n "$_qn" ] && _qnames+=("$_qn"); done < <(python3 -c "import json;[print(k) for k in json.load(open('/tmp/govless_links.json')).keys()]" 2>/dev/null)
                    if [ ${#_qnames[@]} -eq 0 ]; then
                        log_warning "$(t users_no_links)"
                    else
                        while true; do
                            echo ""
                            echo -e "  ${BOLD}$(t users_pick_qr)${NC}"
                            local _qi=1 _qn
                            for _qn in "${_qnames[@]}"; do echo -e "    ${CYAN}${_qi})${NC} ${_qn}"; _qi=$((_qi+1)); done
                            echo -e "    ${CYAN}0)${NC} $(t back)"
                            local _qp; read -rp "  ▸ " _qp </dev/tty
                            [ "$_qp" = "0" ] && break
                            if [[ "$_qp" =~ ^[0-9]+$ ]] && [ "$_qp" -ge 1 ] && [ "$_qp" -le "${#_qnames[@]}" ]; then
                                local _qsel="${_qnames[$((_qp-1))]}" _qlink _qsub=""
                                _qlink=$(python3 -c "import json,sys; print(json.load(open('/tmp/govless_links.json')).get(sys.argv[1],''))" "$_qsel" 2>/dev/null)
                                [ -s /tmp/govless_subs.json ] && _qsub=$(python3 -c "import json,sys; print(json.load(open('/tmp/govless_subs.json')).get(sys.argv[1],''))" "$_qsel" 2>/dev/null)
                                show_user_link_choice "$_qsel" "$_qlink" "$_qsub"
                            else
                                log_warning "$(t invalid_choice)"
                            fi
                        done
                    fi
                fi
                ;;
            4)
                regenerate_links_from_db && log_success "$(t users_links_regen_ok)"
                ;;
            0) return ;;
            *)
                log_warning "$(t invalid_choice)"
                sleep 1
                continue
                ;;
        esac
        echo -ne "  $(t press_enter_return) "
        read -r
    done
}

# ── Submenu: Manage ─────────────────────────────────────────────────────
submenu_manage() {
    while true; do
        print_header "$(t submenu_manage_title)"
        echo -e "  ${CYAN}1)${NC} $(t manage_language)"
        echo -e "  ${CYAN}2)${NC} $(t proxy_restart)"
        echo -e "  ${CYAN}3)${NC} $(t manage_repair)"
        echo -e "  ${CYAN}4)${NC} $(t manage_backup)"
        echo -e "  ${CYAN}5)${NC} $(t manage_restore)"
        echo -e "  ${CYAN}6)${NC} $(t manage_remove)"
        echo -e "  ${CYAN}0)${NC} $(t back)"
        echo ""

        local choice
        read -rp "  ▸ " choice || { echo ""; return; }
        case "$choice" in
            1)
                local new_lang
                new_lang=$(pick_language_interactive)
                load_language "$new_lang"
                save_language "$new_lang"
                ;;
            2) restart_xui ;;
            3) repair_user_facing ;;
            4) backup_govless ;;
            5)
                # Pick the most recent backup interactively
                local pick
                local -a backups
                if [ -d /root/govless-backups ]; then
                    while IFS= read -r f; do backups+=("$f"); done < <(ls -t /root/govless-backups/govless-*.tgz 2>/dev/null)
                fi
                if [ ${#backups[@]} -eq 0 ]; then
                    log_warning "$(t backup_no_files)"
                else
                    echo "  $(t restore_pick):"
                    local i=1
                    for b in "${backups[@]}"; do
                        echo "    ${CYAN}${i})${NC} $(basename "$b")"
                        i=$((i+1))
                    done
                    read -rp "  ▸ " pick
                    if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#backups[@]}" ]; then
                        restore_govless "${backups[$((pick-1))]}"
                    else
                        log_warning "$(t invalid_choice)"
                    fi
                fi
                ;;
            6) submenu_remove ;;
            0) return ;;
            *)
                log_warning "$(t invalid_choice)"
                sleep 1
                continue
                ;;
        esac
        echo -ne "  $(t press_enter_return) "
        read -r
    done
}

# ── Submenu: Remove (NEW — granular: site / panel / everything) ─────────
submenu_remove() {
    while true; do
        print_header "$(t submenu_remove_title)"
        echo -e "  ${CYAN}1)${NC} $(t remove_only_site)"
        echo -e "  ${CYAN}2)${NC} $(t remove_only_panel)"
        echo -e "  ${CYAN}3)${NC} ${RED}${BOLD}$(t remove_everything)${NC}"
        echo -e "  ${CYAN}0)${NC} $(t back)"
        echo ""

        local choice
        read -rp "  ▸ " choice || { echo ""; return; }
        case "$choice" in
            1)
                if typed_confirm "DELETE SITE" "$(t remove_confirm_site)"; then
                    remove_site_only
                fi
                ;;
            2)
                if typed_confirm "DELETE PANEL" "$(t remove_confirm_panel)"; then
                    remove_panel_only
                fi
                ;;
            3)
                if typed_confirm "DELETE EVERYTHING" "$(t remove_confirm_all)"; then
                    remove_everything
                    # After full nuke, exiting is the only sane next step
                    echo ""
                    echo -e "  $(t bye)"
                    exit 0
                fi
                ;;
            0) return ;;
            *)
                log_warning "$(t invalid_choice)"
                sleep 1
                continue
                ;;
        esac
        echo -ne "  $(t press_enter_return) "
        read -r
    done
}

# ── Submenu: About ──────────────────────────────────────────────────────
submenu_about() {
    print_header "$(t submenu_about_title)"
    echo -e "  goVLESS:    v${GOVLESS_VERSION}"
    echo -e "  Engine:     3X-UI + Xray-core"
    echo -e "  Protocol:   VLESS + XTLS-Vision"
    echo -e "  Security:   Reality / TLS"
    echo -e "  Author:     anten-ka"
    echo -e "  GitHub:     github.com/anten-ka"
    echo -e "  YouTube:    youtube.com/@anten-ka"
    show_credits
    # Disclaimer (info-only, no gate — operator can re-read anytime)
    show_disclaimer
    echo -ne "  $(t press_enter_return) "
    read -r
}

# ═══════════════════════════════════════════════════════════════════════
# MODE SELECTION
# ═══════════════════════════════════════════════════════════════════════

# ── Foreign 3X-UI detected (panel exists, but NOT a goVLESS install) ─────
# Shown on first run when x-ui is already present. Returns 0 ONLY when the user
# chose to delete the panel (caller then proceeds with a clean install); returns
# 1 for show-access / reset / exit (installer stops).
_foreign_backup_and_remove() {
    local ru="${1:-0}" ts bdir bfile
    ts=$(date +%Y%m%dT%H%M%SZ); bdir="/root/govless-backups"; mkdir -p "$bdir"
    bfile="${bdir}/foreign-xui-${ts}.tgz"
    [ "$ru" -eq 1 ] && log_step "Бэкап текущей панели…" || log_step "Backing up current panel…"
    # Checkpoint WAL so the tar captures a complete DB (not a 4KB stub), then
    # REQUIRE a non-empty archive before deleting anything.
    [ -f "$XUI_DB" ] && command -v sqlite3 >/dev/null 2>&1 && sqlite3 "$XUI_DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1
    if tar czf "$bfile" /etc/x-ui 2>/dev/null && [ -s "$bfile" ]; then
        [ "$ru" -eq 1 ] && log_success "Бэкап: $bfile" || log_success "Backup: $bfile"
    else
        [ "$ru" -eq 1 ] && log_error "Бэкап не удался — удаление ОТМЕНЕНО." || log_error "Backup failed — removal ABORTED."
        return 1
    fi
    [ "$ru" -eq 1 ] && log_step "Удаляю 3X-UI…" || log_step "Removing 3X-UI…"
    systemctl stop "$XUI_SERVICE" 2>/dev/null
    systemctl disable "$XUI_SERVICE" 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service /usr/bin/x-ui /usr/local/bin/x-ui 2>/dev/null
    rm -rf "$XUI_DIR" /etc/x-ui 2>/dev/null
    systemctl daemon-reload 2>/dev/null
    pkill -9 -f xray 2>/dev/null
    [ "$ru" -eq 1 ] && log_success "Панель удалена — приступаю к установке goVLESS." || log_success "Panel removed — starting goVLESS install."
    sleep 1
}

handle_foreign_panel() {
    set +e
    local ru=0; [ "${LANG_CODE:-en}" = "ru" ] && ru=1
    local ip; ip=$(get_server_ip 2>/dev/null)
    while true; do
        local port path cert proto user url
        port=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null | head -1)
        path=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null | head -1)
        cert=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='webCertFile';" 2>/dev/null | head -1)
        user=$(sqlite3 "$XUI_DB" "SELECT username FROM users LIMIT 1;" 2>/dev/null | head -1)
        # These come from a FOREIGN db — strip anything but safe chars so a crafted
        # value can't inject ANSI/escape sequences into the terminal.
        port=$(printf '%s' "$port" | tr -cd '0-9')
        path=$(printf '%s' "$path" | tr -cd 'A-Za-z0-9/._-')
        user=$(printf '%s' "$user" | tr -cd 'A-Za-z0-9._@-')
        [ -n "$cert" ] && proto="https" || proto="http"
        [ -z "$port" ] && port="2053"
        url="${proto}://${ip}:${port}${path}"

        if [ "$ru" -eq 1 ]; then
            print_header "Обнаружена панель 3X-UI"
            echo -e "  ${YELLOW}${BOLD}На сервере уже установлена панель 3X-UI.${NC}"
            echo -e "  ${DIM}Чтобы её не повредить, goVLESS поверх не устанавливается.${NC}"
            echo ""
            echo -e "  ${BOLD}Адрес панели:${NC} ${CYAN}${url}${NC}"
            [ -n "$user" ] && echo -e "  ${BOLD}Логин:${NC} ${CYAN}${user}${NC}"
            echo ""
            echo -e "  ${CYAN}1)${NC} Показать, как зайти в панель"
            echo -e "  ${CYAN}2)${NC} Сбросить логин/пароль и показать доступы"
            echo -e "  ${CYAN}3)${NC} ${RED}${BOLD}Удалить панель${NC} и установить goVLESS"
            echo -e "  ${CYAN}4)${NC} Ничего не делать и выйти"
        else
            print_header "3X-UI panel detected"
            echo -e "  ${YELLOW}${BOLD}A 3X-UI panel is already installed on this server.${NC}"
            echo -e "  ${DIM}To avoid breaking it, goVLESS will not install on top.${NC}"
            echo ""
            echo -e "  ${BOLD}Panel URL:${NC} ${CYAN}${url}${NC}"
            [ -n "$user" ] && echo -e "  ${BOLD}Username:${NC} ${CYAN}${user}${NC}"
            echo ""
            echo -e "  ${CYAN}1)${NC} Show how to open the panel"
            echo -e "  ${CYAN}2)${NC} Reset panel login/password and show access"
            echo -e "  ${CYAN}3)${NC} ${RED}${BOLD}Remove the panel${NC} and install goVLESS"
            echo -e "  ${CYAN}4)${NC} Do nothing and exit"
        fi
        echo ""
        local ch; echo -ne "  ▸ "; read -r ch || { echo ""; return 1; }
        case "$ch" in
            1)
                echo ""
                if [ "$ru" -eq 1 ]; then
                    echo -e "  ${BOLD}Откройте в браузере:${NC} ${CYAN}${url}${NC}"
                    [ -n "$user" ] && echo -e "  ${BOLD}Логин:${NC} ${CYAN}${user}${NC}"
                    echo -e "  ${DIM}Пароль goVLESS не знает — он хранится зашифрованным.${NC}"
                    echo -e "  ${DIM}Забыли пароль? Выберите пункт 2 (сброс).${NC}"
                    echo ""; echo -ne "  Нажмите Enter… "
                else
                    echo -e "  ${BOLD}Open in your browser:${NC} ${CYAN}${url}${NC}"
                    [ -n "$user" ] && echo -e "  ${BOLD}Username:${NC} ${CYAN}${user}${NC}"
                    echo -e "  ${DIM}goVLESS doesn't know the password — it's stored hashed.${NC}"
                    echo -e "  ${DIM}Forgot it? Choose option 2 (reset).${NC}"
                    echo ""; echo -ne "  Press Enter… "
                fi
                read -r
                ;;
            2)
                local nu np
                nu=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
                np=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 14)
                echo ""
                [ "$ru" -eq 1 ] && log_info "Сбрасываю логин и пароль…" || log_info "Resetting login and password…"
                if ! "$XUI_BIN" setting -username "$nu" -password "$np" >/dev/null 2>&1; then
                    echo ""; [ "$ru" -eq 1 ] && log_error "Не удалось сбросить — панель не приняла команду." || log_error "Reset failed — the panel rejected the command."
                    echo ""; echo -ne "  ↵ "; read -r; continue
                fi
                systemctl restart "$XUI_SERVICE" >/dev/null 2>&1
                sleep 1
                local _vu; _vu=$(sqlite3 "$XUI_DB" "SELECT username FROM users LIMIT 1;" 2>/dev/null | head -1)
                if [ "$_vu" != "$nu" ]; then
                    echo ""; [ "$ru" -eq 1 ] && log_error "Сброс не подтвердился — доступы НЕ изменены." || log_error "Reset not confirmed — credentials NOT changed."
                    echo ""; echo -ne "  ↵ "; read -r; continue
                fi
                echo ""
                if [ "$ru" -eq 1 ]; then
                    echo -e "  ${GREEN}${BOLD}Доступы к панели обновлены:${NC}"
                    echo -e "  ${BOLD}Адрес:${NC}  ${CYAN}${url}${NC}"
                    echo -e "  ${BOLD}Логин:${NC}  ${CYAN}${nu}${NC}"
                    echo -e "  ${BOLD}Пароль:${NC} ${CYAN}${np}${NC}"
                    echo -e "  ${DIM}Сохраните эти данные.${NC}"
                    echo ""; echo -ne "  Нажмите Enter… "
                else
                    echo -e "  ${GREEN}${BOLD}Panel access updated:${NC}"
                    echo -e "  ${BOLD}URL:${NC}      ${CYAN}${url}${NC}"
                    echo -e "  ${BOLD}Username:${NC} ${CYAN}${nu}${NC}"
                    echo -e "  ${BOLD}Password:${NC} ${CYAN}${np}${NC}"
                    echo -e "  ${DIM}Save these credentials.${NC}"
                    echo ""; echo -ne "  Press Enter… "
                fi
                read -r
                ;;
            3)
                local c1 c2
                echo ""
                if [ "$ru" -eq 1 ]; then
                    echo -e "  ${RED}${BOLD}⚠ Это удалит панель 3X-UI и ВСЕ её inbounds/ключи.${NC}"
                    echo -ne "  Удалить? 1) Да  2) Нет: "
                else
                    echo -e "  ${RED}${BOLD}⚠ This removes 3X-UI and ALL its inbounds/keys.${NC}"
                    echo -ne "  Remove? 1) Yes  2) No: "
                fi
                read -r c1
                [ "$c1" = "1" ] || continue
                if [ "$ru" -eq 1 ]; then
                    echo -ne "  Подтвердите — введите ${BOLD}УДАЛИТЬ${NC}: "
                else
                    echo -ne "  Confirm — type ${BOLD}DELETE${NC}: "
                fi
                read -r c2
                if { [ "$ru" -eq 1 ] && [ "$c2" = "УДАЛИТЬ" ]; } || { [ "$ru" -eq 0 ] && [ "$c2" = "DELETE" ]; }; then
                    if _foreign_backup_and_remove "$ru"; then
                        set -e
                        return 0
                    fi
                    echo ""; echo -ne "  ↵ "; read -r
                fi
                [ "$ru" -eq 1 ] && log_warning "Отменено." || log_warning "Cancelled."
                ;;
            4)
                echo -e "  $(t bye)"
                return 1
                ;;
            *)
                log_warning "$(t invalid_choice)"
                ;;
        esac
    done
}

select_and_install() {
    # Disclaimer gate — shown on first install; cached in $GOVLESS_DIR/.disclaimer-accepted
    show_disclaimer --gate || return 1

    while true; do
        print_header "$(t install_select_mode)"
        echo ""
        echo -e "  ${CYAN}1)${NC} ${BOLD}$(t install_lazy_title)${NC} ${DIM}🔒 Anten-ka Club${NC}"
        echo -e "     ${DIM}$(t install_lazy_desc1)${NC}"
        echo -e "     ${DIM}$(t install_lazy_desc2)${NC}"
        echo ""
        echo -e "  ${CYAN}2)${NC} ${BOLD}$(t install_pro_title)${NC} ${DIM}🔒 Anten-ka Club${NC}"
        echo -e "     ${DIM}$(t install_pro_desc1)${NC}"
        echo -e "     ${DIM}$(t install_pro_desc2)${NC}"
        echo -e "     ${DIM}$(t install_pro_desc3)${NC}"
        echo ""
        echo -e "  ${CYAN}3)${NC} ${BOLD}$(t install_lite_title)${NC}"
        echo -e "     ${DIM}$(t install_lite_desc1)${NC}"
        echo -e "     ${DIM}$(t install_lite_desc2)${NC}"
        echo -e "     ${DIM}$(t install_lite_desc3)${NC}"
        echo ""

        local mode_choice
        echo -ne "  $(t install_mode_choice) "
        read -r mode_choice || { echo ""; return 1; }

        case "$mode_choice" in
            1|2) show_club_gate ;;
            ""|3) install_lite; return 0 ;;
            *) log_error "$(t invalid_choice)"; sleep 1 ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════
main() {
    # `curl ... | bash` puts the SCRIPT on stdin, so interactive `read` prompts
    # hit EOF and every gate "declines" no matter what the user types. If stdin
    # isn't a TTY but a controlling terminal exists, reconnect stdin to it.
    # Detached/non-interactive runs (no /dev/tty) keep their piped stdin so
    # answer-ribbon automation still works.
    if [ ! -t 0 ] && [ -r /dev/tty ]; then exec < /dev/tty; fi
    init_language
    print_banner

    # Check disk space
    if ! check_disk_space 500; then
        local avail
        avail=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}')
        log_error "$(tf err_low_disk "${avail:-?}" "500")"
        exit 1
    fi

    # Preflight: verify + install all required packages once, up front, so a
    # missing tool can't surface as a confusing mid-install failure.
    if ! preflight_deps; then
        log_error "$(t preflight_abort)"
        exit 1
    fi

    # If already installed — show menu
    if is_xui_installed && [ -f "$GOVLESS_CONFIG" ]; then
        load_credentials
        setup_api_base
        # Interactive menu: handlers (restart/logs/backup/repair, empty user list, mode
        # switch) legitimately return non-zero; under `set -e` that would eject the
        # user from the menu to the shell. The install flow guards its own steps.
        set +e
        maybe_run_migrations
        main_menu
    else
        # First run. If a foreign 3X-UI panel is already here, offer the panel
        # gate (open / reset creds / remove+install / exit) instead of trying to
        # install on top (which cannot auto-configure someone else's panel).
        if is_xui_installed; then
            handle_foreign_panel || exit 0
        fi
        select_and_install
    fi
}

main "$@"
