# Apple Health → coach: intakeplan (LIVE)

## Status
**Live.** De iPhone uploadt met Health Auto Export (HAE) naar Google Drive; een cron haalt het elke 30 min op en
voert het door `scripts/apple-health-ingest.py` naar `coaching/apple_health_daily.csv`. Geen inkomende poort nodig —
dat is precies waarom deze route gekozen is (poort 8644 is niet gepubliceerd). Historiek: 100+ dagen.

Controles: `apple-health-drive-sync` (elke 30 min, monitor) en `apple-health-sync-check.sh` (elke 4 u, versheid).
Een lege of onveranderde monitor-output betekent "niets nieuws", niet "stuk" — daarom print een fout expliciet een
marker (`FOUT=…`), anders blijft een dode pijplijn dagenlang onzichtbaar.

## Wat er in de export zit (20 metrieken) en wat niet
Wel: slaap (`sleep_analysis` met deep/rem/awake), stappen, rusthartslag, HRV, actieve energie, afstand,
lichaamstemperatuur tijdens slaap, daglicht, flights, inspanning.
**Niet standaard: gewicht, vetpercentage, spiermassa.** HAE exporteert alléén aangevinkte metrics; dat Tanita naar
Apple Health schrijft betekent niet dat het in de export staat. Diagnose = tel de metric-namen in de ruwe JSON;
staat `body_mass` er niet in, dan is het een exportinstelling. Vraag **Body Mass**, **Body Fat Percentage** en
**Lean Body Mass** aan te vinken — niet in de code gaan zoeken.

## Bodycompositie toevoegen aan de ingest
- Aliassen: `body_mass`/`weight`/`body_weight`, `body_fat_percentage`/`body_fat`, `lean_body_mass`/`muscle_mass`.
- Eenheden: lb → ×0,45359237; vetpercentage als fractie (≤ 1,5) → ×100.
- **Laatste meting van de dag**, niet het gemiddelde en niet de som: het is een meting, geen accumulatie.
- **De valkuil die stil faalt:** een kolom toevoegen aan `CSV_FIELDS` én een familie in `day_rows()` is niet genoeg.
  `main()` bouwt de rij met een expliciete `pick("<veld>")` per kolom; zonder die regel bestaat de kolom wel en
  blijft ze **voor altijd leeg**, zonder foutmelding. Drie plaatsen dus: `CSV_FIELDS`, `day_rows()`, `pick()`.
- E2E testen zonder de echte CSV te raken: kopieer de CSV naar scratch, monkeypatch `m.DAILY_CSV`/`RAW_DIR`/
  `STATE_FILE`, zet `sys.stdin` op een `StringIO` met een payload met de drie metingen, zet
  `APPLE_HEALTH_FORCE_PUSH=1`, vang `SystemExit`, controleer de nieuwe rij **en** dat oude rijen intact zijn, en
  ruim de map op met `shutil.rmtree`.

## Verbruik (TDEE) uit de export halen
`basal_energy_burned` (BMR) + `active_energy` per dag, gemiddeld over **volledige** dagen.
**Filter dagen met BMR < 1200 of active ≈ 0 weg** — horloge niet gedragen of halve export, en die trekken het
gemiddelde zo 400 kcal naar beneden. Vergelijk dat getal met zijn inname vóór je "tekort" of "onderhoud" zegt.

## Vijf datavalkuilen (allemaal echt gezien)
1. **kJ ≠ kcal** — `active_energy` komt in kJ; ×0,239006.
2. **`asleep`/`inBed` kunnen 0 zijn** terwijl `totalSleep` en de tijdstempels gevuld zijn; reken uit de tempels.
3. **Meerdere automations naast elkaar** leveren dezelfde dag dubbel met verschillende waarden — hou er één over.
4. **iPhone vergrendeld = geen sync**, dus gaten van 30-40 u zijn normaal, geen storing.
5. **Diepe slaap + REM > totale slaap** komt voor in onvolledige exports: lees in-bed-tijd als betrouwbaarder.

## Zolang een metric ontbreekt
Vraag 's ochtends om twee cijfers (slaap + stappen) en noteer zelf ochtendstijfheid in minuten in
`coaching/log_herstel.csv`. Bij AS is stijfheid de sterkste indicator, niet het stapnummer.
