#!/usr/bin/env python3
"""Debug 3X-UI API login — test different approaches."""
import requests
import sys
import os

# Read credentials from env or defaults
port = os.environ.get("XUI_PORT", "38465")
webpath = os.environ.get("XUI_WEB_PATH", "/YcKFYzaPrAlNs0ZDzr")
user = os.environ.get("XUI_USER", "IZeqm6fJnT")
passwd = os.environ.get("XUI_PASS", "hA7AOEwCH3")

base = f"http://127.0.0.1:{port}{webpath}"
print(f"Base URL: {base}")
print(f"Creds: {user} / {passwd}")

# Test 1: Direct POST (like our current code)
print("\n=== Test 1: Direct POST ===")
r = requests.post(f"{base}/login", data={"username": user, "password": passwd})
print(f"Status: {r.status_code}")
print(f"Headers: {dict(r.headers)}")
print(f"Body: {r.text[:200]}")

# Test 2: Session-based (GET first, then POST)
print("\n=== Test 2: Session GET+POST ===")
s = requests.Session()
r1 = s.get(f"{base}/")
print(f"GET /: {r1.status_code}")
print(f"Session cookies: {dict(s.cookies)}")
r2 = s.post(f"{base}/login", data={"username": user, "password": passwd})
print(f"POST /login: {r2.status_code}")
print(f"Body: {r2.text[:200]}")

# Test 3: With X-Requested-With header
print("\n=== Test 3: XHR header ===")
s2 = requests.Session()
s2.get(f"{base}/")
r3 = s2.post(f"{base}/login", data={"username": user, "password": passwd},
             headers={"X-Requested-With": "XMLHttpRequest"})
print(f"Status: {r3.status_code}")
print(f"Body: {r3.text[:200]}")

# Test 4: JSON body instead of form
print("\n=== Test 4: JSON body ===")
s3 = requests.Session()
s3.get(f"{base}/")
r4 = s3.post(f"{base}/login", json={"username": user, "password": passwd})
print(f"Status: {r4.status_code}")
print(f"Body: {r4.text[:200]}")

# Test 5: Check if there's a CSRF token in session cookie
print("\n=== Test 5: Cookie + Referer ===")
s4 = requests.Session()
s4.get(f"{base}/")
r5 = s4.post(f"{base}/login", data={"username": user, "password": passwd},
             headers={"Referer": f"{base}/", "Origin": f"http://127.0.0.1:{port}"})
print(f"Status: {r5.status_code}")
print(f"Body: {r5.text[:200]}")

# Test 6: Check HTML for CSRF meta tag
print("\n=== Test 6: HTML analysis ===")
html = requests.get(f"{base}/").text
for line in html.split("\n"):
    if "csrf" in line.lower() or "token" in line.lower() or "meta" in line.lower():
        print(f"  Found: {line.strip()[:120]}")
