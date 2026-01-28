#!/bin/bash
# =============================================================================
# Browser Launch Script
# Supports Firefox and Chromium with their respective options
# =============================================================================

# Detect browser - use env var if set, otherwise detect installed browser
detect_browser() {
    # If BROWSER env var is set and not empty, use it
    if [ -n "$BROWSER" ]; then
        echo "$BROWSER"
        return
    fi

    # Auto-detect installed browser
    if command -v firefox >/dev/null 2>&1; then
        echo "firefox"
    elif command -v chromium-browser >/dev/null 2>&1; then
        echo "chromium"
    elif command -v chromium >/dev/null 2>&1; then
        echo "chromium"
    else
        echo "firefox"  # Default fallback
    fi
}

BROWSER=$(detect_browser)

log() { echo "[BROWSER] $1"; }

log "Detected browser: $BROWSER"

# Determine the URL to open
# Priority: STARTING_URL > profile settings (if custom user-data mounted) > about:blank
get_start_url() {
    if [ -n "$STARTING_URL" ]; then
        echo "$STARTING_URL"
        return
    fi

    # Check if user mounted custom config via /user-data
    case "$BROWSER" in
        firefox)
            # Check for custom Firefox profile or policies in user-data
            if [ -d "/user-data/firefox-profile" ] || [ -d "/user-data/firefox-policies" ]; then
                echo ""  # Empty = use profile settings
                return
            fi
            ;;
        chromium|chromium-browser)
            # Check for custom Chromium profile in user-data
            if [ -d "/user-data/chromium-profile" ]; then
                echo ""  # Empty = use profile settings
                return
            fi
            ;;
    esac

    # No custom config, use about:blank
    echo "about:blank"
}

URL=$(get_start_url)

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

if [ -n "$URL" ]; then
    log "Launching $BROWSER to $URL"
else
    log "Launching $BROWSER (using profile settings)"
fi

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
        if [ -n "$URL" ]; then
            exec firefox \
                --no-remote \
                --profile "$HOME/.mozilla/firefox/default" \
                --new-window \
                "$URL"
        else
            exec firefox \
                --no-remote \
                --profile "$HOME/.mozilla/firefox/default"
        fi
        ;;

    chromium|chromium-browser)
        # Hide loading screen
        hide_loading_screen

        # Chromium options optimized for container
        exec chromium-browser \
            --no-sandbox \
            --test-type \
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
            --disable-session-crashed-bubble \
            --no-first-run \
            --no-default-browser-check \
            --disable-features=WhatsNewUI \
            --start-maximized \
            --user-data-dir="$HOME/.config/chromium" \
            $URL
        ;;

    *)
        log "Unknown browser: $BROWSER, falling back to Firefox"
        if [ -n "$URL" ]; then
            exec firefox --no-remote "$URL"
        else
            exec firefox --no-remote
        fi
        ;;
esac
