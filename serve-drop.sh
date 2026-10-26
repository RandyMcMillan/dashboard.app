#!/usr/bin/env bash

# Linux/Unix helper for the Tailwind Admin Dashboard droplet.
#
# Serves the bundled Contents/Resources/index.html by default, or a file or
# directory passed on the command line / dropped onto the script.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BUNDLE_ROOT="$SCRIPT_DIR"
BUNDLED_INDEX="$BUNDLE_ROOT/Contents/Resources/index.html"

# Handle a dragged-and-dropped item or fall back to the bundled page.
if [ $# -gt 0 ]; then
    TARGET="$1"
elif [ -f "$BUNDLED_INDEX" ]; then
    TARGET="$BUNDLED_INDEX"
else
    if command -v zenity >/dev/null 2>&1; then
        TARGET="$(zenity --file-selection --title="Select HTML file or Web Directory" --filename="$PWD/")"
        [ -z "$TARGET" ] && exit 0
    else
        printf 'Usage: %s [file-or-directory]\n' "$0" >&2
        exit 2
    fi
fi

# Determine whether the target is a file or directory.
if [ -d "$TARGET" ]; then
    WEB_ROOT="$TARGET"
    DEFAULT_PAGE=""
elif [ -f "$TARGET" ]; then
    WEB_ROOT="$(dirname -- "$TARGET")"
    DEFAULT_PAGE="/$(basename -- "$TARGET")"
else
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --text="Invalid file or directory selected: $TARGET"
    else
        printf 'Invalid file or directory: %s\n' "$TARGET" >&2
    fi
    exit 1
fi

port_in_use() {
    (exec 3<>/dev/tcp/127.0.0.1/"$1") 2>/dev/null
}

# Find an available port starting from 8080.
PORT=8080
while port_in_use "$PORT"; do
    PORT=$((PORT + 1))
done

# Start Python's HTTP server in the background.
cd "$WEB_ROOT" || exit 1
python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER_PID=$!

trap 'kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true' EXIT INT TERM

# Give the server a brief moment to start.
for _ in {1..50}; do
    if (exec 3<>/dev/tcp/127.0.0.1/"$PORT") 2>/dev/null; then
        exec 3>&- 3<&- 2>/dev/null || true
        break
    fi
    sleep 0.1
done

SERVER_URL="http://localhost:${PORT}${DEFAULT_PAGE}"

# Open the default browser when possible.
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$SERVER_URL" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then
    open "$SERVER_URL" >/dev/null 2>&1 &
fi

# Keep the server alive until the user dismisses the dialog or presses Enter.
if command -v zenity >/dev/null 2>&1; then
    zenity --info \
        --title="Local Web Server Running" \
        --text="Root: $WEB_ROOT\nURL: $SERVER_URL\n\nClick OK to stop the server and quit." \
        --width=400
else
    printf 'Web server started!\nRoot: %s\nURL: %s\nPress Enter to stop the server and quit.\n' \
        "$WEB_ROOT" "$SERVER_URL"
    read -r _ || true
fi

exit 0