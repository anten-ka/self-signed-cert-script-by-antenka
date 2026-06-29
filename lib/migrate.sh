#!/bin/bash
# goVLESS — lib/migrate.sh
# ──────────────────────────────────────────────────────────────────────────
# Seamless, in-place upgrades for EXISTING installations.
#
# Design goals:
#   • Never recreate the inbound or its clients — every UUID / subId / email
#     stays exactly as-is, so existing VLESS keys and subscription URLs keep
#     working byte-for-byte (no rescan / no re-subscribe for server-only fixes).
#   • Always take a restorable backup (config.json + x-ui.db) before touching
#     anything, in addition to the git rollback tag.
#   • Be idempotent — running twice changes nothing the second time.
#   • Gate migrations on an integer SCHEMA counter (independent of the
#     human-facing version string), so rc/pre-release version names never
#     confuse the comparison.
#   • Print an ACCURATE, mode-aware summary: only tell users to re-scan /
#     re-subscribe when a migration actually changed the VLESS link.
#
# State that carries over from older versions automatically:
#   • /opt/govless/config.json   — mode, domain, mask_domain, reality keys,
#                                  transport, port, users_count, email …
#   • /etc/x-ui/x-ui.db          — panel creds, inbound, all clients (UUID/subId)
#   • /etc/letsencrypt/…         — Pro-mode certificates
#   Nothing here is regenerated; migrations only PATCH fields in place.
# ──────────────────────────────────────────────────────────────────────────

XUI_DB="${XUI_DB:-/etc/x-ui/x-ui.db}"
GOVLESS_BACKUP_DIR="${GOVLESS_BACKUP_DIR:-${GOVLESS_DIR:-/opt/govless}/backups}"

# Set to 1 by any migration that alters the VLESS link itself
# (port, flow, network, security, sni, pbk, sid, alpn …). Server-only
# migrations (sniffing, rejectUnknownSni, sysctl, nginx) leave it at 0.
MIG_LINK_CHANGED=0
# Set to 1 if at least one migration actually changed something.
MIG_APPLIED=0

# ── Backup config.json + x-ui.db before migrating ───────────────────────────
backup_state() {
    local ts dir
    ts=$(date +%Y%m%d-%H%M%S)
    dir="${GOVLESS_BACKUP_DIR}/${ts}"
    mkdir -p "$dir" 2>/dev/null || return 1
    [ -f "$GOVLESS_CONFIG" ] && cp -a "$GOVLESS_CONFIG" "$dir/config.json" 2>/dev/null
    [ -f "$XUI_DB" ] && cp -a "$XUI_DB" "$dir/x-ui.db" 2>/dev/null
    echo "$dir"
}

# ── Core patch: sniffing + (TLS) rejectUnknownSni, clients untouched ────────
# Operates directly on the x-ui SQLite DB so it is version-agnostic and needs
# no API login. Only the `sniffing` and `stream_settings` columns are written;
# `settings` (the clients array) is never modified.
migrate_db_inbounds() {
    [ -f "$XUI_DB" ] || { log_warning "$(t mig_db_missing)"; return 1; }
    command -v python3 >/dev/null 2>&1 || { log_warning "python3 missing"; return 1; }

    local out rc
    out=$(python3 - "$XUI_DB" <<'PYEOF'
import sqlite3, json, sys
db = sys.argv[1]
con = sqlite3.connect(db)
con.row_factory = sqlite3.Row
cur = con.cursor()
try:
    rows = cur.execute(
        "SELECT id, port, protocol, remark, stream_settings, sniffing "
        "FROM inbounds WHERE port=443 OR remark LIKE 'govless%' "
        "OR remark LIKE 'xuifast%' OR remark LIKE 'VLESS%'"
    ).fetchall()
except Exception as e:
    print("ERR", e); sys.exit(3)

changed = 0
for r in rows:
    iid = r["id"]

    # --- sniffing: drop quic+fakedns, stop rewriting dest (routeOnly) ---
    try:
        sn = json.loads(r["sniffing"]) if r["sniffing"] else {}
    except Exception:
        sn = {}
    new_sn = dict(sn)
    new_sn["enabled"] = True
    new_sn["destOverride"] = ["http", "tls"]
    new_sn["routeOnly"] = True
    new_sn.setdefault("metadataOnly", sn.get("metadataOnly", False))

    # --- stream_settings: rejectUnknownSni for real-domain TLS only ---
    try:
        ss = json.loads(r["stream_settings"]) if r["stream_settings"] else {}
    except Exception:
        ss = {}
    ss_changed = False
    if ss.get("security") == "tls" and isinstance(ss.get("tlsSettings"), dict):
        tls = ss["tlsSettings"]
        if tls.get("serverName") and tls.get("rejectUnknownSni") is not True:
            tls["rejectUnknownSni"] = True
            ss_changed = True

    if sn != new_sn or ss_changed:
        cur.execute(
            "UPDATE inbounds SET sniffing=?, stream_settings=? WHERE id=?",
            (json.dumps(new_sn), json.dumps(ss), iid)
        )
        changed += 1

con.commit()
con.close()
print("OK", changed)
PYEOF
)
    rc=$?
    if [ $rc -ne 0 ]; then
        log_warning "$(t mig_inbound_warn) ($out)"
        return 1
    fi
    local n="${out##* }"
    [ "${n:-0}" -gt 0 ] 2>/dev/null && MIG_APPLIED=1
    return 0
}

