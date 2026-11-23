#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
if [ ! -x .artwork-api/venv/bin/python3 ]; then
    python3 -m venv .artwork-api/venv || exit 1
fi
if ! .artwork-api/venv/bin/python3 -c 'import PIL, certifi' >/dev/null 2>&1; then
    .artwork-api/venv/bin/python3 -m pip install --quiet 'Pillow>=10,<13' 'certifi>=2025.1' || exit 1
fi
printf 'Birder België: circa 335 overige soorten, maximaal 670 nieuwe beelden.\n'
printf 'Raming $17–20 zonder hergeneraties. Zorg voor voldoende API-tegoed.\n'
printf 'Lokale verbruiksstop: $25; dit is geen harde factureringslimiet.\n'
printf 'Je sleutel wordt verborgen ingevoerd en niet bewaard. Bestaande beelden en de vorige proef worden overgeslagen.\n'
printf 'Houd je laptop open. De reviewpagina wordt tussendoor bijgewerkt.\n'
if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i .artwork-api/venv/bin/python3 Scripts/artwork_api_pilot.py --plan Docs/BelgiumArtworkAPIPlan.json --output .artwork-api/belgium-medium --execute --max-requests 670 --spend-stop-usd 25
    result=$?
else
    .artwork-api/venv/bin/python3 Scripts/artwork_api_pilot.py --plan Docs/BelgiumArtworkAPIPlan.json --output .artwork-api/belgium-medium --execute --max-requests 670 --spend-stop-usd 25
    result=$?
fi
if [ -f .artwork-api/belgium-medium/review.html ]; then
    open .artwork-api/belgium-medium/review.html
fi
exit "$result"
