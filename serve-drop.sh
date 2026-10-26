#!/usr/bin/env bash

# Check if Zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "Error: 'zenity' is required for graphical prompts. Install it via your package manager." >&2
    exit 1
fi

# Handle dragged-and-dropped items or prompt for selection if none passed
if [ $# -gt 0 ]; then
    TARGET="$1"
else
    TARGET=$(zenity --file-selection --title="Select HTML file or Web Directory" --filename="$PWD/")
    [ $? -ne 0 ] && exit 0
fi

# Determine if the target is a file or directory
if [ -d "$TARGET" ]; then
    WEB_ROOT="$TARGET"
    DEFAULT_PAGE=""
elif [ -f "$TARGET" ]; then
    WEB_ROOT=$(dirname "$TARGET")
    DEFAULT_PAGE="/$(basename "$TARGET")"
else
    zenity --error --text="Invalid file or directory selected."
    exit 1
fi

# Find an available port starting from 8080
PORT=8080
while nc -z 127.0.0.1 "$PORT" 2>/dev/null; do
    PORT=$((PORT + 1))
done

# Start Python's HTTP server in the background
cd "$WEB_ROOT" || exit 1
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

# Ensure the server process is killed when this script exits
trap 'kill -9 "$SERVER_PID" 2>/dev/null' EXIT

SERVER_URL="http://localhost:${PORT}${DEFAULT_PAGE}"

# Open default browser
xdg-open "$SERVER_URL" > /dev/null 2>&1 &

# Display a blocking dialog to keep the server alive until dismissed
zenity --info \
    --title="Local Web Server Running" \
    --text="Root: $WEB_ROOT\nURL: $SERVER_URL\n\nClick OK to stop the server and quit." \
    --width=400

# Explicitly trigger cleanup trap
exit 0
