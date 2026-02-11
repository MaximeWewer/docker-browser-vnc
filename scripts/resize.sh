#!/bin/bash
# Dynamic resolution change script
# Usage: resize.sh WIDTHxHEIGHT

RESOLUTION="${1:-1920x1080}"
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"

if ! [[ "$WIDTH" =~ ^[0-9]+$ ]] || ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 WIDTHxHEIGHT"
    exit 1
fi

MODE_NAME="${WIDTH}x${HEIGHT}"

# Reapply wallpaper after resolution change
reapply_wallpaper() {
    if [ -f "$HOME/.fehbg" ]; then
        sh "$HOME/.fehbg" 2>/dev/null &
    elif [ -f /tmp/wallpaper.jpg ]; then
        feh --bg-center --image-bg "#1e1e2e" /tmp/wallpaper.jpg 2>/dev/null &
    fi
}

# Try to set existing mode first (TigerVNC uses VNC-0 as output name)
if xrandr --output VNC-0 --mode "$MODE_NAME" 2>/dev/null; then
    echo "Resolution changed to $MODE_NAME"
    reapply_wallpaper
    exit 0
fi

# Create new mode if needed
MODELINE=$(cvt "$WIDTH" "$HEIGHT" 60 2>/dev/null | grep Modeline | cut -d' ' -f3-)
if [ -n "$MODELINE" ]; then
    xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null || true
    xrandr --addmode VNC-0 "$MODE_NAME" 2>/dev/null || true
    xrandr --output VNC-0 --mode "$MODE_NAME" 2>/dev/null
    echo "Resolution changed to $MODE_NAME"
    reapply_wallpaper
else
    echo "Error: Could not create mode $MODE_NAME"
    exit 1
fi
