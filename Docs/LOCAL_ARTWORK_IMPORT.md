# API-illustraties lokaal in Birder installeren

De PNG’s blijven op je Mac. Voor deze stap is geen API-sleutel nodig en wordt
geen nieuwe beeldgeneratie gestart. Python 3 is nodig; de launcher installeert
Pillow zo nodig in een eigen lokale Python-omgeving. Houd de productiemappen
met state.json, review-template.json en de PNG’s bij elkaar.

## Snel: alles tegelijk accepteren en installeren

Op uitdrukkelijk verzoek van de eigenaar kan dit nu zonder afzonderlijke vinkjes:

1. Download het nieuwste `Scripts/Birder-illustraties-importeren.zip` en pak uit.
2. Open `Scripts/Importeer-API-illustraties.command`.
3. Kies de app-projectmap met `BirdingCompanion.xcodeproj`.
4. Typ **3**: **alle beelden accepteren en direct installeren**.
5. Kies de productiemap met `Start-Belgie-illustraties.command`.
6. Wacht op **Klaar** en bouw de app opnieuw in Xcode.

De PNG’s blijven op de Mac. Bestaande identieke beelden worden overgeslagen en
bestaand ander werk wordt niet overschreven. De tool controleert de bestanden,
hashes, bronregistratie, afmetingen en alpha. Geen API-sleutel of nieuwe betaalde
generatie. Voor een aparte oorspronkelijke proefmap kun je dezelfde stappen
herhalen. Opties 1 en 2 hieronder blijven beschikbaar voor individuele controle.

Bulkacceptatie wordt per exacte PNG opgeslagen als `ownerAcceptance` met
bestands-SHA-256, methode en tijdstip. Dit is een acceptatie door de eigenaar,
geen verklaring dat anatomie of soortkenmerken individueel gecontroleerd zijn.
Die velden blijven false; de manifeststatus geeft dat expliciet aan. De twintig
reeds door Codex bekeken proefbeelden houden hun bestaande echte review.
Specifieke correcties kunnen later afzonderlijk worden aangevraagd.

## 1. Controleoverzicht maken

1. Download `Scripts/Birder-illustraties-importeren.zip` en pak de hele map uit.
2. Dubbelklik `Scripts/Importeer-API-illustraties.command`.
3. Kies de **app-projectmap**: de volledige map met `BirdingCompanion.xcodeproj`.
   Kies de appversie die je daadwerkelijk in Xcode gebruikt. Het losse
   Belgische productie-/scriptpakket is geen app-projectmap.
4. Typ **1** en druk Enter.
5. Kies de **productiemap** met `Start-Belgie-illustraties.command`. De verborgen
   submap `.artwork-api/belgium-medium` wordt automatisch gevonden. Voor de
   oorspronkelijke proef kies je de oorspronkelijke projectmap met
   `.artwork-api/pilot-medium`. Staat beide uitvoer onder één map, dan neemt de
   tool beide mee. Je mag ook rechtstreeks een uitvoermap met state.json kiezen.
6. De tool controleert bestanden, ID’s, hashes en transparantie, en opent een
   controlepagina in je browser. Deze technische controle keurt niets visueel goed.

Bestaande, exact identieke geïnstalleerde beelden worden overgeslagen. Bij een
ander of onvolledig bestaand beeld stopt de tool; ze worden nooit vervangen.

## 2. Beelden beoordelen

Open elk origineel op volle grootte. Controleer soort, verenkleed, stijl,
transparantie, één kop/snavel, twee vleugels zonder extra gevouwen vleugel,
natuurlijke voeten en goede randruimte. Standaardbeelden: vogel naar rechts,
volledig in beeld, zonder takken, ondergrond, water, schaduw of attributen.
Dynamische scènes: bovenrand eindigt natuurlijk of vervaagt naar transparant.

Vink alleen afzonderlijk gecontroleerde, goede beelden aan. Geen knop keurt
alles tegelijk goed. Laat twijfelgevallen leeg. De browser probeert de selectie
lokaal te onthouden; dat hangt af van browserinstellingen. Bewaar tussentijds je
selectie via **Bewaar goedgekeurde selectie**. Dit downloadt
`Birder-goedgekeurde-illustraties.json`. Er zijn dan nog geen assets geïnstalleerd.
Bewaar de productiemap op dezelfde plek tot de import klaar is.

