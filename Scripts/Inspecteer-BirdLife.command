#!/bin/bash
# Double-click on macOS; no pip, Homebrew, GIS library or upload is needed.
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is nodig. Met Xcode is dit meestal al beschikbaar."
    echo "Druk op Enter om te sluiten."
    read -r _
    exit 1
fi
if ! BIRD_PACKAGE_PATH=$(/usr/bin/osascript -e 'POSIX path of (choose file with prompt "Kies BOTW_2025.gpkg uit de uitgepakte BirdLife-map")'); then
    exit 0
fi
python3 "$SCRIPT_DIR/inspect_birdlife_geopackage.py" "$BIRD_PACKAGE_PATH"
BIRD_INSPECT_STATUS=$?
echo ""
echo "Druk op Enter om te sluiten."
read -r _
exit "$BIRD_INSPECT_STATUS"
