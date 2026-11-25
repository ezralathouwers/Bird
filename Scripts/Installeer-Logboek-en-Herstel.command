#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
printf 'Birder: logboekbatch + goedgekeurde herstelbeelden installeren. Geen API-kosten.\n'
if [ ! -x .artwork-api/import-venv/bin/python3 ]; then
    python3 -m venv .artwork-api/import-venv || exit 1
fi
if ! .artwork-api/import-venv/bin/python3 -c 'import PIL' >/dev/null 2>&1; then
    .artwork-api/import-venv/bin/python3 -m pip install --quiet 'Pillow>=10,<13' || exit 1
fi
printf '1. Beide batches installeren\n2. Onderbroken import terugdraaien\n'
read -r -p 'Keuze [1]: ' keuze
case "$keuze" in
    ''|1) .artwork-api/import-venv/bin/python3 Scripts/import_logbook_and_repairs.py ;;
    2) .artwork-api/import-venv/bin/python3 Scripts/import_logbook_and_repairs.py --recover ;;
    *) printf 'Ongeldige keuze. Niets gewijzigd.\n'; exit 1 ;;
esac
