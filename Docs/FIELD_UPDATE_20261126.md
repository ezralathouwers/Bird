# Veldfeedback — 26 november 2026

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
