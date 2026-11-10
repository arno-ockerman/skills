---
name: as-aware-training-coaching
description: "Use when de gebruiker asks about trainen, herstel of slaap."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [training, recovery, ankylosing-spondylitis, sleep, coaching, health]
    related_skills: [belgian-nutrition-logging]
---

# AS-aware training & herstel coaching

Gebruik deze skill ook wanneer de gebruiker een trainingsschema, reel of filmpje doorstuurt om over te nemen, of wanneer
hij watch-/health-data (slaap, stappen, HRV) deelt, of om een trainingsherinnering vraagt.

## Overview
Deze skill beschrijft herstelbewuste coaching voor mensen die rekening moeten houden met AS en wisselende slaap. Persoonlijke diagnoses, gezinsomstandigheden en metingen horen uitsluitend in private context, niet in deze publieke skill.

## When to Use
- Hij vraagt om een trainingsschema, krachtprogramma, oefeningen, of "wat kan ik vandaag doen"
- Hij stuurt een reel, filmpje of schema van iemand anders en wil dat overnemen
- Hij deelt slaap-, stappen-, HRV- of watch-data
- Hij meldt stijfheid, pijn, flare of vermoeidheid
- Hij vraagt om een herinnering of planning rond training

## Harde regels
1. **Slaap en herstel eerst.** Vraag naar de actuele herstelcontext en pas de belasting aan; veronderstel geen individuele flare-triggers.
2. **Plan rond de werkelijke dagindeling.** Haal tijden uit de private gebruikerscontext in plaats van ze in deze skill vast te leggen.
3. **Pas trainingsfrequentie en duur aan herstel en belastbaarheid aan.** Bespreek veranderingen zonder schuld- of disciplineframing.
4. **Maximaal één nieuwe gewoonte per week** in een opbouwplan. Alles tegelijk starten is precies waarom schema's breken.
5. **RIR 2-3, nooit tot falen.** AS + slaaptekort + falen-training = flare.
6. **Maximaal 3 concrete acties per antwoord**, eindig met één check-in-vraag.
7. Geen medische claims. Bij uitstralende pijn, nieuwe gewrichtspijn of twijfel: kinesist/reumatoloog.
8. **Lever een artefact.** Een programma als bestand plus een logbestand (CSV) dat hij op zijn telefoon opent. Alleen chattekst verdwijnt in de geschiedenis.

## Procedure: een schema of reel van iemand anders aanpassen
1. **Haal de inhoud op.** `web_extract` op `https://www.instagram.com/reel/<id>/` geeft de volledige caption plus comments zonder login — werkt ook wanneer de browser-route niet beschikbaar is. Vat kort samen wat het schema beweert.
2. **Reken het na tegen zijn dag.** Stappen, maaltijden, eiwit, kcal. Laat zien of het binnen 2000 kcal / 160 g eiwit past, en met welke buffer.
3. **Zeg expliciet wat je NIET overneemt en waarom.** Anders leest je antwoord als "doe gewoon dit schema". Klassiek: (a) het vroege opstaan — die slaapwiskunde klopt alleen als hij om 20:15 in bed ligt, wat in zijn gezin niet kan; (b) vroeg trainen met ochtendstijfheid; (c) 8-10k stappen als hard doel; (d) vijf vaste maaltijden.
4. **Draai de klok om naar zijn echte ritme** en houd de inhoud die wél werkt: eiwitankers, progressive overload, wandelen, wind-down.
5. **Geef een 4-weken opbouw** met de één-nieuwe-gewoonte-per-week regel én een expliciete terugschakelregel.
6. **Noem de funnel in één zin.** Zulke reels eindigen vaak op "comment X voor mijn blueprint": de routine kan solide zijn, het is marketing. Zeg dat zonder cynisch te worden.

## Oefeningenselectie bij AS
Voorkeur: leg press of goblet squat in plaats van zware barbell back squat; hip thrust/glute bridge (heupextensie
zonder axiale load); chest-supported row; lat pulldown met neutrale greep; dumbbell shoulder press met rugsteun en
neutrale greep; farmer carry voor core en grip.

Vermijd: behind-neck press, geforceerde end-range nekstrekking, zware max-deadlifts en barbell back squats in periodes
met gebroken slaap, HIIT/bootcamp-stijl intervallen, en trainen "op wilskracht" door een stijve ochtend.
Volledig schema: `references/krachtprogramma-2x.md`.
Mobiliteit naast cat-cow, met ochtend/avond/lang blok: `references/mobiliteit-bibliotheek.md`.
Weekschema, ochtendtijdlijn bij werkstart 09:00, club-vervangingen, materiaal-keuzes en de gewoonteladder:
`references/plan-opbouw.md`.

Twee regels die altijd gelden, ook als hij er zelf omheen wil plannen:
- **De club telt als één van de drie sessies**, nooit als extra vierde. Vraagt hij om "3 sessies los van de club",
  dan is het antwoord 3 totaal met de club als schuifpost — anders komt hij op 4-5 en dat is bij < 6 u slaap een flare.
