#!/bin/bash
# XUIFAST v3.0.0 — 3X-UI REST API, inbound creation, user management
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

# ── Setup API base URL ──────────────────────────────────────────────────
setup_api_base() {
    API_BASE="https://127.0.0.1:${XUI_PORT}${XUI_WEB_PATH}"
    # Ensure no double slashes
    API_BASE="${API_BASE%/}"
}

# ── Wait for API to become available ────────────────────────────────────
wait_for_api() {
    local timeout="${1:-60}"
    local elapsed=0

    setup_api_base

    while [ "$elapsed" -lt "$timeout" ]; do
        local code
        code=$(curl -sk -o /dev/null -w '%{http_code}' "${API_BASE}/login" 2>/dev/null)
        if [ "$code" = "200" ]; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    log_error "$(t api_waiting) — timeout ${timeout}s"
    return 1
}

# ── API login (cookie-based) ────────────────────────────────────────────
api_login() {
    local cookie_file="${1:-/tmp/xuifast_cookie.txt}"

    local http_code
    http_code=$(curl -sk -w '%{http_code}' -o /tmp/xuifast_login_resp.json \
        -c "$cookie_file" \
        "${API_BASE}/login" \
        --data-urlencode "username=${XUI_USER}" \
        --data-urlencode "password=${XUI_PASS}" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        # 3X-UI returns 200 even on wrong creds — check JSON success field
        local success
        success=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_login_resp.json')); print(d.get('success', False))" 2>/dev/null || echo "False")
        if [ "$success" = "True" ]; then
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
    local cookie_file="${1:-/tmp/xuifast_cookie.txt}"
    local attempts="${2:-3}"

    for i in $(seq 1 "$attempts"); do
        if api_login "$cookie_file"; then
            return 0
        fi
        [ "$i" -lt "$attempts" ] && sleep 3
    done
    return 1
}

# ── Set panel language ──────────────────────────────────────────────────
api_set_language() {
    local lang="${1:-en}"
    local cookie_file="${2:-/tmp/xuifast_cookie.txt}"

    # Map our language codes to 3x-ui panel codes
    local panel_lang="en-US"
    [ "$lang" = "ru" ] && panel_lang="ru-RU"

    curl -sk -b "$cookie_file" \
        -X POST "${API_BASE}/panel/setting/update" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "webLang=${panel_lang}" >/dev/null 2>&1
}

# ── Create VLESS Reality inbound (Lite mode) ────────────────────────────
api_create_reality_inbound() {
    local mask_domain="$1"
    local cookie_file="${2:-/tmp/xuifast_cookie.txt}"

    log_info "$(t api_creating_inbound)"

    # Validate prerequisites
    [ -f /tmp/xuifast_clients.json ] || { log_error "Clients file not found"; return 1; }
    [ -n "$REALITY_PRIVATE_KEY" ] || { log_error "Reality private key not set"; return 1; }
    [ -n "$REALITY_PUBLIC_KEY" ] || { log_error "Reality public key not set"; return 1; }

    # Build the payload using Python (injection-safe)
    python3 - "$mask_domain" "$REALITY_PRIVATE_KEY" "$REALITY_PUBLIC_KEY" << 'PYEOF'
import json, sys

mask_domain = sys.argv[1]
private_key = sys.argv[2]
public_key = sys.argv[3]

with open('/tmp/xuifast_clients.json') as f:
    clients = json.load(f)

# Generate short IDs
import secrets
short_ids = [secrets.token_hex(8) for _ in range(4)]

settings = json.dumps({
    "clients": clients,
    "decryption": "none",
    "fallbacks": []
})

stream_settings = json.dumps({
    "network": "tcp",
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
            "fingerprint": "chrome",
            "serverName": "",
            "spiderX": "/"
        }
    },
    "tcpSettings": {
        "acceptProxyProtocol": False,
        "header": {"type": "none"}
    }
})

sniffing = json.dumps({
    "enabled": True,
    "destOverride": ["http", "tls", "quic", "fakedns"],
    "metadataOnly": False,
    "routeOnly": False
})

