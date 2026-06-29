#!/bin/bash
# goVLESS — Copyright (c) 2025-2026 anten-ka. All rights reserved.
# Licensed under the goVLESS Source-Available License (see the LICENSE file).
# Redistribution, mirroring, or republishing in any form — whole or partial,
# modified or not — is prohibited without prior written permission.

# goVLESS v3.0.0 — 3X-UI REST API, inbound creation, user management
# Handles: API login, panel settings, VLESS inbound (Reality/TLS),
#          user creation, VLESS link generation, QR codes, online check

API_BASE=""  # set after credentials loaded

# ── Random name generator ───────────────────────────────────────────────
ADJECTIVES=(
    swift brave noble lunar solar clever silent shadow bright cosmic
    frost storm rapid steel coral amber azure ivory pearl velvet
    crystal golden silver arctic polar prism radiant serene vivid calm
    gentle mystic nimble omega prime ultra zenith echo delta sigma
    alpha brave cedar drift eagle forge ghost haven iris jade
    karma lotus maple nexus oasis pine quartz river stone terra
    unity valor willow xenon yarn zephyr atlas blaze crest dawn
    ember flame grove halo inlet jetty knoll lagoon marsh nova
    onyx plume quest ridge summit tide umbra vista wren apex
    birch cedar dusk ember fern grove haze inlet jade kelp
    larch mist nook opal plume quill ridge sage thorn ursa
    vapor weald xerus yew zinc alder brook clove dune elm
)

ANIMALS=(
    fox wolf bear hawk lynx deer hare pike bass carp
    owl ram elk yak puma crane robin finch swift raven
    eagle shark whale cobra viper gecko newt toad frog ibis
    lark wren dingo bison koala panda lemur otter stoat marten
    brant crane egret heron stork grebe diver murre shrike jay
    falcon osprey condor marmot ferret badger skunk moose reindeer bongo
    okapi genet civet camel llama tapir sloth coati kiwi tucan
    macaw quail pheasant parrot myna starling pipit wagtail oriole cedar
    tiger jaguar ocelot margay cheetah serval caracal bobcat cougar lion
    hyena jackal dhole coyote fennec mink sable ermine fisher weasel
)

generate_random_name() {
    local adj="${ADJECTIVES[$((RANDOM % ${#ADJECTIVES[@]}))]}"
    local animal="${ANIMALS[$((RANDOM % ${#ANIMALS[@]}))]}"
    echo "${adj}-${animal}"
}

# ── CSRF token (3X-UI v3.x) ────────────────────────────────────────────
API_CSRF_TOKEN=""

# Build curl args array with CSRF header if token is set
# Usage: local csrf_args=(); _csrf_args csrf_args; curl ... "${csrf_args[@]}"
_csrf_args() {
    local _varname=$1
    if [ -n "$API_CSRF_TOKEN" ]; then
        eval "$_varname=(-H \"X-CSRF-Token: \${API_CSRF_TOKEN}\")"
    else
        eval "$_varname=()"
    fi
}

# ── Setup API base URL ──────────────────────────────────────────────────
setup_api_base() {
    local base_path="${XUI_WEB_PATH%/}"
    # 3X-UI panel runs HTTP by default (no built-in TLS unless configured)
    # Try HTTPS first (in case panel has TLS enabled), fall back to HTTP
    local code
    code=$(curl -sk -o /dev/null -w '%{http_code}' \
        "https://127.0.0.1:${XUI_PORT}${base_path}/" 2>/dev/null) || true
    if [ "$code" != "000" ] && [ "$code" != "" ]; then
        API_BASE="https://127.0.0.1:${XUI_PORT}${base_path}"
    else
        API_BASE="http://127.0.0.1:${XUI_PORT}${base_path}"
    fi
}

# ── Wait for API to become available ────────────────────────────────────
wait_for_api() {
    local timeout="${1:-60}"
    local elapsed=0
    local base_path="${XUI_WEB_PATH%/}"

    while [ "$elapsed" -lt "$timeout" ]; do
        # Try both HTTPS and HTTP — panel protocol depends on config
        for proto in https http; do
            local code
            code=$(curl -sk -o /dev/null -w '%{http_code}' \
                "${proto}://127.0.0.1:${XUI_PORT}${base_path}/" 2>/dev/null) || true
            if [ "$code" = "200" ]; then
                API_BASE="${proto}://127.0.0.1:${XUI_PORT}${base_path}"
                return 0
            fi
        done
        sleep 2
        elapsed=$((elapsed + 2))
    done
    # Final attempt to set API_BASE even on timeout
    setup_api_base
    log_error "$(t api_waiting) — timeout ${timeout}s"
    return 1
}

