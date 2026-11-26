#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
printf 'Birder: veldupdate in je bestaande project. Geen illustraties verplaatsen.\n1. Update installeren\n2. Onderbroken update terugdraaien\n'
read -r -p 'Keuze [1]: ' keuze
case "$keuze" in
    ''|1) python3 Scripts/install_field_update.py ;;
    2) python3 Scripts/install_field_update.py --recover ;;
    *) printf 'Ongeldige keuze. Niets gewijzigd.\n'; exit 1 ;;
esac
