#!/bin/bash
# Deploy Pro mode: real SSL, website masking, VLESS TLS keys
set +e

SCRIPT_DIR="/root/self-signed-cert-script-by-antenka"
LOG="/tmp/deploy_pro.log"

echo "=== XUIFAST PRO DEPLOY $(date -Iseconds) ===" | tee "$LOG"

cd "$SCRIPT_DIR" || exit 1
source lib/common.sh
source lib/i18n.sh
source lib/lang/en.sh
source lib/xui.sh
source lib/xui_api.sh
source lib/reality_domains.sh
source lib/website.sh
mkdir -p "$XUIFAST_DIR"

PRO_DOMAIN="anten-ka.com"
XUI_TRANSPORT="tcp"
NUM_USERS=3

# ── CLEANUP ───────────────────────────────────────────────────────
echo ">>> Cleaning up..." | tee -a "$LOG"
systemctl stop x-ui 2>/dev/null
systemctl disable x-ui 2>/dev/null
rm -rf /usr/local/x-ui /usr/bin/x-ui /etc/x-ui /etc/systemd/system/x-ui.service 2>/dev/null
systemctl daemon-reload 2>/dev/null
rm -f /root/.xuifast_credentials /tmp/xuifast_* 2>/dev/null
rm -rf "$XUIFAST_DIR" 2>/dev/null; mkdir -p "$XUIFAST_DIR"
systemctl stop nginx 2>/dev/null
rm -f /etc/nginx/sites-enabled/xuifast /etc/nginx/sites-available/xuifast 2>/dev/null
# Remove old certs so we get fresh ones
rm -rf "/etc/letsencrypt/live/$PRO_DOMAIN" "/etc/letsencrypt/renewal/$PRO_DOMAIN.conf" "/etc/letsencrypt/archive/$PRO_DOMAIN" 2>/dev/null
echo ">>> Cleanup done" | tee -a "$LOG"

# ── 1. Install 3X-UI ─────────────────────────────────────────────
echo ">>> Step 1: Installing 3X-UI..." | tee -a "$LOG"
install_3xui "v3.0.1" 2>&1 | tee -a "$LOG"
if [ ! -f "$XUI_BIN" ] || ! systemctl is-active --quiet x-ui; then
    echo "FATAL: 3X-UI install failed" | tee -a "$LOG"
    exit 1
fi
echo ">>> 3X-UI installed OK" | tee -a "$LOG"

# ── 2. Extract credentials ───────────────────────────────────────
echo ">>> Step 2: Extracting credentials..." | tee -a "$LOG"
extract_credentials
echo "USER=$XUI_USER PORT=$XUI_PORT PATH=$XUI_WEB_PATH" | tee -a "$LOG"

# ── 3. API login ─────────────────────────────────────────────────
echo ">>> Step 3: API login..." | tee -a "$LOG"
setup_api_base
wait_for_api 30
if ! api_login; then
    echo "FATAL: API login failed" | tee -a "$LOG"
    exit 1
fi
echo ">>> API login OK (base=$API_BASE)" | tee -a "$LOG"

# ── 4. Install nginx ─────────────────────────────────────────────
echo ">>> Step 4: Installing nginx..." | tee -a "$LOG"
install_nginx 2>&1 | tee -a "$LOG"

# ── 5. Install certbot ───────────────────────────────────────────
echo ">>> Step 5: Installing certbot..." | tee -a "$LOG"
install_certbot 2>&1 | tee -a "$LOG"

# ── 6. Deploy stub site + get SSL ────────────────────────────────
echo ">>> Step 6: Deploying site and getting SSL cert..." | tee -a "$LOG"
deploy_stub_site
generate_nginx_temp_config "$PRO_DOMAIN"
systemctl restart nginx 2>&1 | tee -a "$LOG"

# Stop x-ui temporarily so port 443 is free for cert validation (if needed)
# Actually certbot uses port 80 webroot, so x-ui on 443 is fine

