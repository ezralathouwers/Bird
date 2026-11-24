#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
printf 'Birder: lokale illustratiecontrole en import. Geen API-sleutel nodig; geen beeldgeneratie.\n'
if [ ! -x .artwork-api/import-venv/bin/python3 ]; then
    python3 -m venv .artwork-api/import-venv || exit 1
fi
if ! .artwork-api/import-venv/bin/python3 -c 'import PIL' >/dev/null 2>&1; then
    .artwork-api/import-venv/bin/python3 -m pip install --quiet 'Pillow>=10,<13' || exit 1
fi
.artwork-api/import-venv/bin/python3 Scripts/local_artwork_import.py
