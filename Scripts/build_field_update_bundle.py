#!/usr/bin/env python3
"""Package only source/config changes; never package local bird artwork or credentials."""
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]
BASE='e3b45d08a483d7a6e4d6120479273357c73fea49'
REVISIONS=['43a0f359c1e66f454c5d37f7da9f95056da75a34','41e8bf3f6ad9dbdd544ac586dbe12c8a1b7f6067','09021ef3e66239892e0ca79fd57d5394a26359f2','1e38b351b05acc944e261c9bad361b51880b1baa','793eff42070aa8c6582f0d02586288b64c267f98',BASE,'0e2dcc08f0028219173ad6a640e5dd3a7507dd57','c3ab1fbce7fa9dd69803ffdeb18b7867c23dd1ea']
SOURCES=[
 'BirdingCompanion/App/CompanionRootView.swift',
 'BirdingCompanion/DesignSystem/FieldGuideTheme.swift',
 'BirdingCompanion/Features/Countries/CountriesView.swift',
 'BirdingCompanion/Features/Discover/DiscoverModels.swift',
 'BirdingCompanion/Features/Discover/DiscoverView.swift',
 'BirdingCompanion/Features/Discover/EBirdConnectionView.swift',
 'BirdingCompanion/Features/Identification/IdentificationModels.swift',
 'BirdingCompanion/Features/Identification/IdentificationViews.swift',
 'BirdingCompanion/Features/Identification/PhotoCropView.swift',
 'BirdingCompanion/Features/Goals/GoalsView.swift',
 'BirdingCompanion/Features/Backups/DataBackupsView.swift',
 'BirdingCompanion/Features/Backups/BirdaImportView.swift',
 'BirdingCompanion/Features/Identification/SoundIdentificationModel.swift',
 'BirdingCompanion/Features/Identification/AudioRecordingActivity.swift',
 'BirdingCompanion/Models/AudioRecordingAttributes.swift',
 'BirdingCompanion/Features/Observations/ObservationHistoryView.swift',
 'BirdingCompanion/Features/Observations/ObservationMapView.swift',
 'BirdingCompanion/Features/Countries/FirstObservationsMap.swift',
 'BirdingCompanion/Features/SpeciesGuide/SpeciesDistributionMap.swift',
 'BirdingCompanion/Features/Sessions/SessionEnhancements.swift',
 'BirdingCompanion/Features/Sessions/SessionLiveLogger.swift',
 'BirdingCompanion/Services/ObservationLocationModel.swift',
 'BirdingCompanion/Persistence/ObservationStore.swift',
 'BirdingCompanion/Features/Sessions/SessionsView.swift',
 'BirdingAudioActivity/AudioRecordingWidget.swift','BirdingAudioActivity/Info.plist']

def build():
    files={}
    for relative in SOURCES:
        known=set(); existed_before_field=False
        for revision in REVISIONS:
            result=subprocess.run(['git','show',revision+':'+relative],cwd=ROOT,capture_output=True)
            if result.returncode==0:
                known.add(hashlib.sha256(result.stdout).hexdigest())
                if revision==BASE:existed_before_field=True
        files[relative]=dict(sha256=hashlib.sha256((ROOT/relative).read_bytes()).hexdigest(),knownOld=sorted(known),requiredExisting=existed_before_field)
    config='Docs/FieldUpdateFiles20261126.json'
    (ROOT/config).write_text(json.dumps(dict(version=1,files=files),indent=2)+'\n')
    include=SOURCES+[config,'Scripts/install_field_update.py','Scripts/field_update_project.py','Scripts/Installeer-Veldupdate.command','Docs/FIELD_UPDATE_20261126.md']
    path=ROOT/'Scripts/Birder-Veldupdate-20261126.zip'
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as archive:
        for file in include:archive.write(ROOT/file,'Birder-Veldupdate/'+file)
        archive.writestr('Birder-Veldupdate/LEESMIJ.txt','Open Scripts/Installeer-Veldupdate.command en kies 1.\nKies je HUIDIGE volledige app-projectmap met alle illustraties en privékaarten.\nOpen hetzelfde project daarna in Xcode, controleer bij BirderAudioActivity dezelfde signing-Team als bij de app en bouw de app opnieuw.\nJe app-bundle identifier blijft behouden; de widget krijgt dezelfde prefix met .AudioActivity.\nGeen illustraties, privékaarten, appdata of sleutels worden vervangen.\nLees Docs/FIELD_UPDATE_20261126.md voor werking, controles en toesteltests.\n')
    print(path.name,len(files),'bronbestanden')

if __name__=='__main__':build()
