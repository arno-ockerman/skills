---
name: workout-app-maintenance
description: Use when updating de gebruiker's workout app (port 30432).
version: 1.0.0
author: Hermes (health-coach)
license: MIT
metadata:
  hermes:
    tags: [app, pwa, flask, voeding, mobiliteit]
    related_skills: [as-aware-training-coaching, belgian-nutrition-logging]
---

# Workout-app onderhouden (poort 30432)

de gebruiker's staande instructie: **elke nieuwe oefening of functie die we afspreken wordt ook in de app gezet** — niet alleen in de chat of in een markdown-bestand. Geen aparte vraag afwachten.

## When to Use
- Je voegt een oefening, blok, pagina of functie toe aan de app.
- de gebruiker zegt "zet dat ook in de app" of "pas de app altijd aan".
- Er staat een foto in `coaching/voeding_wachtrij/` die verwerkt moet worden.

## Vaste update-ritus
1. **Bron aanpassen**: nieuwe mobiliteitsoefeningen in `scripts/gen_mobiliteit_svg.py` (tekenfunctie + blok), kracht in de skill `as-aware-training-coaching` (`references/krachtprogramma-2x.md`) én in de app-data.
2. **Generator draaien** → SVG's in `static/mobiliteit/`.
3. **App aanpassen**: route + template (+ content-JSON als het om oefeningen gaat).
4. **`SW_VERSION` bumpen** in `app.py`. Zonder bump houdt een geïnstalleerde client de oude cache.
5. **Herstarten**: `pkill -f '[g]unicorn.*30432'` (met blokhaken, anders matcht de pkill zijn eigen shell) en daarna `scripts/services-watchdog.sh`.
6. **Verifiëren**: `test_app.py` (4 tests) + HTTP 200 op elke route + screenshot op 390 px, licht én donker.

## Navigatie: 5 tabs
`Kracht · Mob. · Eten · Plan · Log`. De tabbar staat in **alle** templates (`index.html`, `mobiliteit.html`, `eten.html`, `plan.html`, `log.html`) — bij een nieuwe pagina moet hij in elk bestand bij, anders verdwijnt de tab zodra je op een andere pagina staat.

## Plan-pagina: de dagelijkse cockpit
de gebruiker wil één scherm met wat er vandaag telt, niet vijf losse pagina's.

- **Checklist van 6** (Blok A · stappen · eiwit · sessie · Blok C 2× · Blok B). Aanvinken gebeurt in de browser via `localStorage` met sleutel `plan-checks-<datum>`, dus elke dag begint de lijst leeg. De server weet niet wat hij afvinkt — dat is bewust: geen extra database.
- **Datakaarten**: stappen met weekdoel, voeding (kcal + eiwitbalk), slaap/HRV/RHR uit `apple_health_daily.csv`, ochtendstijfheid uit `log_herstel.csv`, de sessie van vandaag via `session_for_day()`, plus de stopregels.
- **Weeknummer**: `PLAN_START = date(2026, 10, 19)`; stappendoel = `min(8000, 4500 + 500 * week)`.
- Toont hij een oudere dag (geen data van vandaag), zet er dan altijd bij **van welke datum** die stappen komen.

## Food tracker (live sinds 21/10)

**Doel:** de gebruiker neemt een foto, ziet daarna zijn kcal/macro's en wat er nog binnen het plan past (2000 kcal / 160 g eiwit).

Pad van een foto:
1. `/eten` → knop **Foto toevoegen** (`input type=file accept=image/* capture=environment`) → POST `/api/eten/foto`.
2. Bestand landt in `coaching/voeding_wachtrij/` (naam `YYYYmmdd_HHMMSS.jpg`). De pagina toont "N foto('s) wachten op verwerking".
3. **Ik** verwerk de wachtrij: foto lezen met `vision_analyze`, macro's schatten, rij toevoegen aan `coaching/log_voeding.csv`, daarna foto uit de wachtrij verwijderen.
4. `/eten` leest die CSV en toont dagtotaal, rest en de maaltijdlijst.

**Belangrijk:** de Flask-app kan zelf geen foto's analyseren. De lus werkt alleen als ik de wachtrij leegmaak — doe dat bij elk bericht van de gebruiker (goedkoper en betrouwbaarder dan een agent-cron die elk kwartier vision aanroept).

CSV-schema (`;`-gescheiden): `datum;maaltijd;omschrijving;kcal;eiwit;kh;vet;vezel;notitie`. Datum als `YYYY-MM-DD`, getallen met punt.

## Watchdog: oordeel nooit na 5 seconden

Gunicorn heeft **6 tot 9 seconden** nodig voor hij luistert (koude start met Flask-imports langer dan een warme herstart van 1 s). Een vaste `sleep 5` na de herstart gaf daardoor twee keer een **vals alarm** "wilde niet herstarten" terwijl de app een seconde later gewoon op 200 stond.

Regels voor de watchdog:
1. **Readiness = HTTP 200** op `/health`, niet een open TCP-poort. Een luisterende socket met een dode worker passeert een poortcheck.
2. **Poll tot 30 s**, 1 s per stap — nooit één vaste slaap.
3. **Tweede poging** pas na die 30 s: `pkill -f '[g]unicorn.*30432'` (blokhaken!), 2 s wachten, opnieuw starten, weer 30 s pollen. Alarmeer pas daarna.
4. **`flock` op een lockbestand** in de coach-map, anders starten twee cron-runs (elke 5 min) tegelijk een tweede gunicorn en vechten ze om de poort.
5. Alarmtekst pas opstellen als de tweede poging ook faalt — anders lees je een storing die niet bestaat.

## Valkuilen (allemaal echt gebeurd)
- **`connect()` is een contextmanager**: gebruik `with connect() as db:` — anders krijg je `'_GeneratorContextManager' object has no attribute 'execute'` (500 op de pagina).
- **De coach-CSV's zijn puntkomma-gescheiden**: `csv.DictReader(fh, delimiter=";")`. Zonder delimiter leest hij één kolom en lijkt elk bestand leeg.
- **Lege cel is niet nul**: `float(r.get(veld) or 0)` toont "0.0 min" terwijl er niets gemeten is. Sla lege cellen over (`continue`) en toon "niet gelogd".
- **Kolom toevoegen ≠ kolom vullen**: bij een nieuwe CSV-kolom moet hij ook in de `values`-dict van `main()` staan (`pick("...")`), anders blijft de kolom eeuwig leeg. Test met een volledige payload, niet alleen met de losse functie.
- **`.figuur` moet altijd een licht vlak houden** (`#f1f6fa`); anders verdwijnt donkere SVG-inkt op een donkere kaart.
- **Testdata nooit in de echte bestanden**: werk met een kopie in `cache/scratch/` en ruim op.
- **Poort 30432 is de enige vrije gepubliceerde poort**; 30433 is het dashboard, 8644 de webhook (niet extern bereikbaar).
- **PWA-installatie vereist HTTPS**; over `http://192.0.2.10:30432` is het een bladwijzer, geen echte app.
