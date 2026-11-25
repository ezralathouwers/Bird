#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
if [ ! -x .artwork-api/venv/bin/python3 ]; then
    python3 -m venv .artwork-api/venv || exit 1
fi
if ! .artwork-api/venv/bin/python3 -c 'import PIL, certifi' >/dev/null 2>&1; then
    .artwork-api/venv/bin/python3 -m pip install --quiet 'Pillow>=10,<13' 'certifi>=2025.1' || exit 1
fi
if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i .artwork-api/venv/bin/python3 Scripts/artwork_api_repairs.py --menu
else
    .artwork-api/venv/bin/python3 Scripts/artwork_api_repairs.py --menu
fi
