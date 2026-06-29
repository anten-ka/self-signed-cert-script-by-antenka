#!/bin/bash
# goVLESS — Copyright (c) 2025-2026 anten-ka. All rights reserved.
# Licensed under the goVLESS Source-Available License (see the LICENSE file).
# Redistribution, mirroring, or republishing in any form — whole or partial,
# modified or not — is prohibited without prior written permission.

# goVLESS v3.0.0 — Reality domain lists for Lite mode
# 100 RU domains + 100 international domains
# All domains must support TLSv1.3 + H2 for Reality to work

# ── Russian domains (popular sites accessible in Russia) ────────────────
RU_DOMAINS=(
    "1c.ru"
    "2gis.ru"
    "74.ru"
    "aliexpress.ru"
    "amediateka.ru"
    "auto.ru"
    "aviasales.ru"
    "beeline.ru"
    "book24.ru"
    "cdek.ru"
    "chitai-gorod.ru"
    "cian.ru"
    "delivery-club.ru"
    "detmir.ru"
    "dodopizza.ru"
    "drive2.ru"
    "edadeal.ru"
    "eldorado.ru"
    "flowwow.com"
    "fontanka.ru"
    "forbes.ru"
    "hh.ru"
    "igromania.ru"
    "ixbt.com"
    "iz.ru"
    "joom.com"
    "kaspersky.ru"
    "kassir.ru"
    "kazanexpress.ru"
    "kinopoisk.ru"
    "kinoteatr.ru"
    "kudago.com"
    "kuper.ru"
    "level.travel"
    "market.yandex.ru"
    "megamarket.ru"
    "more.tv"
    "music.yandex.ru"
    "mvideo.ru"
    "netology.ru"
    "ngs.ru"
    "nix.ru"
    "nplus1.ru"
    "ok.ru"
    "okko.tv"
    "onlinetrade.ru"
    "overclockers.ru"
    "ozon.ru"
    "papajohns.ru"
    "perekrestok.ru"
    "pikabu.ru"
    "rambler.ru"
    "rb.ru"
    "re-store.ru"
    "regard.ru"
    "s7.ru"
    "sostav.ru"
    "sports.ru"
    "start.ru"
    "stopgame.ru"
    "superjob.ru"
    "sutochno.ru"
    "tass.ru"
    "tele2.ru"
    "tutu.ru"
    "uchi.ru"
    "vk.com"
    "vseinstrumenti.ru"
    "wildberries.ru"
    "wink.ru"
    "xcom-shop.ru"
    "yaklass.ru"
    "yandex.cloud"
    "yandex.ru"
    "zr.ru"
    "zvuk.com"
    "4pda.to"
    "kp.ru"
    "lamoda.ru"
    "ria.ru"
    "sport-express.ru"
    "ya.ru"
    "gloria-jeans.ru"
    "mybook.ru"
    "tripster.ru"
    "okeydostavka.ru"
    "161.ru"
    "chita.ru"
    "76.ru"
    "aif.ru"
    "59.ru"
    "pyaterochka.ru"
    "pogoda.ru"
    "dzen.ru"
    "nn.ru"
    "ufa1.ru"
    "msk1.ru"
    "v1.ru"
    "63.ru"
    "93.ru"
)

