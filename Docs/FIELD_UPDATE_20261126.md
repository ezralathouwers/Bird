# Veldfeedback — 26 november 2026

Laatste illustratieronde: acht compacte portretten iets groter, twee dynamische
beelden +15%, drie dynamische beelden 45pt naar rechts. Gecorrigeerde/nieuwe
dynamische soorten krijgen volledige breedtepassing. De aparte lokale
15-beeldenopdracht zit in Birder-Illustratiecorrecties-20261126.zip; zie
ILLUSTRATIECORRECTIES_20261126.md. Deze broncode-update behoudt alle PNG's.

## In je bestaande project installeren

Pak `Birder-Veldupdate-20261126.zip` uit, open
`Scripts/Installeer-Veldupdate.command` en kies 1. Selecteer de **huidige**
volledige Xcode-projectmap met alle geïmporteerde illustraties en privékaarten.
Het hulpmiddel controleert bekende broncodeversies vóór wijzigingen, bewaart
herstelkopieën en past alleen broncode en vereiste configuratie aan. Assets,
artworkmanifest, PrivateBirdLifeRanges, appdata en sleutels blijven ongemoeid.
Lokale onbekende broncodewijzigingen blokkeren de update in plaats van ze te
overschrijven. Na een hard onderbroken update: kies 2 om terug te draaien.

De app-target, bundle identifier en signing-instellingen blijven behouden.
Het Xcode-project krijgt een ingebedde WidgetKit-extensie BirderAudioActivity
met dezelfde bundle-prefix + `.AudioActivity`. De bestaande Team wordt waar
mogelijk overgenomen; controleer in Xcode dezelfde Team voor app en extensie.
Bouw het **gekozen project** opnieuw, verwijder de bestaande iPhone-app niet.
Er is geen server, pushcertificaat of betaalde beeldgeneratie nodig.

## Audio ID en Live Activity

- De expliciete stop bij scenePhase.background is verwijderd. UIBackgroundModes
  bevat audio; AVAudioSession gebruikt playAndRecord/measurement met mixWithOthers.
  De app-eigen capture-/herkenningstaken blijven draaien bij navigatie, wisselen
  van app en vergrendelen. Er wordt geen opnamebestand automatisch bewaard.
- iOS kan de microfoon onderbreken, bijvoorbeeld bij een telefoongesprek of
  andere microfoonapp. Bij een hervatbare onderbreking hervat Birder met behoud
  van resultaten, pins en de oorspronkelijke starttijd. Handmatig stoppen wist
  de hervatwens. Hardware-/toestemmingsfouten blijven expliciet zichtbaar.
- Een lokale Live Activity toont Birder Audio ID en de verstreken tijd op het
  vergrendelscherm en, op ondersteunde iPhones, Dynamic Island. Tik opent
  birder://audio en navigeert naar het gedeelde opnamemodel. Dezelfde opname
  wordt ook via Audio ID op het livesessiescherm hergebruikt.
- Een heartbeat ververst de activiteit elke 20 seconden; na 60 seconden zonder
  update toont zij dat de status gecontroleerd moet worden. Een geforceerd
  afgesloten proces kan zelf geen laatste ActivityKit-update versturen; iOS
  beheert het verwijderen en de maximale looptijd van Live Activities. Bij een
  volgende appstart worden oude indicatoren opgeruimd. Een uitgeschakelde Live
  Activities-instelling blokkeert de opname niet.
- Sonogram van 120 naar 84pt. Resultaatpijl verwijderd; naam/illustratie blijven
  navigeren. Plus rechts uitgelijnd. Zonder livesessie opent plus het gewone
  formulier; met livesessie voegt hij aan die sessie toe. Donkerder beige bij
  actuele detectie; de animatie over de volledige rij/knop is verwijderd.
  Actueel gehoorde soorten schuiven nog steeds boven de overige resultaten;
  vastgezette soorten blijven bovenaan. Alleen tijdens het indrukken van een
  plus blijft de rijvolgorde kort vast, zodat de knop niet onder je vinger
  verschuift. Na loslaten volgt direct weer de actuele volgorde.

## Geografische context

