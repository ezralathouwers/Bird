#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
if ! BIRD_PACKAGE_PATH=$(/usr/bin/osascript -e 'POSIX path of (choose file with prompt "Kies BOTW_2025.gpkg")'); then exit 0; fi
if ! BIRD_PROJECT_PATH=$(/usr/bin/osascript -e 'POSIX path of (choose folder with prompt "Kies de appmap die je nu in Xcode gebruikt, met de bestaande PrivateBirdLifeRanges-export")'); then exit 0; fi
BIRD_CONVERTER_ENV="$HOME/Library/Application Support/BirdingCompanion/BirdLifeConverter"
echo "Lokale converter voorbereiden (Python en Shapely, zonder de kaartdata te uploaden)…"
if ! python3 -m venv "$BIRD_CONVERTER_ENV"; then
    echo "Python 3 ontbreekt of kan geen omgeving maken."
    read -r _
    exit 1
fi
if ! "$BIRD_CONVERTER_ENV/bin/python3" -m pip install --quiet 'shapely>=2,<3'; then
    echo "Shapely kon niet worden geïnstalleerd. Controleer je internetverbinding."
    read -r _
    exit 1
fi
"$BIRD_CONVERTER_ENV/bin/python3" "$SCRIPT_DIR/convert_birdlife_geopackage.py" "$BIRD_PACKAGE_PATH" "$BIRD_PROJECT_PATH"
BIRD_STATUS=$?
echo "Druk op Enter om te sluiten."
read -r _
exit "$BIRD_STATUS"
