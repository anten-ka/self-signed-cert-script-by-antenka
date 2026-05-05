#!/bin/bash
# XUIFAST v3.0.0 — Reality domain lists for Lite mode
# 50 RU domains + 50 international domains
# All domains must support TLSv1.3 + H2 for Reality to work

# ── Russian domains (popular sites accessible in Russia) ────────────────
RU_DOMAINS=(
    "yandex.ru"
    "vk.com"
    "mail.ru"
    "ok.ru"
    "dzen.ru"
    "ria.ru"
    "rbc.ru"
    "lenta.ru"
    "gazeta.ru"
    "tass.ru"
    "kommersant.ru"
    "habr.com"
    "pikabu.ru"
    "ozon.ru"
    "wildberries.ru"
    "avito.ru"
    "lamoda.ru"
    "dns-shop.ru"
    "mvideo.ru"
    "citilink.ru"
    "sberbank.ru"
    "tinkoff.ru"
    "vtb.ru"
    "gosuslugi.ru"
    "mos.ru"
    "nalog.gov.ru"
    "hh.ru"
    "superjob.ru"
    "kinopoisk.ru"
    "ivi.ru"
    "stepik.org"
    "geekbrains.ru"
    "skillbox.ru"
    "1c.ru"
    "kaspersky.ru"
    "ria.com"
    "sports.ru"
    "auto.ru"
    "cian.ru"
    "youla.ru"
    "2gis.ru"
    "yandex.cloud"
    "rutube.ru"
    "mts.ru"
    "megafon.ru"
    "beeline.ru"
    "tele2.ru"
    "pochta.ru"
    "rzd.ru"
    "aeroflot.ru"
)

# ── International domains (popular global sites) ────────────────────────
INT_DOMAINS=(
    "google.com"
    "microsoft.com"
    "apple.com"
    "amazon.com"
    "cloudflare.com"
    "github.com"
    "stackoverflow.com"
    "mozilla.org"
    "wikipedia.org"
    "medium.com"
    "notion.so"
    "figma.com"
    "canva.com"
    "slack.com"
    "zoom.us"
    "dropbox.com"
    "atlassian.com"
    "jetbrains.com"
    "docker.com"
    "gitlab.com"
    "npmjs.com"
    "pypi.org"
    "rust-lang.org"
    "golang.org"
    "swift.org"
    "yahoo.com"
    "bing.com"
    "duckduckgo.com"
    "brave.com"
    "samsung.com"
    "intel.com"
    "amd.com"
    "nvidia.com"
    "hp.com"
    "dell.com"
    "cisco.com"
    "oracle.com"
    "ibm.com"
    "salesforce.com"
    "shopify.com"
    "stripe.com"
    "paypal.com"
    "spotify.com"
    "netflix.com"
    "twitch.tv"
    "reddit.com"
    "pinterest.com"
    "linkedin.com"
    "coursera.org"
    "udemy.com"
)

# ── Domain validation for Reality ───────────────────────────────────────
# Reality requires the target domain to support TLSv1.3 and H2
test_reality_domain() {
    local domain="$1"
    local result

    # Check TLS 1.3 + H2 support
    result=$(echo | timeout 5 openssl s_client -connect "${domain}:443" \
        -tls1_3 -alpn h2 2>/dev/null)

    if echo "$result" | grep -q "TLSv1.3" && echo "$result" | grep -q "ALPN.*h2"; then
        return 0
    fi
    return 1
}

# ── Interactive domain picker ───────────────────────────────────────────
select_reality_domain() {
    local server_ip="${1:-}"
    local country

    # Detect geo
    if [ -n "$server_ip" ]; then
        country=$(get_ip_country "$server_ip")
    else
        country=$(get_ip_country)
    fi

    local domains=()
    local list_title=""

    if [ "$country" = "RU" ]; then
        domains=("${RU_DOMAINS[@]}")
        list_title="$(t lite_ru_domains)"
        log_info "$(tf lite_detected_geo "RU 🇷🇺")"
    else
        domains=("${INT_DOMAINS[@]}")
        list_title="$(t lite_int_domains)"
        log_info "$(tf lite_detected_geo "$country")"
    fi

    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t lite_select_domain)${NC}" >&2
    echo -e "  ${DIM}${list_title}${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2

    # Display in 2 columns
    local total=${#domains[@]}
    local i=1
    for d in "${domains[@]}"; do
        printf "  ${CYAN}%2d)${NC} %-28s" "$i" "$d" >&2
        if (( i % 2 == 0 )); then
            echo "" >&2
        fi
        ((i++)) || true
    done
    if (( (i-1) % 2 != 0 )); then echo "" >&2; fi

    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo -ne "  ${WHITE}$(t choose) (1-${total}):${NC} " >&2
    local choice
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
        local selected="${domains[$((choice-1))]}"

        # Test domain suitability
        log_info "$(tf lite_testing_domain "$selected")"
        if test_reality_domain "$selected"; then
            log_success "$(tf lite_domain_ok "$selected")"
            echo "$selected"
            return 0
        else
            log_warning "$(tf lite_domain_fail "$selected")"
            if confirm "$(t pro_continue_anyway)"; then
                echo "$selected"
                return 0
            fi
            return 1
        fi
    fi

    log_error "$(t invalid_choice)"
    return 1
}
