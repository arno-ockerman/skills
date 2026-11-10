---
name: apple-health-webhook-ingest
description: "Use when ingesting Apple Health data into Hermes."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [apple-health, webhook, health-auto-export, ingest, health-coach]
    related_skills: [belgian-nutrition-logging, webhook-subscriptions]
---

# Apple Health → Hermes webhook ingest

Pijplijn: iPhone-app **Health Auto Export** (REST API-automation) → Hermes webhook-route → filter-/verwerkingsscript → CSV-opslag + max 1 agent-push per dag.

Werkende implementatie: route `apple-health`, script `/opt/data/profiles/health-coach/scripts/apple-health-ingest.py` (profiel health-coach).

## When to Use

Gebruik deze skill wanneer:
- de gebruiker Apple Health-data (slaap/stappen/HRV) automatisch wil laten binnenkomen,
- de app **Health Auto Export** opnieuw geconfigureerd of getest moet worden,
- een route moet worden gemaakt of gedebugd die een statisch token gebruikt in plaats van HMAC,
- het push-venster of de 1×/dag-rem in `apple-health-ingest.py` aangepast moet worden.

## Auth: Health Auto Export kan geen HMAC, Hermes wel een statisch token

De app ondersteunt enkel **statische** custom headers, geen berekende HMAC. Hermes' webhook-validator accepteert naast
GitHub/Svix/Linear ook de GitLab-modus: `X-Gitlab-Token` moet exact gelijk zijn aan het route-secret.

→ Zet in Health Auto Export een header **`X-Gitlab-Token: <route-secret>`**. Dat is de enige werkende auth zonder eigen proxy.

Bewijs dat auth echt afgedwongen wordt (altijd beide testen):
- zonder/fout token → `HTTP 401 {"error": "Invalid signature"}`
- juist token → `HTTP 200/202`

## Route binden aan een profiel (belangrijk)

- `--route-profile <profiel>` → URL wordt `http://<host>:8644/p/<profiel>/webhooks/<naam>`.
- Het root-pad `/webhooks/<naam>` geeft dan **404** — dat is het bewijs dat de profielbinding klopt.
- Het route-script en de prompt worden uitgevoerd in de context van dat profiel: `~/.hermes/scripts/x.py` en
  relatieve scriptpaden resolven tegen **HERMES_HOME van het route-profiel**. Zet het script dus in
  `/opt/data/profiles/<profiel>/scripts/`.

## Deze omgeving: welk profiel bezit de webhook-poort

Alleen het **default**-profiel draait een gateway en bezit poort 8644; de gateways van health-coach, dev-builder en
herbalife-business staan down (s6 `down`-file). Daarom:

```bash
/opt/hermes/bin/hermes -p default webhook subscribe <naam> \
  --script <script-in-profielmap>.py \
  --route-profile <doelprofiel> \
  --deliver telegram --deliver-chat-id <chat_id> \
  --prompt "...{samenvatting}..."
```

`hermes -p <profiel> ...` bepaalt **welke subscriptions-file** geschreven wordt (die van de gateway die luistert),
`--route-profile` bepaalt **als welk profiel de agent draait**. Dat zijn twee losse assen.

## Scriptcontract

- Payload komt als JSON op **stdin**.
- stdout = JSON-object → **vervangt** de payload voor prompt-rendering (`{veld}` werkt dan op jouw velden).
- stdout leeg, `[SILENT]`, of `{"[SILENT]": true}` → webhook wordt genegeerd (HTTP 200 `{"status":"ignored","reason":"script"}`).
- Non-zero exit → genegeerd. Timeout standaard 30 s.

## Limieten van de webhook-server

- `max_body_bytes` = **1 MB** standaard (`platforms.webhook.extra.max_body_bytes`). Laat Health Auto Export dus
  **aggregate by day** + **batch requests** gebruiken en selecteer enkel de metrics die je nodig hebt; anders kapt de
  server de payload af.
- Rate limit: 30 requests/minuut per route.
- Idempotentie-cache 1 uur op delivery-id.
- Apple-limiet: Health Auto Export kan **niet syncen terwijl de iPhone vergrendeld is**; automations lopen enkel als het
  toestel ontgrendeld is. Zet de cadans op 1×/dag en niet op elk uur.

## Anti-spam patroon in het script

