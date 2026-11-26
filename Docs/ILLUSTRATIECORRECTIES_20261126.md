# Illustratiecorrecties — 26 november 2026

Pak Birder-Illustratiecorrecties-20261126.zip uit als een **eigen map**. De oude
productiemappen en hun resultaten/checkpoints blijven waar ze staan.

1. Open `Scripts/Installeer-Veldupdate.command`, kies **1** en selecteer je
   **huidige volledige app-projectmap**, met alle eerder geïmporteerde beelden.
   Dit werkt de groottes/plaatsing bij, met broncodeherstelkopie. Afbeeldingen,
   artworkmanifest, privékaarten, app-identiteit en signing worden behouden.
2. Open `Scripts/Start-Illustratiecorrecties.command`, kies **1** en selecteer
   dezelfde app-projectmap. De 11 afgekeurde originele rollen moeten daar
   aanwezig zijn; het programma bewaart hun exacte hashes en een lokale kopie.
   Voer de API-sleutel verborgen in. De nieuwe ronde maakt **15 beelden**,
   raming ongeveer **$0,40–$0,60** exclusief btw/hergeneraties. Lokale kostenstop
   $2; één aanvraag kan die overschrijden, dus geen harde factureringslimiet.
3. Kies **2** om de resultaten te bekijken, ook tijdens generatie. Bekijk elk
   origineel op volledige grootte. Kies daarna **3** en typ **JA** om alle
   voltooide beelden samen te accepteren en te installeren. Nieuwe beelden
   krijgen geen automatische anatomie-/kleuren-QA-attestatie.
4. Bouw **dezelfde app-projectmap** opnieuw in Xcode en installeer over de
   bestaande iPhone-app. Verwijder de app niet.

## Wat verandert in de weergave?

- Standaard: halsbandparkiet +12%, boomklever +18%, grote zilverreiger +22%.
  Boomkruiper, fitis, grauwe gans, grote stern en zwarte mees +15%.
  Dit is een gedeelde SwiftUI-weergavecorrectie; oorspronkelijke PNG's blijven
  intact. De rijhoogte en positie van de teksten veranderen niet.
- Dynamisch: taigaboomkruiper en halsbandparkiet +15%, vanuit de onderrand.
- Bruinstaarthoornkolibrie, grote kraaghoningzuiger en purperhoningzuiger:
  precies 45pt naar rechts ten opzichte van hun bestaande plaatsing.
- De gerepareerde/nieuwe dynamische soorten passen in de schermbreedte, zonder
  de algemene 18% horizontale overflow en -50pt verschuiving. Dit voorkomt
  opnieuw afsnijden van hun volledige bronbeelden op het scherm.

## De 15 API-beelden

| Soort | Rollen | Correctie |
| --- | --- | --- |
| Indische rotsmus | Standaard + dynamisch | Rustige bruingrijze kop; klein geel keelvlekje, lichte buik |
| Kaapse wever | Dynamisch | Twee gevouwen vleugels |
| Magelhaenspecht | Dynamisch | Twee gevouwen vleugels, natuurlijke aanhechting |
| Indische dwergaalscholver | Dynamisch | Precies twee spreidende vleugels, geen extra gevouwen vleugel |
| Waterroodstaart | Dynamisch | Volledige rechterrand van vogel en scène |
| Chinese reuzenijsvogel | Dynamisch | Volledige snavel/scène en rechterruimte |
| Baltimoretroepiaal | Dynamisch | Tak en bladeren eindigen natuurlijk rechts |
| Geelpootpapegaaiduif | Dynamisch | Volledige vogel en takken rechts |
| Zwarte frankolijn | Dynamisch | Rots/gras/vogel volledig binnen het canvas |
| Himalayaboomkruiper | Dynamisch | Volledige bovenrand; stam eindigt/vervaagt, minimaal 8% bovenruimte |
| Oostelijke koereiger | Standaard + dynamisch | Nieuwe illustraties, wit niet-broedkleed |
| Zwartbuikstern | Standaard + dynamisch | Nieuwe illustraties, broedkleed met zwarte buik |

Alle standaardbeelden bevatten uitsluitend de vogel, naar rechts, zonder props.
Alle prompts vragen minimaal 6% transparante rechterruimte, twee anatomisch
correcte vleugels en natuurlijke uiteinden van stammen/takken bovenaan.
De bronverwijzingen en eigen samenvattingen van soortkenmerken staan in
`Docs/ArtworkFollowup20261126.json`. Er worden geen foto's van derden verstuurd.
Bij Indische rotsmus bevestigen onder meer Qatar e-Nature en de gepubliceerde
beschrijving van de eerste Jordaanse waarneming het bescheiden keelvlekje.

## Resultaten, bewaren en hervatten

Deze ronde staat in de **nieuwe pakketmap** onder `.artwork-api/followup-20261126`:
`review.html`, PNG's, `state.json`, `review-template.json`, `framing-report.json`,
een lokaal vastgezet `plan.json` en `originals/` met de 11 afgekeurde bronnen.
Optie 2 opent dit overzicht rechtstreeks. De verborgen map is in Finder
zichtbaar met Cmd+Shift+punt. Je kunt ook naar de afgedrukte locatie navigeren.

Opnieuw optie 1 overslaat bestaande, hash-gecontroleerde resultaten. Onzekere
aanvragen worden niet automatisch herhaald. Verwijder nooit state.json of PNG's
om een nieuwe poging af te dwingen. Het plan uit de vorige 77-beeldenronde
blijft onaangeraakt; verplaats die checkpoints niet naar dit pakket.

Installatie vervangt uitsluitend exacte lokaal vastgelegde afgekeurde hashes;
de vier nieuwe rollen mogen geen bestaande beelden overschrijven. Bestaande
overige beelden blijven behouden. Een broncode-update alleen installeert deze
15 beelden niet. Technische rechterrandmeting bewijst geen correcte anatomie
of volledige scène; controleer zelf de originelen voordat je JA bevestigt.

Vervangen app-assets en manifest worden bovendien bewaard in de app-projectmap
onder `.artwork-api/repair-import-backups/repair-…`. Bij een gewone schrijffout
wordt teruggedraaid. Na hard afbreken: kies **4** in het correctiescript om eerst
de vorige installatie te herstellen. Bestaande generatiebestanden blijven staan.

## Verificatie en grenzen

Deze taak doet hier geen betaalde API-aanvragen. De echte afgekeurde beelden
staan alleen op de Mac; de 15 correcties worden daar gegenereerd en moeten nog
visueel beoordeeld worden. De bijgevoegde screenshots en drie beschikbare
bronillustraties zijn bekeken voor de weergaveaanpassingen.

Offline regressies controleren lokale bronbinding, gemengde toevoegingen en
vervangingen, hervatten zonder dubbele aanvragen, bronconflicten, backups en
rollback. De bestaande herstel-/API-/updatecontroles blijven van toepassing.
Swift-syntax kan hier gecontroleerd worden; er is geen Xcode beschikbaar voor
een native build of visuele iPhone-controle.