Audio haalt een actuele GPS-fix op, onafhankelijk van Ontdek. Herkende soorten
worden asynchroon gecontroleerd met het bestaande lokale BirdLife-pakket en de
gewone Belgische soortenlijst. Binnen kaart of 25km-buffer: waarschijnlijk.
Buiten dat gebied maar binnen 2.500km van een grens: behouden met zacht oranje
bolletje. Pas bij nog grotere afstand wordt een audioresultaat verborgen.
Dat is een ruime afstandsregel, geen biologische garantie van onmogelijkheid.
Geen/ongeldige/lege kaart of ontbrekende locatie: onbekend, nooit wegfilteren.
De plaatselijke checklist kan introducties/gewone soorten beschermen tegen een
gegeneraliseerde kaart. Er wordt geen geluidsidentificatie automatisch gelogd.

De livesessiezoeker behoudt alle tekstmatches. Recente plaatselijke meldingen,
gewone regionale soorten en positieve beschikbare kaartcontroles staan eerst;
dan een scheidingslijn en alle overige soorten, ook onbekende/onwaarschijnlijke.
Bij tekstzoeken worden de matches na een korte debounce van lokale kaartcontext
voorzien. Zonder zoektekst leveren meldingen/checklist de eerste groep; niet de
hele wereldatlas wordt bij iedere opening doorgerekend. Catalogusfiltering loopt
buiten de hoofdactor en wordt gecachet om opname-updates niet met herhaald
sorteren van de wereldcatalogus te belasten.

## Ontdek en vormgeving

- Instellingen heeft Locatie boven Zoekstraal. Standaard actuele GPS; een gekozen
  kaartplek wordt alleen als Ontdek-voorkeur op dit toestel bewaard. Terug naar
  live blijft mogelijk. In live-modus wordt bij zichtbaar Ontdek periodiek een
  verse fix gevraagd met het gedeelde cachebeleid. Sessies/logs/audio blijven
  echte GPS gebruiken; een gekozen ontdeklocatie verplaatst die niet.
- Bij externe waarnemingen: zichtbaar, meedraaiend MapCompass linksboven dat naar
  het noorden reset, en UserAnnotation met een subtiel pulserende olijfgroene stip.
  Geen user-tracking/automatisch uitzoomen; de camera blijft op de melding of de
  door de gebruiker gekozen uitsnede staan. Minder beweging respecteert iOS.
- Afgeronde sessies hebben grotere leefomgevingsillustraties rechtsonder, met een
  fade naar links en uitloop rechts; lijntjes lopen over de volle schermbreedte.
  Automatische habitatkeuze en handmatige aanpassing blijven intact.
- Vlagcirkels zijn 22pt, gelijk aan de landdetail-header, ook in landen/sessies.

## Verificatie en toestelcontrole

XCTest-regressies toegevoegd voor onbekende kaarten/ongeldige locaties,
continentverschil versus dwaalgasten, datumgrens, behoud/volgorde van alle
zoekmatches en de afzonderlijke Ontdek-locatievoorkeur. Deze native tests en een
Xcode-build kunnen niet op deze Linux-omgeving worden uitgevoerd.

Python-tests controleren projectintegratie/signingbehoud/herhaalbaarheid en de
in-place updater, broncodeconflicten, herstelkopieën, terugdraaien, privéassets
behouden en een hard onderbroken update. Swift-syntax en OpenStep-projectstructuur
worden apart gecontroleerd; dat vervangt geen iOS-build of toesteltest.

Controleer op iPhone: begin Audio ID, wissel app en vergrendel 2 minuten, open via
Dynamic Island, test plus tijdens een highlight met/zonder livesessie, open
Audio ID vanuit de sessie, roteer de externe kaart en reset met kompas, kies een
andere ontdeklocatie en verifieer dat echte logs GPS blijven gebruiken. Controleer
ook ruime bereikmarges en de sessielandschappen met de eigen privékaarten/data.

## Herstel voor door Xcode geformatteerde projectbestanden

De eerste updater kon stoppen met `Projectveld ontbreekt: files`. De combinatie
van Xcode-commentaar bij ID-verwijzingen en herschikte projectsecties liet de
objectzoeker voorbij een commentaareinde lezen. Daardoor werd een verwijzing
als definitie behandeld en een verkeerd onderdeel uitgelezen.

De zoeker mag nu nooit voorbij het eerste afsluitende commentaar doorzoeken.
Regressies bootsen Xcode-commentaren bij alle ID's en de sectievolgorde na,
controleren de juiste Sources-definitie en voeren de volledige update tweemaal
uit met behoud van instellingen en privébestanden. Er zijn nu negen Python-
tests voor projectintegratie en installatie. De fout trad vóór de schrijffase
op; download de bijgewerkte zip en voer optie 1 opnieuw uit in hetzelfde project.