## 3. Installeren

1. Start dezelfde `.command` opnieuw.
2. Kies dezelfde app-projectmap.
3. Typ **2** en druk Enter.
4. Kies het gedownloade JSON-bestand met de goedgekeurde selectie.
5. Wacht op **Klaar** en bouw de app opnieuw in Xcode.

De tool valideert de goedkeuringen opnieuw tegen de exacte originele PNG’s en
API-checkpoints. De bestaande importer kopieert originele PNG’s ongewijzigd naar
Assets.xcassets en vult ArtworkManifest.json met generatieprovenance en
hashgebonden anatomiecontrole aan. Geen wijziging van soort-ID’s, logs, sessies,
kaarten of bestaande illustraties. Geen Xcode-projectwijziging nodig: het bestaande
assetcatalogus-buildonderdeel neemt de nieuwe imagesets mee.

Vóór installatie wordt het bestaande manifest gekopieerd naar
`.artwork-api/import-backups/`. Bij een afgevangen schrijffout worden uitsluitend
nieuw gemaakte imagesets teruggedraaid en het oude manifest hersteld. Dit is geen
belofte van een volledig crashbestendige transactie bij stroomuitval. Bewaar je
productiemappen en projectback-up. Een lock voorkomt twee gelijktijdige lokale
imports via deze tool. Dezelfde goedgekeurde selectie opnieuw importeren slaat
exact identieke assets over.

## Proefbatch toegevoegd op 24 november 2026

De twintig door de gebruiker aangeleverde originele API-PNG’s zijn afzonderlijk
op volle resolutie bekeken. Ook is een aanvullende composiet op de ivoorkleurige
appachtergrond bekeken, zodat verborgen RGB buiten de alpha niet als zichtbare
achtergrond wordt aangezien. Alle twintig zijn geïnstalleerd:

- Shikra, grote gele kwikstaart, mandarijneend, houtsnip, bruine kiekendief.
- Tjiftjaf, himalayavisuil, bruine hokko, zwartvoetpinguïn, oosterse roodstuitzwaluw.
- Elke soort: uitsluitend primary en dynamic; geen andere aanzichten aangemaakt.

De bestanden komen byte-voor-byte overeen met de huidige proef-checkpoint en
review-template van de gebruiker. Per origineel staan reviewnotities, SHA-256,
noProps waar vereist en generatieprovenance in
`ArtworkAPIPilotReviewedImport.json` en/of het artworkmanifest. De nieuwe
manifestrecords dragen batch `api-pilot-import-20261124`. Dit is een visuele
controle door Codex, geen onafhankelijke ornithologische expertgoedkeuring.
Er zijn geen nieuwe betaalde aanvragen verstuurd.

Verificatie: 15 bestaande API-productietests en 8 nieuwe lokale-importtests
(synthetische fixtures) geslaagd. De laatste dekken ontbrekende/gewijzigde
bestanden, geen automatische goedkeuring, behoud van originele bytes/provenance,
herhaalde import, bestaande conflicten en herstel na een gedeeltelijke schrijffout.
De assetmanifesten, individuele hashes en productie-inventaris zijn gecontroleerd.
Een Node-test met een gesimuleerde DOM controleert openen, goedkeuren en exporteren
van de geselecteerde hashgebonden review. Dit is geen echte browsertest.
De macOS-mapkiezers, browserbediening, Xcode-build en iPhone-weergave zijn hier
niet uitgevoerd en moeten op de Mac worden bevestigd.

## Verificatie van bulkimport

Vier aanvullende synthetische tests controleren echte CLI-installatie met optie
3/`--accept-all`, opnieuw uitvoeren zonder dubbels, hash-/tijdzonevalidatie van
eigenaaracceptatie, het behouden van false reviewvelden (ook bij onterechte true
invoer) en uitsluiting van uitgestelde rollen. In totaal 12 lokale-importtests
plus 15 API-productietests. Geen betaalde generatie of echte Belgische batch
uitgevoerd bij deze tests; macOS-mapkiezers en iPhone-weergave blijven onbevestigd.