Laat het script **altijd** opslaan, maar slechts **1× per dag** een agent-push doorlaten binnen een tijdvenster
(06:30–12:00). Dat voorkomt dat een uurlijkse sync LLM-runs en berichten genereert. Implementatie: state-bestand met
`last_push_date` + venstercheck; `APPLE_HEALTH_FORCE_PUSH=1` als expliciete test-escape.

## Tijdzone-valkuil (in deze container organisatorisch fout gegaan)

De container draait op **UTC** terwijl de gebruiker in **Europe/Brussels** zit. Gebruik in scripts dus expliciet
`datetime.now(ZoneInfo("Europe/Brussels"))`; met `datetime.now()` schuift het push-venster 2 uur op en komt een
"ochtendbericht" om 08:30 of juist om 04:00 binnen.

## Valkuil bij testen

`mark_push()` gebruikt `datetime.now()`, niet de datum van de data. Een **geforceerde test** zet dus de 1×/dag-vlag
voor vandaag, waarna elke volgende POST dezelfde dag stil wordt genegeerd. Wis bij het testen altijd
`.apple_health_push_state.json` en gebruik een dummy-datum (bv. 2000-01-01) voor de testrij, anders vervuil je de
log en blokkeer je de echte sync.

## End-to-end verificatie

1. `curl` zonder token → 401; met token → 200/202.
2. Root-pad zonder profiel → 404.
3. CSV bevat de testrij; daarna testdata opschonen.
4. Echte push (state gewist + venster tijdelijk open) → `HTTP 202` met `delivery_id`, en het staat in het state-bestand.

## Draaiend houden (persistentie)

De gateway die de webhook serveert is **s6-supervised** en komt terug na een containerherstart; de dynamic route staat in
`/opt/data/webhook_subscriptions.json` op een volume, dus dat overleeft ook. Wat níet vanzelf terugkomt zijn zelf
gestarte side-services (bv. de Flask/gunicorn workout-planner op poort 8765).

Patroon daarvoor: een **no_agent cronjob met een watchdog-script** (`every 5m`, lege stdout = geen bericht):
- script: `~/profiles/health-coach/scripts/services-watchdog.sh`
- start de service opnieuw met `nohup setsid … &` als de poort dicht is, maar **oordeel niet na 5 s**: poll tot 30 s op HTTP 200 van `/health`, doe één tweede poging en alarmeer pas daarna. Gunicorn heeft 6-9 s nodig bij een koude start; een vaste `sleep 5` gaf twee keer een vals alarm terwijl de app één seconde later gewoon liep (details in `workout-app-maintenance`)
- waarschuw ook als de webhook-poort 8644 niet luistert of als er >30 u geen health-sync meer binnenkwam
- cron: `cronjob_manage(action='create', schedule='every 5m', no_agent=True, script='services-watchdog.sh')`

Let op: de cron-scheduler rekent in **UTC** (container-tijd), dus "every sunday 6am" = 08:00 Belgische zomertijd.

## Poortloze route: Google Drive pull (aanbevolen als poorten publiceren niet lukt)

Health Auto Export kan ook naar **Google Drive** exporteren (automation type "Google"). Dan is er **geen inkomende
poort nodig**: de app uploadt uitgaand, Hermes haalt het bestand op met `gog drive`. Werkt ook buitenshuis, zonder
Cloudflare-hostname.

Werkende implementatie:
- Drive-mappen: `Health Auto Export` (root, door de app gemaakt/gehergebruikt) → submap `Hermes`.
- Pull-script: `~/profiles/health-coach/scripts/apple-health-drive-pull.py`
  - leest `gog.env`, zoekt de mappen (IDs gecachet in `.apple_health_drive_state.json`),
    downloadt nieuwe JSON-bestanden, voert ze door `apple-health-ingest.py` en onthoudt verwerkte file-IDs.
- Cron: `cronjob_manage(action='create', schedule='every 30m', monitor='apple-health-drive-pull.py', ...)`.
  **Monitor-modus** is hier ideaal: de agentstart alleen als de output verandert, en één LLM-run per nacht volstaat.
- **Monitor-output moet deterministisch zijn** (geen tijdstempels): print enkel de nieuwste slaapnacht
  (`NACHT=… SLAAP=… WAKKER=…`). Zet er geen stappen/tijd in die tijdens de dag veranderen, of je krijgt meerdere
  berichten per dag.
