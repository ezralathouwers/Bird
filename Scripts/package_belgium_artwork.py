#!/usr/bin/env python3
"""Package only the Belgian API producer/data/style references, no app or secrets."""
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Scripts/Birder-Belgie-illustraties.zip'
PREFIX = 'Birder-Belgie-illustraties/'
FILES = [
    'Scripts/artwork_api_pilot.py', 'Scripts/Start-Belgie-illustraties.command',
    'Docs/BelgiumArtworkAPIPlan.json', 'Docs/BelgiumArtworkInventory.csv',
    'Docs/BelgiumArtworkSummary.json', 'Docs/BELGIUM_ARTWORK_API.md',
    'BirdingCompanion/Resources/WorldSpeciesCatalog.json',
    'BirdingCompanion/Resources/ArtworkManifest.json',
]


def package():
    plan = json.loads((ROOT / 'Docs/BelgiumArtworkAPIPlan.json').read_text())
    files = FILES + list(plan['referenceAssets'].values())
    with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in files:
            archive.write(ROOT / name, PREFIX + name)
        starter = zipfile.ZipInfo(PREFIX + 'Start-Belgie-illustraties.command')
        starter.create_system = 3
        starter.external_attr = 0o100755 << 16
        archive.writestr(starter, '#!/bin/bash\nexec /bin/bash "$(dirname "$0")/Scripts/Start-Belgie-illustraties.command"\n')
        archive.writestr(PREFIX + 'LEESMIJ.txt',
            'Birder: overige Belgische soorten\n\n'
            '1. Pak de volledige map uit.\n'
            '2. Dubbelklik Start-Belgie-illustraties.command bovenaan de map.\n'
            '3. Voer je API-sleutel verborgen in.\n\n'
            'Ongeveer 335 soorten, 670 nieuwe beelden. Raming $17–20 zonder hergeneraties.\n'
            'Zorg voor voldoende API-tegoed. De lokale stop op $25 is geen harde factureringslimiet.\n'
            'De eerder gemaakte proefbeelden en bestaande appillustraties worden overgeslagen.\n'
            'Houd de laptop open en aangesloten. Reken op enkele uren.\n'
            'Resultaten staan in .artwork-api/belgium-medium; de reviewpagina wordt telkens bijgewerkt.\n'
            'Dit pakket produceert kandidaten en vervangt geen app, logs of bestaande illustraties.\n'
            'Alle beelden moeten nog afzonderlijk worden beoordeeld voor import.\n'
            'Bij onvoldoende tegoed: vul tegoed aan en start hetzelfde bestand opnieuw. Afgewerkte beelden blijven behouden.\n'
            'Bij onzekere netwerkfouten: stuur state.json door; niet wissen of een nieuwe kopie starten.\n'
            'Details en soortenlijst: Docs/BELGIUM_ARTWORK_API.md en Docs/BelgiumArtworkInventory.csv.\n')
    print(f'{OUTPUT.name}: {OUTPUT.stat().st_size:,} bytes; explicit allowlist, no local outputs or credentials.')


if __name__ == '__main__':
    package()
