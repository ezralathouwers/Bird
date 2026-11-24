# Mijlpalen, waarnemingskaarten en thuisfilter — 24 november 2026

## Gedrag

- Mijlpalen verschijnen als een olijfgroen scherm met lichte tekst, over de
  volledige hoofdpagina inclusief navigatie. Eén tik sluit de melding; er is
  geen sluitknop of timer. VoiceOver heeft een benoemde knop en ontsnapactie.
- Eerste soort en totalen 10/25/50/100/200/300/500/750/1000/2000/5000/10000,
  eerste uil, volledige catalogusfamilies met meer dan één soort en afgeronde
  doelstellingen. Alleen bevestigde, niet-gevangen vogels tellen.
- De bestaande geschiedenis vormt bij starten de basis. Reeds bereikte
  mijlpalen worden niet opnieuw getoond; imports en herstel worden expliciet
  herkend met een vluchtige geschiedenis-ID. Geen aanpassing van opgeslagen
  waarnemingen of back-upformaat. Getoonde mijlpalen worden lokaal onthouden.
- Een nieuwe persoonlijke waarneming kan nieuwe mijlpalen activeren. Bewerkingen,
  landaanvulling, verwijderen en een reeds volledig aangemaakte doelstelling
  veroorzaken geen nieuwe melding. Tijdens een modalvenster wacht de overlay
  achter dat venster; de onderliggende opname blijft lopen.

## Kaarten

- Het logicoon bij elke nabije melding opent de melding in de app, ongeacht de
  eigen logstatus. De soortnaam blijft de soortpagina openen.
- De kaart gebruikt precies het bronrecord van die resultaatregel: coördinaten,
  lokale datum/tijd, locatie, waarnemer indien beschikbaar. Geen omzetting naar
  persoonlijke waarnemingen en geen automatische toevoeging aan het logboek.
- De openbare Observation.org-feed is gecontroleerd: locatie via
  `location_detail.name`, waarnemer alleen als numerieke `user`-ID; die wordt
  eerlijk als `Waarnemer #…` getoond. De gebruikelijke eBird-geo-feed geeft
  `locName`, maar doorgaans geen waarnemersnaam. Ontbrekende namen worden als
  niet meegeleverd aangegeven; ontbrekende tijden worden niet verzonnen.
- Links van de sluitknop staat een ronde bronlink naar de bijbehorende openbare
  waarneming/checklist. eBird-links blijven Nederlands aanvragen.
- Sessiedetail en landdetail hebben een kaartknop. Deze kaarten tonen alle
  beschikbare waarnemingspunten binnen de sessie/het land, niet alleen de
  eerste plek per soort. Het algemene Landen-kaartscherm blijft eerste plekken
  per soort tonen. Ongeldige, ontbrekende en 0,0-coördinaten worden overgeslagen.
- De bestaande geclusterde kaart, seriële thumbnailverwerking en detailkeuze
  worden hergebruikt. Volledige illustraties, 12pt interne markerpadding.
- Landen heeft 15pt extra bodemruimte (109pt); sessiedetail 35pt extra (59pt
  bovenop algemene contentpadding).

## Thuis

- Huisknop tussen sorteren en zoeken in het algemene logboek. Actief: olijfgroen.
- Eénmalig het thuisadres invoeren, de door Apple gevonden plek controleren op
  een kleine kaart met een straal van 150 meter en bevestigen. Houd de huisknop
  ingedrukt of gebruik de VoiceOver-actie om dit later te wijzigen.
- Adres en coördinaten uitsluitend in lokale voorkeuren, niet in git, catalogus
  of beeld-API-opdrachten. Adresopzoeking gaat via Apple; filteren werkt daarna
  offline. De privé-instelling maakt nog geen deel uit van de loggegevensback-up.
- De filter gebruikt echte afstanden tot elke waarneming; daarna wordt de
  soortenlijst inclusief telling en sortering opgebouwd. Een soort verschijnt
  als minstens één waarneming binnen 150m ligt. Verre waarnemingen van diezelfde
  soort worden niet als thuiswaarnemingen meegeteld.
- Geen hardcoded privé-adres of stilzwijgende locatiebepaling.

