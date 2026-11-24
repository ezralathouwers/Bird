# Ontbrekende logboekillustraties via de API

Deze opdracht selecteert de vogelsoorten uit je actuele geschiedenis en maakt
alleen de ontbrekende standaard- en dynamische illustraties. De drie andere
rollen worden niet gemaakt. Bestaande illustraties worden niet vervangen.

## Starten op de Mac

1. Zorg dat je eerdere Belgische/proefbeelden eerst in je huidige app-project
   zijn geïnstalleerd. De selectie gebruikt de werkelijke imagesets en het
   artworkmanifest in die projectmap, niet alleen de meegeleverde voorbeeldinventaris.
2. Maak op de iPhone een recente back-up via Ontdek → back-upicoon → Gegevens en
   back-ups → Maak nu een back-up. Gebruik iCloud Drive of zet het bestand naar
   je Mac. Zo zitten ook je nieuwste waarnemingen in de selectie.
3. Download `Scripts/Birder-Logboek-illustraties.zip` en pak de hele map uit.
4. Open `Scripts/Start-Logboek-illustraties.command`.
5. Kies je huidige app-projectmap met `BirdingCompanion.xcodeproj` en vervolgens
   je recente Birder-back-up (.json). Een oudere Birda-CSV of ruwe JSON-export
   kan ook, maar bevat mogelijk niet je nieuwste logs.
6. De Terminal vermeldt het aantal gelogde soorten, de soorten met ontbrekend
   werk en het aantal nieuwe beelden. Daarna voer je de API-sleutel verborgen in.

De `.command` start na deze selectie betaalde generatie. Dezelfde gecontroleerde
model-snapshot, medium-kwaliteit, transparante PNG’s, maten, primaire/dynamische
instructies en ijvogel-stijlreferenties als bij de proef blijven gelden. Prompt-
context gebruikt publieke catalogus-/habitat-/bio-informatie. Dit is geen
individuele ornithologische expertcontrole.

De raming gebruikt circa $0,026 per beeld uit de eerdere proef, zonder btw of
hergeneraties. De lokale verbruiksstop is $25; dit is geen harde platformlimiet
en een lopende aanvraag kan die overschrijden. De API Usage-pagina bepaalt de
werkelijke rekening. Houd de laptop open en aangesloten; caffeinate voorkomt
normale inactiviteitsslaap, niet alle onderbrekingen.

## Hervatten, bewaren en installeren

Alle uitvoer staat in de nieuwe productiemap onder
`.artwork-api/logbook-medium/`: `plan.json`, `summary.json`, `state.json`, de
originele PNG’s, `review.html` en `review-template.json`. Op de Mac maakt ⌘⇧.
verborgen mappen zichtbaar. De bestaande proef- en Belgische uitvoer blijven intact.

De eerste selectie wordt vastgelegd. Hetzelfde bestand opnieuw starten hervat
**diezelfde** opdracht, ook als je logboek intussen is veranderd. Voltooide,
hash-gecontroleerde aanvragen worden niet nogmaals betaald. Onzekere netwerk-
uitkomsten worden niet blind herhaald; bestaande runner/checkpointregels blijven
van kracht. Laat de checkpoint staan. Gebruik voor een volgende uitbreiding een
nieuw uitgepakt productiepak nadat eerdere beelden in het app-project staan.

Na afronden kun je alle nieuwe kandidaten lokaal in één keer accepteren:
open `Scripts/Importeer-API-illustraties.command` in ditzelfde pakket, kies je
app-projectmap, kies **3**, en kies de nieuwe productiemap. Het hulpprogramma
vindt `.artwork-api/logbook-medium` automatisch. Bulkacceptatie wordt eerlijk
vastgelegd als eigenaaracceptatie zonder individuele anatomiecontrole.
Bouw daarna de app opnieuw in Xcode. Voor afzonderlijke visuele controle blijven
opties 1 en 2 beschikbaar.

Je hoeft geen honderden afbeeldingen naar ChatGPT te uploaden. De back-up wordt
lokaal gelezen; locaties, tijdstippen, notities en de back-up zelf worden niet
naar de beeld-API gestuurd of in het productiepakket gekopieerd. De sleutel
wordt niet opgeslagen. De vaste selectie/checkpoints zijn lokale privébestanden
onder de al uitgesloten `.artwork-api`-map.

## Voorbereiding en verificatie

De generieke runner kent nu een begrensde `logbook`-scope, met een vaste lijst
catalogus-ID’s en scopehash, en een expliciete lokale project-root voor de
catalogus/stijlreferenties. Een beschadigde back-up, onbekende soort, onvolledig
bestaand imageset of afwijkende geregistreerde bestandshash stopt vóór generatie.

Zes synthetische Python-tests controleren actuele back-ups/checksums, eerdere
exportformaten, CSV-namen, onbekende soorten, alleen gelogde soorten/missende
rollen, bestaand werk behouden, scopewijzigingen weigeren en offline hervatten.
Een aanvullende lokale dry-run met de aangeleverde geschiedenis en de volledige
catalogus valideert de koppeling. Er zijn hier geen betaalde API-calls gestart.

Voor een kosteloze Terminal-proef kan de voorbereider zonder --execute draaien:
`python Scripts/prepare_logbook_artwork.py --project /pad/naar/app --history /pad/naar/backup.json --output /tmp/logboek-proef`.
