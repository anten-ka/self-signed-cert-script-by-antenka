#!/bin/bash
# XUIFAST v3.0.0 — English translations
# shellcheck disable=SC2034,SC2148

# ── Common ─────────────────────────────────────────────────────────────
I18N[yes]="Yes"
I18N[no]="No"
I18N[back]="« Back"
I18N[exit]="Exit"
I18N[choose]="Choose"
I18N[press_enter]="Press Enter..."
I18N[press_enter_return]="Press Enter to return to menu..."
I18N[invalid_choice]="Invalid choice"
I18N[running]="running"
I18N[stopped]="stopped"
I18N[not_installed]="not installed"
I18N[wait]="Please wait..."

# ── Banner ─────────────────────────────────────────────────────────────
I18N[banner_subtitle]="3X-UI + VLESS Reality / TLS"
I18N[banner_features]="Stealth • Anti-DPI • XTLS-Vision"
I18N[credits_title]="Credits / Thanks"

# ── Dependencies ───────────────────────────────────────────────────────
I18N[deps_installing]="Installing dependencies: %s"
I18N[deps_installed]="Dependencies installed"

# ── Main menu ──────────────────────────────────────────────────────────
I18N[dashboard_title]="Control Panel"
I18N[menu_proxy]="VPN              ▸"
I18N[menu_users]="Users            ▸"
I18N[menu_stats]="Statistics       ▸"
I18N[menu_manage]="Management       ▸"
I18N[menu_about]="About            ▸"
I18N[auto_refresh_30s]="Refresh in 30 sec"

# ── Status dashboard ───────────────────────────────────────────────────
I18N[svc_xui]="3X-UI"
I18N[svc_xray]="Xray"
I18N[svc_nginx]="nginx"
I18N[svc_site]="Site"
I18N[svc_ssl]="SSL"
I18N[ssl_until]="until %s"
I18N[net_ip]="IP:"
I18N[net_port]="Port:"
I18N[net_mode]="Mode:"
I18N[net_domain]="Domain:"
I18N[net_users]="Users:"
I18N[vpn_not_configured]="VPN not configured. Select option 1."
I18N[dashboard_xui_ver]="3X-UI:"

# ── 3X-UI version selection ────────────────────────────────────────────
I18N[xui_version_title]="Select 3X-UI panel version"
I18N[xui_version_detecting]="Detecting latest versions..."
I18N[xui_version_new_gen]="New Generation"
I18N[xui_version_new_desc]="Vue 3 frontend, new API, modern UI (recommended)"
I18N[xui_version_legacy]="Legacy (stable)"
I18N[xui_version_legacy_desc]="Classic UI, battle-tested, proven stability"
I18N[xui_version_choice]="Your choice [1/2]:"
I18N[xui_version_selected]="Selected: %s"
I18N[xui_installing_version]="Installing 3X-UI %s..."

# ── Transport selection ────────────────────────────────────────────────
I18N[transport_title]="Select transport protocol"
I18N[transport_tcp_desc]="Recommended for most users"
I18N[transport_xhttp_desc]="Try if TCP doesn't work"
I18N[transport_grpc_desc]="Try if TCP doesn't work"
I18N[transport_choice]="Your choice [1/2/3]:"
I18N[transport_selected]="Transport: %s"
I18N[config_transport]="Transport:"

# ── Install flow ───────────────────────────────────────────────────────
I18N[install_select_mode]="🎭 Select stealth mode:"
I18N[install_lite_title]="⚡ Lite — masquerade as another site (Reality)"
I18N[install_lite_desc1]="Fast, no domain needed. Xray mimics TLS"
I18N[install_lite_desc2]="of the chosen site via Reality protocol."
I18N[install_lite_desc3]="DPI sees a connection to a real website."
I18N[install_pro_title]="🛡  Pro — your own site + full stealth (TLS)"
I18N[install_pro_desc1]="nginx + Let's Encrypt + HTML template + 3X-UI."
I18N[install_pro_desc2]="DPI sees a real website with a real certificate."
I18N[install_pro_desc3]="Requires: a domain pointing to this server."
I18N[install_mode_choice]="Choice (1/2):"
I18N[install_lite_step]="Installing Lite mode (Reality)"
I18N[install_pro_step]="Installing Pro mode (TLS)"

# ── Lite mode ──────────────────────────────────────────────────────────
I18N[lite_select_domain]="🌐 Select a website to masquerade as:"
I18N[lite_ru_domains]="Popular Russian websites"
I18N[lite_int_domains]="Popular international websites"
I18N[lite_detected_geo]="Detected: server IP is %s"
I18N[lite_testing_domain]="Testing domain %s..."
I18N[lite_domain_ok]="Domain %s is suitable for Reality"
I18N[lite_domain_fail]="Domain %s not suitable (no TLSv1.3 or H2)"

