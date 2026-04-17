#!/bin/bash
# XUIFAST Installer Bootstrap
# Usage: curl -sL https://is.gd/xuifast | sudo bash
set -e

# Ensure root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Run as root (sudo)!"
    exit 1
fi

# Install minimal deps for bootstrap
apt-get update -qq && apt-get install -y -qq git curl >/dev/null 2>&1

# Clone or update repo
REPO_DIR="$HOME/self-signed-cert-script-by-antenka"
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR" && git pull -q
else
    git clone -q https://github.com/anten-ka/self-signed-cert-script-by-antenka.git "$REPO_DIR"
fi

cd "$REPO_DIR"
chmod +x xuifast.sh
./xuifast.sh
