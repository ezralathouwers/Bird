# Sessies: zoeken, leefomgeving en tijdcorrectie — 25 november 2026

## Overzicht en details

- Zoekknop rechts van afspelen, met dezelfde cirkel/zoekmarkering als Ontdek.
  Het zoekveld blijft onder de vaste header; de bestaande scrollfade blijft.
- Zoeken op plaatsnaam, landnaam, datum en Nederlandse/Engelse/wetenschappelijke
  namen en aliassen van de gelogde soorten. Case/diakritische tekens worden
  genegeerd. Ook de actieve sessie volgt de zoekfilter. Geen resultaten heeft
  een expliciete melding. Alleen daadwerkelijk gelogde soorten worden opgezocht.
- Vlag links van de sessienaam in overzicht en detail bij een bekend land buiten
  België. De bestaande cirkelvlagrenderer blijft behouden.
- Rechterzijde van overzichtsitems: gedeelde leefomgevingsillustratie,
  geheel passend in 112 x 90pt. Geprepareerde thumbnails worden asynchroon
  geladen; geen nieuwe netwerkintegratie of beeldgeneratie. Ook de actieve sessie
  toont een kleiner landschap zodra een voorstel of eigen keuze beschikbaar is.
- Op sessiedetails linken de soorten naar de bestaande soortpagina. De
  verwijderknoppen in live/afronden/bewerken blijven hun huidige werking houden.
- Details hebben 20pt meer bodemruimte (59 -> 79pt naast algemene padding).

## Leefomgeving

Elke unieke bevestigde, niet-gevangen vogelsoort stemt op de brongekoppelde
primaire leefomgeving uit de bestaande habitatcatalogus. Hoogste aantal stemmen
wint, met scene-ID als stabiele tie-breaker. Geen betrouwbare koppeling betekent
geen verzonnen landschap. De coördinaten worden hiervoor niet naar een externe
dienst gestuurd; dit is een soortgebaseerd voorstel, geen terreinclassificatie.

Bij aanmaken/bewerken/afronden kan de gebruiker een van de bestaande landschappen
kiezen of terug naar Automatisch. De optionele `BirdSession.habitatSceneID`
wordt in de gewone lokale opslag en back-up bewaard. Bij Automatisch evolueert
het voorstel mee met de soortenlijst. Oude sessies decoderen met nil en tonen
hun afgeleide landschap zonder databasebewerking.

## Eenmalige correctie van bestaande sessies

De eigenaar vroeg op 25 november 2026 alle bestaande sessies twee uur te
verschuiven. Interpretatie: **+7200 seconden**, inclusief gekoppelde
waarnemingstijden zodat begin/einde, lijst en kaartdetails consistent blijven.

- Uitvoering op het toestel bij openen van deze versie, voor de eerste normale
  gebruikersinteractie. Alleen afgeronde sessies; een lopende livesessie en losse
  waarnemingen blijven op hun bestaande tijdstip.
- Start/einde en gekoppelde observedAt schuiven met exact hetzelfde interval.
  Duur, onderlinge volgorde, ID's, count, createdAt, notities, coördinaten,
  tijdzone-identifiers en doelstellingen veranderen niet.
- Eerst archiefvalidatie en een recoverykopie van het originele bestand, daarna
  één atomische schrijfopdracht voor alle aangepaste gegevens én de markering.
  Bij fouten worden geen gewijzigde arrays of succesmarkering gepubliceerd;
  de app toont een foutmelding. Geen automatische betaalde diensten.
- `BirdingArchive.appliedDataFixes` is een optioneel veld binnen het bestaande
  v3-formaat. De gewone JSON-savepaden behouden deze markering. Export/back-up
  bevat de markering; herstel laadt haar terug. De correctie wordt daardoor
  niet herhaald na herstart/herinstallatie met een nieuwe back-up. Een oude
  back-up van vóór de correctie krijgt de correctie eenmaal bij herstel.
- Per gecorrigeerde sessie blijft bovendien de oorspronkelijke start/eindtijd
  als ISO-tekst in importMetadata, met de correctiemarkering. Dit voorkomt een
  tweede verschuiving wanneer een oudere app de globale markering niet kende.
- Nieuwe sessies na de eerste correctie worden niet verschoven. Dit is geen
  tijdzoneconversie of algemene vaste offset voor toekomstige waarnemingen.
- De bestaande milestone-logica negeert tijdsbewerkingen zonder nieuwe logs.

## Verificatie en grenzen

- Swift tree-sitter: 50 Swift app-/testbestanden zonder syntaxfouten.
- OpenStep-projectcontrole: SessionEnhancements.swift precies eenmaal in app Sources.
- git diff --check geslaagd.
- Zeven native regressietests toegevoegd: exact +2u en gegevensbehoud;
  idempotentie en oude/globaleloze markering; recoverykopie, gewone save,
  export en herstel; schrijfout zonder gepubliceerde wijzigingen;
  unieke/zekere habitatstemmen; zoeken; habitatopslag en oude JSON.
- Geen Swift/Xcode-toolchain aanwezig: de native tests zijn niet uitgevoerd.
  Native build, appnavigatie, tijdcorrectie en de nieuwe overzichtsillustraties
  moeten nog in Xcode/op iPhone worden gecontroleerd. Er zijn in deze omgeving
  geen persoonlijke records van het toestel gewijzigd.
