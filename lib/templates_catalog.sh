#!/bin/bash
# XUIFAST v3.0.0 — website templates catalog
# Pick from ~1800 templates, preview links, git sparse-checkout downloads,
# + custom git URL templates (user-supplied public repos)

# Look for catalog in XUIFAST_DIR first, then in the script's own directory
_script_dir_tc="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
if [ -f "${XUIFAST_DIR:-/opt/xuifast}/templates_catalog.json" ]; then
    CATALOG_FILE="${XUIFAST_DIR:-/opt/xuifast}/templates_catalog.json"
elif [ -f "${_script_dir_tc}/templates_catalog.json" ]; then
    CATALOG_FILE="${_script_dir_tc}/templates_catalog.json"
else
    CATALOG_FILE="${XUIFAST_DIR:-/opt/xuifast}/templates_catalog.json"
fi
TEMPLATES_CACHE="/tmp/xuifast_templates"

# Custom git template limits
CUSTOM_GIT_MAX_SIZE_MB=100
CUSTOM_GIT_CLONE_TIMEOUT=90

# ── Catalog loading ────────────────────────────────────────────────────
load_catalog() {
    if [ ! -f "$CATALOG_FILE" ]; then
        if type tf &>/dev/null; then
            log_error "$(tf templates_catalog_not_found "$CATALOG_FILE")"
        else
            log_error "Templates catalog not found: $CATALOG_FILE"
        fi
        return 1
    fi
    return 0
}

# ── Categories ─────────────────────────────────────────────────────────
get_categories() {
    jq -r '.categories[] | "\(.id)|\(.name)|\(.icon)|\(.templates | length)"' "$CATALOG_FILE" 2>/dev/null
}

get_category_name() {
    local cat_id="$1"
    jq -r ".categories[] | select(.id == \"$cat_id\") | .name" "$CATALOG_FILE" 2>/dev/null
}

# ── Templates in a category ────────────────────────────────────────────
get_templates_by_category() {
    local cat_id="$1"
    jq -r ".categories[] | select(.id == \"$cat_id\") | .templates[] | \"\(.id)|\(.name)|\(.source)|\(.preview_url)\"" "$CATALOG_FILE" 2>/dev/null
}

# ── Template info ──────────────────────────────────────────────────────
get_template_info() {
    local tpl_id="$1"
    jq ".categories[].templates[] | select(.id == \"$tpl_id\")" "$CATALOG_FILE" 2>/dev/null
}

get_template_field() {
    local tpl_id="$1"
    local field="$2"
    jq -r ".categories[].templates[] | select(.id == \"$tpl_id\") | .$field" "$CATALOG_FILE" 2>/dev/null
}

# ── Interactive category picker (returns category id or special __custom_git__/__random__) ──
select_category() {
    load_catalog || return 1

    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t templates_categories)${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2

    # First item: custom git URL template
    printf "  ${CYAN}%2d)${NC} ${GREEN}%s${NC}\n" 1 "$(t templates_custom_git)" >&2

    local cats=()
    local i=2
    while IFS='|' read -r id name icon count; do
        [ "$count" -eq 0 ] && continue
        local emoji
        case "$icon" in
            briefcase)     emoji="🏢" ;;
            shopping-cart) emoji="🛒" ;;
            heart)         emoji="🏥" ;;
            book)          emoji="🎓" ;;
            palette)       emoji="📸" ;;
            home)          emoji="🏠" ;;
            utensils)      emoji="🍕" ;;
            rocket)        emoji="🎨" ;;
            chart-bar)     emoji="🔧" ;;
            *)             emoji="📄" ;;
        esac
        printf "  ${CYAN}%2d)${NC} ${emoji} %-30s ${DIM}$(tf templates_count_fmt "$count")${NC}\n" "$i" "$name" >&2
        cats+=("$id")
        ((i++))
    done < <(get_categories)

    printf "  ${CYAN}%2d)${NC} %s\n" "$i" "$(t templates_random)" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo -ne "  ${WHITE}$(t choose):${NC} " >&2
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        log_error "$(t invalid_choice)"
        return 1
    fi

    # Custom git URL
    if [ "$choice" -eq 1 ]; then
        echo "__custom_git__"
        return 0
    fi

    # Random
    if [ "$choice" -eq "$i" ]; then
        local random_cat="${cats[$((RANDOM % ${#cats[@]}))]}"
        echo "$random_cat"
        return 0
    fi

    # Regular category (offset by 1 because item 1 is custom git)
    if [ "$choice" -ge 2 ] && [ "$choice" -lt "$i" ]; then
        echo "${cats[$((choice-2))]}"
        return 0
    fi

    log_error "$(t invalid_choice)"
    return 1
}

