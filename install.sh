#!/bin/bash
set -e

apt update && apt install -y git curl openssl qrencode systemd

REPO_DIR="$HOME/self-signed-cert-script-by-antenka"

if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR" && git pull
else
    git clone https://github.com/anten-ka/self-signed-cert-script-by-antenka.git "$REPO_DIR"
fi

cd "$REPO_DIR"
chmod +x self_signed_cert.sh
./self_signed_cert.sh