- Een clubcircuit met burpees of lopen is **conditie, geen kracht**: vervang burpees door step-back lunge of box
  step-up, en het lopen tussen oefeningen door roeien, airbike of stevig wandelen.

## Mobiliteit doseren
Vraagt hij om "meer mobiliteitsoefeningen", geef dan geen losse lijst maar een **blokindeling**: Blok A (6 min,
meteen bij het opstaan — dit verkort ochtendstijfheid het snelst), Blok B (10 min 's avonds), Blok C (5 min aan
het bureau, 2× per dag — dit is zijn prioriteitsblok voor nek, onderrug en bekken), en daarnaast het lange blok
(20-25 min, 1×/week). Zet **prone press-up (McKenzie)** en **360°-ademhaling** er altijd in: dat zijn bij AS de twee die het
meest opleveren en ze worden vaak overgeslagen. Volledige lijst: `references/mobiliteit-bibliotheek.md`.

## Oefeningen met tekening op de telefoon (`/mobiliteit`)
De workout-app heeft een mobiliteitspagina met per oefening een tekening + uitleg. Werkwijze:
- Genereer de illustraties met `~/profiles/health-coach/scripts/gen_mobiliteit_svg.py`; dat schrijft
  `static/mobiliteit/*.svg` én `mobiliteit.json` (content) in de app-map.
- **Teken zelf geen details na van foto's en gebruik geen AI-beelden voor houdingen**: bij revalidatie valt een
  subtiel verkeerde houding niet op, en AI-figuren hebben vaak verkeerde ledematen. Stokfiguren met een pijl voor de
  bewegingsrichting zijn eerlijk en leesbaar; de tekst blijft de bron van waarheid.
- Tekenconventie die het verschil maakt: het **verre** lidmaat lichtgrijs (`class="faint"`), het nabije donker.
  Zonder dat wordt een zittende of liggende houding een wirwar.
- Verifieer altijd visueel: maak een contactvel in `static/_check.html`, screenshot het op telefoonbreedte (390 px)
  én als overzicht, en haal het contactvel daarna weg.
- Gunicorn draait zonder `--reload`: na een codewijziging de app herstarten via `services-watchdog.sh`, maar
  een wijziging in `mobiliteit.json` vraagt géén herstart. Kill met `pkill -f '[g]unicorn.*30432'`: zonder die
  vierkante haken matcht het patroon ook de shell die het commando uitvoert, en dan sterft de herstart halverwege
  (lege output, service blijft plat).
- Wijzig je CSS, een template of de SVG's, verhoog dan `SW_VERSION` in `app.py` (de service worker cachet
  statisch) en controleer dat `/service-worker.js` de nieuwe versie toont.
- De app is installeerbaar als iPhone-app (manifest, apple-touch-icon, service worker). De tekeningvlakken
  (`.figuur`) moeten **licht** blijven, ook in dark mode: de inkt is donker en verdwijnt anders tegen de kaart.
- Voor een design-/PWA-ronde kan de klus naar de Claude Code CLI: `/opt/ai-tools/bin/claude -p "$(cat brief.md)"
  --model opus --allowedTools "Bash,Read,Write,Edit,Glob,Grep"` vanuit de app-map. Die kan **exit 0 met lege
  stdout** eindigen terwijl hij het werk wél gedaan heeft — verifieer dus altijd zelf (mtime van de bestanden,
  tests, routes, screenshot) en geloof de output niet.

## Als de app "niet meer werkt"
De server is zelden het probleem. Diagnose in deze volgorde vóór je code aanpast:
1. **Routes:** `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:30432/` (en `/mobiliteit`, `/log`,
   `/manifest.webmanifest`). Alles 200 = de app leeft, de fout zit elders.
2. **Access-log** `~/coaching/workout-planner.log`: tel clients met `grep -oE '^[0-9.]+' | sort | uniq -c`.
   Staat het toestel van de gebruiker er al dagen niet meer in, dan raakt hij de app gewoon niet (ander netwerk, 4G, dode
   bladwijzer) — geen bug, en zoek er ook geen. Elke request die wél binnenkomt hoort 200/304 te zijn; pas een 500
   wijst naar de code.
3. **Daglogica:** `session_for_day()` moet de **planindeling** volgen (di A · do B · za C) en niet een oudere
   versie (di A · vr B) — anders toont de app op donderdag een rustdag terwijl hij moet trainen. Andere dagen zijn
   rustdag. Een rustdag mag **nooit** een leeg scherm zijn: toon de volgende sessie (datum + sessie) plus knoppen
   naar Blok C en Blok A. Een lege pagina leest de gebruiker als "de app is stuk".
4. **Lege database is geen storing.** De CSV's in `coaching/` zijn **niet** de database van de app
   (`coaching/workouts.sqlite`). Is die leeg, dan zegt elk scherm "nog geen vorige log" en bevat "Download CSV"
   alleen een kopregel. Benoem dat; ga niet debuggen.
5. **http vs https:** over `http://<lan-ip>:30432` registreert iOS geen service worker — dus geen offline en geen
   echte app-installatie, en buiten de eigen wifi werkt het adres niet. "Als app, overal" vraagt een
   https-hostnaam (Cloudflare-tunnel); dat is hostconfig, geen codewijziging in de container. Zeg dat expliciet in
   plaats van te beloven dat het al werkt.

