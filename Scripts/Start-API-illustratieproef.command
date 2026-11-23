#!/bin/bash
set -e
cd "$(dirname "$0")/.."
if [ ! -x .artwork-api/venv/bin/python3 ]; then
    python3 -m venv .artwork-api/venv
fi
if ! .artwork-api/venv/bin/python3 -c 'import PIL, certifi' >/dev/null 2>&1; then
    .artwork-api/venv/bin/python3 -m pip install --quiet 'Pillow>=10,<13' 'certifi>=2025.1'
fi
printf 'Birder API-proef: maximaal 2 nieuwe beelden. De API-sleutel wordt verborgen ingevoerd en niet bewaard.\n'
printf 'De verbruiksstop van $2 is een lokale schatting, geen harde factureringslimiet.\n'
.artwork-api/venv/bin/python3 Scripts/artwork_api_pilot.py --execute --max-requests 2 --spend-stop-usd 2
open .artwork-api/pilot-medium/review.html
read -r -p 'Druk op Enter om te sluiten.'
