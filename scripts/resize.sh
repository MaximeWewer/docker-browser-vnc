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

# Try to set existing mode first
if xrandr --output screen --mode "$MODE_NAME" 2>/dev/null; then
    echo "Resolution changed to $MODE_NAME"
    exit 0
fi

# Create new mode if needed
MODELINE=$(cvt "$WIDTH" "$HEIGHT" 60 2>/dev/null | grep Modeline | cut -d' ' -f3-)
if [ -n "$MODELINE" ]; then
    xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null || true
    xrandr --addmode screen "$MODE_NAME" 2>/dev/null || true
    xrandr --output screen --mode "$MODE_NAME" 2>/dev/null
    echo "Resolution changed to $MODE_NAME"
else
    echo "Error: Could not create mode $MODE_NAME"
    exit 1
fi