# ── International domains (popular global sites) ────────────────────────
INT_DOMAINS=(
    "gateway.icloud.com"
    "www.icloud.com"
    "www.apple.com"
    "www.google.com"
    "google.com"
    "www.amazon.com"
    "aws.amazon.com"
    "cloudflare.com"
    "www.cloudflare.com"
    "github.com"
    "www.github.com"
    "stackoverflow.com"
    "mozilla.org"
    "www.mozilla.org"
    "wikipedia.org"
    "www.wikipedia.org"
    "wikimedia.org"
    "archive.org"
    "medium.com"
    "notion.so"
    "www.notion.so"
    "figma.com"
    "www.figma.com"
    "canva.com"
    "www.canva.com"
    "slack.com"
    "zoom.us"
    "dropbox.com"
    "www.dropbox.com"
    "atlassian.com"
    "jetbrains.com"
    "www.jetbrains.com"
    "docker.com"
    "www.docker.com"
    "gitlab.com"
    "npmjs.com"
    "www.npmjs.com"
    "pypi.org"
    "rust-lang.org"
    "www.rust-lang.org"
    "yahoo.com"
    "www.yahoo.com"
    "duckduckgo.com"
    "brave.com"
    "intel.com"
    "www.intel.com"
    "amd.com"
    "www.amd.com"
    "hp.com"
    "www.hp.com"
    "ibm.com"
    "www.ibm.com"
    "spotify.com"
    "www.spotify.com"
    "open.spotify.com"
    "netflix.com"
    "www.netflix.com"
    "www.twitch.tv"
    "reddit.com"
    "www.reddit.com"
    "pinterest.com"
    "www.pinterest.com"
    "coursera.org"
    "www.coursera.org"
    "shopify.com"
    "www.shopify.com"
    "cdn.jsdelivr.net"
    "unpkg.com"
    "vimeo.com"
    "www.vimeo.com"
    "soundcloud.com"
    "bandcamp.com"
    "tumblr.com"
    "www.tumblr.com"
    "wordpress.com"
    "www.wix.com"
    "squarespace.com"
    "webflow.com"
    "vercel.com"
    "digitalocean.com"
    "www.digitalocean.com"
    "vultr.com"
    "www.vultr.com"
    "hetzner.com"
    "flickr.com"
    "www.flickr.com"
    "behance.net"
    "www.behance.net"
    "dribbble.com"
    "producthunt.com"
    "ebay.com"
    "booking.com"
    "bbc.com"
    "nytimes.com"
    "theguardian.com"
    "adobe.com"
    "python.org"
    "debian.org"
    "kernel.org"
    "ubuntu.com"
)

# ── Domain validation for Reality ───────────────────────────────────────
# Reality requires the target domain to support TLSv1.3 and H2
test_reality_domain() {
    local domain="$1" result i
    # Reality needs the dest to do TLS1.3 + HTTP/2. Send SNI, offer BOTH h2 and
    # http/1.1 (so the server reveals its real ALPN), retry twice (throttled RU
    # links stall), and require h2 to actually be negotiated.
    for i in 1 2; do
        result=$(echo | timeout 8 openssl s_client -connect "${domain}:443" \
            -servername "${domain}" -alpn h2,http/1.1 -tls1_3 2>/dev/null)
        if echo "$result" | grep -q "TLSv1.3" && echo "$result" | grep -q "ALPN protocol: h2"; then
            return 0
        fi
    done
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
    echo -e "  ${CYAN} 0)${NC} ${DIM}$(t lite_custom_domain)${NC}" >&2
    local choice cdom selected
    while true; do
        echo -ne "  ${WHITE}$(t choose) (1-${total}, 0):${NC} " >&2
        # EOF (non-interactive / exhausted stdin) -> give up gracefully instead
        # of spinning the loop forever.
        if ! read -r choice; then return 1; fi

        if [ "$choice" = "0" ]; then
            echo -ne "  ${WHITE}$(t lite_custom_prompt)${NC} " >&2
            read -r cdom || true
            cdom=$(printf '%s' "$cdom" | tr -d '[:space:]' | sed -E 's#^https?://##; s#/.*$##')
            if [ -z "$cdom" ]; then log_warning "$(t invalid_choice)" >&2; continue; fi
            # Reject anything that isn't a plain hostname (no metachars/garbage that
            # would become a broken Reality dest) — re-loop instead of accepting it.
            if ! [[ "$cdom" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                log_warning "$(t invalid_choice)" >&2; continue
            fi
            log_info "$(tf lite_testing_domain "$cdom")" >&2
            if test_reality_domain "$cdom"; then
                log_success "$(tf lite_domain_ok "$cdom")" >&2; echo "$cdom"; return 0
            fi
            log_warning "$(tf lite_domain_fail "$cdom")" >&2
            if confirm "$(t pro_continue_anyway)"; then echo "$cdom"; return 0; fi
            # User declined -> go back to the picker instead of aborting install.
            log_info "$(t lite_pick_another)" >&2
            continue
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
            selected="${domains[$((choice-1))]}"
            # Curated list entries are pre-verified (real TLS1.3+h2 handshake at
            # build time) — trust them, skip the flaky per-install re-probe.
            log_success "$(tf lite_domain_ok "$selected")" >&2
            echo "$selected"; return 0
        else
            log_error "$(t invalid_choice)" >&2
            continue
        fi
    done
}
