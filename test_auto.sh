#!/bin/bash
# XUIFAST automated test script — runs non-interactively on VPS
# Tests: sourcing, functions, dependencies, install flow
set +e  # Don't exit on errors — we want to capture them all

SCRIPT_DIR="/root/self-signed-cert-script-by-antenka"
LOG="/tmp/xuifast_autotest.log"
ERRORS=0
TESTS=0
PASSED=0

log() { echo "[TEST] $*" | tee -a "$LOG"; }
pass() { ((TESTS++)); ((PASSED++)); echo "[PASS] $*" | tee -a "$LOG"; }
fail() { ((TESTS++)); ((ERRORS++)); echo "[FAIL] $*" | tee -a "$LOG"; }

echo "=== XUIFAST Auto-Test $(date -Iseconds) ===" > "$LOG"

# ── Test 1: Source all files ──────────────────────────────────
log "--- Test group: Sourcing files ---"

# Need to set up minimal env before sourcing
export XUIFAST_DIR="/etc/xuifast"
export XUI_DIR="/usr/local/x-ui"
export XUI_BIN="/usr/local/x-ui/x-ui"
export XUI_DB="/etc/x-ui/x-ui.db"
export XUI_SERVICE="x-ui"
export XRAY_BIN="/usr/local/x-ui/bin/xray-linux-amd64"
export CREDENTIALS_FILE="/etc/xuifast/credentials"
export NGINX_SITE_CONF="/etc/nginx/sites-available/xuifast"
export NGINX_SITE_LINK="/etc/nginx/sites-enabled/xuifast"
export WEBSITE_ROOT="/var/www/xuifast"

# Source common.sh first
if source "$SCRIPT_DIR/lib/common.sh" 2>>"$LOG"; then
    pass "source common.sh"
else
    fail "source common.sh — exit code $?"
fi

# Source i18n
if source "$SCRIPT_DIR/lib/i18n.sh" 2>>"$LOG"; then
    pass "source i18n.sh"
else
    fail "source i18n.sh — exit code $?"
fi

# Load language
if source "$SCRIPT_DIR/lib/lang/ru.sh" 2>>"$LOG"; then
    pass "source lang/ru.sh"
else
    fail "source lang/ru.sh — exit code $?"
fi

if source "$SCRIPT_DIR/lib/lang/en.sh" 2>>"$LOG"; then
    pass "source lang/en.sh"
else
    fail "source lang/en.sh — exit code $?"
fi

# Source other modules
for mod in xui.sh xui_api.sh reality_domains.sh website.sh; do
    if source "$SCRIPT_DIR/lib/$mod" 2>>"$LOG"; then
        pass "source $mod"
    else
        fail "source $mod — exit code $?"
    fi
done

# ── Test 2: i18n functions ────────────────────────────────────
log "--- Test group: i18n ---"

CURRENT_LANG="en"
if source "$SCRIPT_DIR/lib/lang/en.sh" 2>/dev/null; then
    # Test t() function
    result=$(t yes 2>/dev/null)
    if [ "$result" = "Yes" ]; then
        pass "t() returns 'Yes' for key 'yes'"
    else
        fail "t() returned '$result' instead of 'Yes'"
    fi

    # Test tf() with format
    result=$(tf ssl_until "2025-12-31" 2>/dev/null)
    if [[ "$result" == *"2025-12-31"* ]]; then
        pass "tf() format substitution works"
    else
        fail "tf() returned '$result' — expected to contain '2025-12-31'"
    fi

    # Test missing key
    result=$(t nonexistent_key_xyz 2>/dev/null)
    if [[ "$result" == *"nonexistent_key_xyz"* ]] || [ -z "$result" ]; then
        pass "t() handles missing key gracefully"
    else
        fail "t() missing key returned: '$result'"
    fi
else
    fail "Could not load en.sh for i18n tests"
fi

# ── Test 3: common.sh functions ───────────────────────────────
log "--- Test group: common.sh functions ---"

# Test get_server_ip
if type get_server_ip &>/dev/null; then
    ip=$(get_server_ip 2>/dev/null)
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        pass "get_server_ip returns valid IP: $ip"
    else
        fail "get_server_ip returned invalid: '$ip'"
    fi
else
    fail "get_server_ip function not found"
fi

# Test detect_os
if type detect_os &>/dev/null; then
    os=$(detect_os 2>/dev/null)
    if [ -n "$os" ]; then
        pass "detect_os returns: $os"
    else
        fail "detect_os returned empty"
    fi
else
    fail "detect_os function not found"
fi

# Test check_disk_space
if type check_disk_space &>/dev/null; then
    if check_disk_space 2>/dev/null; then
        pass "check_disk_space passes"
    else
        fail "check_disk_space failed (disk full?)"
    fi
