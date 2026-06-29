#!/bin/bash
# goVLESS — Copyright (c) 2025-2026 anten-ka. All rights reserved.
# Licensed under the goVLESS Source-Available License (see the LICENSE file).
#
# Entry point for the public Anten-ka install command:
#   git clone https://github.com/anten-ka/self-signed-cert-script-by-antenka.git
#   cd self-signed-cert-script-by-antenka && chmod +x self_signed_cert.sh && sudo ./self_signed_cert.sh
#
# This repository is a SELF-CONTAINED public clone, so we install straight from
# the local files here — no token, no re-download of the app. We copy the
# installer to a stable directory (so the `govless` command keeps working after
# this folder is deleted), then launch it.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: запустите через sudo  →  sudo ./self_signed_cert.sh" >&2
    exit 1
fi

SRC="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DEST="/opt/govless-installer"

if [ ! -f "$SRC/govless.sh" ] || [ ! -d "$SRC/lib" ]; then
    echo "Ошибка: рядом нет govless.sh / lib. Клонируйте репозиторий целиком." >&2
    exit 1
fi

mkdir -p "$DEST"
cp -rf "$SRC/govless.sh" "$SRC/lib" "$DEST"/ 2>/dev/null || true
[ -f "$SRC/bootstrap.sh" ] && cp -f "$SRC/bootstrap.sh" "$DEST"/ 2>/dev/null || true
chmod +x "$DEST/govless.sh" 2>/dev/null || true

# stdin is a real terminal here (user runs ./self_signed_cert.sh), so the
# installer's interactive prompts work directly.
exec bash "$DEST/govless.sh" "$@"