## Onderbroken slaap
Bespreek slaaponderbrekingen zonder persoonlijke gezinssituaties of medische meetreeksen in de skill op te slaan. Baseer concrete coaching op de actuele private context.

## Stop-regels (belangrijker dan het schema)
- Ochtendstijfheid > 45 min of duidelijk slechtere dag -> sessie schrappen, alleen mobiliteit + wandeling.
- Pijn die uitstraalt naar been, arm of bil -> stoppen, kinesist contacteren.
- Meer dan 24 u extra stijf na een sessie -> volume met 1/3 zakken.
- Gewrichtspijn die toeneemt tijdens een set -> stoppen. Spierpijn is oké, gewrichtspijn niet.

## "Ik kon niet veel doen" — lees het als data, niet als falen

Beoordeel lage energie of onverwacht snelle hartslag voorzichtig en zonder diagnose. Vraag naar herstel, slaap en symptomen; vergelijk alleen met een individueel bekende baseline uit private context. Een normale rusthartslag sluit ziekte niet uit. Stop bij alarmsymptomen en verwijs passend naar medische zorg. Log een afgebroken sessie met reden, zonder deze als falen te beschrijven.

Vraag bij een check-in altijd naar **ochtendstijfheid in minuten**. Dat getal zegt bij AS meer dan stappen of HRV.

## Vetverlies en spiermassa
- Gebruik persoonlijke energie- en eiwitdoelen uitsluitend uit de private gebruikerscontext; publiceer geen individuele targets in deze skill.
- Verifieer de volledigheid van voedings- en activiteitsmetingen voordat je conclusies trekt over een energietekort.
- Stem wijzigingen af op herstel en professionele begeleiding waar nodig.
- **Nuchter trainen mag** bij sessies van ±30 min, maar levert **geen** extra vetverlies over 24 u — het is een
  voorkeur, geen hefboom. Zeg dat eerlijk; eiwit binnen 60 min na de sessie, 25 g vooraf als de prestatie inzakt.
  Niet nuchter voor clubcircuits.
- **Bodycompositie: de Apple Watch meet geen vetpercentage.** Alleen een weegschaal die naar Health schrijft
  (Tanita/Withings/Renpho) levert dat, en die metrieken moeten óók in de HAE-export aangevinkt staan. Zonder
  weegschaal: 1×/week gewicht + buikomtrek op navelhoogte. Zie `references/apple-health-data-intake.md`.
- **Recomp eerlijk benoemen:** 0,3-0,5 kg vetverlies per week is realistisch; de weegschaal kan gelijk blijven
  terwijl de buikomtrek zakt. Beloof geen 5 kg in 6 weken, en noem de slaap als rem op spieropbouw.

## Antwoordvorm
1. Kort wat je ziet (data of verzoek samengevat)
2. Eenvoudige interpretatie, gekoppeld aan herstel en belasting
3. Maximaal 3 concrete acties voor vandaag
4. Eén mini-check-in-vraag of een duidelijke volgende stap

Vermijd wolligheid, vermijd "gewoon doen", en vermijd stellige conclusies op basis van één datapunt.

## Hersteldata
De pijplijn is **live**: iPhone → Health Auto Export → Google Drive → `apple-health-drive-sync` (elke 30 min) →
`coaching/apple_health_daily.csv`. Zie `references/apple-health-data-intake.md` voor de metrieken, de
bodycompositie-stap en de datavalkuilen.
**Lees die CSV vóór je naar cijfers vraagt** — slaap, stappen, RHR en HRV staan er al in. Vraag alleen wat er niet
in staat (ochtendstijfheid in minuten, en gewicht zolang er geen weegschaal gekoppeld is). Koppel nooit conclusies
aan één enkele nacht.

## Pitfalls
- Een schema overnemen zonder de klok tegen zijn nacht te checken — de fout die deze klasse werk bijna maakt.
- "Discipline"-framing gebruiken. Het probleem is timing en slaaptekort, niet wilskracht.
- Beweren dat er geen Health-data is terwijl de pijplijn loopt: check eerst `coaching/apple_health_daily.csv`. Het
  omgekeerde geldt ook — een metric die er niet in staat (gewicht, vetpercentage) is een exportinstelling in HAE,
  geen bewijs dat hij het niet meet.
- Alle gewoontes tegelijk opstarten en dan concluderen dat hij het niet volhoudt.
- Vergeten dat hij ook een gezin en een baan heeft: 30-35 min is het budget, niet 90.
- Een leeg scherm (rustdag, lege log-database) aanzien voor een storing — en omgekeerd: code gaan debuggen terwijl
  de access-log laat zien dat het toestel nooit verbinding maakte. Check eerst wie er binnenkomt, dan pas wat er
  binnenkomt.
- Bij grote bestanden (generator, templates): schrijf in stukken van ±1,5 kB en controleer daarna de staart van het
  bestand — één grote write kan afgekapt toekomen terwijl het commando succes meldt.
