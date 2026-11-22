# Gegevens en back-ups

Open het tandwiel rechts naast Info bovenaan Ontdek. Beide iconen gebruiken
hetzelfde mutedIcon-kleurtoken en dezelfde 44pt aanraakruimte.

## Eerste keer instellen

1. Kies **Back-upmap kiezen**.
2. Kies of maak een persoonlijke map in **iCloud Drive** via de Bestanden-kiezer.
   Een map binnen de lokale Birder-sandbox wordt geweigerd. ‘Op mijn iPhone’
   geeft geen bescherming tegen verlies/defect van de telefoon.
3. Birder maakt meteen een volledige back-up, leest die terug en controleert
   inhoud en checksum. Alleen na succes wordt de map opgeslagen en automatisch
   back-uppen aangezet.
4. Controleer de datum onder **Laatste geslaagde back-up** en controleer in
   Bestanden of iCloud klaar is met uploaden voordat je Birder verwijdert.

Automatische back-ups volgen na succesvolle gegevenswijzigingen (2 seconden
gebundeld) en worden opnieuw geprobeerd bij appstart/activering. Een ongewijzigd
archief wordt overgeslagen als het laatste bestand nog aanwezig is. Handmatig
kan altijd een nieuwe versie worden gemaakt. Achtergronduitvoering en internet
worden niet afgedwongen: iOS verzorgt cloud-upload en die kan uitgesteld zijn.
Een gecontroleerde bestandswrite bewijst dus geen voltooide cloud-upload.

Elke versie staat in `Birder-reservekopieen` onder de gekozen map, met tijd en
UUID in de naam. Bestaande versies worden niet overschreven of automatisch
verwijderd. Houd zelf de beschikbare opslagruimte in de gaten. Geen betaalde
CloudKit/iCloud-container-entitlements of externe back-updienst toegevoegd;
de gebruiker verleent uitsluitend toegang tot een map via de systeemkiezer.

## Inhoud en herstel

Een JSON-envelop bevat format/version, aanmaaktijd, exact archiefpayload en
SHA256. Het archief bevat alle waarnemingen, sessies en doelstellingen, inclusief
IDs, relaties, tijden, coördinaten, notities en favoriete doelsoorten. Modellen,
catalogus/illustraties, privékaarten, tijdelijke herkenningsfoto's/audio,
API-sleutels en maptoegang maken geen deel uit van deze gebruikersback-up.
Het bestand is niet apart door Birder versleuteld: bewaar het privé. Een checksum
controleert beschadiging en is geen handtekening van een vertrouwde afzender.

Herstel ondersteunt het huidige envelopformaat en oudere volledige JSON-archieven
(v2/v3); geldige oude standalone-waarnemingsarrays kunnen ook worden gelezen.
Maximaal 64 MiB aan archiefpayload en 128 MiB aan importbestand wordt geaccepteerd.
Onbekende versies, dubbele IDs, kapotte checksum, ongeldige velden en verweesde
sessielogs worden geweigerd. Er wordt geen onbekende soort-ID verwijderd.

Na kiezen toont een preview datum en aantallen. De gebruiker bevestigt expliciet
dat de huidige geschiedenis wordt **vervangen**, niet samengevoegd. Als er huidige
gegevens zijn, is een back-upmap verplicht en wordt eerst een geverifieerde
externe versie `voor-herstel` geschreven. Het originele lokale bestand wordt
ook bytegetrouw gekopieerd naar Application Support/BirdingCompanion/RecoveryCopies
voordat het atomair vervangen wordt. Ook een onleesbaar lokaal bestand blijft zo
bewaard bij herstel uit een geldige back-up. Die lokale herstelkopieën alleen
beschermen niet tegen het verwijderen van de app.

Een lopende vogelsessie blokkeert herstel. Verandert de geschiedenis sinds de
preview, dan moet de back-up opnieuw geopend worden. Een schrijf-/validatiefout
publiceert geen nieuw archief en verhoogt de gegevensrevisie niet. Bij een nieuwe
installatie kun je de bewaarde JSON direct via Bestanden kiezen; daarna moet de
back-upmap opnieuw worden ingesteld.

## Techniek en controle

BackupFiles is een actor met security-scoped bookmarks, NSFileCoordinator,
atomaire writes en readbackcontrole. Accessorresultaten worden met NSLock
beschermd. Toegang tot een verwijderde of verlopen map vraagt opnieuw selecteren.
De laatste geslaagde datum verandert uitsluitend na een geverifieerde write.
ObservationStore meldt een nieuwe revisie uitsluitend na een geslaagde commit;
de bestaande versie-3 lokale opslag en alle IDs blijven behouden.

XCTest-fixtures toegevoegd voor volledige roundtrip/relaties, beschadiging,
nieuwere schema's, dubbele doelen, verweesde sessies, oude bronkopie, herstel van
corrupte lokale opslag, stale previews, falende lokale writes, verschillende
bestandsversies en behoud van de laatste succesdatum bij fouten. Deze tests zijn
niet uitgevoerd in Linux. Swift syntax, Xcode-bronverwijzingen, JSON/plist en
whitespace zijn hier controleerbaar; geen native build geclaimd.

Vereiste iPhone-acceptatietest: kies een iCloud-map, maak logs/sessie/doelstelling,
controleer dat nieuwe bestanden verschijnen en upload klaar is, probeer offline
schrijven, verlopen maptoegang, onvoldoende ruimte en corrupte imports. Test
preview/annuleren/herstel eerst op een aparte simulator of testinstallatie met
fixturedata. Verwijder geen echte installatie voordat een hersteltest geslaagd is.
