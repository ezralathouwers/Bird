# Logboekbatch en herstelbeelden samen installeren

Dit lokale hulpmiddel importeert de eerdere grote logboekproductie en de 77
inmiddels door de eigenaar geaccepteerde herstelbeelden naar één app-project.
Geen beeldgeneratie, API-sleutel of betaalde API-aanvragen.

1. Pak `Birder-Logboek-en-Herstel-import.zip` uit als aparte hulpmiddelenmap.
2. Open `Scripts/Installeer-Logboek-en-Herstel.command` en kies 1.
3. Kies je huidige volledige Xcode-projectmap met `BirdingCompanion.xcodeproj`.
4. Kies je **bestaande** `Birder-Logboek-illustraties`-productiemap met gemaakte
   beelden onder `.artwork-api/logbook-medium`.
5. Kies je **bestaande** `Birder-Illustratieherstel`-productiemap met de 77
   goedgekeurde beelden onder `.artwork-api/repairs-20261125`.
6. Bevestig eenmaal met JA. Na succes bouw je het gekozen project in Xcode.

Je hoeft geen beelden of checkpoints te verplaatsen. Een uitvoermap met
state.json mag ook direct gekozen worden. Het gekozen app-project bepaalt de
appcode; dit hulpmiddel wijzigt alleen illustratiebestanden en het manifest.
Gebruik het nieuwste app-project voor de sessie-leefomgevingsfunctie.

## Behoud en volgorde

Alle logboekbestanden worden tegen hun checkpoint, review en provenance-hashes
gecontroleerd. Overlappende afgekeurde rollen moeten exact bij de vaste
herstelopdracht horen; zij worden direct door het herstelbeeld ingevuld en niet
eerst als fout beeld geïnstalleerd. Overige logboekbeelden worden alleen
bijgeplaatst als ze ontbreken of identiek zijn. Herstel van bestaande rollen
vereist exact de afgekeurde bronhash; reeds geïnstalleerde herstelbeelden blijven
intact. De herstelbatch moet volledig zijn. Anatomie-/verenkleedcontrole wordt
niet automatisch geclaimd; hashgebonden eigenaaracceptatie blijft bewaard.

Voor de echte installatie doorlopen beide batches de bestaande importers in een
tijdelijke projectkopie met uitsluitend relevante assets, stijlreferenties en
manifest/catalogus. Pas wanneer beide slagen, worden de gewijzigde imagesets en
het gecombineerde manifest in het gekozen app-project gezet. Niet-geselecteerde
assets en alle overige projectbestanden blijven ongemoeid. Bronnen en state.json
blijven behouden; de herstel-reviewpagina kan opnieuw worden opgebouwd.

Alle vervangen oorspronkelijke beelden en het oude manifest staan onder
`.artwork-api/repair-import-backups/repair-combined-…`. Fouten tijdens de laatste
wissel draaien beide batches terug. Bij een hard beëindigd proces start je
hetzelfde command-bestand opnieuw, kiest 2 en hetzelfde app-project om de
installatie eerst terug te draaien. Daarna kun je optie 1 opnieuw gebruiken.
Reeds correct geïnstalleerde versies worden overgeslagen bij herhalen.
Sluit andere illustratie-importers en bewerk geen assets tijdens de import.

## Verificatie

Zes synthetische offline regressies: ontbrekende grote batch + vervangingen,
identieke herhaling zonder wijzigingen, al geïnstalleerde afgekeurde batch met
herstelkopieën, beschadigd/conflicterend bestand en onvolledige herstelbatch
zonder appwijziging, terugdraaien bij schrijffout en herstel na echt beëindigd
subproces. Alle tests gebruiken kunstmatige PNG's en een nagebootste API;
geen nieuwe vogelbeelden of betaalde aanvragen. Native Mac-keuzevensters zijn
niet in deze Linux-omgeving getest.
