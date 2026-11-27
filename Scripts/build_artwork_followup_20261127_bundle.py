#!/usr/bin/env python3
"""Ship the existing-project UI update with a separate nine-role repair round."""
from pathlib import Path
import zipfile
import build_artwork_followup_bundle as previous

ROOT = Path(__file__).resolve().parents[1]


def build():
    previous.build()
    target = ROOT / 'Scripts/Birder-Illustratiecorrecties-20261127.zip'
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as output:
        with zipfile.ZipFile(ROOT / 'Scripts/Birder-Veldupdate-20261126.zip') as source:
            for old in source.infolist():
                if old.filename.endswith('/LEESMIJ.txt'): continue
                info = zipfile.ZipInfo(old.filename.replace('Birder-Veldupdate/', 'Birder-Illustratiecorrecties-27nov/', 1))
                info.external_attr = old.external_attr
                info.compress_type = zipfile.ZIP_DEFLATED
                output.writestr(info, source.read(old))
        for relative in ['Scripts/artwork_followup_20261126.py', 'Scripts/artwork_api_repairs.py',
                         'Scripts/artwork_api_pilot.py', 'Scripts/install_artwork_batch.py',
                         'Scripts/Start-Illustratiecorrecties-27nov.command', 'Docs/ArtworkFollowup20261127.json',
                         'Docs/ILLUSTRATIECORRECTIES_20261127.md']:
            output.write(ROOT / relative, 'Birder-Illustratiecorrecties-27nov/' + relative)
        output.writestr('Birder-Illustratiecorrecties-27nov/LEESMIJ.txt', (ROOT / 'Docs/ILLUSTRATIECORRECTIES_20261127.md').read_text())
    print(target.name)


if __name__ == '__main__': build()