# ── Interactive template picker ────────────────────────────────────────
select_template() {
    local cat_id="$1"
    local cat_name
    cat_name=$(get_category_name "$cat_id")

    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(tf templates_list "$cat_name")${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..60})${NC}" >&2

    local tpls=()
    local i=1
    while IFS='|' read -r id name source preview; do
        printf "  ${CYAN}%2d)${NC} %-30s ${DIM}[%s]${NC}\n" "$i" "$name" "$source" >&2
        tpls+=("$id")
        ((i++))
    done < <(get_templates_by_category "$cat_id")

    if [ ${#tpls[@]} -eq 0 ]; then
        log_info "$(t templates_cat_empty)"
        return 1
    fi

    echo -e "  ${DIM}$(printf '─%.0s' {1..60})${NC}" >&2
    echo -ne "  ${WHITE}$(t choose) (1-$((i-1))):${NC} " >&2
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        local selected_id="${tpls[$((choice-1))]}"

        # Show preview
        show_template_preview "$selected_id" || return 1

        echo "$selected_id"
        return 0
    fi

    log_error "$(t invalid_choice)"
    return 1
}

# ── Template preview ───────────────────────────────────────────────────
show_template_preview() {
    local tpl_id="$1"
    local info
    info=$(get_template_info "$tpl_id")

    local name source preview_url repo_url description
    name=$(echo "$info" | jq -r '.name')
    source=$(echo "$info" | jq -r '.source')
    preview_url=$(echo "$info" | jq -r '.preview_url // empty')
    repo_url=$(echo "$info" | jq -r '.repo_url // empty')
    description=$(echo "$info" | jq -r '.description // "—"')

    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t templates_preview_title)${NC}" >&2
    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo -e "  ${WHITE}$(t templates_name)${NC}  $name" >&2
    echo -e "  ${WHITE}$(t templates_source)${NC}  $source" >&2
    echo -e "  ${WHITE}$(t templates_description)${NC}  $description" >&2

    if [ -n "$preview_url" ]; then
        echo "" >&2
        echo -e "  ${GREEN}$(t templates_preview)${NC} ${CYAN}${preview_url}${NC}" >&2
        echo -e "  ${DIM}$(t templates_preview_hint)${NC}" >&2
    fi

    if [ -n "$repo_url" ]; then
        echo -e "  ${DIM}$(t templates_repo)    ${repo_url}${NC}" >&2
    fi

    # Thanks
    echo "" >&2
    echo -e "  ${MAGENTA}$(tf templates_thanks "$source")${NC}" >&2

    echo -e "  ${DIM}$(printf '─%.0s' {1..55})${NC}" >&2
    echo "" >&2

    if ! confirm "$(t templates_install_this)"; then
        return 1
    fi
    return 0
}

