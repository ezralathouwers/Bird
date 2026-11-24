# Logboek, sessies, Audio ID en eerste-waarnemingenkaart — 24 november 2026

## Gedrag

- Logboek, Sessies, Doelstellingen, Identificeer en Landen gebruiken een vaste
  header boven CatalogResultsScroll. De gedeelde topfade verschijnt alleen als
  de inhoud omhoog is gescrold. De logboek-teller staat 12pt hoger; rechts staan
  ronde sorteer- en zoekknoppen. De zoekopdracht gebruikt uitsluitend de soorten
  in het (eventueel landgebonden) logboek en bewaart de gekozen sortering.
- Landen sorteert op unieke gelogde soorten, aflopend; gelijke aantallen op
  waarnemingsaantal en vervolgens Nederlandse naam. Geen aparte België-regel.
  Onderaan 50pt extra ruimte; de melding met onbekende landen is verwijderd.
  De waarnemingen-tab op een soortpagina krijgt nog 30pt extra, nu 104pt.
- Ontdek toont een eenvoudige klok-met-cirkelpijl voor back-ups. De drie
  top-left iconen staan op gelijke visuele afstanden. De lokale instellingen
  blijven via het tandwiel beschikbaar; andere acties zijn ongewijzigd.

## Gegevensbewerkingen

De bewerkschermen voor waarnemingen, doelstellingen en sessies bevatten een
verwijderactie met bevestiging. Het afrondscherm van een livesessie heeft die
ook. Verwijderen van een sessie verwijdert de sessie én haar opgeslagen logs;
verwijderen van een doelstelling verwijdert geen waarnemingen. Na succes sluit
ook een eventuele detailpagina van het verwijderde record.

Omzetten van een voltooide sessie verwijdert alleen die sessie en maakt de
opgeslagen logs los door sessionID te wissen. Alle overige velden/ID’s/tijden/
coördinaten/importmetadata blijven exact behouden. Sla eventuele andere
bewerkingen eerst op als je die ook wilt bewaren. De omzetting is atomair en
kan niet op een actieve livesessie. Opnieuw importeren van dezelfde Birda-CSV
maakt na omzetting geen lege sessie aan voor uitsluitend reeds aanwezige logs.
Elke schrijffout laat de actuele store/revision ongewijzigd.

## Audio naar livesessie

Elk Audio ID-resultaat heeft een afzonderlijke toevoegknop, naast het bestaande
openen/vastzetten. De expliciete tik bevestigt de suggestie als waarneming.
Een bestaande livesessie wordt gebruikt; als die ontbreekt worden sessie en
haar eerste log in één gevalideerde opslaghandeling aangemaakt, na een geldige
locatie. Een mislukte locatie/opslag laat geen lege sessie achter. Soorten die
al in die livesessie staan hebben een vinkje en kunnen niet dubbel worden
opgeslagen. Er is geen succes-toast, wel duidelijke laad-/foutfeedback.

De Audio ID-knop op Livesessie gaat via de gedeelde root-route naar de huidige
opname, of start een nieuwe als er geen opname loopt. De bestaande gedeelde
microfoon-/achtergrond-stopregels, tijdelijke opnames en pins blijven gelden.

## Eerste waarnemingen op de kaart

De kaartknop op Landen opent een volledige Apple-kaart met de bestaande ronde
sluitknop en zonder onderste navigatie. Per soort wordt de oudste opgeslagen
waarneming gekozen (bij gelijke tijden UUID-volgorde). Als die geen bruikbare
coördinaten heeft wordt geen latere plek als eerste voorgesteld. Er worden geen
waarnemingen toegevoegd/gewijzigd om de kaart te maken.

Markers zijn cirkels met de standaardillustratie en 12pt padding. MKMapView
hergebruikt/clustert ze. Uitgezoomde clusters tonen het aantal; tikken zoomt in.
Bij exact samenvallende plekken of sterk ingezoomde clusters opent een soorten-
lijst zodat geen soort onbereikbaar blijft. Tikken op een vogel opent de echte
waarnemingsdetails. Kleine thumbnails worden één voor één asynchroon voorbereid
en begrensd gecachet; originele PNG’s en manifesten blijven onaangeraakt. De
kaart behoudt de camera bij wijzigingen zonder gewijzigde markerposities.

## Verificatie

Negen nieuwe XCTest-regressies controleren sessieconversie en alle delete-
bewerkingen, behoud van niet-gerelateerde data/goals, atomair falen, automatisch
Audio-sessies starten/hergebruiken/dubbels weigeren, geen lege sessie na fout,
herimport na conversie en deterministische eerste-kaartplekken/ontbrekende GPS.
De eerdere country-sorttest is aangepast aan soorten als primaire sorteersleutel.

Op Linux uitgevoerd: Swift tree-sitter syntax voor app/testbestanden, OpenStep
project/nieuwe source-inclusion, relevante Python-productie/import/datasettests,
launcher-shellsyntax en pakketintegriteit. Native XCTest, Xcode-compilatie,
MapKit-clustering, echte GPS/microfoon en visuele iPhone-controle zijn hier niet
uitgevoerd. Test de bewerkingen eerst met een actuele externe back-up op de Mac.

De lokale API-opdracht voor ontbrekende logboekillustraties is beschreven in
LOGBOOK_ARTWORK_API.md en maakt geen deel uit van de iPhone-runtime.
