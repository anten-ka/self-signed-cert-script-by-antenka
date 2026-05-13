#!/usr/bin/env python3
"""Dump xray inbound config from 3X-UI database for debugging."""
import sqlite3, json, sys

db_path = "/etc/x-ui/x-ui.db"
conn = sqlite3.connect(db_path)
c = conn.cursor()

c.execute("SELECT id, remark, port, protocol, settings, stream_settings, sniffing FROM inbounds")
for row in c.fetchall():
    rid, remark, port, proto, settings_raw, stream_raw, sniff_raw = row
    print(f"=== INBOUND #{rid}: {remark} ===")
    print(f"Port: {port}, Protocol: {proto}")

    settings = json.loads(settings_raw)
    print(f"Clients: {len(settings.get('clients', []))}")
    for cl in settings.get("clients", []):
        print(f"  - {cl.get('email')}: id={cl.get('id')[:8]}... flow='{cl.get('flow', '')}'")
    print(f"Fallbacks: {settings.get('fallbacks', [])}")

    stream = json.loads(stream_raw)
    print(f"\nStream settings:")
    print(json.dumps(stream, indent=2))

    if sniff_raw:
        sniff = json.loads(sniff_raw)
        print(f"\nSniffing: {json.dumps(sniff)}")
    print()

conn.close()