## Meldingeninstellingen

Het tandwiel op Ontdek opent Lokale vogelmeldingen fullscreen met een
CenteredPageHeader en terugpijl, zoals Gegevens en back-ups. Instellingen,
sleutelhanger en API-verificatie blijven hetzelfde.

## Controle

- Swift tree-sitter syntaxcontrole voor alle 49 app-/testbestanden zonder fouten.
- OpenStep-projectcontrole: beide nieuwe Swift-bestanden precies eenmaal in
  app Sources.
- Nieuwe native regressietests: thuisafstand/ongeldige punten, coherent
  bronrecord bij meerdere meldingen, optionele providermetadata, bevestigde
  unieke soorten, uil/doelstelling, mijlpalen zonder herhaling bij herstart en
  geschiedenisvervanging.
- `git diff --check` geslaagd.
- Geen Xcode/Swift-toolchain aanwezig: native tests, build, fullscreen-layout,
  VoiceOver, kaartinteractie en geocoding moeten op Mac/iPhone worden getest.

## Visuele verfijning — later 24 november 2026

- Openbare meldingdetails: waarnemerregel verwijderd; uitsluitend het
  locatie-icoon 3pt omhoog via offset. Bronknop gebruikt dezelfde 0.7pt
  stroke als zoeken.
- Gedeelde FineControlIcon/FineControlMark paden voor kaart, afspelen, klok,
  plus/min/cirkelvarianten, audio, microfoon, bronlink, sorteren en eenvoudig huis.
  De paden schalen voor het stroken, zodat lijndikte niet van icoonmaat afhangt.
  De ronde bediening houdt de bestaande 44pt raakvlakken en labeltoegankelijkheid;
  RoundAction behoudt de dynamisch geschaalde 17pt basismaat.
- Identificeer/Sessies/Doelstellingen/Landen: header top 20 -> 8pt, gelijk aan
  de iconenrij van Logboek. Daar schuift alleen het aantal visueel 8pt omhoog.
- Het Opnemen-knopicoon wordt waveform; Stop opname blijft stop. Het
  microfoonsymbool in de statusregel blijft behouden, met een lichtere fontweight.
- Geen wijzigingen aan herkenning, gegevensopslag, signing of bundle identifier.
- Swift-syntaxcontrole en git diff --check uitgevoerd; native visuele controle
  en compilatie blijven voor Xcode/iPhone.

## Herstel van ontbrekende iconenlijnen — 24 november 2026

- De vorige padimplementatie gebruikte `Path.addLines` na `move`. Die functie
  begint een nieuwe subpath bij het eerste arraypunt; daardoor ontbraken onder
  meer de verticale wijzers, driehoekzijden en linkerkant van het huisje.
  Alle elf toepassingen in FineControlMark gebruiken nu expliciete addLine(to:)
  stappen. Stroke en icoongrootte blijven behouden.
- De vijf gemelde iconen zijn geïnspecteerd in een technische rasterpreview van
  de gecorrigeerde padcoördinaten; dit is geen native SwiftUI/iPhone-render.
- Drie native geometrische regressietests toegevoegd voor de gesloten
  afspeeldriehoek, beide huiszijden zonder deur, klokwijzers, backuppijl en
  volledige sorteerpijlen. Niet uitgevoerd zonder Xcode.
- Sessiedetail krijgt dezelfde ronde sorteerknop als Logboek, met de bestaande
  keuzes Laatste eerst / Alfabetisch en toegankelijke selectieaanduiding.
- Identificeer: expliciete volledige breedte en leading alignment voor titel.
- Detailheaders voor sessie/doelstelling: top 4 -> 8pt, bottom 8 -> 4pt zodat de
  inhoud eronder op zijn plek blijft. De actie-/terugrij van de vogelsoortpagina
  schuift alleen visueel 4pt omlaag; illustratieframe en tabstrip blijven staan.
- Alleen het algemene logboekaantal krijgt nog 10pt extra opwaartse offset
  (-8 -> -18pt); knoppen blijven op hun plek.
- Syntaxcontrole voor alle 49 Swift-bestanden en git diff --check geslaagd;
  native build en uitlijning op iPhone nog te controleren.