else
    fail "check_disk_space function not found"
fi

# Test config_set / config_get
if type config_set &>/dev/null && type config_get &>/dev/null; then
    mkdir -p "$XUIFAST_DIR" 2>/dev/null
    config_set "test_key" "test_value" 2>/dev/null
    result=$(config_get "test_key" 2>/dev/null)
    if [ "$result" = "test_value" ]; then
        pass "config_set/config_get roundtrip works"
    else
        fail "config_get returned '$result' instead of 'test_value'"
    fi
else
    fail "config_set/config_get functions not found"
fi

# ── Test 4: Dependencies ──────────────────────────────────────
log "--- Test group: Dependencies ---"

for cmd in curl jq python3 openssl; do
    if command -v "$cmd" &>/dev/null; then
        pass "dependency $cmd found"
    else
        fail "dependency $cmd NOT found"
    fi
done

# Check if expect is available (needed for 3X-UI install)
if command -v expect &>/dev/null; then
    pass "expect found"
else
    fail "expect NOT found — needed for 3X-UI install"
fi

# Check qrencode
if command -v qrencode &>/dev/null; then
    pass "qrencode found"
else
    fail "qrencode NOT found — needed for QR codes"
fi

# ── Test 5: GitHub API (version detection) ────────────────────
log "--- Test group: GitHub API ---"

if type get_latest_2x_version &>/dev/null; then
    ver2=$(get_latest_2x_version 2>/dev/null)
    if [[ "$ver2" =~ ^v2\.[0-9]+\.[0-9]+$ ]]; then
        pass "get_latest_2x_version: $ver2"
    else
        fail "get_latest_2x_version returned: '$ver2'"
    fi
else
    fail "get_latest_2x_version not found"
fi

if type get_latest_3x_version &>/dev/null; then
    ver3=$(get_latest_3x_version 2>/dev/null)
    if [[ "$ver3" =~ ^v3\.[0-9]+\.[0-9]+$ ]] || [ -z "$ver3" ]; then
        pass "get_latest_3x_version: '${ver3:-latest}'"
    else
        fail "get_latest_3x_version returned: '$ver3'"
    fi
else
    fail "get_latest_3x_version not found"
fi

# ── Test 6: Reality domain testing ────────────────────────────
log "--- Test group: Reality domains ---"

if type test_reality_domain &>/dev/null; then
    # Test a known good domain
    if test_reality_domain "www.google.com" 2>/dev/null; then
        pass "test_reality_domain: www.google.com passes"
    else
        fail "test_reality_domain: www.google.com failed"
    fi

    # Test a bad domain
    if ! test_reality_domain "this-domain-does-not-exist-xyz.com" 2>/dev/null; then
        pass "test_reality_domain: bad domain correctly rejected"
    else
        fail "test_reality_domain: bad domain incorrectly accepted"
    fi
else
    fail "test_reality_domain not found"
fi

# ── Test 7: Install dependencies ──────────────────────────────
log "--- Test group: Install dependencies ---"

if type install_dependencies &>/dev/null; then
    if install_dependencies 2>>"$LOG"; then
        pass "install_dependencies completed"
    else
        fail "install_dependencies failed with code $?"
    fi
else
    fail "install_dependencies function not found"
fi

# ── Test 8: API functions existence ───────────────────────────
log "--- Test group: API function signatures ---"

for fn in api_login api_create_reality_inbound api_create_tls_inbound generate_clients generate_all_vless_links setup_api_base; do
    if type "$fn" &>/dev/null; then
        pass "function $fn exists"
    else
        fail "function $fn NOT found"
    fi
done

# ── Test 9: XUI functions existence ───────────────────────────
log "--- Test group: XUI function signatures ---"

for fn in install_3xui extract_credentials save_credentials load_credentials is_xui_installed xui_status start_xui stop_xui restart_xui remove_xui generate_reality_keypair; do
    if type "$fn" &>/dev/null; then
        pass "function $fn exists"
    else
        fail "function $fn NOT found"
    fi
done

# ── Test 10: Website functions ────────────────────────────────
log "--- Test group: Website function signatures ---"

for fn in deploy_website setup_nginx_pro obtain_ssl_certificate setup_lite_nginx; do
    if type "$fn" &>/dev/null; then
        pass "function $fn exists"
    else
        fail "function $fn NOT found"
    fi
done

# ── Summary ───────────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
echo "  Tests: $TESTS  Passed: $PASSED  Failed: $ERRORS" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"

if [ "$ERRORS" -gt 0 ]; then
    echo "RESULT: SOME_TESTS_FAILED" | tee -a "$LOG"
else
    echo "RESULT: ALL_TESTS_PASSED" | tee -a "$LOG"
fi