payload = {
    "up": 0,
    "down": 0,
    "total": 0,
    "remark": "xuifast-vless-reality",
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

with open('/tmp/xuifast_payload.json', 'w') as f:
    json.dump(payload, f)
PYEOF

    if [ $? -ne 0 ]; then
        log_error "Failed to build Reality payload"
        return 1
    fi

    # Send the request
    local http_code
    http_code=$(curl -sk -w '%{http_code}' -o /tmp/xuifast_api_resp.json \
        -b "$cookie_file" \
        -X POST "${API_BASE}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/xuifast_payload.json 2>/dev/null)

    local success
    success=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_api_resp.json')); print(d.get('success', False))" 2>/dev/null || echo "False")

    if [ "$success" = "True" ]; then
        log_success "$(t api_inbound_created)"
        return 0
    else
        local msg
        msg=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_api_resp.json')); print(d.get('msg', 'unknown'))" 2>/dev/null || echo "HTTP $http_code")
        log_error "$(t api_inbound_failed): $msg"
        return 1
    fi
}

# ── Create VLESS TLS inbound (Pro mode) ─────────────────────────────────
api_create_tls_inbound() {
    local domain="$1"           # e.g. "example.com"
    local cert_file="$2"        # /etc/letsencrypt/live/$domain/fullchain.pem
    local key_file="$3"         # /etc/letsencrypt/live/$domain/privkey.pem
    local cookie_file="${4:-/tmp/xuifast_cookie.txt}"

    log_info "$(t api_creating_inbound)"

    # Validate prerequisites
    [ -f /tmp/xuifast_clients.json ] || { log_error "Clients file not found"; return 1; }

    python3 - "$domain" "$cert_file" "$key_file" << 'PYEOF'
import json, sys

domain = sys.argv[1]
cert_file = sys.argv[2]
key_file = sys.argv[3]

with open('/tmp/xuifast_clients.json') as f:
    clients = json.load(f)

settings = json.dumps({
    "clients": clients,
    "decryption": "none",
    "fallbacks": [{"dest": 80}]
})

stream_settings = json.dumps({
    "network": "tcp",
    "security": "tls",
    "externalProxy": [],
    "tlsSettings": {
        "serverName": domain,
        "minVersion": "1.2",
        "maxVersion": "1.3",
        "cipherSuites": "",
        "rejectUnknownSni": False,
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
        "alpn": ["h2", "http/1.1"],
        "settings": {
            "allowInsecure": False,
            "fingerprint": "chrome"
        }
    },
    "tcpSettings": {
        "acceptProxyProtocol": False,
        "header": {"type": "none"}
    }
})

sniffing = json.dumps({
    "enabled": True,
    "destOverride": ["http", "tls", "quic", "fakedns"],
    "metadataOnly": False,
    "routeOnly": False
})

payload = {
    "up": 0,
    "down": 0,
    "total": 0,
    "remark": "xuifast-vless-tls",
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

with open('/tmp/xuifast_payload.json', 'w') as f:
    json.dump(payload, f)
PYEOF

    if [ $? -ne 0 ]; then
        log_error "Failed to build TLS payload"
        return 1
    fi

    local http_code
    http_code=$(curl -sk -w '%{http_code}' -o /tmp/xuifast_api_resp.json \
        -b "$cookie_file" \
        -X POST "${API_BASE}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/xuifast_payload.json 2>/dev/null)

    local success
    success=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_api_resp.json')); print(d.get('success', False))" 2>/dev/null || echo "False")

    if [ "$success" = "True" ]; then
        log_success "$(t api_inbound_created)"
        return 0
    else
        local msg
        msg=$(python3 -c "import json; d=json.load(open('/tmp/xuifast_api_resp.json')); print(d.get('msg', 'unknown'))" 2>/dev/null || echo "HTTP $http_code")
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
    local flow="xtls-rprx-vision"

    python3 - "$mode" "$flow" "${names[@]}" << 'PYEOF'
import json, sys, uuid

mode = sys.argv[1]
flow = sys.argv[2]
names = sys.argv[3:]

clients = []
for name in names:
    client = {
        "id": str(uuid.uuid4()),
        "alterId": 0,
        "email": name,
        "limitIp": 0,
        "totalGB": 0,
        "expiryTime": 0,
        "enable": True,
        "tgId": "",
        "subId": "",
        "comment": f"XUIFAST user {name}",
        "reset": 0
    }
    # Reality: flow = xtls-rprx-vision; TLS: also xtls-rprx-vision
    client["flow"] = flow
    clients.append(client)

with open('/tmp/xuifast_clients.json', 'w') as f:
    json.dump(clients, f)

# Also save name→uuid mapping for VLESS link generation
mapping = {c["email"]: c["id"] for c in clients}
with open('/tmp/xuifast_users_map.json', 'w') as f:
    json.dump(mapping, f)
PYEOF

    if [ $? -ne 0 ]; then
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

    local encoded_name
    encoded_name=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$name" 2>/dev/null || echo "$name")

    echo "vless://${uuid}@${server_ip}:443?type=tcp&security=reality&pbk=${public_key}&fp=chrome&sni=${mask_domain}&sid=${short_id}&spx=%2F&flow=xtls-rprx-vision#${encoded_name}"
}

generate_vless_link_tls() {
    local uuid="$1"
    local name="$2"
    local domain="$3"

    local encoded_name
    encoded_name=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$name" 2>/dev/null || echo "$name")

    echo "vless://${uuid}@${domain}:443?type=tcp&security=tls&sni=${domain}&alpn=h2%2Chttp%2F1.1&fp=chrome&flow=xtls-rprx-vision#${encoded_name}"
}

# ── Generate all VLESS links and save ───────────────────────────────────
generate_all_vless_links() {
    local mode="$1"             # lite or pro
    local server="$2"           # IP (lite) or domain (pro)
    local mask_domain="${3:-}"   # only for lite mode

    if [ ! -f /tmp/xuifast_users_map.json ]; then
        log_error "User map not found"
        return 1
    fi

    # Get short_id from payload (for Reality)
    local short_id=""
    if [ "$mode" = "lite" ] && [ -f /tmp/xuifast_payload.json ]; then
        short_id=$(python3 -c "
import json
p = json.load(open('/tmp/xuifast_payload.json'))
ss = json.loads(p['streamSettings'])
sids = ss.get('realitySettings', {}).get('shortIds', [])
print(sids[0] if sids else '')
" 2>/dev/null)
    fi

    # Generate links
    python3 - "$mode" "$server" "$mask_domain" "${REALITY_PUBLIC_KEY:-}" "$short_id" << 'PYEOF'
import json, sys
from urllib.parse import quote

mode = sys.argv[1]
server = sys.argv[2]
mask_domain = sys.argv[3]
public_key = sys.argv[4]
short_id = sys.argv[5]

with open('/tmp/xuifast_users_map.json') as f:
    users = json.load(f)

links = {}
for name, uuid in users.items():
    enc_name = quote(name)
    if mode == "lite":
        link = (
            f"vless://{uuid}@{server}:443"
            f"?type=tcp&security=reality"
            f"&pbk={public_key}&fp=chrome"
            f"&sni={mask_domain}&sid={short_id}"
            f"&spx=%2F&flow=xtls-rprx-vision"
            f"#{enc_name}"
        )
    else:
        link = (
            f"vless://{uuid}@{server}:443"
            f"?type=tcp&security=tls"
            f"&sni={server}&alpn=h2%2Chttp%2F1.1"
            f"&fp=chrome&flow=xtls-rprx-vision"
            f"#{enc_name}"
        )
    links[name] = link

with open('/tmp/xuifast_links.json', 'w') as f:
    json.dump(links, f, indent=2)
PYEOF

    log_success "VLESS links generated"
}

# ── Display credentials box ─────────────────────────────────────────────
show_credentials() {
    local ip
    ip=$(get_server_ip)

    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}$(t creds_title)${NC}"
    echo -e "  ${YELLOW}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${YELLOW}║${NC}  $(t creds_url)   ${CYAN}https://${ip}:${XUI_PORT}${XUI_WEB_PATH}${NC}"
    echo -e "  ${YELLOW}║${NC}  $(t creds_user)  ${CYAN}${XUI_USER}${NC}"
    echo -e "  ${YELLOW}║${NC}  $(t creds_pass)  ${CYAN}${XUI_PASS}${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
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

    if command -v qrencode &>/dev/null; then
        qrencode -t UTF8 -m 2 "$link" 2>/dev/null
    fi

    echo -e "  ${DIM}$(t qr_scan_hint)${NC}"
}

show_all_users() {
    if [ ! -f /tmp/xuifast_links.json ]; then
        log_error "No user links found"
        return 1
    fi

    python3 << 'PYEOF'
import json
with open('/tmp/xuifast_links.json') as f:
    links = json.load(f)
for i, (name, link) in enumerate(links.items(), 1):
    print(f"{i}|{name}|{link}")
PYEOF
}

# ── Check user online status ────────────────────────────────────────────
check_client_online() {
    local email="$1"
    local cookie_file="${2:-/tmp/xuifast_cookie.txt}"

    local resp
    resp=$(curl -sk -b "$cookie_file" "${API_BASE}/panel/api/inbounds/onlines" 2>/dev/null)
    if [ -z "$resp" ]; then
        return 1
    fi

    echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    clients = d.get('obj', [])
    target = sys.argv[1]
    if clients and target in clients:
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" "$email" 2>/dev/null
}
