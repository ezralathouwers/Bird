#!/bin/bash
cd "$(dirname "$0")" || exit 1
trap 'read -r -p "Stuur een screenshot van de uitkomst. Druk op Enter om te sluiten."' EXIT
printf 'Birder: certificaten herstellen voor de API-proef. Geen API-sleutel nodig; geen beeldgeneratie.\n'
project_dir="${HOME}/Downloads/Bird-74a7fb0688135a05f78c9255deaac3e427dddcd7"
if [ ! -f "$project_dir/Docs/ArtworkAPIPilot.json" ]; then
    project_dir="$(osascript -e 'POSIX path of (choose folder with prompt "Kies de uitgepakte Bird-projectmap met de mappen Docs en Scripts.")')" || exit 1
fi
python3 repair_artwork_api_certificates.py "$project_dir"
