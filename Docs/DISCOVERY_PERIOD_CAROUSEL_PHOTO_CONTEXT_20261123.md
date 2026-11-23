# Ontdek, illustraties en fotolocatie — 23 november 2026

- De vaste kop/filterknoppen op Ontdek blijven staan. De resultaten gebruiken
  nu dezelfde scrollafhankelijke 24 pt fade als de zoeklijsten: geen fade op de
  beginpositie, geleidelijk zichtbaar na omhoog scrollen.
- Standaardperiode: drie dagen. Lokale vogelmeldingen heeft naast de straal een
  periode-instelling van 1–14 dagen, bewaard in UserDefaults. De instellingen,
  query-identiteit, beide API-aanvragen, datumcontrole, cache-identiteit en lokale
  filtering gebruiken dezelfde queryperiode. Het bereik blijft binnen het ene
  ondersteunde Observation.org-datumvenster. Demo's blijven expliciet fictief.
- De soortcarousel bevat uitsluitend aanwezige detailrollen. Alleen de
  beschikbare rollen loopen; nul/één pagina heeft geen datasource en geen
  scrollinteractie. Als alle detailrollen ontbreken, kan de standaardillustratie
  tijdelijk de overzichtspagina vullen, met dezelfde rechtsgerichte correctie
  als in lijsten. Zonder beelden verschijnt één statische placeholder. De
  toegankelijkheidsbeschrijving telt alleen daadwerkelijk aangeboden pagina's.

## Foto ID: geografische plausibiliteit

De bestaande classifier gebruikte uitsluitend exact punt-in-polygoon op de
BirdLife-kaarten. We beschikken hier niet over de private kaart van de gebruiker
of diens testfoto, dus de precieze oorzaak van het ravenvoorbeeld is niet op
dezelfde invoer gereproduceerd. Een gegeneraliseerde verspreidingsgrens is
echter geen betrouwbare uitsluitingsgrens voor een mobiele vogel.

De fotolocatie bewaart nu ook de landcode uit de bestaande plaatsnaamservice.
Als die nog ontbreekt, gebruikt de classifier dezelfde gecachte, begrensde
reverse-geocodingservice. Lege kandidaten en ongeldige coördinaten starten geen
geocodingaanvraag. De contextkey bevat ook de landcode.

De aanvullende resource `PhotoRegionalContext.json` bevat uitsluitend positieve
landcontext voor 237 gewone/gevestigde Belgische soorten, afgeleid uit de reeds
opgestelde Belgische broninventaris (Avibase). Zeldzame/dwaalgast- en
onzekere-herkomstmeldingen zijn geen reguliere positieve context. De gewone raaf
(*Corvus corax*) staat wel in deze context; buitenlandse raven als *C. albicollis*,
*C. crassirostris* en *C. ruficollis* niet. Afwezigheid uit de landenresource
bewijst nooit dat een kandidaat onwaarschijnlijk is. Andere landen vallen
terug op de verspreidingskaarten. De bronnenpagina vermeldt deze aanvulling.

Een positief regulier voorkomen in het geselecteerde land kan een kandidaat
ondersteunen wanneer de exacte kaart ontbreekt of het punt erbuiten ligt.
Daarnaast geldt voor gegeneraliseerde kaarten een geografische marge van 25 km
tot een polygonenrand. Verder afgelegen kandidaten blijven onwaarschijnlijk;
zonder geografisch bewijs blijft de status onbekend. De lokale afstandsmarge
is een plausibiliteitsheuristiek, geen ecologische aanwezigheidskans of exacte
geodetische meting. Grenzen bij de datumlijn worden lokaal uitgepakt.

Visuele modelscores worden niet aangepast en er verdwijnen geen kandidaten.
Foto ID blijft een suggestie; aanwezigheid in een land garandeert geen
voorkomen op elk punt of in elk seizoen binnen dat land.

## Verificatie

- Swift tree-sitter syntaxscan: alle 42 app-/testbestanden geslaagd.
- Xcode-projectstructuur geparseerd; de nieuwe JSON staat in de app-resourcefase.
- `python -m unittest discover -s Scripts -p test_photo_regional_context.py`: 2 geslaagd.
- `python -m unittest discover -s Scripts -p test_catalog_visibility.py`: 3 geslaagd.
- `git diff --check`: geslaagd.
- XCTest-regressies toegevoegd voor standaard/instelbare perioden, API-parameters
  en grensfiltering, beschikbare carouselrollen en singleton-interactie, positieve
  ravencontext, onbekende gegevens, nabijgelegen kaartgrenzen en de datumlijn.
- Geen Swift-compiler/Xcode op deze Linux-omgeving: native build, XCTest-uitvoering
  en iPhone-weergave zijn nog niet geverifieerd.

De lokale Belgische API-illustratieopdracht, beelden, checkpoint en tegoed zijn
niet gewijzigd of gebruikt voor deze appaanpassingen.