# ── Template download (from catalog) ───────────────────────────────────
download_template() {
    local tpl_id="$1"
    local output_dir="${2:-$TEMPLATES_CACHE}"
    local info
    info=$(get_template_info "$tpl_id")

    local repo_url sparse_path source name
    repo_url=$(echo "$info" | jq -r '.repo_url')
    sparse_path=$(echo "$info" | jq -r '.sparse_path')
    source=$(echo "$info" | jq -r '.source')
    name=$(echo "$info" | jq -r '.name')

    local clone_dir="$output_dir/${tpl_id}"
    rm -rf "$clone_dir"
    mkdir -p "$clone_dir"

    log_info "$(tf templates_downloading "$name")"

    # HTML5 UP — one repo with folders
    if [ "$source" = "html5up" ]; then
        local tmp_clone="/tmp/html5up_clone_$$"
        rm -rf "$tmp_clone"

        # Sparse checkout
        git clone --depth 1 --filter=blob:none --sparse "$repo_url" "$tmp_clone" 2>/dev/null
        if [ $? -ne 0 ]; then
            # Fallback: full clone
            git clone --depth 1 "$repo_url" "$tmp_clone" 2>/dev/null
        fi

        if [ -d "$tmp_clone" ]; then
            cd "$tmp_clone" && git sparse-checkout set "$sparse_path" 2>/dev/null
            if [ -d "$tmp_clone/$sparse_path" ]; then
                cp -r "$tmp_clone/$sparse_path"/* "$clone_dir/"
            fi
            cd - >/dev/null
        fi
        rm -rf "$tmp_clone"

    # learning-zone — one big repo
    elif [ "$source" = "learning-zone" ]; then
        local tmp_clone="/tmp/lz_clone_$$"
        rm -rf "$tmp_clone"

        git clone --depth 1 --filter=blob:none --sparse "$repo_url" "$tmp_clone" 2>/dev/null
        if [ $? -ne 0 ]; then
            git clone --depth 1 "$repo_url" "$tmp_clone" 2>/dev/null
        fi

        if [ -d "$tmp_clone" ]; then
            cd "$tmp_clone" && git sparse-checkout set "$sparse_path" 2>/dev/null
            if [ -d "$tmp_clone/$sparse_path" ]; then
                cp -r "$tmp_clone/$sparse_path"/* "$clone_dir/"
            fi
            cd - >/dev/null
        fi
        rm -rf "$tmp_clone"

    # StartBootstrap — each template in its own repo
    elif [ "$source" = "startbootstrap" ]; then
        local sb_tmp="/tmp/sb_clone_$$"
        rm -rf "$sb_tmp"
        git clone --depth 1 "$repo_url" "$sb_tmp" 2>/dev/null
        if [ -d "$sb_tmp" ]; then
            rm -rf "$sb_tmp/.git"
            # StartBootstrap stores production files in dist/
            if [ -f "$sb_tmp/dist/index.html" ]; then
                cp -r "$sb_tmp/dist/"* "$clone_dir/"
            elif [ -f "$sb_tmp/index.html" ]; then
                cp -r "$sb_tmp/"* "$clone_dir/"
            else
                local found_index
                found_index=$(find "$sb_tmp" -name "index.html" -type f 2>/dev/null | head -1)
                if [ -n "$found_index" ]; then
                    local found_dir
                    found_dir=$(dirname "$found_index")
                    cp -r "$found_dir/"* "$clone_dir/"
                fi
            fi
        fi
        rm -rf "$sb_tmp"

    # ThemeWagon / ColorlibHQ — each template in its own repo
    elif [ "$source" = "themewagon" ] || [ "$source" = "colorlib" ]; then
        local tw_tmp="/tmp/tw_clone_$$"
        rm -rf "$tw_tmp"
        git clone --depth 1 "$repo_url" "$tw_tmp" 2>/dev/null
        if [ -d "$tw_tmp" ]; then
            rm -rf "$tw_tmp/.git"
            if [ -f "$tw_tmp/dist/index.html" ]; then
                cp -r "$tw_tmp/dist/"* "$clone_dir/"
            elif [ -f "$tw_tmp/index.html" ]; then
                cp -r "$tw_tmp/"* "$clone_dir/"
            else
                local found_index
                found_index=$(find "$tw_tmp" -name "index.html" -type f -maxdepth 3 2>/dev/null | head -1)
                if [ -n "$found_index" ]; then
                    local found_dir
                    found_dir=$(dirname "$found_index")
                    cp -r "$found_dir/"* "$clone_dir/"
                fi
            fi
        fi
        rm -rf "$tw_tmp"

    # dawidolko — one big repo with folders (similar to learning-zone)
    elif [ "$source" = "dawidolko" ]; then
        local tmp_clone="/tmp/dw_clone_$$"
        rm -rf "$tmp_clone"
        git clone --depth 1 --filter=blob:none --sparse "$repo_url" "$tmp_clone" 2>/dev/null
        if [ $? -ne 0 ]; then
            git clone --depth 1 "$repo_url" "$tmp_clone" 2>/dev/null
        fi
        if [ -d "$tmp_clone" ]; then
            cd "$tmp_clone" && git sparse-checkout set "$sparse_path" 2>/dev/null
            if [ -d "$tmp_clone/$sparse_path" ]; then
                cp -r "$tmp_clone/$sparse_path"/* "$clone_dir/"
            fi
            cd - >/dev/null
        fi
        rm -rf "$tmp_clone"
    fi

    # Check result
    if [ -f "$clone_dir/index.html" ]; then
        log_success "$(tf templates_downloaded "$name")"
        echo "$clone_dir"
        return 0
    else
        # fallback: find index.html in subfolders (non-standard structure)
        local fallback_index
        fallback_index=$(find "$clone_dir" -name "index.html" -type f 2>/dev/null | head -1)
        if [ -n "$fallback_index" ]; then
            local fallback_dir
            fallback_dir=$(dirname "$fallback_index")
            if [ "$fallback_dir" != "$clone_dir" ]; then
                cp -r "$fallback_dir/"* "$clone_dir/"
                log_success "$(tf templates_downloaded_subfolder "$name")"
                echo "$clone_dir"
                return 0
            fi
        fi
        log_error "$(t templates_no_index)"
        log_dim "$(tf templates_path "$clone_dir")"
        ls -la "$clone_dir" 2>/dev/null >&2
        return 1
    fi
}

# ── Custom git URL helpers ─────────────────────────────────────────────

# Validate a user-supplied git URL
# Accepts: https://host/path[.git][@branch]
# Rejects: ssh://, git://, file://, absolute file paths
_validate_custom_git_url() {
    local url="$1"
    # Must begin with https://
    [[ "$url" =~ ^https:// ]] || return 1
    # Reject shell metacharacters that could be exploited
    [[ "$url" =~ [[:space:]\;\`\$\(\)\<\>\|\\\&] ]] && return 1
    # Reasonable length limit
    [ "${#url}" -gt 512 ] && return 1
    return 0
}

# Parse URL → sets CUSTOM_GIT_CLEAN and CUSTOM_GIT_BRANCH globals
_parse_custom_git_url() {
    local url="$1"
    CUSTOM_GIT_CLEAN=""
    CUSTOM_GIT_BRANCH=""
    # Handle trailing @branch
    if [[ "$url" =~ ^(https://[^@]+)@([A-Za-z0-9._/-]+)$ ]]; then
        CUSTOM_GIT_CLEAN="${BASH_REMATCH[1]}"
        CUSTOM_GIT_BRANCH="${BASH_REMATCH[2]}"
    else
        CUSTOM_GIT_CLEAN="$url"
    fi
    # Strip trailing slash
    CUSTOM_GIT_CLEAN="${CUSTOM_GIT_CLEAN%/}"
    # Append .git if missing (works better with git clone on some hosts)
    if [[ ! "$CUSTOM_GIT_CLEAN" =~ \.git$ ]]; then
        CUSTOM_GIT_CLEAN="${CUSTOM_GIT_CLEAN}.git"
    fi
}

# Check repo size (in MB) by inspecting cloned directory
_clone_dir_size_mb() {
    local dir="$1"
    du -sm "$dir" 2>/dev/null | awk '{print $1}'
}

# ── Show detailed help for custom git template ─────────────────────────
show_custom_git_help() {
    local line
    line=$(printf '─%.0s' $(seq 1 60))
    echo "" >&2
    echo -e "  ${BOLD}${GREEN}$(t custom_git_title)${NC}" >&2
    echo -e "  ${DIM}${line}${NC}" >&2
    echo -e "  $(t custom_git_help_1)" >&2
    echo -e "  $(t custom_git_help_2)" >&2
    echo -e "  $(t custom_git_help_3)" >&2
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t custom_git_formats)${NC}" >&2
    echo -e "  ${CYAN}$(t custom_git_fmt_github)${NC}" >&2
    echo -e "  ${CYAN}$(t custom_git_fmt_gitlab)${NC}" >&2
    echo -e "  ${CYAN}$(t custom_git_fmt_gitext)${NC}" >&2
    echo -e "  ${CYAN}$(t custom_git_fmt_branch)${NC}" >&2
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t custom_git_auto_detect)${NC}" >&2
    echo -e "  $(t custom_git_auto_1)" >&2
    echo -e "  $(t custom_git_auto_2)" >&2
    echo -e "  $(t custom_git_auto_3)" >&2
    echo -e "  $(t custom_git_auto_4)" >&2
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t custom_git_requirements)${NC}" >&2
    echo -e "  ${YELLOW}$(t custom_git_req_1)${NC}" >&2
    echo -e "  ${YELLOW}$(t custom_git_req_2)${NC}" >&2
    echo -e "  ${YELLOW}$(t custom_git_req_3)${NC}" >&2
    echo -e "  ${YELLOW}$(t custom_git_req_4)${NC}" >&2
    echo "" >&2
    echo -e "  ${BOLD}${WHITE}$(t custom_git_examples)${NC}" >&2
    echo -e "  ${DIM}$(t custom_git_ex_1)${NC}" >&2
    echo -e "  ${DIM}$(t custom_git_ex_2)${NC}" >&2
    echo -e "  ${DIM}${line}${NC}" >&2
    echo "" >&2
}

# ── Download a custom git template ─────────────────────────────────────
# Prompts user for a URL (unless passed), clones, detects index.html,
# copies result into $output_dir/custom_<hash>, echoes the final path.
download_custom_git_template() {
    local url="${1:-}"
    local output_dir="${2:-$TEMPLATES_CACHE}"

    show_custom_git_help

    if [ -z "$url" ]; then
        echo -ne "  ${WHITE}$(t custom_git_enter_url)${NC} " >&2
        read -r url
        url=$(echo "$url" | tr -d '\r\n[:space:]')
    fi

    if [ -z "$url" ]; then
        log_error "$(t custom_git_empty)"
        return 1
    fi

    if ! _validate_custom_git_url "$url"; then
        log_error "$(t custom_git_bad_url)"
        return 1
    fi

    _parse_custom_git_url "$url"
    local clean_url="$CUSTOM_GIT_CLEAN"
    local branch="$CUSTOM_GIT_BRANCH"

    # Stable-ish directory name from a hash of the original URL
    local hash
    hash=$(echo -n "$url" | md5sum 2>/dev/null | awk '{print $1}' | head -c 10)
    [ -z "$hash" ] && hash=$(date +%s)
    local tpl_id="custom_${hash}"
    local clone_dir="$output_dir/${tpl_id}"
    local tmp_clone="/tmp/custom_git_clone_$$"

    rm -rf "$clone_dir" "$tmp_clone"
    mkdir -p "$clone_dir"

    log_info "$(t custom_git_cloning)"

    # Clone with timeout so a hung server can't freeze the installer
    local clone_status=0
    local git_args=("clone" "--depth" "1")
    [ -n "$branch" ] && git_args+=("--branch" "$branch")
    git_args+=("$clean_url" "$tmp_clone")

    if command -v timeout &>/dev/null; then
        timeout "$CUSTOM_GIT_CLONE_TIMEOUT" git "${git_args[@]}" 2>/tmp/custom_git_err_$$
        clone_status=$?
    else
        git "${git_args[@]}" 2>/tmp/custom_git_err_$$
        clone_status=$?
    fi

    if [ $clone_status -ne 0 ] || [ ! -d "$tmp_clone" ]; then
        local err_msg
        err_msg=$(head -3 "/tmp/custom_git_err_$$" 2>/dev/null | tr '\n' ' ')
        rm -f "/tmp/custom_git_err_$$"
        rm -rf "$tmp_clone" "$clone_dir"
        log_error "$(tf custom_git_clone_failed "${err_msg:-$clone_status}")"
        return 1
    fi
    rm -f "/tmp/custom_git_err_$$"

    # Drop .git before measuring size (we only care about payload)
    rm -rf "$tmp_clone/.git"

    # Size guard
    local size_mb
    size_mb=$(_clone_dir_size_mb "$tmp_clone")
    if [ -n "$size_mb" ] && [ "$size_mb" -gt "$CUSTOM_GIT_MAX_SIZE_MB" ]; then
        rm -rf "$tmp_clone" "$clone_dir"
        log_error "$(tf custom_git_too_big "${size_mb}MB")"
        return 1
    fi

    log_info "$(t custom_git_scanning)"

    # Priority list of common static-site output folders
    local candidates=("" "dist" "public" "build" "_site" "site" "docs" "out" "www")
    local found_dir=""
    for sub in "${candidates[@]}"; do
        local try_dir="$tmp_clone"
        [ -n "$sub" ] && try_dir="$tmp_clone/$sub"
        if [ -f "$try_dir/index.html" ]; then
            found_dir="$try_dir"
            break
        fi
    done

    # Fallback: search for any index.html in the repo (shallow depth first)
    if [ -z "$found_dir" ]; then
        local fallback_index
        fallback_index=$(find "$tmp_clone" -maxdepth 4 -name "index.html" -type f 2>/dev/null | head -1)
        if [ -n "$fallback_index" ]; then
            found_dir=$(dirname "$fallback_index")
        fi
    fi

    if [ -z "$found_dir" ] || [ ! -f "$found_dir/index.html" ]; then
        rm -rf "$tmp_clone" "$clone_dir"
        log_error "$(t custom_git_no_index)"
        return 1
    fi

    # Show what we found (human-friendly relative path)
    local rel_path="${found_dir#$tmp_clone}"
    rel_path="${rel_path#/}"
    [ -z "$rel_path" ] && rel_path="(root)"
    log_dim "$(tf custom_git_found_at "$rel_path")"

    # Copy the detected directory as the new template
    cp -r "$found_dir"/* "$clone_dir/" 2>/dev/null
    cp -r "$found_dir"/.[!.]* "$clone_dir/" 2>/dev/null

    rm -rf "$tmp_clone"

    if [ ! -f "$clone_dir/index.html" ]; then
        rm -rf "$clone_dir"
        log_error "$(t custom_git_no_index)"
        return 1
    fi

    # Remember the URL so users can see what template they used
    echo "$url" > "$clone_dir/.custom_git_source" 2>/dev/null

    log_success "$(tf custom_git_installed "$url")"
    echo "$clone_dir"
    return 0
}

# ── Full interactive template selection ───────────────────────────────
interactive_template_selection() {
    load_catalog || return 1

    # Category selection
    local cat_id
    cat_id=$(select_category)
    [ $? -ne 0 ] && return 1

    # Custom git URL path
    if [ "$cat_id" = "__custom_git__" ]; then
        local template_dir
        template_dir=$(download_custom_git_template)
        [ $? -ne 0 ] && return 1
        echo "$template_dir"
        return 0
    fi

    # Template selection
    local tpl_id
    tpl_id=$(select_template "$cat_id")
    [ $? -ne 0 ] && return 1

    # Download
    local template_dir
    template_dir=$(download_template "$tpl_id")
    [ $? -ne 0 ] && return 1

    echo "$template_dir"
    return 0
}
