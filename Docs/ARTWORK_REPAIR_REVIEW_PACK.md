# Illustratieherstel: compact controlepakket — 25 november 2026

Het oorspronkelijke geüploade Archief.zip is groter dan de overdrachtslimiet
van de bestandstool (32 MiB). De beelden daarin zijn nog niet geïnspecteerd;
het aantal bestanden/soorten is daarom nog onbekend. Oude uploads met dezelfde
naam mogen niet voor dit nieuwe archief worden aangezien.

## Op de Mac

1. Pak Birder-Illustratiecontrole.zip uit.
2. Open Scripts/Maak-Illustratiecontrole.command.
3. Kies het oorspronkelijke Archief.zip met je drie groepen.
4. Kies je huidige app-projectmap, met je geïmporteerde afbeeldingen. Het
   hulpmiddel zoekt daar ook naar de zes genoemde soorten met afsnijding rechts.
5. Finder toont Archief-controle.zip naast het origineel. Upload dat ene bestand
   in de chat. Het is beperkt tot 24 MiB, dus onder de overdrachtslimiet.

Er is geen API-sleutel nodig; er worden geen afbeeldingen gegenereerd of in de
app vervangen. Originele archieven en app-assets worden uitsluitend gelezen.
Een bestaande controlezip wordt niet overschreven: hernoem die indien nodig.

## Inhoud

- Eén WebP-voorbeeld per afbeelding, volledige canvas behouden, maximaal 960px
  langste zijde, alpha behouden. Bij een te grote zip worden de voorbeelden
  automatisch kleiner gemaakt (tot 480px), met de gekozen maat in inventory.json.
  Geen croppen/rekken van vogel of scène.
- inventory.json met oorspronkelijke map/bestandsnaam, rol/soort-ID indien
  herkenbaar, oorspronkelijke SHA256, afmetingen en alpha-bounds. Geen absolute
  gebruikerspaden, inloggegevens of andere appgegevens.
- Voor Bonte zanger BN06072, Monniksparkiet BN06289, Bruinstaarthoornkolibrie
  BN01170, Grote kraaghoningzuiger BN02171, Purperhoningzuiger BN02172 en Zwarte
  frankolijn BN03921 worden beschikbare primary/dynamic-assets uit de app
  toegevoegd. Ontbrekende soorten worden expliciet gerapporteerd, niet verzonnen.
- Edge-contact is uitsluitend een aanwijzing voor nader onderzoek. Het bewijst
  geen afsnijding; een bestand zonder alpha wordt niet automatisch afgekeurd.
- De compacte voorbeelden vervangen geen volledige-resolutiecontrole van nieuwe
  definitieve artworkoutputs. Bij een onduidelijk detail kan één origineel
  aanvullend nodig zijn. Geen QA-vlaggen worden automatisch goedgekeurd.

## Herstelplan na ontvangst

De voorbeelden worden per soort/rol geïnspecteerd. Een hashgebonden lijst van
alleen afgekeurde rollen wordt opgesteld. Per soort worden diagnostische
kenmerken en bronverwijzingen toegevoegd. Onzekere leeftijd/morf wordt eerst
vastgelegd. De eerste herstelbatch blijft klein en divers; bestaande goede
beelden en originele outputbestanden worden niet overschreven.

De vijf expliciete kleurvoorbeelden zijn alvast aan catalogus-ID en
soortbeschrijving gekoppeld in ArtworkRepairIntake20261125.json. Dat document
claimt geen inspectie van het onleesbare zipbestand en bevat nog geen uitvoerbare
of goedgekeurde vervangingslijst. De gorzensoorten worden pas na de inventaris
vastgesteld. Aanmaken van de controlezip kost geen API-tegoed.

## Toekomstige generatie

artwork_api_pilot.py voegt de nieuwe rechterrand-/vleugelregels als laatste toe
aan elke primary/dynamic-prompt, ook bij hervatten van eerder vastgelegde
opdrachten. Opgeslagen beelden worden nog steeds overgeslagen. Prompt-hashes
per nieuwe API-aanvraag blijven de daadwerkelijk gebruikte instructies tonen.
Geen al bestaande beelden zijn hiermee automatisch hersteld.

## Tests

De helpertests controleren veilige paden, bestandshashes, volledige canvas,
alpha, geen overschrijven, begrenzing en opruimen, ontbrekende extra soorten en
ongewijzigde originele data. De API-prompttest controleert dat beide rollen de
laatste compositieregels krijgen. Alle API-tests gebruiken nagebootste data;
geen betaalde aanvragen. De Mac-keuzevensters kunnen hier niet native draaien.