- Het eerste tick van een monitor-job draait altijd als baseline: zorg dat het prompt een lege/geen-data-regel
  opvangt, anders krijg je één verward bericht.

## Een vrije, al gepubliceerde poort vinden (TrueNAS-portmapping ontwijken)

Moet je iets ontsluiten maar kun je de container-poorten niet aanpassen? Test welke poorten al naar de container
gepubliceerd zijn: **bind in de container een listener op poort P en probeer van binnenuit `192.0.2.10:P`**.
Komt de verbinding bij je eigen listener terug, dan is host-poort P → container-poort P gepubliceerd en dus
herbruikbaar. Zo gevonden: **30432** (vrij) naast dashboard 30433. De workout-pagina draait daarom op 30432 en is
bereikbaar op `http://192.0.2.10:30432` — zonder enige TrueNAS-wijziging.

## Valkuil: achtergrondprocessen starten via de terminal-tool

Commando's die eindigen op `&` worden door de terminal-tool geweigerd (exit -1, lege output) — je ziet dus geen
foutmelding en denkt dat het gelukt is. Start daemons daarom via een **script** (subshell + `nohup setsid … &`),
zoals `services-watchdog.sh` doet.

## HAE-Google-automation: er is géén URL-veld

Vraagt de gebruiker "welke URL geef ik in?" bij het Google-type: antwoord = **geen**. De Google-automation heeft geen
URL; je tapt **Connect Google**, kiest een **Folder Name** en klaar. Belangrijk: het veld **Automation Name wordt
óók als mapnaam gebruikt** — zet Automation Name én Folder Name op exact dezelfde naam als het pull-script verwacht
(`Hermes`), anders landen de bestanden in een map die het script niet kent. Valt de upload toch elders: in de
geavanceerde Drive-velden kan de **Backup Folder ID** van de submap handmatig ingevuld worden.

## Valkuil: HAE-export kan meerdere dagen bevatten

Met **Date Range** stopt de app meerdere dagen in één JSON-bestand (bv. de eerste export van een week). Schrijf
daarom **per datum een rij** (`day_rows()` in `apple-health-ingest.py`) en niet enkel de nieuwste dag, anders
verlies je alle eerdere dagen stil. De monitor-regel blijft wél op de nieuwste nacht gebaseerd, zodat er maar één
bericht per nacht volgt.

## Vijf valkuilen in echte HAE-exports (allemaal gezien, allemaal gefixt)

1. **HAE hergebruikt je zelfgemaakte root niet.** Maak je vooraf `Health Auto Export/Hermes` aan, dan maakt de app
   tóch een tweede root met dezelfde naam. **Nooit folder-ID's hardcoden** — zoek dynamisch: alle mappen die
   `Health Auto Export` heten → al hun submappen → alle `.json` erin.
2. **Twee exportformaten door elkaar.** Een automation met dag-samenvatting levert 1 entry/dag (~5 kB), een
   automation met ruwe samples honderden entries/dag (~300-700 kB). "Laatste entry wint" gaf 6 stappen als
   dagwaarde. Fix: **totalen optellen** (steps, energie), **hartslag/HRV middelen**, en bij meerdere bestanden per dag
   de **grote (ruwe) bestanden eerst** verwerken zodat de kleine samenvatting wint.
3. **`active_energy` staat in kJ**, niet kcal → vermenigvuldig met 0,239006 (676 kJ = 162 kcal).
4. **`asleep` en `inBed` kunnen 0 zijn** terwijl `totalSleep` en `inBedStart`/`inBedEnd` wél gevuld zijn. Gebruik
   `totalSleep` en bereken de tijd in bed uit de twee tijdstempels — anders log je 0 u slaap.
5. **Meerdere automations naast elkaar** (de gebruiker had er drie: Hermes, DailyExport, AppleHealth) leveren dezelfde dagen
   dubbel met verschillende waarden. Advies: hou er **één** over, anders blijft de databron wisselen.

## HAE overschrijft hetzelfde bestand — onthoud id + modifiedTime

Health Auto Export schrijft per dag één bestand (`AppleHealth-YYYY-MM-DD.json`) en **overschrijft dat bij elke sync**: het Drive-ID blijft gelijk, de inhoud verandert (eerst zonder slaap, later met).

