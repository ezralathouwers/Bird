# Gerichte illustratieherstelopdracht — 25 november 2026

## Gecontroleerde selectie

De ontvangen controlezip bevat 80 voorbeelden voor 62 soorten. Witkeelwaaierstaart
staat met dezelfde originele hash in twee foutgroepen en wordt eenmaal behandeld.
Van 79 unieke rollen blijven twee complete standaardbeelden behouden: Bonte zanger
en Monniksparkiet. Hun dynamische scènes hebben wel afgesneden takken/bladeren.
De opdracht bevat daarom **77 rollen: 15 primary en 62 dynamic**.

De vier andere extra soorten waren niet aanwezig: Bruinstaarthoornkolibrie,
Grote kraaghoningzuiger, Purperhoningzuiger en Zwarte frankolijn. Ze staan als
openstaand geregistreerd; geen onbekende rollen/bronhashes worden vervangen.
Lever hun afgekeurde beelden nog aan als compacte controlezip. Ze krijgen een
aparte ronde, zodat deze opdracht en checkpoints niet tussentijds veranderen.

Alle contactvellen zijn bekeken; voor moeilijke kop-/anatomie-/randgevallen is
het individuele compacte voorbeeld vergroot. Dit is geen inspectie van alle
originele PNG's op volledige resolutie en geen goedkeuring van nieuwe beelden.
De 62 taxon-ID's zijn tegen de publieke BirdNET-records gecontroleerd. Voor de
17 soorten in de kleur/patroongroep staan eigen diagnostische instructies en
bronverwijzingen in de opdracht; de zes gorzen hebben aparte kop/keel/borst-
patronen en expliciete leeftijd/geslacht. Bij toekan en buulbuul is ook de
gekozen ondersoort/morf vastgelegd. Geen foto's van derden worden meegezonden.

## Eerst de proef

1. Pak Birder-Illustratieherstel.zip uit als een eigen map. Verplaats bestaande
   productiebeelden of checkpoints niet naar deze map.
2. Open Scripts/Start-Illustratieherstel.command.
3. Kies **1 — Maak de proef van 6 beelden** en selecteer je huidige app-projectmap
   met je bestaande illustraties. De goedgekeurde ijvogelbeelden leveren alleen
   de stijlreferentie. Voer je API-sleutel lokaal verborgen in, nooit in de chat.
4. Bekijk review.html. Dit overzicht wordt na ieder voltooid beeld bijgewerkt;
   vernieuw de browser om tussentijdse resultaten te zien.
5. Bespreek de proefresultaten voordat je alle 77 laat maken. Optie 2 is beschikbaar
   voor de volledige opdracht; eerder gemaakte rollen worden overgeslagen.

De proef: Bruine rotsspekvreter primary, Bosgors primary, Witbandzeearend primary,
Geelkeeltoekan dynamic, Roodrugzwaluw dynamic en Bonte zanger dynamic. Dit test
kleur/patroon, soortverwarring, vleugelproporties, laterale vleugelaanhechting en
rechte afsnijding van de scène.

Op basis van de eerdere medium-proef: orde van grootte circa $0,20 voor zes
beelden en $2–$3 voor alle 77; geen offerte of harde bovengrens. De lokale
verbruiksstop is $1 voor de proef en $5 voor alles, inclusief reeds vastgelegde
kosten. Eén aanvraag kan de lokale stop overschrijden. OpenAI-facturering/btw en
hergeneraties staan hier los van. Deze taak heeft geen betaalde aanvragen gedaan.

## Resultaten en controles

Resultaten staan naast het scriptpakket in `.artwork-api/repairs-20261125`:
originele 1024px PNG's, state.json, review.html, review-template.json en
framing-report.json. De compacte inputvoorbeelden worden nooit in de app gezet.

Nieuwe prompts gebruiken eenvoudiger houdingen met twee gevouwen vleugels,
behalve natuurlijke vlucht/drogen waar beide vleugels passend open staan.
Zwaluwen/gierzwaluwen krijgen een zichtbare laterale schouderaanhechting.
Alle delen van vogel en scène blijven binnen het canvas, met 6% transparante
ruimte rechts. Takken eindigen natuurlijk of vervagen vóór de grens.

De technische rechterrandcontrole gebruikt de alpha-bounds boven drempel 16.
Bij minder dan 6% ruimte volgt een waarschuwing in review.html en blokkeert de
installatie van de selectie. Geen automatische retry of extra facturering.
Een afgekeurd resultaat moet in een afzonderlijke gecontroleerde vervolgronde
opnieuw worden gemaakt; verwijder nooit zomaar state.json/PNG's om te herstarten.
Anatomie, soortkenmerken, stijl en realistische pose blijven visueel te beoordelen.
Alle visuele/anatomische QA-vlaggen van nieuwe output blijven standaard false.

## Gerichte installatie na controle

Optie 4 installeert de voltooide herstelbeelden pas na expliciet `JA`. Dat is
een lokale eigenaaracceptatie; het programma claimt geen individuele expert-QA.

- Alleen opgenomen soort/rol-combinaties; bestaand ander goed werk blijft staan.
- Bestaand beeld moet exact dezelfde SHA256 hebben als het afgekeurde origineel
  uit de controle-inventaris. Een andere versie wordt niet overschreven.
- Nog niet geïnstalleerde afgekeurde rollen kunnen als nieuwe assets worden
  toegevoegd; een onvolledige/conflicterende map of manifest wordt geweigerd.
- Nieuwe bestanden en manifest worden eerst apart klaargezet en technisch
  gevalideerd met de bestaande importer. Geen rescaling of bewerking van PNG's.
- Originele assetmappen en manifest worden bewaard onder de app-projectmap:
  `.artwork-api/repair-import-backups/repair-…`.
- Versienummer stijgt en replacesSHA256 verwijst naar het vervangen bronbeeld.
- Gewone fouten draaien de installatie terug. Bij hard afbreken blijft een
  installatielogboek staan; kies optie 5 om eerst de originelen te herstellen.
  Onverwachte externe wijzigingen blokkeren automatisch herstel in plaats van
  ongecontroleerd werk te overschrijven. De bron-PNG's blijven in het pakket.
- Herhaald installeren slaat reeds exact geïnstalleerde beelden over.

## Bronnen en grenzen

Diagnostiek/bronnen per rol staan in ArtworkRepairPlan20261125.json en een
leesbare selectie in ArtworkRepairSelection20261125.csv. Voorbeelden van extra
identificatiebronnen: Audubon (Rustic/Little Bunting), Cornell All About Birds
(Lapland Longspur), NZ Birds Online (Cirl), HKBWS avifauna (Yellow-breasted en
Yellow-browed Bunting, Rufous-bellied Woodpecker, Great Barbet), BirdGuides/
Oiseaux (Citril Finch), BirdNET/University of Michigan Animal Diversity Web
(Yellow-throated Toucan). Dit zijn eigen samengevatte kenmerken, geen gekopieerde
foto's of complete bronteksten. Definitieve output moet nog worden beoordeeld.

## Verificatie

Offline plancontrole tegen de appcatalogus en zes pilotkeys; geen API-aanvragen.
Python-regressies met nagebootste API controleren 77 gerichte rollen, bewaren
van twee goede primary-rollen, dubbele aanvragen vermijden, checksums,
manifest/versies/provenance, onjuiste bronhash, rechterrandweigering, terugdraaien
bij schrijffout en expliciet herstel na een echt beëindigd testproces.
Mac-keuzevensters en daadwerkelijke API-output zijn in deze omgeving niet getest.