echo ">>> Getting Let's Encrypt certificate for $PRO_DOMAIN..." | tee -a "$LOG"
obtain_ssl_certificate "$PRO_DOMAIN" "" 2>&1 | tee -a "$LOG"

CERT_FILE="/etc/letsencrypt/live/$PRO_DOMAIN/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/$PRO_DOMAIN/privkey.pem"

if [ ! -f "$CERT_FILE" ]; then
    echo "FATAL: SSL certificate not obtained" | tee -a "$LOG"
    exit 1
fi
echo ">>> SSL certificate OK" | tee -a "$LOG"

# ── 7. Setup Pro nginx config ────────────────────────────────────
echo ">>> Step 7: Setting up nginx Pro config..." | tee -a "$LOG"
generate_nginx_pro_config "$PRO_DOMAIN"
if nginx -t 2>/dev/null; then
    systemctl restart nginx
    echo ">>> nginx running with Pro config" | tee -a "$LOG"
else
    echo "ERROR: nginx config test failed" | tee -a "$LOG"
    nginx -t 2>&1 | tee -a "$LOG"
fi

# ── 8. Setup SSL auto-renewal ────────────────────────────────────
setup_ssl_auto_renewal 2>&1 | tee -a "$LOG"

# ── 9. Generate clients ──────────────────────────────────────────
echo ">>> Step 9: Generating $NUM_USERS users..." | tee -a "$LOG"
generate_clients "$NUM_USERS" "pro"
echo ">>> Clients generated" | tee -a "$LOG"

# ── 10. Create TLS inbound on port 443 ───────────────────────────
echo ">>> Step 10: Creating TLS inbound..." | tee -a "$LOG"
api_create_tls_inbound "$PRO_DOMAIN" "$CERT_FILE" "$KEY_FILE" 2>&1 | tee -a "$LOG"

# ── 11. Generate VLESS links ─────────────────────────────────────
echo ">>> Step 11: Generating VLESS links..." | tee -a "$LOG"
generate_all_vless_links "pro" "$PRO_DOMAIN"

# ── 12. Save everything ──────────────────────────────────────────
config_set "mode" "pro"
config_set "transport" "tcp"
config_set "domain" "$PRO_DOMAIN"
save_credentials

# ── RESULTS ───────────────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "=============================================" | tee -a "$LOG"
echo "  XUIFAST PRO MODE — DEPLOYMENT COMPLETE" | tee -a "$LOG"
echo "=============================================" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Domain: $PRO_DOMAIN" | tee -a "$LOG"
echo "Panel URL: http://$PRO_DOMAIN:${XUI_PORT}${XUI_WEB_PATH}" | tee -a "$LOG"
echo "Panel User: $XUI_USER" | tee -a "$LOG"
echo "Panel Pass: $XUI_PASS" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "SSL Certificate: $(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null)" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "=== VLESS KEYS ===" | tee -a "$LOG"
python3 -c "
import json
with open('/tmp/xuifast_links.json') as f:
    links = json.load(f)
for i, (name, link) in enumerate(links.items(), 1):
    print(f'{i}. {name}:')
    print(f'   {link}')
    print()
" 2>/dev/null | tee -a "$LOG"

echo "=== SUBSCRIPTION (base64) ===" | tee -a "$LOG"
python3 -c "
import json, base64
with open('/tmp/xuifast_links.json') as f:
    links = json.load(f)
all_links = '\n'.join(links.values())
sub = base64.b64encode(all_links.encode()).decode()
print(sub)
" 2>/dev/null | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "Website check: $(curl -sk -o /dev/null -w '%{http_code}' http://$PRO_DOMAIN)" | tee -a "$LOG"
echo "TLS check: $(echo | timeout 5 openssl s_client -connect $PRO_DOMAIN:443 -servername $PRO_DOMAIN 2>/dev/null | grep -c 'Verify return code')" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "=== DEPLOY DONE ===" | tee -a "$LOG"