# ── API login (cookie-based) ────────────────────────────────────────────
api_login() {
    local cookie_file="${1:-/tmp/govless_cookie.txt}"

    # 3X-UI v3.x requires CSRF token from the HTML page for POST requests
    # Step 1: GET the panel page to obtain session cookie and CSRF token
    local html
    html=$(curl -sk -c "$cookie_file" "${API_BASE}/" 2>/dev/null) || true
    API_CSRF_TOKEN=$(echo "$html" | grep -o 'csrf-token" content="[^"]*' | sed 's/csrf-token" content="//' 2>/dev/null) || true

    # Step 2: POST login with session cookie and CSRF token
    local http_code
    local csrf_args=(); _csrf_args csrf_args
    http_code=$(curl -sk -w '%{http_code}' -o /tmp/govless_login_resp.json \
        -b "$cookie_file" -c "$cookie_file" \
        "${csrf_args[@]}" \
        "${API_BASE}/login" \
        --data-urlencode "username=${XUI_USER}" \
        --data-urlencode "password=${XUI_PASS}" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        # 3X-UI returns 200 even on wrong creds — check JSON success field
        local success
        success=$(python3 -c "import json; d=json.load(open('/tmp/govless_login_resp.json')); print(d.get('success', False))" 2>/dev/null || echo "False")
        if [ "$success" = "True" ]; then
            # Refresh CSRF token from the login response cookies (may have rotated)
            local post_html
            post_html=$(curl -sk -b "$cookie_file" "${API_BASE}/" 2>/dev/null)
            local new_token
            new_token=$(echo "$post_html" | grep -o 'csrf-token" content="[^"]*' | sed 's/csrf-token" content="//' 2>/dev/null) || true
            [ -n "$new_token" ] && API_CSRF_TOKEN="$new_token"
            log_success "$(t api_login_ok)"
            return 0
        else
            log_error "$(t api_login_fail) — wrong credentials"
            return 1
        fi
    else
        log_error "$(t api_login_fail) (HTTP $http_code)"
        return 1
    fi
}

# ── API login with retry ───────────────────────────────────────────────
api_login_with_retry() {
    local cookie_file="${1:-/tmp/govless_cookie.txt}"
    local attempts="${2:-3}"

    for i in $(seq 1 "$attempts"); do
        if api_login "$cookie_file"; then
            return 0
        fi
        [ "$i" -lt "$attempts" ] && sleep 3
    done
    return 1
}

# api_set_language() — REMOVED.
# Used to POST a partial settings update (only webLang) to /panel/setting/update.
# x-ui v3.x treats missing fields as defaults, which triggered the webPort=0
# validation failure (audit 002 B3). webLang is now set via direct sqlite
# UPDATE in configure_panel_tls (lib/xui.sh). DO NOT reintroduce a partial
# POST to /panel/setting/update — always write the full settings payload
# or use sqlite directly.


# ── Create VLESS Reality inbound (Lite mode) ────────────────────────────
# Supports transports: tcp, xhttp, grpc (via XUI_TRANSPORT global)
api_create_reality_inbound() {
    local mask_domain="$1"
    local cookie_file="${2:-/tmp/govless_cookie.txt}"
    local transport="${XUI_TRANSPORT:-tcp}"

    log_info "$(t api_creating_inbound)"

    # Validate prerequisites
    [ -f /tmp/govless_clients.json ] || { log_error "Clients file not found"; return 1; }
    [ -n "$REALITY_PRIVATE_KEY" ] || { log_error "Reality private key not set"; return 1; }
    [ -n "$REALITY_PUBLIC_KEY" ] || { log_error "Reality public key not set"; return 1; }

    # Build the payload using Python (injection-safe)
    if ! python3 - "$mask_domain" "$REALITY_PRIVATE_KEY" "$REALITY_PUBLIC_KEY" "$transport" "${XUI_FP:-chrome}" << 'PYEOF'
import json, sys

mask_domain = sys.argv[1]
private_key = sys.argv[2]
public_key = sys.argv[3]
transport = sys.argv[4]
fp = sys.argv[5] if len(sys.argv) > 5 else "chrome"

with open('/tmp/govless_clients.json') as f:
    clients = json.load(f)

# Generate short IDs
import secrets
short_ids = [secrets.token_hex(8) for _ in range(4)]

settings = json.dumps({
    "clients": clients,
    "decryption": "none",
    "fallbacks": []
})

# Build transport-specific stream settings
stream = {
    "network": transport,
    "security": "reality",
    "externalProxy": [],
    "realitySettings": {
        "show": False,
        "xver": 0,
        "dest": f"{mask_domain}:443",
        "serverNames": [mask_domain, f"www.{mask_domain}"],
        "privateKey": private_key,
        "minClient": "",
        "maxClient": "",
        "maxTimediff": 0,
        "shortIds": short_ids,
        "settings": {
            "publicKey": public_key,
            "fingerprint": fp,
            "serverName": "",
            "spiderX": "/"
        }
    }
}

if transport == "tcp":
    stream["tcpSettings"] = {
        "acceptProxyProtocol": False,
        "header": {"type": "none"}
    }
elif transport == "xhttp":
    stream["xhttpSettings"] = {
        "path": "/",
        "host": "",
        "mode": "auto"
    }
elif transport == "grpc":
    stream["grpcSettings"] = {
        "serviceName": "govless",
        "multiMode": True
    }

stream_settings = json.dumps(stream)

sniffing = json.dumps({
    "enabled": True,
    "destOverride": ["http", "tls"],
    "metadataOnly": False,
    "routeOnly": True
})

payload = {
    "up": 0,
    "down": 0,
    "total": 0,
    "remark": f"govless-vless-reality-{transport}",
    "enable": True,
    "expiryTime": 0,
    "listen": "",
    "port": 443,
    "protocol": "vless",
    "settings": settings,
    "streamSettings": stream_settings,
    "sniffing": sniffing,
    "allocate": json.dumps({"strategy": "always", "refresh": 5, "concurrency": 3})
}

with open('/tmp/govless_payload.json', 'w') as f:
    json.dump(payload, f)
PYEOF
    then
        log_error "Failed to build Reality payload"
        return 1
    fi

    # Send the request
    local http_code
    local csrf_args=(); _csrf_args csrf_args
    http_code=$(curl -sk -w '%{http_code}' -o /tmp/govless_api_resp.json \
        -b "$cookie_file" \
        "${csrf_args[@]}" \
        -X POST "${API_BASE}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/govless_payload.json 2>/dev/null)

    local success
    success=$(python3 -c "import json; d=json.load(open('/tmp/govless_api_resp.json')); print(d.get('success', False))" 2>/dev/null || echo "False")

    if [ "$success" = "True" ]; then
        log_success "$(t api_inbound_created)"
        return 0
    else
        local msg
        msg=$(python3 -c "import json; d=json.load(open('/tmp/govless_api_resp.json')); print(d.get('msg', 'unknown'))" 2>/dev/null || echo "HTTP $http_code")
        log_error "$(t api_inbound_failed): $msg"
        return 1
    fi
}

# ── Create VLESS TLS inbound (Pro mode) ─────────────────────────────────
api_create_tls_inbound() {
    local domain="$1"           # e.g. "example.com"
    local cert_file="$2"        # /etc/letsencrypt/live/$domain/fullchain.pem
    local key_file="$3"         # /etc/letsencrypt/live/$domain/privkey.pem
    local cookie_file="${4:-/tmp/govless_cookie.txt}"

    log_info "$(t api_creating_inbound)"

    # Validate prerequisites
    [ -f /tmp/govless_clients.json ] || { log_error "Clients file not found"; return 1; }

    local transport="${XUI_TRANSPORT:-tcp}"
    if ! python3 - "$domain" "$cert_file" "$key_file" "$transport" "${XUI_FP:-chrome}" << 'PYEOF'
import json, sys

domain = sys.argv[1]
cert_file = sys.argv[2]
key_file = sys.argv[3]
transport = sys.argv[4]
fp = sys.argv[5] if len(sys.argv) > 5 else "chrome"

with open('/tmp/govless_clients.json') as f:
    clients = json.load(f)

settings = json.dumps({
    "clients": clients,
    "decryption": "none",
    "fallbacks": [{"dest": 80}]
})

stream = {
    "network": transport,
    "security": "tls",
    "externalProxy": [],
    "tlsSettings": {
        "serverName": domain,
        "minVersion": "1.2",
        "maxVersion": "1.3",
        "cipherSuites": "",
        "rejectUnknownSni": True,
        "disableSystemRoot": False,
        "enableSessionResumption": False,
        "certificates": [{
            "certificateFile": cert_file,
            "keyFile": key_file,
            "ocspStapling": 3600,
            "oneTimeLoading": False,
            "usage": "encipherment",
            "buildChain": False
        }],
        "settings": {
            "allowInsecure": False,
            "fingerprint": fp
        }
    },
}

# Transport-specific stream settings + ALPN (XHTTP/gRPC require h2)
if transport == "tcp":
    stream["tlsSettings"]["alpn"] = ["http/1.1"]
    stream["tcpSettings"] = {"acceptProxyProtocol": False, "header": {"type": "none"}}
elif transport == "xhttp":
    stream["tlsSettings"]["alpn"] = ["h2", "http/1.1"]
    stream["xhttpSettings"] = {"path": "/", "host": "", "mode": "auto"}
elif transport == "grpc":
    stream["tlsSettings"]["alpn"] = ["h2"]
    stream["grpcSettings"] = {"serviceName": "govless", "multiMode": True}

stream_settings = json.dumps(stream)

sniffing = json.dumps({
    "enabled": True,
    "destOverride": ["http", "tls"],
    "metadataOnly": False,
    "routeOnly": True
})

payload = {
    "up": 0,
    "down": 0,
    "total": 0,
    "remark": "govless-vless-tls",
    "enable": True,
    "expiryTime": 0,
    "listen": "",
    "port": 443,
    "protocol": "vless",
    "settings": settings,
    "streamSettings": stream_settings,
    "sniffing": sniffing,
    "allocate": json.dumps({"strategy": "always", "refresh": 5, "concurrency": 3})
}

with open('/tmp/govless_payload.json', 'w') as f:
    json.dump(payload, f)
PYEOF
    then
        log_error "Failed to build TLS payload"
        return 1
    fi

    local http_code
    local csrf_args=(); _csrf_args csrf_args
    http_code=$(curl -sk -w '%{http_code}' -o /tmp/govless_api_resp.json \
        -b "$cookie_file" \
        "${csrf_args[@]}" \
        -X POST "${API_BASE}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/govless_payload.json 2>/dev/null)

    local success
    success=$(python3 -c "import json; d=json.load(open('/tmp/govless_api_resp.json')); print(d.get('success', False))" 2>/dev/null || echo "False")

    if [ "$success" = "True" ]; then
        log_success "$(t api_inbound_created)"
        return 0
    else
        local msg
        msg=$(python3 -c "import json; d=json.load(open('/tmp/govless_api_resp.json')); print(d.get('msg', 'unknown'))" 2>/dev/null || echo "HTTP $http_code")
        log_error "$(t api_inbound_failed): $msg"
        return 1
    fi
}

# ── Generate clients JSON array ─────────────────────────────────────────
generate_clients() {
    local count="${1:-10}"
    local mode="${2:-lite}"     # lite (Reality) or pro (TLS)
    local names=()
    local used_names=""

    # Generate unique names
    declare -A seen_names
    while [ ${#names[@]} -lt "$count" ]; do
        local name
        name=$(generate_random_name)
        if [ -z "${seen_names[$name]+x}" ]; then
            names+=("$name")
            seen_names[$name]=1
        fi
    done
    unset seen_names

    # Build JSON array with Python
    # flow=xtls-rprx-vision only works with TCP; must be empty for gRPC/XHTTP
    local transport="${XUI_TRANSPORT:-tcp}"
    local flow="xtls-rprx-vision"
    if [ "$transport" != "tcp" ]; then
        flow=""
    fi

    if ! python3 - "$mode" "$flow" "${names[@]}" << 'PYEOF'
import json, sys, uuid

mode = sys.argv[1]
flow = sys.argv[2]
names = sys.argv[3:]

clients = []
for name in names:
    client_id = str(uuid.uuid4())
    client = {
        "id": client_id,
        "alterId": 0,
        "email": name,
        "limitIp": 0,
        "totalGB": 0,
        "expiryTime": 0,
        "enable": True,
        "tgId": "",
        "subId": client_id,
        "comment": f"goVLESS user {name}",
        "reset": 0
    }
    # Reality: flow = xtls-rprx-vision; TLS: also xtls-rprx-vision
    client["flow"] = flow
    clients.append(client)

with open('/tmp/govless_clients.json', 'w') as f:
    json.dump(clients, f)

# Also save name→uuid mapping for VLESS link generation
mapping = {c["email"]: c["id"] for c in clients}
with open('/tmp/govless_users_map.json', 'w') as f:
    json.dump(mapping, f)
PYEOF
    then
        log_error "Failed to generate clients"
        return 1
    fi
}

# ── Generate VLESS link ─────────────────────────────────────────────────
generate_vless_link_reality() {
    local uuid="$1"
    local name="$2"
    local server_ip="$3"
    local mask_domain="$4"
    local public_key="$5"
    local short_id="$6"
    local transport="${7:-tcp}"

    local encoded_name
    encoded_name=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$name" 2>/dev/null || echo "$name")

    local params="encryption=none&type=${transport}&security=reality&pbk=${public_key}&fp=${XUI_FP:-chrome}&sni=${mask_domain}&sid=${short_id}&spx=%2F"
    if [ "$transport" = "tcp" ]; then
        params="${params}&flow=xtls-rprx-vision"
    elif [ "$transport" = "grpc" ]; then
        params="${params}&serviceName=govless&mode=multi"
    elif [ "$transport" = "xhttp" ]; then
        params="${params}&path=%2F&mode=auto"
    fi

    echo "vless://${uuid}@${server_ip}:443?${params}#${encoded_name}"
}

generate_vless_link_tls() {
    local uuid="$1"
    local name="$2"
    local domain="$3"
    local transport="${4:-${XUI_TRANSPORT:-tcp}}"

    local encoded_name
    encoded_name=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$name" 2>/dev/null || echo "$name")

    local params="encryption=none&type=${transport}&security=tls&sni=${domain}&fp=${XUI_FP:-chrome}"
    if [ "$transport" = "tcp" ]; then
        params="${params}&alpn=http%2F1.1&flow=xtls-rprx-vision"
    elif [ "$transport" = "grpc" ]; then
        params="${params}&alpn=h2&serviceName=govless&mode=multi"
    elif [ "$transport" = "xhttp" ]; then
        params="${params}&alpn=h2&path=%2F&mode=auto"
    fi

    echo "vless://${uuid}@${domain}:443?${params}#${encoded_name}"
}

# ── Generate all VLESS links and save ───────────────────────────────────
generate_all_vless_links() {
    local mode="$1"             # lite or pro
    local server="$2"           # IP (lite) or domain (pro)
    local mask_domain="${3:-}"   # only for lite mode

    if [ ! -f /tmp/govless_users_map.json ]; then
        log_error "User map not found"
        return 1
    fi

    # Get short_id from payload (for Reality)
    local short_id=""
    if [ "$mode" = "lite" ] && [ -f /tmp/govless_payload.json ]; then
        short_id=$(python3 -c "
import json
p = json.load(open('/tmp/govless_payload.json'))
ss = json.loads(p['streamSettings'])
sids = ss.get('realitySettings', {}).get('shortIds', [])
print(sids[0] if sids else '')
" 2>/dev/null || true)
    fi

    if [ "$mode" = "lite" ] && [ -z "$short_id" ]; then
        log_warning "Empty short_id — VLESS links may not work"
    fi

    # Generate links
    local transport="${XUI_TRANSPORT:-tcp}"
    if ! python3 - "$mode" "$server" "$mask_domain" "${REALITY_PUBLIC_KEY:-}" "$short_id" "$transport" "${XUI_FP:-chrome}" << 'PYEOF'
import json, sys
from urllib.parse import quote

mode = sys.argv[1]
server = sys.argv[2]
mask_domain = sys.argv[3]
public_key = sys.argv[4]
short_id = sys.argv[5]
transport = sys.argv[6]
fp = sys.argv[7] if len(sys.argv) > 7 else "chrome"

with open('/tmp/govless_users_map.json') as f:
    users = json.load(f)

links = {}
for name, uuid in users.items():
    enc_name = quote(name)
    if mode == "lite":
        # Base params
        params = f"encryption=none&type={transport}&security=reality"
        params += f"&pbk={public_key}&fp={fp}"
        params += f"&sni={mask_domain}&sid={short_id}"
        params += f"&spx=%2F"

        # Transport-specific params
        if transport == "tcp":
            params += "&flow=xtls-rprx-vision"
        elif transport == "grpc":
            params += "&serviceName=govless&mode=multi"
        elif transport == "xhttp":
            params += "&path=%2F&mode=auto"

        link = f"vless://{uuid}@{server}:443?{params}#{enc_name}"
    else:
        # Pro mode: VLESS+TLS over chosen transport
        params = f"encryption=none&type={transport}&security=tls&sni={server}&fp={fp}"
        if transport == "tcp":
            params += "&alpn=http%2F1.1&flow=xtls-rprx-vision"
        elif transport == "xhttp":
            # XHTTP requires h2 ALPN (http/1.1 can't multiplex)
            params += "&alpn=h2&path=%2F&mode=auto"
        elif transport == "grpc":
            params += "&alpn=h2&serviceName=govless&mode=multi"
        link = f"vless://{uuid}@{server}:443?{params}#{enc_name}"
    links[name] = link

with open('/tmp/govless_links.json', 'w') as f:
    json.dump(links, f, indent=2)
PYEOF
    then
        log_error "Failed to generate VLESS links"
        return 1
    fi

    log_success "VLESS links generated"
}

# ── Regenerate VLESS links from 3X-UI sqlite (source of truth) ─────────
# Reads /etc/x-ui/x-ui.db (first inbound) + config.json (mode, server, domain).
# Writes /tmp/govless_links.json + /tmp/govless_users_map.json on demand.
# Idempotent. Returns 0 on success, 1 if no inbound / no config / sqlite missing.
#
# This is THE single source of truth for client lists/links/QR/subscriptions.
# Menu/bot must call this before reading the cache. /tmp files are ephemeral
# scratch — survive only until next install or /tmp cleanup, and are
# regenerated on every menu read.
regenerate_links_from_db() {
    # CRITICAL: this function MUST either succeed (writing fresh
    # /tmp/govless_links.json + users_map.json) or remove any stale
    # files. Callers rely on absence-on-failure to know they have no
    # source-of-truth state — per Codex 016 P1 #3.
    local out_links=/tmp/govless_links.json
    local out_users=/tmp/govless_users_map.json
    local out_subs=/tmp/govless_subs.json
    local tmp_links tmp_users tmp_subs
    tmp_links=$(mktemp /tmp/govless_links.json.XXXXXX)
    tmp_users=$(mktemp /tmp/govless_users_map.json.XXXXXX)
    tmp_subs=$(mktemp /tmp/govless_subs.json.XXXXXX)

    _regen_fail() {
        rm -f "$tmp_links" "$tmp_users" "$tmp_subs"               "$out_links" "$out_users" "$out_subs" 2>/dev/null
        return 1
    }

    [ -f "$XUI_DB" ] || { _regen_fail; return 1; }
    command -v python3 >/dev/null 2>&1 || { _regen_fail; return 1; }
    command -v sqlite3 >/dev/null 2>&1 || { _regen_fail; return 1; }
    if declare -F ensure_client_subids >/dev/null 2>&1; then
        ensure_client_subids >/dev/null 2>&1 || true
    fi

    local mode server domain server_ip
    mode=$(config_get mode "lite")
    server_ip=$(config_get server_ip "")
    # If config says something unroutable (127.x / 10.x / 192.168.x), discard
    # it and re-resolve. This was the source of broken QR codes on first install.
    if [ -n "$server_ip" ] && ! _valid_ip "$server_ip"; then
        log_warning "Config has unroutable server_ip=${server_ip} — re-detecting"
        server_ip=""
    fi
    [ -z "$server_ip" ] && server_ip=$(get_server_ip 2>/dev/null) || true
    # If re-detect put valid IP, persist it so next call doesnt re-fetch
    if [ -n "$server_ip" ] && _valid_ip "$server_ip"; then
        config_set "server_ip" "$server_ip" 2>/dev/null || true
    fi
    domain=$(config_get domain "")
    if [ "$mode" = "pro" ] && [ -n "$domain" ]; then
        server="$domain"
    elif [ -n "$server_ip" ] && _valid_ip "$server_ip"; then
        server="$server_ip"
    else
        log_error "Cannot determine server address — no valid IP and no domain"
        _regen_fail
        return 1
    fi

    local sub_port sub_path
    sub_port=$(config_get sub_port "")
    sub_path=$(config_get sub_path "")
    if ! python3 - "$mode" "$server" "$XUI_DB" "$tmp_links" "$tmp_users" "$sub_port" "$sub_path" "$(config_get domain "")" "$tmp_subs" <<'PYREGEN'
import json, sys, sqlite3, urllib.parse

mode = sys.argv[1]
server = sys.argv[2]
db_path = sys.argv[3]
out_links = sys.argv[4]
out_users = sys.argv[5]
sub_port = sys.argv[6] if len(sys.argv) > 6 else ""
sub_path = sys.argv[7] if len(sys.argv) > 7 else ""
domain = sys.argv[8] if len(sys.argv) > 8 else ""
out_subs = sys.argv[9] if len(sys.argv) > 9 else ""

try:
    c = sqlite3.connect(db_path)
    c.execute("PRAGMA busy_timeout = 5000")
    rows = c.execute("SELECT id, settings, stream_settings, port, enable FROM inbounds ORDER BY id").fetchall()
except Exception:
    sys.exit(1)
if not rows:
    sys.exit(1)

quote = lambda x: urllib.parse.quote(str(x))
try:
    _cfg = json.load(open("/opt/govless/config.json"))
    fp = _cfg.get("fingerprint") or "chrome"
except Exception:
    fp = "chrome"
links = {}
users_map = {}
subs = {}

for row in rows:
    try:
        inb_id, settings_raw, stream_raw, port, enable = row
    except Exception as exc:
        # Malformed row — skip with warning rather than raw traceback
        print(f"regen: skipping malformed inbound row: {exc}", file=sys.stderr)
        continue
    if not enable:
        continue
    port = port or 443
    try:
        settings = json.loads(settings_raw)
        stream = json.loads(stream_raw)
    except Exception as exc:
        print(f"regen: inbound id={inb_id} has malformed settings/stream JSON, skipping ({exc})", file=sys.stderr)
        continue
    clients = settings.get("clients", [])
    if not clients:
        continue
    network = stream.get("network", "tcp")
    security = stream.get("security", "tls")

    if security == "reality":
        rs = stream.get("realitySettings", {})
        pbk = rs.get("settings", {}).get("publicKey", "") or rs.get("publicKey", "")
        sni_list = rs.get("serverNames") or [""]
        sni = sni_list[0] if sni_list else ""
        sid_list = rs.get("shortIds") or [""]
        sid = sid_list[0] if sid_list else ""
        common = f"security=reality&pbk={pbk}&fp={fp}&sni={sni}&sid={sid}&spx=%2F"
    elif security == "tls":
        ts = stream.get("tlsSettings", {})
        sni = ts.get("serverName", server)
        common = f"security=tls&sni={sni}&fp={fp}"
        # Read ALPN from DB (P2 #2)
        alpn_list = ts.get("alpn") or []
        if alpn_list:
            alpn_str = urllib.parse.quote(",".join(alpn_list), safe="")
            common += f"&alpn={alpn_str}"
    else:
        common = f"security={security}"

    for cli in clients:
        uuid = cli.get("id")
        if not uuid:
            continue
        name = cli.get("email") or f"user-{uuid[:8]}"
        # Avoid name collision across inbounds: prefix with inbound id
        key = name if name not in links else f"{name}#inb{inb_id}"
        enc_name = quote(key)
        # Read flow from DB (P2 #2)
        flow = cli.get("flow", "")

        params = f"encryption=none&type={network}&{common}"

        if network == "tcp":
            if flow:
                params += f"&flow={flow}"
        elif network == "xhttp":
            xs = stream.get("xhttpSettings", {})
            path_q = quote(xs.get("path", "/") or "/")
            m = xs.get("mode", "auto") or "auto"
            params += f"&path={path_q}&mode={m}"
        elif network == "grpc":
            gs = stream.get("grpcSettings", {})
            sn = gs.get("serviceName", "") or ""
            m = "multi" if gs.get("multiMode") else "single"
            params += f"&serviceName={sn}&mode={m}"

        vless_url = f"vless://{uuid}@{server}:{port}?{params}#{enc_name}"
        # Subscription URL (Pro/domain only). In Lite this is intentionally
        # disabled: HTTP subscriptions by IP are rejected by many clients.
        sub_url = ""
        if mode == "pro" and domain and sub_port and sub_path:
            sub_id = cli.get("subId") or ""
            if sub_id:
                clean_path = sub_path.strip("/")
                # configure_sub_server gives the Pro sub-server the domain cert.
                sub_url = f"https://{domain}:{sub_port}/{clean_path}/{sub_id}"

        # Backward-compat top-level shape (callers read d[name] directly)
        links[key] = vless_url
        users_map[key] = uuid
        # Sidecar: subscription URLs in a parallel dict
        if sub_url:
            subs[key] = sub_url

if not links:
    sys.exit(1)

with open(out_links, "w") as f:
    json.dump(links, f, indent=2)
with open(out_users, "w") as f:
    json.dump(users_map, f, indent=2)
# Subscription URLs file — present iff sub-server is configured
if subs and out_subs:
    with open(out_subs, "w") as f:
        json.dump(subs, f, indent=2)
PYREGEN
    then
        _regen_fail
        return 1
    fi
    # Atomic install: tmp → final. Either both files in place or none.
    mv -f "$tmp_links" "$out_links" || { _regen_fail; return 1; }
    mv -f "$tmp_users" "$out_users" || { _regen_fail; return 1; }
    # subs.json is optional — present iff Python actually wrote URLs.
    # If python skipped (no sub_port/sub_path), tmp_subs stays size 0 → drop.
    if [ -s "$tmp_subs" ]; then
        mv -f "$tmp_subs" "$out_subs" || { _regen_fail; return 1; }
    else
        rm -f "$tmp_subs" "$out_subs" 2>/dev/null
    fi
    return 0
}

# ── State DB schema (bindings + audit_log + capabilities) ──────────────
# Lives at /opt/govless/state.db (separate from x-ui.db which is 3X-UI's).
# WAL journaling + busy_timeout to coexist with bot/cron/SSH menu concurrent
# writers. Idempotent migration via CREATE TABLE IF NOT EXISTS.
#
# Tables:
#   govless_user_bindings — TG id ↔ x-ui client UUID mapping (Telegram bot
#     binds a Telegram user to a specific VLESS client). 014 Rule 5/8.
#   govless_audit         — every admin write through govlessctl. Retention
#     90 days, pruned by govless-audit-prune.timer. 014 Rule 5.
#   govless_capabilities  — cached results of 3X-UI feature probes. 014 Rule 4.
#   govless_meta          — schema version, install_at, last_audit_prune.
init_state_db() {
    local state_db="${GOVLESS_DIR}/state.db"
    mkdir -p "${GOVLESS_DIR}"
    command -v sqlite3 >/dev/null 2>&1 || return 1
    sqlite3 "$state_db" >/dev/null <<SQL
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS govless_user_bindings (
    telegram_id     TEXT NOT NULL,
    xui_client_uuid TEXT NOT NULL,
    label           TEXT,
    created_at      INTEGER DEFAULT (strftime('%s', 'now')),
    last_seen_at    INTEGER,
    PRIMARY KEY (telegram_id, xui_client_uuid)
);
CREATE INDEX IF NOT EXISTS idx_bindings_uuid ON govless_user_bindings(xui_client_uuid);

CREATE TABLE IF NOT EXISTS govless_audit (
    ts        INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    admin_tg  TEXT NOT NULL,
    action    TEXT NOT NULL,
    target    TEXT,
    before    TEXT,
    after     TEXT
);
CREATE INDEX IF NOT EXISTS idx_audit_ts ON govless_audit(ts DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action ON govless_audit(action);

CREATE TABLE IF NOT EXISTS govless_capabilities (
    probe_ts  INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    feature   TEXT NOT NULL UNIQUE,
    status    TEXT NOT NULL CHECK (status IN ('ok','absent','degraded','unknown')),
    details   TEXT
);

CREATE TABLE IF NOT EXISTS govless_meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);
INSERT OR IGNORE INTO govless_meta(key, value) VALUES ('schema_version', '2');
INSERT OR IGNORE INTO govless_meta(key, value) VALUES ('install_at', strftime('%s','now'));
SQL
    chmod 600 "$state_db" 2>/dev/null
    return 0
}


# ── Display credentials box ─────────────────────────────────────────────
show_credentials() {
    local ip
    ip=$(get_server_ip 2>/dev/null) || ip="localhost"

    # Pro mode: show the panel URL on the domain (matches the domain LE cert the
    # panel is served with) — consistent with save_credentials / the creds file.
    # Lite (or no domain yet) keeps the IP URL.
    local host="$ip"
    local _mode
    _mode=$(config_get mode "lite" 2>/dev/null) || _mode="lite"
    if [ "$_mode" = "pro" ]; then
        local _d
        _d=$(config_get domain 2>/dev/null || true)
        [ -n "$_d" ] && [ "$_d" != "null" ] && host="$_d"
    fi

    # Normalize trailing slash on web path — x-ui v3.x is strict about
    # /<base>/ routing (Codex 012 P3, completes B4 from 005).
    local web_path_norm="${XUI_WEB_PATH%/}/"
    local url="https://${host}:${XUI_PORT}${web_path_norm}"
    local line="${YELLOW}$(printf '═%.0s' {1..55})${NC}"

    echo ""
    echo -e "  ${line}"
    echo -e "  ${BOLD}$(t creds_title)${NC}"
    echo -e "  ${line}"
    echo -e "  $(t creds_user)  ${CYAN}${XUI_USER}${NC}"
    echo -e "  $(t creds_pass)  ${CYAN}${XUI_PASS}${NC}"
    echo -e "  $(t creds_url)   ${CYAN}${url}${NC}"

    # 3X-UI 3.x panel secret token (token-based access / 2-step login). Present
    # in the settings table when the panel generates it; show so the operator
    # knows it (some clients/integrations log in with this token).
    local panel_secret=""
    if command -v sqlite3 >/dev/null 2>&1 && [ -f "$XUI_DB" ]; then
        panel_secret=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='secret' LIMIT 1;" 2>/dev/null)
    fi
    if [ -n "$panel_secret" ]; then
        echo -e "  $(t creds_secret) ${CYAN}${panel_secret}${NC}"
        echo -e "  ${DIM}$(t creds_secret_hint)${NC}"
    fi
    echo -e "  ${line}"
    echo -e "  ${BOLD}${YELLOW}$(t creds_save_warning)${NC}"
    echo -e "  ${line}"
    echo ""
    echo -e "  ${CYAN}$(t cert_info_title)${NC}"
    if [ "$_mode" = "pro" ]; then
        # Pro: panel + VPN + subscription all use the domain Let's Encrypt cert.
        echo -e "  $(t cert_info_pro_1)"
        echo -e "  $(t cert_info_pro_2)"
        echo -e "  ${YELLOW}$(t cert_info_pro_3)${NC}"
    else
        # Lite: x-ui's built-in short-lived self-cert for the panel only.
        echo -e "  $(t cert_info_1)"
        echo -e "  $(t cert_info_2)"
    fi
    echo ""
    echo -e "  ${GREEN}$(t cert_info_ready)${NC}"
    echo -e "  ${line}"
    echo ""
}

# ── Display user links with QR ──────────────────────────────────────────
show_user_link() {
    local name="$1"
    local link="$2"

    echo ""
    echo -e "  ${BOLD}${WHITE}$(tf qr_title "$name")${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}"
    echo -e "  ${GREEN}${link}${NC}"
    echo ""

    qr_print "$link"

    echo -e "  ${DIM}$(t qr_scan_hint)${NC}"
}

# ── show_user_link_choice: pick subscription (Pro) or direct key ──
# Pro shows subscription first because it has a real domain. Lite does not
# generate subscription URLs because many clients refuse HTTP subscriptions by
# bare IP, so this function falls straight back to direct VLESS key/QR there.
show_user_link_choice() {
    local name="$1"
    local vless_url="$2"
    local sub_url="$3"   # may be empty if sub-server not configured

    echo ""
    echo -e "  ${BOLD}${WHITE}$(tf qr_title "$name")${NC}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}"

    # If no subscription available, fall back to direct link (no menu)
    if [ -z "$sub_url" ]; then
        show_user_link "$name" "$vless_url"
        return 0
    fi

    local pick
    while true; do
        echo -e "  $(t link_choice_prompt)"
        echo -e "    ${CYAN}1)${NC} $(t link_choice_sub)  ${DIM}$(t link_choice_sub_hint)${NC}"
        echo -e "    ${CYAN}2)${NC} $(t link_choice_key)  ${DIM}$(t link_choice_key_hint)${NC}"
        echo -e "    ${CYAN}3)${NC} $(t link_choice_both)"
        echo ""
        # Read from the terminal, not inherited stdin: this function is called
        # inside `while ... done < <(show_all_users)` (submenu_users QR), where stdin
        # is the user-list stream — a plain read would steal a user row, not the key.
        read -rp "  ▸ " pick < /dev/tty
        case "$pick" in
            1|"")
                show_user_link "$name (subscription)" "$sub_url"
                return 0
                ;;
            2)
                show_user_link "$name (direct key)" "$vless_url"
                return 0
                ;;
            3)
                show_user_link "$name (subscription)" "$sub_url"
                echo ""
                show_user_link "$name (direct key)" "$vless_url"
                return 0
                ;;
            *)
                log_warning "$(t invalid_choice)"
                ;;
        esac
    done
}

show_all_users() {
    # Always regen from 3X-UI DB (source of truth). /tmp is scratch.
    regenerate_links_from_db 2>/dev/null
    if [ ! -s /tmp/govless_links.json ]; then
        log_error "No user links found"
        return 1
    fi

    python3 << 'PYEOF'
import base64, json
with open('/tmp/govless_links.json') as f:
    links = json.load(f)
enc = lambda value: base64.b64encode(str(value).encode()).decode()
for i, (name, link) in enumerate(links.items(), 1):
    print(f"{i}\t{enc(name)}\t{enc(link)}")
PYEOF
}

# ── Check user online status ────────────────────────────────────────────
check_client_online() {
    # Three-layer detection (Codex-flagged race + user report 2026-05-24):
    #
    #   Layer 1: /panel/api/inbounds/onlines  (xray's live online set)
    #            Can be stale: x-ui flushes this cache every 10-30s, and a
    #            recent inbound recreate (switch_mode) invalidates it.
    #
    #   Layer 2: re-login + retry once if Layer 1 returns empty/auth-fail
    #            Cookie may have expired during long install.
    #
    #   Layer 3: traffic-stats fallback via x-ui.db client_traffics table.
    #            If up_bytes+down_bytes > 100KB for this email, the client
    #            HAS connected at least once — that's what the user cares
    #            about. Bytes are written by xray directly, no API round-trip.
    local email="$1"
    local cookie_file="${2:-/tmp/govless_cookie.txt}"

    # ── Layer 1: live online set ────────────────────────────────────────
    local csrf_args=(); _csrf_args csrf_args
    local resp http_code
    http_code=$(curl -sk -b "$cookie_file" -o /tmp/govless_onlines.json \
        -w '%{http_code}' \
        "${csrf_args[@]}" \
        -X POST "${API_BASE}/panel/api/inbounds/onlines" 2>/dev/null)
    resp=$(cat /tmp/govless_onlines.json 2>/dev/null)

    # ── Layer 2: cookie expired? re-login and retry once ───────────────
    # Gated to auth-failure codes only (Codex 022 P2): empty body alone
    # can mean "no online clients", not auth failure — re-logging in that
    # case would spam the panel up to N times per wait window.
    if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
        api_login "$cookie_file" >/dev/null 2>&1 || true
        # Rebuild csrf_args — api_login may have rotated API_CSRF_TOKEN
        csrf_args=(); _csrf_args csrf_args
        http_code=$(curl -sk -b "$cookie_file" -o /tmp/govless_onlines.json \
            -w '%{http_code}' \
            "${csrf_args[@]}" \
            -X POST "${API_BASE}/panel/api/inbounds/onlines" 2>/dev/null)
        resp=$(cat /tmp/govless_onlines.json 2>/dev/null)
    fi

    if [ -n "$resp" ]; then
        if echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    clients = d.get('obj') or []
    target = sys.argv[1]
    # x-ui may return list-of-strings (emails) or list-of-dicts {email: ...}
    found = False
    for c in clients:
        if isinstance(c, str) and c == target: found = True; break
        if isinstance(c, dict) and c.get('email') == target: found = True; break
    sys.exit(0 if found else 1)
except Exception:
    sys.exit(1)
" "$email" 2>/dev/null; then
            return 0
        fi
    fi

    # ── Layer 3: traffic-stats fallback (parameterized — Codex 022 P2) ──
    # Use Python sqlite3 with bound params instead of string-interpolated
    # WHERE — emails can contain quotes (3X-UI lets admin set arbitrary
    # client emails), which would break the literal SQL or allow injection.
    if [ -f /etc/x-ui/x-ui.db ]; then
        local total
        total=$(python3 - "$email" <<'PYEOF' 2>/dev/null
import sys, sqlite3
email = sys.argv[1]
try:
    con = sqlite3.connect("/etc/x-ui/x-ui.db", timeout=2)
    con.execute("PRAGMA busy_timeout = 2000")
    row = con.execute(
        "SELECT COALESCE(up,0) + COALESCE(down,0) FROM client_traffics WHERE email = ?",
        (email,)
    ).fetchone()
    print(row[0] if row and row[0] is not None else 0)
except Exception:
    print(0)
PYEOF
)
        if [ -n "$total" ] && [ "$total" -gt 102400 ]; then
            return 0
        fi
    fi

    return 1
}

# True if xray is actually serving a Reality inbound on :443 (the config.json
# xray runs). 3X-UI v2.9.4's API can report inbound-create "failure" even after
# the row is committed to the DB; restarting x-ui regenerates config.json, so we
# verify by RESULT instead of trusting the API return code.
reality_inbound_serving() {
    systemctl is-active --quiet "${XUI_SERVICE:-x-ui}" || return 1
    local cfg="${XUI_DIR:-/usr/local/x-ui}/bin/config.json"
    [ -f "$cfg" ] || return 1
    python3 - "$cfg" <<'PYIN' 2>/dev/null
import json,sys
try: c=json.load(open(sys.argv[1]))
except Exception: sys.exit(1)
sys.exit(0 if any(i.get("port")==443 and i.get("streamSettings",{}).get("security")=="reality" for i in c.get("inbounds",[])) else 1)
PYIN
}
