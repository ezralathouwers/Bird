# Illustratiecorrecties — 27 november 2026

Dit pakket bevat de appaanpassingen en een aparte herstelronde van **9 dynamische
illustraties**. De negen bronbeelden zijn alleen op je Mac beschikbaar; hier is
geen betaalde API-aanvraag uitgevoerd en er zijn nog geen nieuwe beelden beoordeeld.

## Installeren en beelden maken

1. Pak `Birder-Illustratiecorrecties-20261127.zip` uit als een **eigen map**.
   Bewaar de oude productiemappen met hun PNG's en checkpoints ongewijzigd.
2. Open `Scripts/Installeer-Veldupdate.command`, kies **1** en selecteer je
   **huidige volledige app-projectmap** met alle geïmporteerde illustraties.
   Dit voegt nog 30pt onderruimte toe aan doelstellingdetails, vergroot dynamische
   Pijlstaart en Grauwe gans met 35%, en past de negen herstelde soorten volledig
   binnen de schermbreedte. Alleen de broncode wordt bijgewerkt; je huidige
   illustraties, privékaarten, bundle identifier en signing blijven behouden.
3. Open `Scripts/Start-Illustratiecorrecties-27nov.command`, kies **1** en selecteer
   dezelfde app-projectmap. De negen afgekeurde originelen en hun hashes worden
   lokaal vastgelegd. Voer je API-sleutel verborgen in. Raming voor negen medium
   beelden: ongeveer **$0,25–$0,40**, exclusief btw/hergeneraties. Lokale kostenstop
   $2; geen harde factureringslimiet, één aanvraag kan die overschrijden.
4. Kies **2** om de resultaten te bekijken. Controleer soortkenmerken, precies
   twee vleugels, natuurlijke schouders en de volledige boven-/rechterrand.
   Kies daarna **3** en typ **JA** om de voltooide beelden samen te accepteren
   en te installeren. Er worden geen automatische anatomie-QA-vlaggen toegekend.
5. Bouw dezelfde app-projectmap opnieuw in Xcode en installeer over de bestaande
   iPhone-app. Verwijder de app niet.

## De negen rollen

| Soort | Correctie |
| --- | --- |
| Rosse sibia | Complete rechterrand van vogel, tak en bladeren, 6% transparante rechterruimte |
| Zwartkopzanger | Natuurlijke houding met beide vleugels gevouwen |
| Roestflankzanger | Natuurlijke houding met beide vleugels gevouwen |
| Grijskopboszanger | Natuurlijke houding met beide vleugels gevouwen |
| Langstaartsnijdervogel | Natuurlijke houding met beide vleugels gevouwen |
| Bergkoolmees | Natuurlijke houding met beide vleugels gevouwen |
| Cederpestvogel | Natuurlijke houding met beide vleugels gevouwen |
| Zilverplevier | Natuurlijke houding met beide vleugels gevouwen |
| Tijgervink | Natuurlijke houding met beide vleugels gevouwen |

De standaardillustraties worden niet vervangen. Ook Pijlstaart en Grauwe gans
worden niet opnieuw gegenereerd; hun dynamische weergave schaalt 1,35 maal de
vorige grootte, vanuit de onderrand. De nieuwe onderruimte is aanvullend op de
35pt van de vorige update: de aparte onderpadding op doelstellingdetails is nu
89pt (oorspronkelijk 24 + 35 + 30), naast de bestaande algemene 20pt.

Het vaste document `Docs/ArtworkFollowup20261127.json` bevat per soort expliciete
leeftijd/geslacht/kleed, eigen korte diagnostische omschrijvingen en bronnen.
De Zwartkopzanger is Blackpoll Warbler (Setophaga striata), geen Zwartkop.
Rosse sibia is Heterophasia capistrata, geen Rufous-backed Sibia. De Zilverplevier
krijgt volwassen niet-broedkleed; andere seizoens-/geslachtskeuzes staan per rol
vast. Bronfoto's worden niet naar de API verstuurd; de ijvogel levert alleen stijl.

## Resultaten en veilig hervatten

Resultaten staan in de **nieuwe pakketmap**, in `.artwork-api/followup-20261127`:
`review.html`, de negen PNG's, `state.json`, `review-template.json`,
`framing-report.json`, het lokaal vastgezette `plan.json` en `originals/`.
Optie 2 opent het overzicht, ook voor tussentijdse resultaten. De verborgen map
maak je in Finder zichtbaar met Cmd+Shift+punt.

De vorige 15- en 77-beeldenrondes hebben andere opdrachten en outputmappen;
hun state.json en PNG's worden niet overgenomen of overschreven. Hervatten
slaat reeds gemaakte hash-gecontroleerde rollen over. Onzekere aanvragen
worden niet automatisch herhaald; verwijder geen checkpoints om te herstarten.

Installeren vervangt uitsluitend de negen lokaal vastgelegde bronhashes;
een inmiddels andere versie wordt niet overschreven. De app bewaart originele
assetmappen en manifest in `.artwork-api/repair-import-backups/repair-…`.
Een gewone schrijffout draait terug. Na hard afbreken: kies **4** om eerst te
herstellen. Een herhaalde installatie slaat reeds exact geïnstalleerde beelden over.

Technische alpha-/hashcontroles bewijzen geen juiste anatomie. De 6%-marge is een
generatiedoel en reviewadvies; een beeld dat echt de rechterrand raakt blijft
geblokkeerd. Visuele beoordeling blijft nodig voordat je JA kiest.

## Verificatie

Offline regressies controleren de negen exacte catalogus-ID's, lokale bronbinding,
vervangen met backups, hervatten zonder dubbele aanvragen en het gescheiden houden
van de oude 15-beeldenronde. De app-update wordt op bekende broncodeversies getest
met behoud van lokale assets. Swift-syntax wordt gecontroleerd; een echte Xcode-
build en visuele iPhone-controle zijn in deze omgeving niet beschikbaar.
