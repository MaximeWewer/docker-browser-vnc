#!/bin/sh
# Kill existing browser and relaunch

export DISPLAY=:0

# Force kill any existing browser
pkill -9 -f chromium 2>/dev/null
pkill -9 -f firefox 2>/dev/null

# Wait for processes to fully die
sleep 1

# Relaunch browser
/usr/local/bin/launch-browser.sh &
