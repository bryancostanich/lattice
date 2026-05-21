#!/usr/bin/env bash
# Generates a README-ready screenshot of Lattice's overview in action.
#
# 1. Toggles "Allow Screenshot of Overview" on (so screencapture sees the overview window).
# 2. Cycles through every space using Ctrl+Opt+→, so each space's thumbnail is captured.
# 3. Opens the overview with Ctrl+Opt+Space.
# 4. Takes a full-screen screenshot via /usr/sbin/screencapture.
# 5. Dismisses overview, toggles screenshot allowance back off.
#
# Prerequisite: Lattice is running. (open /Applications/Lattice.app)
#
# Usage: ./scripts/screenshot.sh [output.png] [num_spaces]

set -euo pipefail

OUTPUT="${1:-lattice-overview.png}"
SPACES="${2:-9}"

LEFT=123; RIGHT=124; DOWN=125; UP=126; SPACE=49

send_key() {
    osascript -e "tell application \"System Events\" to key code $1 using {control down, option down}"
}

toggle_screenshot_allowance() {
    osascript <<'EOF' || echo "(automatic toggle failed — toggle 'Allow Screenshot of Overview' in Lattice's menu manually before running)"
tell application "System Events"
    tell process "Lattice"
        click menu bar item 1 of menu bar 2
        delay 0.2
        click menu item "Allow Screenshot of Overview" of menu 1 of menu bar item 1 of menu bar 2
    end tell
end tell
EOF
}

echo "Toggling screenshot allowance on..."
toggle_screenshot_allowance
sleep 0.5

# Dismiss any open overview so the navigation phase starts clean.
send_key $SPACE 2>/dev/null || true
sleep 0.5

echo "Cycling through $SPACES spaces to populate thumbnails..."
for ((i=0; i<SPACES; i++)); do
    send_key $RIGHT
    sleep 0.7
done

echo "Opening overview..."
send_key $SPACE
sleep 0.8

echo "Capturing $OUTPUT..."
screencapture -x "$OUTPUT"

echo "Dismissing overview..."
send_key $SPACE
sleep 0.3

echo "Toggling screenshot allowance off..."
toggle_screenshot_allowance

echo "Done: $OUTPUT"
