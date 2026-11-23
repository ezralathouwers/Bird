#!/bin/bash
cd "$(dirname "$0")" || exit 1
printf 'Birder: HTTPS-verbindingscontrole. Geen sleutel nodig; er worden geen beelden aangevraagd.\n'
python3 artwork_api_pilot.py --diagnose
read -r -p 'Stuur een screenshot van de bovenstaande uitkomst. Druk op Enter om te sluiten.'
