#!/bin/sh
# =============================================================================
# VNC Resize Initializer
#
# Workaround for libvncclient bug in guacd: screen.id == 0 is filtered out
# in ExtendedDesktopSize handling, so rfbClient->screen never gets initialized.
# This script detects new VNC client connections and triggers a brief
# resolution change to force TigerVNC to send ExtendedDesktopSize with
# valid screen data, enabling Guacamole's VNC resize to work.
# =============================================================================

DISPLAY="${DISPLAY:-:0}"
export DISPLAY

VNC_PORT="${VNC_PORT:-5901}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1920x1080}"
LAST_CONN_COUNT=0

# Wait for Xvnc to be ready
sleep 5

# Initialize xrandr mode table by requesting a different resolution
# TigerVNC's Xvnc populates standard modes on first randr request
xrandr --output VNC-0 --mode 1280x720 2>/dev/null
sleep 0.5
# Restore original resolution
RES_W=$(echo "$VNC_RESOLUTION" | cut -dx -f1)
RES_H=$(echo "$VNC_RESOLUTION" | cut -dx -f2)
xrandr --output VNC-0 --mode "${RES_W}x${RES_H}" 2>/dev/null

while true; do
    sleep 2

    # Count established VNC connections (exclude the listening socket)
    CONN_COUNT=$(netstat -tn 2>/dev/null | grep ":${VNC_PORT} " | grep -c ESTABLISHED)

    if [ "$CONN_COUNT" -gt "$LAST_CONN_COUNT" ] && [ "$CONN_COUNT" -gt 0 ]; then
        # New VNC client connected - trigger resolution bounce
        CURRENT_MODE=$(xrandr 2>/dev/null | grep '\*' | awk '{print $1}')

        if [ -n "$CURRENT_MODE" ]; then
            # Pick a different resolution for the bounce
            if [ "$CURRENT_MODE" = "1280x720" ]; then
                BOUNCE_MODE="1280x800"
            else
                BOUNCE_MODE="1280x720"
            fi

            # Brief resolution change to trigger ExtDesktopSize
            xrandr --output VNC-0 --mode "$BOUNCE_MODE" 2>/dev/null
            sleep 0.5
            xrandr --output VNC-0 --mode "$CURRENT_MODE" 2>/dev/null
        fi
    fi

    LAST_CONN_COUNT="$CONN_COUNT"
done