## Swift 6 / ActivityKit-buildherstel

Op sommige SDK-versies is Activity niet Sendable. De eerste controller bewaarde
het Activity-object op MainActor en gebruikte het als receiver van asynchrone
SDK-methoden, wat drie Swift 6-fouten over mogelijke data races opleverde.
De controller bewaart nu alleen het String-ID. Niet-geïsoleerde clientoperaties
zoeken een lokaal SDK-handle op voor een update of beëindiging. Er worden dus
alleen Sendable IDs en tijdstippen tussen actor/taken doorgegeven, geen bewaarde
Activity-referenties. Geen @unchecked Sendable of uitgezette concurrencycontrole.

Download de bijgewerkte veldupdate, voer optie 1 opnieuw uit op hetzelfde reeds
bijgewerkte project en bouw opnieuw. Bestaande veldversies worden herkend;
illustraties, kaarten en signing blijven behouden. Native Apple-SDK-compilatie
blijft hier niet beschikbaar; een syntaxcontrole is geen iPhone-buildtest.

De reparatie is ook getest op een project met de reeds geïnstalleerde veldversie:
alleen AudioRecordingActivity.swift verandert, en opnieuw uitvoeren wijzigt niets.
De updater herkent zowel oudere appversies als de twee uitgebrachte veldversies.
Het bestandsplan onderscheidt vereiste oude bronbestanden van nieuw toegevoegde
Live Activity-bestanden. Alle tien Python-project/update-tests slagen.

## Aanvullende feedback — 26 november

Alle Audio ID-resultaten blijven nu zichtbaar: afstandsclassificatie impossible
krijgt een zacht rood bolletje; unlikely houdt oranje. Ontbrekende kaartcontext
blijft ongemarkeerd. Geen resultaat wordt hierdoor automatisch verwijderd of
gelogd. Live volgorde/pins en de kort vastgehouden plusknop blijven behouden.

De livesessiezoeker toont ONWAARSCHIJNLIJK als afgeronde familieachtige strip
boven de overige resultaten, met 16pt bovenmarge. De strip duidt de restgroep
aan, waaronder ook soorten zonder lokale context; het is geen zeker oordeel
over aanwezigheid. Sessielandschappen gaan 20pt omlaag en het transparantiemasker
verschuift 40pt naar rechts, zonder bronafbeeldingen te wijzigen.

Het standaard SwiftUI-kompas is vervangen door een steeds zichtbare, enabled
44pt-knop met dezelfde volledig dekkende achtergrond als MapCloseButton. Voor
eigen/externe waarnemingen volgt de naald de MapCamera en wordt alleen heading
naar nul gezet. Native kaarten voor sessies/landen/logboek en fullscreen
verspreiding gebruiken dezelfde knop en reset op een kopie van hun actuele
camera; centrum, afstand en pitch blijven behouden. Compacte verspreidingskaarten
krijgen geen extra bediening. De bronvermelding schuift naast de nieuwe knop.

Een native XCTest controleert de ondoorzichtige/enabled knop en reset met behoud
van camera. Deze test vereist Xcode en is hier niet uitgevoerd. De in-place
updater herkent de vorige veldversie inclusief de Swift 6-reparatie en bewaart
alle illustraties/privékaarten/signing. Alleen relevante bronbestanden veranderen.

## Plaatsnamen en verdere kaartverfijning — 26 november

Sessielandschappen gaan nog 15pt omlaag (nu 35pt ten opzichte van de eerste
veldversie); de fade nog 30pt naar rechts (nu 70pt). Sorteerknop op sessiedetails
15pt lager. Externe-linkmarkering krijgt afgeronde hoeken; alle fullscreen
kaartsluitknoppen gebruiken de gedeelde 0,7pt-lijn in plaats van een SF-glyph.

De native compass gebruikte de interne UIImageView van UIButton voor rotatie.
UIKit kon de getransformeerde afbeelding opnieuw indelen en vervormen. De naald
zit nu in een eigen vast 22×22pt beeldvlak met aspect-fit; alleen de tekenlaag
draait. De achtergrond en 44pt-hitbox draaien niet. De native regressie draait
meerdere hoeken en controleert gelijke bounds en ongewijzigde schaal; uitvoering
hiervan vereist nog de Apple-SDK.

