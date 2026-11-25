# Ontbrekende oude illustraties en lege sessiebeelden — 25 november 2026

## Bevindingen

De projectdownload bevat 151 primary-afbeeldingen. Onder andere Slangenarend,
Steenarend, Vale gier, Zwarte wouw, Grauwe fitis, Humes bladkoning, Witkeelgors,
Zanggors, Papegaaiduiker en Monniksparkiet hebben daarin geen primary-imageset
of manifestregistratie. De screenshots tonen precies de generieke placeholder.
De nieuwste logboekproductie selecteerde alleen wat ontbrak in het toen gebruikte
lokale project; eerdere lokale importen moeten daarom óók worden meegenomen
wanneer een nieuwe projectdownload wordt gebruikt. Alleen de privékaarten
kopiëren en de twee laatste batches importeren is niet altijd voldoende.
Zonder de lokale projectmap is niet vastgesteld welke extra oude assets de
gebruiker daadwerkelijk bezit. Het hulpmiddel rapporteert ontbrekende voorbeelden.

SessionHabitatArtwork hing zijn laadtaak aan een Group met alleen een optionele
Image. Aanvankelijk is de image nil en is er geen concreet child om die taak te
starten. Een permanente transparante view draagt nu de taak en toont het geladen
beeld als overlay. De eerdere thumbnailfallback blijft behouden. Alleen die
fallback loste de lege startweergave niet op. Dit is een codebevinding, geen
op het toestel geverifieerde reproductie. De 11.130 habitatkoppelingen sluiten
in deze repository aan op de catalogus; de 33 scènes en bundelreferenties zijn
aanwezig. Soortgebaseerde stemming en handmatig bewerken blijven ongewijzigd.

## Herstel in het huidige project

1. Pak `Birder-Illustraties-en-Sessiebeelden-herstel.zip` uit.
2. Open `Scripts/Herstel-Illustraties-en-Sessiebeelden.command` en kies 1.
3. Kies de NIEUWE app-projectmap waarin de laatste twee batches al geïmporteerd
   zijn. Dit blijft het project dat je bouwt; geen nieuwe projectmigratie nodig.
4. Kies de OUDE volledige app-projectmap van vóór de update, waarin de eerdere
   illustraties geïnstalleerd waren.
5. Bouw de nieuwe projectmap opnieuw in Xcode met je bestaande app-identiteit.

Alleen ontbrekende artworkrollen worden overgenomen. Bestaande nieuwere beelden,
waaronder de laatste reparaties, worden behouden. Bestaande onvolledige assets
worden niet overschreven. Bronhashes worden gecontroleerd; bronbeelden en oude
projectmap blijven ongewijzigd. Metadata en bestaande reviewstatus blijven exact
bewaard; er wordt geen nieuwe visuele controle geclaimd. De nieuwe manifestversie
wordt samengevoegd, niet door het oude manifest vervangen.

Gewijzigde code krijgt een herstelkopie; alleen bekende uitgebrachte versies van
SessionEnhancements.swift worden bijgewerkt. De illustratie-overname gebruikt
staging, proceslocks, een hersteljournaal en een kopie van het oude manifest.
Bij een gewone fout wordt teruggedraaid; kies na een hard afgebroken proces
optie 3 om de onvoltooide overname terug te draaien. De broncodefix is afzonderlijk
herhaalbaar via optie 2. Privékaarten, signing, appdata en andere broncode worden
niet gewijzigd. Geen API-aanvragen of nieuwe beeldgeneratie.

Rapport: `.artwork-api/artwork-overname-rapport.json` in de nieuwe projectmap.
Als de voorbeeldsoorten ook in de oude map ontbreken, blijven zij eerlijk als
ontbrekend vermeld. Bewaar dan de eerdere Belgische/proef-productiemappen om die
originele, eerder gegenereerde beelden alsnog lokaal te importeren.

## Verificatie

Vijf synthetische regressietests controleren ontbrekende beelden overnemen,
nieuwere correcties behouden, identieke herhaling, bronhashfouten/onvolledige
bestemmingen, terugdraaien bij fout, metadata behouden, onbekende soorten overslaan
en de gerichte broncode-update met backup/weigering van onbekende gebruikerscode.
Geen native Xcode-build of toesteltest in deze omgeving.
