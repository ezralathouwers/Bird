#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
printf 'Birder: compacte controlezip maken. Geen API-sleutel of beeldgeneratie.\n'
if [ ! -x .illustration-review/venv/bin/python3 ]; then
    python3 -m venv .illustration-review/venv || exit 1
fi
if ! .illustration-review/venv/bin/python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    .illustration-review/venv/bin/python3 -m pip install --quiet 'Pillow>=10,<13' || exit 1
fi
.illustration-review/venv/bin/python3 Scripts/prepare_artwork_review_pack.py --choose
