#!/bin/bash
# =============================================================================
# VNC Browser Container Startup Script
# =============================================================================
set -e

# Log colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[START]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Display configuration
# =============================================================================
echo ""
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
echo -e "${BLUE}|              VNC Browser - Lightweight container                   |${NC}"
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
echo -e "${BLUE}|${NC}  VNC Port:    ${GREEN}${VNC_PORT:-5901}${NC}"
echo -e "${BLUE}|${NC}  noVNC Port:  ${GREEN}${NOVNC_PORT:-6080}${NC}"
echo -e "${BLUE}|${NC}  Resolution:  ${GREEN}${VNC_RESOLUTION:-1920x1080}${NC}"
echo -e "${BLUE}|${NC}  Browser:     ${GREEN}${BROWSER:-firefox}${NC}"
echo -e "${BLUE}|${NC}  Start URL:   ${GREEN}${STARTING_URL:-about:blank}${NC}"
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
echo ""

# =============================================================================
# Prepare directories
# =============================================================================
log "Preparing directories..."

mkdir -p ~/.vnc ~/.config/openbox ~/.mozilla/firefox ~/.config/chromium ~/Desktop ~/Downloads

# =============================================================================
# Configure VNC password
# =============================================================================
if [ -n "$VNC_PW" ]; then
    log "Setting VNC password..."
    x11vnc -storepasswd "$VNC_PW" ~/.vnc/passwd 2>/dev/null || true
fi

# =============================================================================
# Setup Firefox profile
# =============================================================================
setup_firefox_profile() {
    local profile_dir="$HOME/.mozilla/firefox"
    local default_profile="$profile_dir/default"

    # Create default profile if it doesn't exist
    if [ ! -d "$default_profile" ]; then
        log "Creating default Firefox profile..."
        mkdir -p "$default_profile"
    fi

    # Create profiles.ini if it doesn't exist
    if [ ! -f "$profile_dir/profiles.ini" ]; then
        cat > "$profile_dir/profiles.ini" << 'PROFILES'
[Profile0]
Name=default
IsRelative=1
Path=default
Default=1

[General]
StartWithLastProfile=1
Version=2
PROFILES
    fi

    # Firefox user preferences
    local prefs_file="$default_profile/user.js"
    if [ ! -f "$prefs_file" ]; then
        log "Configuring Firefox preferences..."
        cat > "$prefs_file" << 'PREFS'
// Disable welcome screens
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);

// Performance
user_pref("browser.cache.disk.capacity", 51200);
user_pref("browser.sessionstore.interval", 60000);

// Disable auto updates
user_pref("app.update.enabled", false);
user_pref("app.update.auto", false);

// Show bookmarks toolbar
user_pref("browser.toolbars.bookmarksToolbar", "always");
user_pref("browser.toolbars.bookmarksToolbar.visibility", "always");
PREFS
    fi
}

# =============================================================================
# Setup Chromium profile
# =============================================================================
setup_chromium_profile() {
    local profile_dir="$HOME/.config/chromium/Default"

    if [ ! -d "$profile_dir" ]; then
        log "Creating default Chromium profile..."
        mkdir -p "$profile_dir"
    fi

    # Create basic preferences
    local prefs_file="$profile_dir/Preferences"
    if [ ! -f "$prefs_file" ]; then
        cat > "$prefs_file" << 'PREFS'
{
  "browser": {
    "check_default_browser": false,
    "show_home_button": true
  },
  "bookmark_bar": {
    "show_on_all_tabs": true
  },
  "profile": {
    "default_content_setting_values": {
      "notifications": 2
    }
  }
}
PREFS
    fi
}

# =============================================================================
# Configure browser based on selection
# =============================================================================
if [ "$BROWSER" = "firefox" ] || [ -x /usr/bin/firefox ]; then
    setup_firefox_profile
elif [ "$BROWSER" = "chromium" ] || [ -x /usr/bin/chromium-browser ]; then
    setup_chromium_profile
fi

# =============================================================================
# Load user data from /user-data (if mounted)
# =============================================================================
setup_user_data() {
    local user_dir="/user-data"

    if [ ! -d "$user_dir" ] || [ -z "$(ls -A $user_dir 2>/dev/null)" ]; then
        log "No custom user data mounted at /user-data, using default configuration"
        return
    fi

    log "Loading custom data from: $user_dir"
    log "User data contents: $(ls -la $user_dir 2>/dev/null || echo 'empty')"

    # Copy Firefox policies if present
    local policies_file="$user_dir/firefox-policies/policies.json"
    if [ -f "$policies_file" ]; then
        log "Firefox policies found: $policies_file"
        if cp "$policies_file" /usr/lib/firefox/distribution/policies.json 2>&1; then
            log "Firefox policies copied successfully"
        else
            error "Failed to copy Firefox policies"
        fi
    fi

    # Copy Firefox profile if present (user.js, bookmarks, etc.)
    if [ -d "$user_dir/firefox-profile" ]; then
        log "Copying custom Firefox profile..."
        cp -a "$user_dir/firefox-profile/"* "$HOME/.mozilla/firefox/default/" 2>/dev/null || true
    fi

    # Copy Chromium profile if present
    if [ -d "$user_dir/chromium-profile" ]; then
        log "Copying custom Chromium profile..."
        cp -a "$user_dir/chromium-profile/"* "$HOME/.config/chromium/Default/" 2>/dev/null || true
    fi

    # Link Desktop files if present
    if [ -d "$user_dir/desktop" ]; then
        log "Linking Desktop files..."
        for f in "$user_dir/desktop"/*; do
            [ -e "$f" ] && ln -sf "$f" "$HOME/Desktop/" 2>/dev/null || true
        done
    fi

    log "Custom user data loaded"
}

setup_user_data

# =============================================================================
# Configure Openbox autostart
# =============================================================================
log "Configuring Openbox autostart..."

cat > ~/.config/openbox/autostart << EOF
#!/bin/sh
# Autostart generated dynamically

# Set background color
xsetroot -solid "#1e1e2e" &

# Set initial resolution
/usr/local/bin/resize.sh ${VNC_RESOLUTION:-1920x1080} &

# Wait for X to stabilize
sleep 1

# Launch browser
/usr/local/bin/launch-browser.sh &
EOF
chmod +x ~/.config/openbox/autostart

# =============================================================================
# Start D-Bus (required for Firefox)
# =============================================================================
log "Starting D-Bus..."
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address 2>/dev/null || echo "")

# =============================================================================
# Start supervisord
# =============================================================================
log "Starting services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