# ── Pro mode ───────────────────────────────────────────────────────────
I18N[pro_enter_domain]="Enter your domain (e.g. example.com):"
I18N[pro_bad_domain]="Invalid domain: %s"
I18N[pro_dns_mismatch]="Domain %s points to %s, not to %s"
I18N[pro_continue_anyway]="Continue anyway?"
I18N[pro_enter_email]="Email for SSL (Enter = no email):"

# ── 3X-UI installation ────────────────────────────────────────────────
I18N[xui_installing]="Installing 3X-UI..."
I18N[xui_installed]="3X-UI installed"
I18N[xui_already_installed]="3X-UI is already installed"
I18N[xui_install_failed]="3X-UI installation failed"
I18N[xui_starting]="Starting 3X-UI..."
I18N[xui_started]="3X-UI started"
I18N[xui_stopped]="3X-UI stopped"
I18N[xui_restarted]="3X-UI restarted"
I18N[xui_removing]="Removing 3X-UI..."
I18N[xui_removed]="3X-UI removed"

# ── API ────────────────────────────────────────────────────────────────
I18N[api_waiting]="Waiting for panel API..."
I18N[api_login_ok]="Panel login OK"
I18N[api_login_fail]="Panel login failed"
I18N[api_creating_inbound]="Creating VPN connection..."
I18N[api_inbound_created]="VPN connection created (port 443)"
I18N[api_inbound_failed]="Failed to create connection"

# ── Users ──────────────────────────────────────────────────────────────
I18N[users_ask_count]="How many VPN keys to create?"
I18N[users_ask_count_hint]="(1-100, default: 3)"
I18N[users_creating]="Creating %d users..."
I18N[users_created]="%d users created"
I18N[users_title]="👥 VPN Users"
I18N[users_show_all]="Show all users?"
I18N[user_online]="🟢 online"
I18N[user_offline]="⚪ offline"

# ── VLESS links & QR ──────────────────────────────────────────────────
I18N[vless_link_title]="🔗 Connection link:"
I18N[qr_title]="📱 QR code for %s:"
I18N[qr_scan_hint]="Scan in Hiddify / V2rayNG / Streisand"

# ── Credentials ────────────────────────────────────────────────────────
I18N[creds_title]="🔐 3X-UI Panel credentials"
I18N[creds_url]="URL:"
I18N[creds_user]="Login:"
I18N[creds_pass]="Password:"
I18N[creds_saved]="Credentials saved to %s"
I18N[creds_save_warning]="SAVE THESE CREDENTIALS!"

# ── Connection test ────────────────────────────────────────────────────
I18N[test_title]="🔍 Connection test"
I18N[test_checking]="Checking user %s..."
I18N[test_online]="✅ %s — connected"
I18N[test_offline]="⏳ %s — waiting for connection"
I18N[test_skip]="Press Enter to skip"

# ── App download ───────────────────────────────────────────────────────
I18N[app_title]="📱 Download VPN app"
I18N[app_platform]="Select platform:"
I18N[app_ios]="iOS (iPhone/iPad)"
I18N[app_android]="Android"
I18N[app_ios_hint]="Install Hiddify from the App Store"
I18N[app_android_hint]="Install Hiddify from Google Play"
I18N[app_installed]="App installed?"

# ── Config summary ─────────────────────────────────────────────────────
I18N[config_title]="📋 Configuration:"
I18N[config_ip]="IP:"
I18N[config_port]="Port:"
I18N[config_mode]="Mode:"
I18N[config_mask]="Masquerade:"
I18N[config_domain]="Domain:"
I18N[config_users]="Users:"
I18N[config_confirm]="Install VPN?"

# ── Website / Templates ────────────────────────────────────────────────
I18N[website_title]="🌐 Website management"
I18N[website_deploying]="Deploying site template..."
I18N[website_deployed]="Site template deployed"
I18N[website_only_pro]="Website management is available in Pro mode only"

# ── Templates catalog ─────────────────────────────────────────────────
I18N[templates_categories]="Website template categories:"
I18N[templates_custom_git]="🔗 Custom Git URL (your own template)"
I18N[templates_random]="🎲 Random template"
I18N[templates_count_fmt]="%s templates"
I18N[templates_list]="Templates in '%s':"
I18N[templates_cat_empty]="This category is empty"
I18N[templates_preview_title]="Template preview"
I18N[templates_name]="Name:"
I18N[templates_source]="Source:"
I18N[templates_description]="Description:"
I18N[templates_preview]="🔗 Preview:"
I18N[templates_preview_hint]="(open in browser to preview)"
I18N[templates_repo]="Repo:"
I18N[templates_thanks]="Thanks to %s for the open-source template!"
I18N[templates_install_this]="Install this template?"
I18N[templates_downloading]="Downloading template '%s'..."
I18N[templates_downloaded]="Template '%s' downloaded"
I18N[templates_downloaded_subfolder]="Template '%s' downloaded (from subfolder)"
I18N[templates_no_index]="Template has no index.html"
I18N[templates_path]="Path: %s"
I18N[templates_catalog_not_found]="Templates catalog not found: %s"