Waarnemingen tonen direct de betekenisvolle naam van hun sessie. Gekoppelde
records met een lege/coördinatennaam worden ook opgeslagen met die sessienaam;
eigen betekenisvolle detailnamen worden in de data behouden. Nog onbekende losse
waarnemingen/sessies krijgen geleidelijk via de bestaande Apple-plaatsnaamdienst
een naam, met 1,5s tussen verzoeken, gedeelde cache en groepering op circa 11m.
Bij netwerkproblemen pauzeert dit tot de volgende appactivatie; geen verzonnen
plaatsnamen of massale herhaalverzoeken. (0,0) blijft een ontbrekende plek.
Tot er een echte plaatsnaam is, tonen overzichten het bekende land of
‘Locatie onbekend’, zonder numerieke coördinaten als titel. Externe kaartmeldingen
zonder plaatsnaam krijgen ook een lokale plaatsnaamlookup voor hun weergave.

Vóór de eerste naamsaanpassing per geladen geschiedenis maakt de persistencelaag
een RecoveryCopies-kopie. De oorspronkelijke titels blijven bovendien in
importMetadata[locationRepair.originalName]. Updates controleren nogmaals ID,
coördinaten en oorspronkelijke naam; recente gebruikersbewerkingen/verwijderingen
of een herstelde geschiedenis worden niet door oude antwoorden overschreven.
IDs, coördinaten, tijden, aantallen, notities, doelen en eerdere correctiemarkeringen
blijven behouden. Opslaan blijft atomisch; bij schrijffouten verandert de
gepubliceerde geschiedenis niet. Titelherstel pauzeert bij achtergrond, terwijl
Audio ID mag blijven opnemen. Geen nieuwe betaalde diensten of API-sleutels.

Native regressies toegevoegd voor coördinatenherkenning (met behoud van namen en
adressen), sessievoorrang, oorspronkelijke metadata, recoverykopie, bestaande
correctiemarkeringen, verouderde antwoorden en schrijffouten. Zij zijn hier niet
uitgevoerd; Python-installatietests en syntaxcontrole blijven aparte controles.

## Vaste headers, velden en marges — 26 november

Sessies en doelstellingen hebben elk 10pt meer bodemruimte (94 → 104pt).
Sessielandschappen zakken nog 5pt (nu 40pt). Alleen de runtimeplaatsing verandert;
geen bronafbeeldingen worden aangepast.

De gedeelde scrollfade staat nu ook onder vaste terugknopheaders van formulieren,
back-ups/preview, Birda-import, live-/sessiedetail en doelstellingdetail. Audio ID,
Foto ID en de uitsnede-editor hebben een gedeelde FixedHeaderScroll: de header
staat buiten het scrollvlak en het bestaande bewegende contentanker bepaalt de
fade, zodat hij in de beginstand onzichtbaar is. Schermen met een kaart of andere
niet-scrollende inhoud krijgen geen statische fade. Bestaande catalogus-/bron-
zoekers gebruikten die fade al. De native instellingen-Form behoudt zijn velden
met een positieprobe bij de eerste rij; als die wordt gerecycled blijft de
laatste scrolltoestand behouden tot de eerste rij terugkomt. Fade-lagen vangen
geen tikken en veranderen de werkelijke header/touchdoelen niet.

Het leefomgevingmenu is full width, beige met afgeronde hoeken en een rechts
uitgelijnd sorteer/pijl-icoon. De gekozen naam/automatische optie staat links;
Picker-selectie en Automatisch blijven werken. De toelichting is verwijderd.
De footer van bewerkformulieren heeft 5pt in plaats van 20pt bodemruimte onder
de verwijderactie. Toevoegformulieren behouden hun bestaande 20pt; opslaan,
verwijderen en de bevestigingsdialoog blijven functioneel ongewijzigd.

Verificatie: installatie/projectregressies, Swift-syntaxcontrole en een uitgepakt
updatepakket op de vorige veldversie. Native scrolling, toetsenbord, safe areas
en schermopmaak moeten nog op de iPhone worden beoordeeld. Er zijn geen tests
voor louter padding of kleuren toegevoegd.

Laatste veldverfijning: bij een bestaande sessie staat het leefomgevingmenu 5pt
hoger. Het label gebruikt één naar beneden gericht chevron met dezelfde 0,7pt
lijn als de overige iconen; keuze, breedte en achtergrond blijven behouden.
