# XUIFAST v3.0.1 — Complete Project Guide for AI Bug Auditors

## WHAT IS THIS PROJECT

XUIFAST is a **bash installer script** for 3X-UI VPN panel. It runs on a fresh Linux VPS (Ubuntu/Debian/CentOS), installs the 3X-UI panel, configures VLESS VPN with automatic user creation, and provides an interactive menu for management.

The script has TWO installation modes:

### Lite Mode (VLESS + Reality)
- Uses XRAY Reality protocol — no real domain needed
- Masquerades VPN traffic as visits to popular websites (e.g. google.com, yandex.ru)
- Geo-aware: shows 50 Russian domains for RU servers, 50 international for others
- Xray listens on port 443, nginx serves stub site on port 80
- Uses x25519 keypair (generated via `xray x25519` command)

### Pro Mode (VLESS + TLS)
- Requires user's own domain + Let's Encrypt SSL certificate
- Real website template served by nginx on port 80 as fallback
- Xray on port 443 with real TLS certificates
- Certbot handles SSL auto-renewal

## FILE STRUCTURE (9 files, ~2900 lines total)

```
xuifast.sh              (566 lines) — Main entry point, install flows, menus
lib/common.sh           (415 lines) — Utilities, logging, config, IP detection
lib/i18n.sh             (110 lines) — Translation engine: t() and tf() functions
lib/lang/ru.sh          (200 lines) — Russian translations (149 keys)
lib/lang/en.sh          (200 lines) — English translations (149 keys)
lib/xui.sh              (255 lines) — 3X-UI install/service/credentials
lib/xui_api.sh          (581 lines) — REST API, users, VLESS links, QR codes
lib/reality_domains.sh  (198 lines) — Domain lists + TLS test for Reality
lib/website.sh          (372 lines) — nginx, certbot, SSL, website templates
```

## HOW THE SCRIPT RUNS