# ── Custom Git templates ──────────────────────────────────────────────
I18N[custom_git_title]="Custom Git Template"
I18N[custom_git_help_1]="You can use any public Git repository as a website template."
I18N[custom_git_help_2]="The repo should contain index.html (in root, dist/, public/, or build/)."
I18N[custom_git_help_3]="We'll auto-detect the site folder."
I18N[custom_git_formats]="Supported URL formats:"
I18N[custom_git_fmt_github]="  https://github.com/user/repo"
I18N[custom_git_fmt_gitlab]="  https://gitlab.com/user/repo"
I18N[custom_git_fmt_gitext]="  https://any-git-host.com/user/repo"
I18N[custom_git_fmt_branch]="  https://github.com/user/repo@branch-name"
I18N[custom_git_auto_detect]="Auto-detection:"
I18N[custom_git_auto_1]="  ✓ Root index.html"
I18N[custom_git_auto_2]="  ✓ dist/, public/, build/ folders"
I18N[custom_git_auto_3]="  ✓ Nested index.html (up to 4 levels deep)"
I18N[custom_git_auto_4]="  ✓ Branch selection via @branch suffix"
I18N[custom_git_requirements]="Requirements:"
I18N[custom_git_req_1]="  • Public repository (no auth required)"
I18N[custom_git_req_2]="  • Must contain index.html"
I18N[custom_git_req_3]="  • Max size: 100 MB"
I18N[custom_git_req_4]="  • HTTPS URLs only"
I18N[custom_git_examples]="Examples:"
I18N[custom_git_ex_1]="  https://github.com/html5up/phantom"
I18N[custom_git_ex_2]="  https://github.com/StartBootstrap/startbootstrap-agency@main"
I18N[custom_git_enter_url]="Enter Git URL:"
I18N[custom_git_empty]="URL cannot be empty"
I18N[custom_git_bad_url]="Invalid URL (must start with https://)"
I18N[custom_git_cloning]="Cloning repository..."
I18N[custom_git_clone_failed]="Clone failed: %s"
I18N[custom_git_too_big]="Repository too large: %s (max 100MB)"
I18N[custom_git_scanning]="Scanning for index.html..."
I18N[custom_git_no_index]="No index.html found in repository"
I18N[custom_git_found_at]="Found site at: %s"
I18N[custom_git_installed]="Custom template installed from %s"

# ── Submenu: Proxy ─────────────────────────────────────────────────────
I18N[submenu_proxy_title]="🚀 VPN"
I18N[proxy_install_update]="Install / Update"
I18N[proxy_status_detail]="Detailed status"
I18N[proxy_show_links]="Show links"
I18N[proxy_show_qr]="QR codes"
I18N[proxy_restart]="Restart"
I18N[proxy_logs]="Logs"
I18N[proxy_change_mode]="Change mode / template"

# ── Submenu: Manage ────────────────────────────────────────────────────
I18N[submenu_manage_title]="⚙️  MANAGEMENT"
I18N[manage_backup]="Backup"
I18N[manage_restore]="Restore"
I18N[manage_update]="Update 3X-UI"
I18N[manage_site_ssl]="Site / SSL"
I18N[manage_remove]="Remove"
I18N[manage_language]="Language / Язык"

# ── Submenu: About ─────────────────────────────────────────────────────
I18N[submenu_about_title]="ℹ️  ABOUT"
I18N[about_version_info]="Version info"
I18N[about_promo]="Promo / Donate"
I18N[version_title]="🔍 Information"

# ── Remove ─────────────────────────────────────────────────────────────
I18N[remove_title]="🗑  Remove XUIFAST"
I18N[remove_xui_only]="Remove 3X-UI only"
I18N[remove_all]="Remove everything (3X-UI + nginx + settings)"
I18N[remove_confirm]="Are you absolutely sure?"
I18N[remove_done]="XUIFAST fully removed"

# ── Backup ─────────────────────────────────────────────────────────────
I18N[backup_title]="💾 Backup"
I18N[backup_creating]="Creating backup..."
I18N[backup_created]="Backup created: %s (%s)"
I18N[backup_restored]="Backup restored"

# ── Errors ─────────────────────────────────────────────────────────────
I18N[err_need_root]="Run the script with sudo / as root"
I18N[err_os_unknown]="Failed to detect OS. Linux required."
I18N[err_low_disk]="Low disk space: %sMB (need %sMB+)"
I18N[lite_nginx_optional_fail]="Stub nginx setup failed (non-critical, VPN still works)"
I18N[api_login_fail_manual]="Could not connect to panel API. You can configure VPN manually via the panel."
I18N[auto_config_fail]="Auto-configuration failed. Panel is installed — configure VPN manually."
I18N[auto_config_incomplete]="Auto-configuration was incomplete. Panel is accessible — you can finish setup manually."
I18N[bye]="See you later! 👋"

# ── Completion ─────────────────────────────────────────────────────────
I18N[install_done]="XUIFAST v%s installed! (%s mode)"
I18N[install_done_hint]="Management command: xuifast"
I18N[enjoy]="Enjoy! 🚀"
