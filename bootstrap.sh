#!/bin/bash
# XUIFAST bootstrap — one-liner installer
# Usage: bash <(curl -sL URL/bootstrap.sh)
set -euo pipefail

REPO="https://github.com/anten-ka/self-signed-cert-script-by-antenka.git"
BRANCH="test"
INSTALL_DIR="/opt/xuifast-installer"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

echo ""
echo -e "  ${CYAN}${BOLD}XUIFAST Installer${NC}"
echo -e "  ${CYAN}─────────────────${NC}"
echo ""

# Root check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "  ${RED}✗${NC} Run as root: ${BOLD}sudo bash bootstrap.sh${NC}"
    exit 1
fi

# Install git if missing
if ! command -v git &>/dev/null; then
    echo -e "  ${CYAN}ℹ${NC}  Installing git..."
    apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq git >/dev/null 2>&1
fi

# Clone or update
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "  ${CYAN}ℹ${NC}  Updating..."
    cd "$INSTALL_DIR"
    git fetch origin "$BRANCH" --quiet 2>/dev/null
    git checkout "$BRANCH" --quiet 2>/dev/null
    git reset --hard "origin/$BRANCH" --quiet 2>/dev/null
else
    echo -e "  ${CYAN}ℹ${NC}  Downloading XUIFAST..."
    rm -rf "$INSTALL_DIR"
    git clone -b "$BRANCH" --depth 1 "$REPO" "$INSTALL_DIR" 2>/dev/null
fi

if [ ! -f "$INSTALL_DIR/xuifast.sh" ]; then
    echo -e "  ${RED}✗${NC} Download failed"
    exit 1
fi

echo -e "  ${GREEN}✓${NC}  Ready"
echo ""

# Run
cd "$INSTALL_DIR"
exec bash xuifast.sh "$@"
