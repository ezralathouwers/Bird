# Belgische illustratieopdracht — 23 november 2026

Praktische ruime selectie, zoals gevraagd: ook zeldzame/historische bezoekers en
gevestigde geïntroduceerde soorten. Geen claim van een exact, actueel officieel
nationaal totaal. De eerste proef is uitsluitend gebruikt om gemaakte beelden
te herkennen en kosten/tijd te ramen; individuele originele beelden moeten nog
beoordeeld worden voordat ze worden geïnstalleerd.

## Omvang

- 478 actieve catalogussoorten in de praktische selectie.
- 143 soorten hebben beide rollen al in het project of in de voltooide proef.
- **335 overige soorten, 670 beelden**: standaard plus dynamisch.
- Geen voor-, achter- of vierde vluchtaanzichten; geen vervanging van bestaand werk.
- De vijf Belgische proefsoorten worden overgeslagen: mandarijneend, houtsnip,
  bruine kiekendief, tjiftjaf en grote gele kwikstaart. De overige vijf proefsoorten
  vallen buiten deze Belgische selectie en worden ook niet opnieuw gemaakt.

De gekozen checklist, bronstatus en productie-/uitsluitingsreden staan per
catalogus-ID in `BelgiumArtworkInventory.csv`. `BelgiumArtworkSummary.json`
bevat totalen en bronhashes; de productieopdracht staat in `BelgiumArtworkAPIPlan.json`.

## Starten

Download `Scripts/Birder-Belgie-illustraties.zip`, pak de hele map uit en dubbelklik
bovenaan **Start-Belgie-illustraties.command**. Alleen Python 3, een internetverbinding
en een werkende API-sleutel met voldoende tegoed zijn nodig. De launcher maakt een
lokale venv met Pillow en certifi. De sleutel wordt verborgen ingevoerd en niet
opgeslagen. Dit is een los productie-/reviewpakket: je hoeft je app of logs niet
te vervangen en geen BirdLife-kaarten te verplaatsen.

Raming op basis van de 20 voltooide proefbeelden: circa **$17–20**, zonder btw of
hergeneraties. Zorg voor voldoende API-tegoed. De lokale verbruiksstop is $25,
geen gegarandeerde factureringslimiet: een lopende aanvraag kan de stopdrempel
overschrijden. Er worden maximaal 670 nieuwe aanvragen in de vastgelegde scope
verstuurd. Er is hier geen betaalde generatie gestart.

De proef duurde gemiddeld 18,74 seconden per beeld. 670 beelden zouden achter
elkaar circa 3,5 uur vragen; dit is een extrapolatie en geen tijdsgarantie.
Houd de laptop open en aangesloten. `caffeinate -i` voorkomt op macOS normale
inactiviteitsslaap tijdens de run, maar garandeert geen uitvoering met gesloten klep.

Dezelfde model-snapshot, medium-kwaliteit, PNG/transparantie, maten en
ijvogel-stijlreferenties als de proef worden gebruikt. De overige soortprompts
gebruiken de bestaande wetenschappelijke namen, korte brongebonden appbio waar
beschikbaar en een passende habitat-/familiescène. Die prompts zijn geen
individuele expertvalidatie van de nieuwe afbeeldingen. Het volwassen verenkleed
blijft consistent binnen elk paar. De standaard is alleen een vogel naar rechts;
dynamische scènes eindigen of vervagen vóór de bovenrand en mogen in de app
langs de zijkanten aflopen.

## Voortgang, stoppen en hervatten

Elke geslaagde afbeelding en het API-verbruik worden direct vastgelegd onder
`.artwork-api/belgium-medium/`. De reviewpagina wordt na elk nieuw beeld
bijgewerkt en gebruikt lazy loading zodat niet meteen honderden PNG's worden
geladen. Ze opent na afronden of stoppen; open `review.html` uit die verborgen
map desgewenst tussendoor en ververs om de voortgang te bekijken.

Start hetzelfde bestand opnieuw om verder te gaan. Geslaagde, hash-gecontroleerde
beelden worden overgeslagen. Na een expliciete API-afwijzing met bekende foutcode
voor onvoldoende tegoed/rate limit/modeltoegang kan een nieuwe, handmatig gestarte
run die afgewezen aanvraag herhalen. Er is geen automatische betaalde retry.
Eerdere afwijzingen blijven in de checkpointgeschiedenis. Bij een onzekere
netwerk-/timeoutuitkomst blokkeert hervatten tot die is nagekeken: wis de checkpoint
niet en start niet blind een nieuwe kopie van de opdracht.

Beoordeel alle kandidaten afzonderlijk op volle grootte vóór installatie. De
controlevelden staan standaard op false. Het pakket keurt niets automatisch goed
en installeert niets in de app. Geen API-sleutel opnemen wanneer je kandidaten of
state.json deelt. De brede wereldwijde automatisering blijft gepauzeerd; deze
opdracht geldt uitsluitend voor deze Belgische selectie.

## Bronafbakening

Bronnen opgevraagd op 23 november 2026:

- [Avibase België, AviList 2026](https://avibase.bsc-eoc.org/checklist.jsp?region=BE&list=avilist&lang=NL).
- [BRBC Belgische checklist](https://www.belgianrbc.be/checklist.php).

Alle 497 Avibase-rijen kwamen via stabiele Avibase-ID en dezelfde wetenschappelijke
naam overeen met de appcatalogus. Van 22 rijen met onzekere herkomst is Ross' gans
wel door BRBC bevestigd; de overige 21 blijven buiten de productie. De ene
uitgestorven soort (dunbekwulp) blijft uitgesloten. Drie aanvullende BRBC-soorten
zijn opgenomen: purperkoet, huisgierzwaluw en het behouden appconcept bonte kraai.
De oudere brede BRBC-naam *Cecropis daurica* wordt niet blind als oosterse
roodstuitzwaluw toegevoegd: de Europese soort *C. rufula* staat al apart in de
actuele Avibase-lijst. Deze praktische afbakening levert 478 actieve catalogus-ID's.
Bronlijsten kennen revisiedata en taxonomische verschillen; het productiedoel is
ruime Belgische dekking, geen nieuwe nationale taxonomische autoriteit.

## Controle van de voorbereiding

Offline tests controleren de 335/670 afbakening, uitsluiten van bestaand werk en
proefsoorten, veilige verbruiksstop, hervatten na expliciete quota-afwijzing en
het blokkeren van onbekende uitkomsten. Geen API-sleutel of betaalde productie
is gebruikt bij die tests. De ZIP bevat alleen expliciet geselecteerde scripts,
broninventaris, catalogus/assetmetadata en de twee bestaande stijlreferenties;
geen lokale checkpoints, privégegevens, API-sleutels of volledige app.