Wie alleen het bestand-ID als verwerkt onthoudt, mist latere aanvullingen met slaapdata. Verifieer daarom zowel ID als wijzigingstijd.

Regel: sla de sleutel `f"{id}:{modifiedTime}"` op in de processed-state. Dan wordt een gewijzigd bestand opnieuw verwerkt en blijft de pijplijn zelfherstellend.

## Slaap: gebruik `totalSleep`, nooit `asleep`

De gevaarlijkste valkuil in de hele pijplijn. Een HAE-`sleep_analysis`-entry bevat meerdere velden die allemaal op "slaap" lijken:

| veld | wat het echt is |
|---|---|
| `totalSleep` | **de geslapen tijd — dit is de juiste waarde** |
| `asleep` | bij iOS 16+ alleen het deel **zonder** fase (core/deep/rem), dus vaak minder dan de helft |
| `core` / `deep` / `rem` | fases, samen zelden de volledige nacht |
| `inBed` | kan `0` zijn → dan uit `inBedStart`/`inBedEnd` rekenen |

Gebruik synthetische fixtures om te testen dat `totalSleep` en niet `asleep` wordt ingelezen. Vergelijk een fix, met toestemming, met een private handmatige referentiemeting; publiceer geen echte slaapmetingen of persoonlijke gemiddelden.

## Versheid: kijk naar de DATUM, niet naar `bijgewerkt`

`bijgewerkt` is het moment waarop wij schreven. Herverwerken we oude bestanden, dan wordt dat veld vernieuwd en lijkt een stilstaande pijplijn ineens vers. Gebruik de nieuwste **datum** in de CSV en alarmeer pas als die ≥2 dagen oud is (een dag data komt normaal pas de volgende ochtend binnen).

## Datumsemantiek: waar hoort elk cijfer bij?

Dit is de meest gemaakte fout in rapportages, en de gebruiker merkt het meteen.

- **Slaap** hoort bij de nacht die **op** die datum eindigde. De rij `2026-10-27` bevat de nacht van 26 → 27 oktober. Noem het altijd zo: **"nacht van 26/10 → 27/10"**, nooit "nacht 27/10" (dat leest als de nacht die nog moet komen).
- **Stappen, energie en hartslag** horen bij de **dag zelf**. Gebruik nooit de stappen van een andere dag als de dag zelf nog geen data heeft — toon dan "nog geen stappen van vandaag" in plaats van een oud getal dat als actueel leest.
- **Gevoeligheid**: als een dag minder dan ~1.500 stappen toont terwijl de gebruiker een normale dag had, is dat vaak een niet-gedragen watch of een telefoon die op het bureau lag. Zeg dat erbij in plaats van te concluderen dat hij te weinig bewogen heeft.

## Tijdelijke Drive-fouten: herhalen, niet alarmeren

`gog drive ls` faalt af en toe met een transportfout in deze vorm:
`Get "https://www.googleapis.com/drive/v3/files?...": <reden>`. Dat is géén kapotte auth — 8 van 8 handmatige pogingen slagen gewoon. Het is netwerk/API-ruis.

Regels die dat afvangen:
1. **Herhaal leesacties** (ls, download) 3× met backoff (2 s, 4 s). Nooit meteen als fout loggen.
2. **Log de staart van stderr, niet de kop.** De kop is alleen de URL met 300 tekens query; de reden staat achteraan. `...{stderr[-220:]}`.
3. **Alarm alleen bij echte stilstand.** Een gog-fout in de laatste logregel betekent niets als er nog verse data binnenkomt. Koppel het alarm aan de leeftijd van de data. Drempel: **24 u** voor "fout + geen data" en 30 u voor "helemaal geen sync". Niet strakker zetten: HAE kan niet uploaden terwijl de iPhone op slot zit, dus nachtgaten van 13-15 u zijn normaal en een drempel van 8 u alarmeert elke nacht.
4. **Schrijf nooit testdata in de productielogs.** Een testregel in `drive-pull.log` werd door de 4-uurscontrole als echte fout gelezen en naar de gebruiker gestuurd. Test met een tijdelijke map en een aangepast `COACH`-pad.

## Kolomindices verschuiven (en dan sterft een check stil)