# ── Migration runner ────────────────────────────────────────────────────────
# $1 = installed schema (integer)
run_migrations() {
    local from_schema="$1"
    local to_schema="${GOVLESS_SCHEMA:-1}"

    log_step "$(t mig_running)"

    local backup_dir
    backup_dir=$(backup_state) && [ -n "$backup_dir" ] \
        && log_info "$(tf mig_backup_done "$backup_dir")" \
        || log_warning "$(t mig_backup_warn)"

    # ── Schema 1 : connection-quality fixes (SERVER-ONLY) ──────────────────
    #    sniffing routeOnly + drop quic/fakedns, TLS rejectUnknownSni, BBR.
    #    None of these change the VLESS link → MIG_LINK_CHANGED stays 0.
    if [ "${from_schema:-0}" -lt 1 ] 2>/dev/null; then
        if migrate_db_inbounds; then
            log_success "$(t mig_inbound_ok)"
        else
            log_warning "$(t mig_inbound_warn)"
        fi
        # Reuse goVLESS's own BBR helper (now also tunes buffers + MTU probing)
        if declare -F enable_bbr >/dev/null 2>&1; then
            enable_bbr || true
        fi
    fi

    # Restart x-ui so xray reloads the patched inbound(s)
    systemctl restart x-ui >/dev/null 2>&1 || true
    sleep 1

    # Record new schema + version
    config_set_int "schema" "$to_schema" || log_warning "Could not persist schema version (migrations may re-run next start)"
    config_set "version" "$GOVLESS_VERSION"

    print_upgrade_summary
}

# ── Auto-trigger on startup when installed schema is older ───────────────────
maybe_run_migrations() {
    local installed
    installed=$(config_get schema 0)
    [[ "$installed" =~ ^[0-9]+$ ]] || installed=0
    if [ "$installed" -lt "${GOVLESS_SCHEMA:-1}" ]; then
        run_migrations "$installed"
        echo -ne "  $(t press_enter_return) "
        read -r _ || true
    fi
}

# ── Accurate, mode-aware post-upgrade summary ───────────────────────────────
print_upgrade_summary() {
    local mode
    mode=$(config_get mode "lite")

    echo ""
    print_header "$(t mig_done_title)"

    if [ "$MIG_LINK_CHANGED" -eq 1 ]; then
        # A link-changing migration ran → users must act.
        log_warning "$(t mig_action_needed)"
        [ "$mode" = "pro" ] && echo -e "  $(t mig_pro_resub)"
        echo -e "  $(t mig_rescan_key)"
    else
        # Server-only changes → keys & subscriptions are unchanged.
        log_success "$(t mig_transparent)"
    fi
    echo ""
}
