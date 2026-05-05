#!/bin/bash
# XUIFAST v3.0.0 — i18n engine
# Usage:
#   source lib/i18n.sh
#   load_language "ru"
#   echo "$(t menu_install)"
#   printf "$(tf greeting)\n" "$name"

declare -gA I18N
LANG_CODE="${LANG_CODE:-en}"

# ── Load a language ─────────────────────────────────────────────────────
load_language() {
    local lang="${1:-en}"
    [[ "$lang" =~ ^[a-z]{2}$ ]] || lang="en"

    local lang_dir
    lang_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lang"
    local lang_file="${lang_dir}/${lang}.sh"

    if [ ! -f "$lang_file" ]; then
        lang_file="${lang_dir}/en.sh"
        lang="en"
    fi

    if [ -f "$lang_file" ]; then
        I18N=()
        # shellcheck disable=SC1090
        source "$lang_file"
        LANG_CODE="$lang"
        return 0
    fi
    return 1
}

# ── Translate ───────────────────────────────────────────────────────────
t() {
    local key="$1"
    echo "${I18N[$key]:-$key}"
}

# ── Translate + printf formatting ───────────────────────────────────────
tf() {
    local key="$1"; shift
    local fmt="${I18N[$key]:-}"
    if [ -z "$fmt" ]; then
        # Key not found — print key name and args literally
        echo "$key $*"
        return
    fi
    # shellcheck disable=SC2059
    printf "$fmt" "$@"
}

# ── Get current language ────────────────────────────────────────────────
get_language() { echo "$LANG_CODE"; }

# ── Detect saved language ───────────────────────────────────────────────
detect_language() {
    local cfg="${XUIFAST_CONFIG:-/opt/xuifast/config.json}"
    local lang=""
    if [ -f "$cfg" ] && command -v jq &>/dev/null; then
        lang=$(jq -r '.language // empty' "$cfg" 2>/dev/null)
    fi
    if [ -z "$lang" ]; then
        local marker="${XUIFAST_DIR:-/opt/xuifast}/.language"
        [ -f "$marker" ] && lang=$(head -c 2 "$marker" 2>/dev/null | tr -d '[:space:]')
    fi
    [[ "$lang" =~ ^(en|ru)$ ]] || lang="en"
    echo "$lang"
}

# ── Persist language ────────────────────────────────────────────────────
save_language() {
    local lang="$1"
    [[ "$lang" =~ ^(en|ru)$ ]] || return 1
    mkdir -p "${XUIFAST_DIR:-/opt/xuifast}" 2>/dev/null
    echo "$lang" > "${XUIFAST_DIR:-/opt/xuifast}/.language" 2>/dev/null

    local cfg="${XUIFAST_CONFIG:-/opt/xuifast/config.json}"
    if [ -f "$cfg" ] && command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp) || return 1
        if jq --arg l "$lang" '. + {language: $l}' "$cfg" > "$tmp" 2>/dev/null; then
            mv "$tmp" "$cfg"
            chmod 600 "$cfg"
        else
            rm -f "$tmp"
        fi
    fi
}

# ── Interactive language picker ─────────────────────────────────────────
pick_language_interactive() {
    echo "" >&2
    echo "  ┌──────────────────────────────────────────┐" >&2
    echo "  │  Select language / Выберите язык         │" >&2
    echo "  ├──────────────────────────────────────────┤" >&2
    echo "  │  1) English                              │" >&2
    echo "  │  2) Русский                              │" >&2
    echo "  └──────────────────────────────────────────┘" >&2
    echo -n "  ▸ " >&2
    local ch
    read -r ch
    case "$ch" in
        1|en|EN|english|English) echo "en" ;;
        2|ru|RU|русский|Русский) echo "ru" ;;
        *) echo "en" ;;
    esac
}
