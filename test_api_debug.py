#!/usr/bin/env python3
"""Debug 3X-UI API login — test CSRF token approach."""
import requests
import re
import os

port = os.environ.get("XUI_PORT", "38465")
webpath = os.environ.get("XUI_WEB_PATH", "/YcKFYzaPrAlNs0ZDzr")
user = os.environ.get("XUI_USER", "IZeqm6fJnT")
passwd = os.environ.get("XUI_PASS", "hA7AOEwCH3")

base = f"http://127.0.0.1:{port}{webpath}"
print(f"Base URL: {base}")
print(f"Creds: {user} / {passwd}")

# Step 1: GET page, extract CSRF token
s = requests.Session()
r1 = s.get(f"{base}/")
print(f"\nGET /: {r1.status_code}")
m = re.search(r'csrf-token" content="([^"]+)"', r1.text)
csrf = m.group(1) if m else ""
print(f"CSRF token: {csrf[:30]}..." if csrf else "No CSRF token found!")

# Step 2: POST login with CSRF header
headers = {}
if csrf:
    headers["X-CSRF-Token"] = csrf
r2 = s.post(f"{base}/login", data={"username": user, "password": passwd}, headers=headers)
print(f"\nPOST /login: {r2.status_code}")
print(f"Body: {r2.text[:300]}")

if r2.status_code == 200:
    data = r2.json()
    print(f"Success: {data.get('success')}")
    if data.get("success"):
        print("\nLogin WORKS! Testing API...")
        # Refresh CSRF after login
        r3 = s.get(f"{base}/")
        m2 = re.search(r'csrf-token" content="([^"]+)"', r3.text)
        csrf2 = m2.group(1) if m2 else csrf
        headers2 = {"X-CSRF-Token": csrf2} if csrf2 else {}
        # Try getting inbounds list
        r4 = s.post(f"{base}/panel/api/inbounds/list", headers=headers2)
        print(f"GET inbounds: {r4.status_code}")
        print(f"Body: {r4.text[:200]}")
