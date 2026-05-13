#!/bin/bash
# Test VLESS TLS connection using local xray client
# Run on the VPS itself to validate the connection works
set +e

XRAY="/usr/local/x-ui/bin/xray-linux-amd64"
CLIENT_CONF="/tmp/xray_client.json"
CLIENT_LOG="/tmp/xray_client.log"
SOCKS_PORT=10808

# Kill any old test client
pkill -f "xray.*xray_client" 2>/dev/null
sleep 1

echo "=== VLESS TLS Client Test $(date -Iseconds) ==="

# Create client config
cat > "$CLIENT_CONF" << 'EOF'
{
  "log": {
    "loglevel": "debug"
  },
  "inbounds": [{
    "port": 10808,
    "listen": "127.0.0.1",
    "protocol": "socks",
    "settings": {"udp": true}
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "anten-ka.com",
        "port": 443,
        "users": [{
          "id": "94e98525-2dd7-4357-bb7f-872b4e349f09",
          "flow": "xtls-rprx-vision",
          "encryption": "none"
        }]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "serverName": "anten-ka.com",
        "fingerprint": "chrome",
        "alpn": ["h2", "http/1.1"]
      }
    }
  }]
}
EOF

echo ">>> Starting xray client (socks5 on $SOCKS_PORT)..."
"$XRAY" run -c "$CLIENT_CONF" > "$CLIENT_LOG" 2>&1 &
CLIENT_PID=$!
sleep 3

echo ">>> Xray client PID: $CLIENT_PID"
echo ">>> Xray client log:"
cat "$CLIENT_LOG"
echo ""

# Test 1: Check socks port is open
if ss -tlnp | grep -q ":${SOCKS_PORT} "; then
    echo ">>> SOCKS port $SOCKS_PORT: OPEN"
else
    echo ">>> SOCKS port $SOCKS_PORT: NOT OPEN — xray client failed"
    cat "$CLIENT_LOG"
    kill $CLIENT_PID 2>/dev/null
    exit 1
fi

# Test 2: Try to reach google through the proxy
echo ""
echo ">>> Test: curl google.com through VLESS proxy..."
RESULT=$(curl -x socks5h://127.0.0.1:${SOCKS_PORT} -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://www.google.com 2>&1)
echo ">>> Google result: HTTP $RESULT"

# Test 3: Try httpbin
echo ""
echo ">>> Test: curl httpbin.org/ip through VLESS proxy..."
IP_RESULT=$(curl -x socks5h://127.0.0.1:${SOCKS_PORT} -s --connect-timeout 15 https://httpbin.org/ip 2>&1)
echo ">>> IP result: $IP_RESULT"

# Test 4: Check server-side xray logs for errors
echo ""
echo ">>> Server xray log (last 10 lines):"
journalctl -u x-ui --no-pager -n 10 2>/dev/null | grep -i "xray\|error\|warn\|reject\|fail" || echo "(no relevant entries)"

# Test 5: Check client log for errors
echo ""
echo ">>> Client xray log (errors/warnings):"
grep -iE "error|warn|fail|reject|refused" "$CLIENT_LOG" || echo "(no errors)"

# Cleanup
kill $CLIENT_PID 2>/dev/null
wait $CLIENT_PID 2>/dev/null
echo ""
echo "=== TEST DONE ==="
