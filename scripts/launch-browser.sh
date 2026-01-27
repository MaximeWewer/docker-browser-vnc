#!/bin/bash
# =============================================================================
# Browser Launch Script
# Supports Firefox and Chromium with their respective options
# =============================================================================

BROWSER="${BROWSER:-firefox}"
URL="${STARTING_URL:-about:blank}"

log() { echo "[BROWSER] $1"; }

# Display loading screen during startup
show_loading_screen() {
    # Dark gray background
    xsetroot -solid "#2d2d2d" 2>/dev/null

    # Show loading message if xmessage is available
    if command -v xmessage >/dev/null 2>&1; then
        xmessage -center -timeout 30 "Loading..." &
        LOADING_PID=$!
    fi
}

# Hide loading screen
hide_loading_screen() {
    if [ -n "$LOADING_PID" ]; then
        kill $LOADING_PID 2>/dev/null || true
    fi
}

log "Launching $BROWSER to $URL"

# Wait for display to be ready
for i in {1..30}; do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Show loading screen
show_loading_screen

case "$BROWSER" in
    firefox)
        # Hide loading screen before Firefox
        hide_loading_screen

        # Firefox options optimized for container
        exec firefox \
            --no-remote \
            --profile "$HOME/.mozilla/firefox/default" \
            --new-window \
            "$URL"
        ;;

    chromium|chromium-browser)
        # Hide loading screen
        hide_loading_screen

        # Chromium options optimized for container
        exec chromium-browser \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-gpu \
            --disable-software-rasterizer \
            --disable-background-networking \
            --disable-default-apps \
            --disable-extensions \
            --disable-sync \
            --disable-translate \
            --disable-background-timer-throttling \
            --disable-backgrounding-occluded-windows \
            --disable-renderer-backgrounding \
            --disable-infobars \
            --no-first-run \
            --no-default-browser-check \
            --start-maximized \
            --user-data-dir="$HOME/.config/chromium" \
            "$URL"
        ;;

    *)
        log "Unknown browser: $BROWSER, falling back to Firefox"
        exec firefox --no-remote "$URL"
        ;;
esac