Toen er kolommen gewicht/vet/spiermassa bijkwamen, verschoof `bijgewerkt` van kolom 12 naar 15. De versheidscontrole bleef `cut -f12` lezen — dat is nu **gewicht** — en gaf dus nooit meer een leeftijd. Resultaat: een controle die altijd stil bleef en nooit iets kon melden.

Gebruik bij zo'n `cut` altijd een benoemde constante (`KOLOM_BIJGEWERKT=15`) naast de kopcomment, en test met een nagebootste oude datum of het alarm echt afgaat.

## Cron-hardening: waarom de pijplijn 2 dagen stil kan staan

Deze fouten zijn echt gebeurd en waren dagenlang onzichtbaar:

1. **`gog.env` gebruikt `export VAR=...`.** Split je alleen op `=`, dan zet je de variabele onder de naam
   `export GOG_KEYRING_PASSWORD` en faalt gog in een cron met "no TTY available for keyring file backend password
   prompt". Strip dus de `export `-prefix. Test met `env -i HOME=/opt/data PATH=/usr/bin:/bin python3 <script>`:
   in een interactieve shell verbergt de geërfde omgeving deze bug.
2. **Falen moet ZICHTBAAR zijn in de monitor-output.** Een script dat bij een fout alleen naar een logbestand
   schrijft, levert elke tick dezelfde (of lege) output → de monitor ziet geen wijziging → niemand merkt dat de
   koppeling stuk is. Print bij een fout een marker (`FOUT=drive-onbereikbaar`) zodat de output verandert en de
   agent één keer alarm slaat.
3. **Dagen zonder slaapdata.** Maak rijen met `days.setdefault(day, {})`; een dag met alleen stappen/energie
   bestaat nog niet in de dict en gaf een `KeyError` die het hele bestand liet mislukken (dag stil verloren).
4. **De monitor-regel moet de nieuwste regel MET slaapdata pakken.** HAE stuurt de dag van vandaag al binnen
   vóórdat de nacht erin zit; de laatste CSV-regel kan dus leeg zijn → loze "wacht op eerste sync"-berichten.

## Ritme van de controles (niet alles elke 5 minuten)
- **Elke 5 min** — alleen services: workout-pagina (herstarten) en webhook-poort. Dat is een
  "is de service nú stuk"-vraag.
- **Elke 4 uur** — `apple-health-sync-check.sh`: komt er nog data binnen (< 30 u) en faalt de Drive-pijplijn?
  Dat is een "is er de laatste dag nog data"-vraag; vaker kijken voegt niets toe en levert alleen ruis.

## Historiek corrigeren na een parseerfout

Een fout in de ingest (verkeerd slaapveld, verkeerde eenheid) zit in **alle** al verwerkte dagen. Repareer de code en herverwerk de bron — niet alleen vandaag.

1. **Back-up** van `apple_health_daily.csv` én van de state-file.
2. **State leegmaken**: `processed` op `[]`. Met de `id:modifiedTime`-sleutel is dat meteen een volledige herverwerking.
3. **Pull opnieuw draaien** in de foreground (~200 s voor ~130 bestanden). Ruime timeout, één run, geen lus.
4. **Valideer tegen een meting van de gebruiker**, niet tegen de oude CSV: zijn Apple Health-scherm of het weekgemiddelde. Zonder die stap weet je alleen dat de code loopt, niet dat de cijfers kloppen.
5. **Weet de bijwerking**: elke herschreven rij krijgt een nieuwe `bijgewerkt`-stempel. Daarom meet de versheidscontrole op **datum** — anders lijkt een stilstaande pijplijn na een herverwerking kersvers.

Kleiner alternatief zonder de state te wissen: één bestand door de ingest duwen met `APPLE_HEALTH_FORCE_PUSH=1 python3 scripts/apple-health-ingest.py < bestand.json`. Dat werkt per dag en laat de rest staan.

## Netwerk

Poort 8644 moet gepubliceerd én bereikbaar zijn. Test vanaf de Hermes-host:
`socket.connect_ex(("192.0.2.10", 8644))`. Alleen 30433 (dashboard) is standaard extern bereikbaar; voor sync
buitenshuis is een Cloudflare-hostname naar `http://192.0.2.10:8644` nodig.
