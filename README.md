# Operation Ostwind

Persistente, dynamische Kampagne für DCS World auf der Karte Caucasus. Blau befreit Georgien von West nach Ost, von der Küste bis Tiflis.

- Solo spielbar, optional Mehrspieler
- Schwierigkeit passt sich an die Spielerzahl an
- Blaue KI unterstützt die Spieler
- Fortschritt bleibt zwischen Sessions erhalten
- Carrier Strike Group mit AIRBOSS, Recovery-Tanker, AWACS, Rettungshubschrauber und Zufallsflügen
- Nur [MOOSE](https://github.com/FlightControl-Master/MOOSE)

## Spielbare Muster

F/A-18C, F-16C, A-10C II, AH-64D, CH-47F, Mi-24P

## Voraussetzungen

1. **MOOSE:** Aktuelle `Moose.lua` von der [Release-Seite](https://github.com/FlightControl-Master/MOOSE/releases) herunterladen und als `scripts/00_Moose.lua` ablegen. Die Datei ist nicht im Repo.
2. **Schreibrechte für DCS:** In `<DCS-Installation>/Scripts/MissionScripting.lua` diese Zeilen auskommentieren:

   ```lua
   --sanitizeModule('io')
   --sanitizeModule('lfs')
   ```

   Nach jedem DCS-Update erneut nötig. Auf einem Server nur vertrauenswürdige Missionen laden.

## Aufbau

```text
mission/
├── (Operation_Ostwind.miz)
└── sounds/
    ├── Airboss Soundfiles/   Sprachdateien für AIRBOSS (aus MOOSE_SOUND v1.4)
    └── LICENSE-MOOSE_SOUND   GPL-3.0
scripts/
├── 00_Moose.lua      MOOSE (nicht im Repo)
├── 00_Loader.lua     Lädt die Skripte beim Entwickeln direkt aus diesem Ordner
├── 01_Config.lua     Alle Einstellungen
├── 02_Persistence.lua Spielstand laden und speichern
├── 03_Zones.lua      Zonen und Frontverlauf
├── 04_Scaling.lua    Spieler zählen, Stufe festlegen
├── 05_Red.lua
├── 06_Blue.lua
├── 07_Carrier.lua    Carrier Strike Group mit AIRBOSS
├── 08_CTLD.lua
├── 09_Tasks.lua
└── 10_Save.lua
tools/
└── pack_sounds.py    Packt die Sprachdateien in die .miz
```

## Spielstand

Liegt unter `Saved Games/DCS/Missions/Saves/Operation Ostwind/`:

| Datei | Inhalt |
| --- | --- |
| `Ostwind.sav.lua` | aktueller Stand |
| `Ostwind.sav.lua.bak` | vorheriger Stand, wird geladen, wenn der aktuelle defekt ist |
| `*.reset.bak`, `*.v<N>.bak`, `*.defekt.bak` | Sicherungen bei Reset, Versionswechsel oder defekter Datei |

**Neue Kampagne starten:** In `01_Config.lua` `Save.Reset = true` setzen, Mission einmal starten, danach wieder auf `false`.

## Zonen im Editor

Diese 11 Trigger-Zonen (Kreis) müssen im Missionseditor mit exakt diesem Namen existieren:

| Phase | Zonen |
| --- | --- |
| 0 (Blau) | `Zone Batumi`, `Zone Kobuleti`, `Zone Senaki` |
| 1 | `Zone Kutaisi` |
| 2 | `Zone Zestafoni` |
| 3 | `Zone Rikoti` |
| 4 | `Zone Khashuri` |
| 5 | `Zone Gori` |
| 6 | `Zone Tbilisi`, `Zone Soganlug`, `Zone Vaziani` |

Blau kann nur Zonen der aktuellen Phase erobern. Rot kann jede Zone zurückerobern. Sind alle Zonen blau, wird das Flag `OstwindSieg` auf 1 gesetzt.

## Carrier Strike Group

Gesteuert von MOOSE AIRBOSS. Der Träger fährt seine Route aus dem Editor in Schleife und dreht sich **nicht** selbständig in den Wind. Wind über Deck ergibt sich also nur aus der Route, die du im Editor legst. Das Deck ist standardmäßig die ganze Mission offen. Feste Zeitfenster stellst du in `01_Config.lua` unter `Carrier.Recovery.Windows` ein.

### Im Editor anlegen

| Name | Was | Hinweis |
| --- | --- | --- |
| `CVN-75 Truman` | Träger-**Einheit** | Unterstützter Typ, zum Beispiel CVN-71 bis 75 oder Stennis. Route mit mehreren Wegpunkten. |
| `BLUE_TPL_CVN_Tanker` | S-3B Tanker | Spät aktiviert, auf dem Träger. Rufzeichen hier festlegen. |
| `BLUE_TPL_CVN_AWACS` | E-2D | Spät aktiviert, auf dem Träger. Rufzeichen hier festlegen. |
| `BLUE_TPL_CVN_Helo` | SH-60B | Spät aktiviert, auf dem Träger |
| `BLUE_TPL_CVN_RAT_Hornet` | F/A-18C | Spät aktiviert, beliebiger Ort. Vorlage für Zufallsflüge. |
| `BLUE_TPL_CVN_RAT_Hawkeye` | E-2D | Spät aktiviert, beliebiger Ort. Vorlage für Zufallsflüge. |

Fehlt eine Vorlage, läuft der Rest trotzdem. Das `dcs.log` nennt die fehlenden Namen.

### Funk und Navigation (Standard)

| Wer | Frequenz | TACAN / ICLS |
| --- | --- | --- |
| Marshal | 305.0 AM | TACAN 75X TRU, ICLS 5 |
| LSO | 264.0 AM | |
| Tanker | 261.0 AM | TACAN 37Y ARC |
| AWACS | 262.0 AM | |

### Sprachdateien in die .miz packen

AIRBOSS spielt den Funkverkehr aus Sprachdateien ab. Sie liegen in `mission/sounds/Airboss Soundfiles/` und müssen in die `.miz`:

```bash
python tools/pack_sounds.py mission/Operation_Ostwind.miz
```

Das Skript legt vorher eine Sicherung `.miz.bak` an und kann beliebig oft laufen. Nach jedem Speichern im Missionseditor prüfen, ob der Ordner `Airboss Soundfiles` noch in der `.miz` ist, und das Skript sonst erneut ausführen.

Die Sprachdateien stammen aus [MOOSE_SOUND](https://github.com/FlightControl-Master/MOOSE_SOUND) und stehen unter GPL-3.0.

## Einbinden im Missionseditor

Trigger "Mission Start" mit zwei Aktionen "DO SCRIPT FILE":

1. `00_Moose.lua`
2. **Entwickeln:** `00_Loader.lua`. Den Pfad darin anpassen. Änderungen an den Skripten greifen dann beim nächsten Missionsstart ohne neues Einbinden.

**Fertige Version:** statt des Loaders alle Skripte ab `01_Config.lua` einzeln in der Reihenfolge der Nummern einbinden.

## Stand

| Skript | Stand |
| --- | --- |
| 00_Loader.lua | fertig |
| 01_Config.lua | fertig |
| 02_Persistence.lua | fertig |
| 03_Zones.lua | fertig |
| 04_Scaling.lua | fertig |
| 07_Carrier.lua | fertig |
| tools/pack_sounds.py | fertig |
| übrige | offen |
