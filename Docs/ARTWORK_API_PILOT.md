# API-proef voor Birder — 23 november 2026

Status: twintig opdrachten voorbereid, nul betaalde aanvragen verstuurd,
nul illustraties gegenereerd of geïnstalleerd. Er is hier geen API-sleutel.
De brede illustratieproductie en terugkerende taak blijven gepauzeerd.
Alleen deze expliciet gevraagde proef van tien soorten/twee rollen is toegestaan.

## Eerst je API-account instellen

1. Log met je bestaande account in op <https://platform.openai.com/>.
2. Maak een project, bijvoorbeeld **Birder illustratieproef**.
3. Open [API Billing](https://platform.openai.com/settings/organization/billing/overview).
   Met ChatGPT Plus is apart API-tegoed nodig; een Pro-upgrade is niet nodig.
   Kies een klein prepaid bedrag dat het scherm toestaat en zet automatisch
   opladen uit. API-facturering staat los van ChatGPT. De huidige promotionele
   API-credits gelden voor in aanmerking komende Pro/Business-abonnementen,
   niet voor Plus.
4. Open [API keys](https://platform.openai.com/api-keys) binnen het juiste project
   en maak een nieuwe geheime sleutel. De proef gebruikt de Images API.
5. Bewaar de sleutel veilig. Plak hem straks alleen in de verborgen invoer van
   het lokale script; niet in de chat, Xcode, de app, een screenshot of Git.
   Als het platform aanvullende verificatie voor beeldgeneratie vraagt, volg
   die accountprocedure eerst.

[OpenAI: facturering](https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform)
en [voorwaarden voor API-credits](https://developers.openai.com/api/docs/guides/chatgpt-api-credits).

## Eerste run op de Mac: twee beelden

Pak het bijgewerkte project uit. Dubbelklik in `Scripts` op
`Start-API-illustratieproef.command`. De launcher maakt een lokale Python-omgeving
met Pillow en certifi, vraagt de API-sleutel verborgen op en genereert maximaal twee nieuwe
beelden: de standaard- en dynamische shikra. Er wordt niets in de app vervangen.
De resultatenpagina opent daarna automatisch in de browser.

De sleutel blijft alleen in het geheugen van het proces en wordt niet bewaard.
De eerste keer installeert de launcher Pillow vanaf PyPI; er is Python 3 nodig.
Als macOS de launcher niet opent, kun je vanuit Terminal in de projectmap starten:

```bash
bash Scripts/Start-API-illustratieproef.command
```

De run is lokaal: sluiten van Terminal/laptop kan de uitvoering onderbreken.
Bij een afgebroken API-aanvraag wordt niet automatisch opnieuw betaald.

## Wat wordt getest?

`ArtworkAPIPilot.json` bevat de tien vaste catalogus-ID's, gekozen leeftijd/
verenkleed, soortkenmerken, scènes en verwijzingen voor controle. Geen nieuwe
soorten of gewijzigde soort-ID's. De spelling **Oosterse roodstuitzwaluw** volgt
de catalogus voor de gevraagde oostelijke roodstuitzwaluw, *Cecropis daurica*;
die mag niet met de Europese *C. rufula* verward worden.

| Soort | Dynamische scène |
| --- | --- |
| Shikra | Alert op een doornige tak |
| Grote gele kwikstaart | Staartwippend op steen langs stromend water |
| Mandarijneend | Zwemmend met beperkte rimpels |
| Houtsnip | Foeragerend in bladstrooisel |
| Bruine kiekendief | Laag jagend boven riet, volwassen vrouwtje |
| Tjiftjaf | Insect zoekend bij bladeren |
| Himalayavisuil | Voorover kijkend langs een stroom |
| Bruine hokko | Lopend op bosbodem, volwassen mannetje |
| Zwartvoetpinguïn | Onderwater zwemmend |
| Oosterse roodstuitzwaluw | Insect vangend in vlucht |

Elke soort krijgt twee afzonderlijke aanvragen. Standaard: 1024×1024, vogel
naar rechts zonder attributen. Dynamisch: 1024×1536, transparante scène met
natuurlijk eindigende of vervagende bovenrand. De bestaande ijvogelbestanden
worden meegestuurd als **stijlreferentie**, niet als soortreferentie. Het linkse
profiel van het primaire voorbeeld moet dus niet worden overgenomen.
Externe foto's worden niet opgehaald of meegestuurd. De bestaande goedgekeurde
beelden worden niet overschreven. De drie andere aanzichten blijven uitgesteld.

## Kosten en modelkeuze

Gecontroleerde baseline: `gpt-image-2.5-sunburst-2026-09-08`, `medium`, PNG,
transparante achtergrond. Het vastgelegde model ondersteunt de benodigde
beeldreferenties en transparantie; de oudere 1.5-documentatie noemt dat model
inmiddels deprecated. Dit is één kwaliteitsbaseline, geen bewezen goedkoopste
model en geen claim van kwaliteitsgelijkheid met de eerdere chatgenerator.

Op de [officiële modelpagina](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst)
staan standaardtarieven per miljoen tokens: tekstinvoer $5, beeldinvoer $8,
beelduitvoer $30. Voor dit model geeft die pagina geen vaste prijs per beeld;
een exact bedrag voor twintig beelden zou dus een onbewezen schatting zijn.
Eerst meten we twee beelden. De checkpoint bewaart API-tokenverbruik en een
USD-schatting zonder cachekorting/belasting, plus generatietijd en originele
bestandshashes. Het Usage-dashboard blijft bepalend voor werkelijke kosten.

`--spend-stop-usd 2` stopt vóór een volgende aanvraag zodra de lokale
verbruiksschatting $2 bereikt. **Dit is geen harde factureringslimiet**: één
lopende aanvraag kan die drempel overschrijden. Ontbrekende verbruiksgegevens
stoppen verdere generatie. Maximaal twee nieuwe aanvragen is wel een harde
lokale aanvraaglimiet van de eerste run; er zijn geen automatische retries.

Als kwaliteit en gemeten kosten goed zijn, kunnen de resterende achttien in
hetzelfde experiment worden gemaakt. Vanuit Terminal in de projectmap:

```bash
.artwork-api/venv/bin/python3 Scripts/artwork_api_pilot.py --execute --max-requests 18 --spend-stop-usd 5
```

Al gemaakte beelden worden overgeslagen. De kostendrempel telt de eerdere
calibratie mee. Een storing/timeout krijgt status `needs_reconciliation`; hervat
pas nadat Usage en de checkpoint zijn nagekeken. Een aanvraag waarvan onbekend
is of hij is verwerkt, wordt nooit stilzwijgend herhaald.
De [modelpagina](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst)
vermeldt ook goedkopere Batch-verwerking; dat is een vervolgstap na deze kleine
synchrone kwaliteitsproef, niet geïmplementeerd in deze runner.

## Beoordelen en pas daarna importeren

Kandidaten staan lokaal onder `.artwork-api/pilot-medium/` (uitgesloten van Git).
`review.html` toont ze op de appkleur en linkt elk origineel voor inspectie op
volle grootte. Beoordeel **alle twintig individueel** op soortkenmerken,
houding, twee vleugels, één kop/snavel, poten, stijl, transparantie en framing.
Bij standaardbeelden ook: naar rechts, geen tak/grond/water/schaduw/attributen.
Geen automatische anatomische goedkeuring of deskundigheid wordt geclaimd.

`review-template.json` zet alle controlevelden standaard op `false` en bindt ze
aan de SHA-256 van het origineel. Maak een aparte kopie met alleen aanvaarde,
individueel geïnspecteerde beelden en vul uitsluitend uitgevoerde controles in.
Daarna kan een importer-mapping worden geëxporteerd:

```bash
.artwork-api/venv/bin/python3 Scripts/artwork_api_pilot.py --export-reviewed .artwork-api/pilot-medium/reviewed.json
.artwork-api/venv/bin/python3 Scripts/install_artwork_batch.py .artwork-api/pilot-medium/reviewed-import.json api-pilot-20261123
python3 Scripts/illustration_production_queue.py
```

Import is een afzonderlijke handeling en weigert bestaande assets te vervangen.
Het manifest bewaart model, request-ID, prompt-/referentie-/uitvoerhashes en
verbruiksprovenance. Pixels worden niet nabewerkt. Afgekeurde beelden blijven
buiten de app; opnieuw maken vereist een bewust aparte poging.

Alleen de lokale reviewpagina opnieuw aanmaken, zonder kosten:

```bash
.artwork-api/venv/bin/python3 Scripts/artwork_api_pilot.py --review-only
```

## Verificatie van de voorbereiding

Dertien offline unittests met synthetische PNG/API-fixtures geslaagd: twintig
unieke opdrachten, offline default, hervatten zonder dubbele aanvragen,
onzekere uitkomst niet herhalen, verbruiksstop, ontbrekende usage,
hashgebonden handmatige review, bestaande assets behouden en generatieprovenance
valideren/bewaren bij import.
Dit zijn **geen** echte gegenereerde vogels of uitgevoerde betaalde API-calls.
De authenticatie en uitvoerkwaliteit worden pas met je account getest.

## Herstel na de eerste mislukte proef

De aangeleverde oude checkpoint meldt `needs_reconciliation` zonder HTTP-status,
request-ID, usage of uitvoerhash. Daarmee is geen API-resultaat bevestigd, maar
ook geen concrete foutoorzaak of facturering vast te stellen. De oude runner
bewaarde alleen HTTP-statuscodes en verborg overige fouttypen; dat is hersteld.
De bestaande checkpoint wordt niet gewist of automatisch opnieuw verstuurd.

De runner registreert nu veilige foutcategorieën en de verwerkingsfase. Bij een
HTTP-fout worden uitsluitend code/type/parameter vastgelegd, geen ruwe server-
melding of sleutel. SSL/certificaatproblemen, timeout en netwerkfouten krijgen
een eigen melding. De betaalde launcher installeert ook certifi en voegt die
CA-certificaten toe aan de standaard trust store. Certificaatverificatie blijft
altijd ingeschakeld. Een certificaatfout is op basis van de oude checkpoint
slechts een mogelijkheid, geen bewezen diagnose.

`Scripts/API-verbindingscontrole.zip` is een klein zelfstandig diagnosepakket.
Pak het uit en dubbelklik `Controleer-API-verbinding.command`. Het verstuurt
alleen een GET naar `/v1/models` zonder authenticatie, prompt of afbeelding.
HTTP 401 is bij deze controle verwacht en betekent dat HTTPS bereikbaar is;
het bewijst niet dat je sleutel, modeltoegang of facturering werkt. Dit pakket
leest of verandert de bestaande checkpoint niet en kan niets genereren.
De controle is ook beschikbaar als `python3 Scripts/artwork_api_pilot.py --diagnose`.

Verificatie: 13 offline tests geslaagd, waaronder veilige foutregistratie,
verwachte unauthenticated HTTP 401 en het blokkeren van diagnose plus generatie
in dezelfde opdracht. De GET-controle in deze omgeving bereikte HTTP 401.
Dat is geen test van de verbinding op de Mac van de gebruiker en geen betaalde
API-proef. Nieuwe generatie blijft uit totdat de storing en oude uitkomst zijn
nagekeken.

## Certificaatfout op de Mac bevestigd

De gebruiker stuurde daarna de diagnose met `URLError`,
`SSLCertVerificationError` en `kind: tls_certificate`. De certificaatcontrole
faalt dus daadwerkelijk op die Mac, onafhankelijk van sleutel of beeldprompt.
Dit bevestigt de verbindingsfout, maar reconcilieert op zichzelf niet de oudere
checkpoint of facturering van die eerdere aanvraag.

`Scripts/Herstel-API-certificaten.zip` is een klein herstelpakket. De launcher
vindt standaard de oorspronkelijke projectdownload `Bird-74a7fb0…`; als die
verplaatst is, verschijnt op macOS een mapkiezer. Het pakket installeert certifi
in uitsluitend de lokale API-proefvenv, bewaart kopieën van de twee oude
proefscripts en vervangt ze door de versie met aanvullende vertrouwde
CA-certificaten. Daarna wordt uitsluitend de unauthenticated GET-controle
uitgevoerd, zonder sleutel en zonder beeldgeneratie. HTTPS-verificatie wordt
niet uitgeschakeld en systeemcertificaten worden niet aangepast.

Bestaande `state.json`, gemaakte beelden en de proefrecipe blijven ongewijzigd.
Ook na een geslaagde verbindingscontrole blijft de oude onbekende aanvraag
geblokkeerd voor automatische herhaling; controle van API Usage/herstel van die
checkpoint is een afzonderlijke volgende stap. Er is hier geen nieuwe betaalde
API-aanvraag verstuurd.

Drie aanvullende offline hersteltests slagen: behoud van checkpoint/beelden en
backups, weigeren van verkeerde/onvolledige mappen en alleen CA-installatie plus
`--diagnose`, zonder `--execute`. De herstelflow op de Mac zelf blijft te bevestigen
met de uitkomst van de gebruiker.
