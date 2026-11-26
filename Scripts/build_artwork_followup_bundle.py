#!/usr/bin/env python3
"""Combine the in-place display update with the separate, frozen local art round."""
from pathlib import Path
import zipfile
import build_field_update_bundle as field

ROOT = Path(__file__).resolve().parents[1]


def build():
    field.build()
    target = ROOT / 'Scripts/Birder-Illustratiecorrecties-20261126.zip'
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as output:
        with zipfile.ZipFile(ROOT / 'Scripts/Birder-Veldupdate-20261126.zip') as source:
            for old in source.infolist():
                if old.filename.endswith('/LEESMIJ.txt'): continue
                info = zipfile.ZipInfo(old.filename.replace('Birder-Veldupdate/', 'Birder-Illustratiecorrecties/', 1))
                info.external_attr = old.external_attr
                info.compress_type = zipfile.ZIP_DEFLATED
                output.writestr(info, source.read(old))
        for relative in ['Scripts/artwork_followup_20261126.py', 'Scripts/artwork_api_repairs.py',
                         'Scripts/artwork_api_pilot.py', 'Scripts/install_artwork_batch.py',
                         'Scripts/Start-Illustratiecorrecties.command', 'Docs/ArtworkFollowup20261126.json',
                         'Docs/ILLUSTRATIECORRECTIES_20261126.md']:
            output.write(ROOT / relative, 'Birder-Illustratiecorrecties/' + relative)
        output.writestr('Birder-Illustratiecorrecties/LEESMIJ.txt', (ROOT / 'Docs/ILLUSTRATIECORRECTIES_20261126.md').read_text())
    print(target.name)


if __name__ == '__main__': build()
