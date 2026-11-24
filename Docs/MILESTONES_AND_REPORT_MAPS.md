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
