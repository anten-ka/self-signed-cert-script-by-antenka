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
I18N[bye]="See you later! 👋"

# ── Completion ─────────────────────────────────────────────────────────
I18N[install_done]="XUIFAST v%s installed! (%s mode)"
I18N[install_done_hint]="Management command: xuifast"
I18N[enjoy]="Enjoy! 🚀"