1. `xuifast.sh` is the entry point. It has `set -euo pipefail` at line 10.
2. It sources ALL lib/*.sh modules at lines 16-21 via `source "${SCRIPT_DIR}/lib/*.sh"`.
3. Registers EXIT trap for cleanup (line 24).
4. Checks root (line 27).
5. Calls `main()` (line 566) which:
   - Initializes language (detect saved or ask user)
   - Checks disk space
   - If 3X-UI already installed → shows management menu (`main_menu`)
   - If first run → shows mode selection (`select_and_install`)

## KEY GLOBAL VARIABLES

Defined in `lib/common.sh`:
- `XUIFAST_VERSION="3.0.0"` — version string
- `XUIFAST_DIR="/opt/xuifast"` — main config directory
- `XUIFAST_CONFIG="/opt/xuifast/config.json"` — JSON config file (managed via jq)
- `XUI_DIR="/usr/local/x-ui"` — 3X-UI installation directory
- `XUI_BIN="/usr/local/x-ui/x-ui"` — 3X-UI binary
- `XRAY_BIN="/usr/local/x-ui/bin/xray-linux-amd64"` — Xray binary
- `XUI_DB="/usr/local/x-ui/db/x-ui.db"` — SQLite database
- `XUI_SERVICE="x-ui"` — systemd service name
- `CREDENTIALS_FILE="/root/.xuifast_credentials"` — saved credentials
- `WEBSITE_ROOT="/var/www/html"` — nginx document root
- `NGINX_SITE_CONF="/etc/nginx/sites-available/xuifast"` — nginx config
- `NGINX_SITE_LINK="/etc/nginx/sites-enabled/xuifast"` — nginx symlink
- Colors: `RED GREEN YELLOW BLUE MAGENTA CYAN WHITE DIM BOLD NC`

Set at runtime by `lib/xui.sh` → `extract_credentials()`:
- `XUI_USER` — admin username (default: "admin")
- `XUI_PASS` — admin password (default: "admin")
- `XUI_PORT` — web panel port (default: "2053")
- `XUI_WEB_PATH` — web base path (default: "/")

Set at runtime by `lib/xui.sh` → `generate_reality_keypair()`:
- `REALITY_PRIVATE_KEY` — x25519 private key for Reality
- `REALITY_PUBLIC_KEY` — x25519 public key for Reality

Set at runtime by `lib/xui_api.sh`:
- `API_BASE` — full API URL like "https://127.0.0.1:2053"

Set at runtime by `lib/i18n.sh`:
- `LANG_CODE` — current language ("en" or "ru")
- `I18N` — associative array with all translation keys

## TEMP FILES (in /tmp/)

These files are created during install and used across functions:
- `/tmp/xuifast_xui_install.log` — 3X-UI installer output
- `/tmp/xuifast_cookie.txt` — API session cookie
- `/tmp/xuifast_clients.json` — JSON array of generated VPN clients
- `/tmp/xuifast_users_map.json` — dict {email: uuid} for VLESS links
- `/tmp/xuifast_payload.json` — API request payload for inbound creation
- `/tmp/xuifast_api_resp.json` — API response from inbound creation
- `/tmp/xuifast_login_resp.json` — API response from login
- `/tmp/xuifast_links.json` — dict {name: vless_link} — all generated links

The EXIT trap `cleanup_temp_files` deletes all `/tmp/xuifast_*` files on exit.

## INSTALL FLOW — LITE MODE (xuifast.sh → install_lite)

Step-by-step order:
1. `get_server_ip()` — detect public IP
2. `select_reality_domain()` — user picks masquerade domain from geo-aware list
3. Show config summary, confirm
4. `install_dependencies()` — install curl, jq, openssl, qrencode, expect
5. `install_3xui()` — run official installer via expect automation
6. `extract_credentials()` → `save_credentials()` → `setup_api_base()`
7. `wait_for_api()` — poll until panel responds on localhost
8. `api_login_with_retry()` — authenticate with cookie
9. `api_set_language()` — set panel UI language
10. `generate_reality_keypair()` — run `xray x25519` to get keys
11. `generate_clients()` — create 10 users with random names, write to temp JSON
12. `api_create_reality_inbound()` — POST to 3X-UI API with Reality config
13. `generate_all_vless_links()` — build vless:// URIs for all users
14. `setup_lite_nginx()` — install nginx with stub site on port 80
15. Save config via `config_set()` (writes to JSON with jq)
16. Show success, credentials, run post_install_flow

## INSTALL FLOW — PRO MODE (xuifast.sh → install_pro)

Same as Lite but:
- Step 2: Ask for domain instead of masquerade domain
- Step 3: DNS check (does domain point to this IP?)
- Step 4: Ask for email (for Let's Encrypt)
- Step 5: Template selection (if catalog available)
- Step 8: `setup_pro_website()` or manual nginx+certbot setup
- Step 12: `api_create_tls_inbound()` instead of Reality inbound
- Step 13: `generate_all_vless_links("pro", domain)` instead of Reality links

## i18n SYSTEM

- `t("key")` — returns translation or key name if missing
- `tf("key", arg1, arg2...)` — returns translation with printf formatting
- Translation files use `declare -gA I18N` associative array
- Format: `I18N[key_name]="Translation text with %s placeholders"`
- IMPORTANT: `t()` uses echo, `tf()` uses printf. Keys with %s MUST use tf().

## API INTERACTION PATTERN

All API calls follow this pattern:
1. Build payload with Python heredoc (`python3 - args << 'PYEOF' ... PYEOF`)
2. Python writes JSON to `/tmp/xuifast_payload.json`
3. Bash sends curl POST with `-d @/tmp/xuifast_payload.json`
4. Response saved to `/tmp/xuifast_api_resp.json`
5. Python parses response to check `success` field

3X-UI REST API endpoints used:
- `POST /login` — authenticate (returns cookie)
- `POST /panel/setting/update` — change panel settings
- `POST /panel/api/inbounds/add` — create VPN inbound
- `GET /panel/api/inbounds/onlines` — check online users

## VLESS LINK FORMAT

Reality: `vless://UUID@IP:443?type=tcp&security=reality&pbk=PUBLIC_KEY&fp=chrome&sni=MASK_DOMAIN&sid=SHORT_ID&spx=%2F&flow=xtls-rprx-vision#NAME`

TLS: `vless://UUID@DOMAIN:443?type=tcp&security=tls&sni=DOMAIN&alpn=h2%2Chttp%2F1.1&fp=chrome&flow=xtls-rprx-vision#NAME`

## CRITICAL BASH PATTERNS TO UNDERSTAND

1. **`set -euo pipefail`** — script dies on ANY unhandled non-zero exit code. Every function call that might fail MUST have `|| return 1` or `|| true`.

2. **Python heredocs** — used for JSON construction because bash can't safely build complex JSON. Pattern: `python3 - "$arg1" "$arg2" << 'PYEOF' ... PYEOF`. The single-quoted PYEOF means NO shell variable expansion inside — everything must come via sys.argv.

3. **Subshell variable scope** — variables set inside `$()` or `( )` are NOT visible in the parent shell. The script works around this by writing to temp files.

4. **heredoc in heredoc** — nginx configs use `<< 'EONGINX'` (single-quoted = no expansion) to prevent bash from interpreting nginx `$uri` variables.

5. **Cookie-based API auth** — `curl -c file` saves cookies, `curl -b file` sends them.

## WHAT TO LOOK FOR (BUG CATEGORIES)

### Category A: Logic Bugs
- Functions called in wrong order (e.g. using API before login)
- Variables used before they're set
- Return values ignored on critical operations
- Off-by-one errors in arrays or loops
- Conditions that are always true/false

### Category B: Bash-Specific Bugs
- Unquoted variables that break with spaces/special chars
- `set -e` interaction: functions failing silently because error isn't propagated
- Subshell scope: variables set in `$()` not available in parent
- heredoc quoting: shell expanding things inside heredocs when it shouldn't
- `read` not working in non-interactive (piped) mode
- `local` declarations hiding function return codes

### Category C: Security Issues
- Shell injection via variables interpolated into commands
- Python injection via variables interpolated into Python -c strings
- Credentials in predictable locations
- Temp files with predictable names (race conditions)

### Category D: Cross-File Integration
- Global variable name mismatches between files
- Function signatures not matching call sites
- Translation keys used in code but missing from lang files
- Temp file paths used inconsistently between functions

### Category E: Edge Cases
- What happens if network is down during install?
- What happens if 3X-UI is already installed?
- What happens if disk is full?
- What happens if user presses Ctrl+C mid-install?
- What happens on second run (reinstall)?

## REPORT FORMAT

For each bug found, provide:
```
FILE: lib/example.sh
LINE: 42
SEVERITY: critical | high | medium | low
BUG: One-line description
DETAILS: Why this is a bug and what goes wrong
FIX: Exact code change needed (show old → new)
```

Only report REAL bugs. Do not report:
- Style preferences (indentation, naming)
- Theoretical issues that can't actually happen with current code
- Features that are missing (unless they're documented but unimplemented)
- Performance suggestions
