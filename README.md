# Operation Ostwind

Persistente, dynamische Kampagne für DCS World auf der Karte Caucasus. Blau befreit Georgien von West nach Ost, von der Küste bis Tiflis.

- Solo spielbar, optional Mehrspieler
- Schwierigkeit passt sich an die Spielerzahl an
- Blaue KI unterstützt die Spieler
- Fortschritt bleibt zwischen Sessions erhalten
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
mission/              .miz-Datei
scripts/
├── 00_Moose.lua      MOOSE (nicht im Repo)
├── 00_Loader.lua     Lädt die Skripte beim Entwickeln direkt aus diesem Ordner
├── 01_Config.lua     Alle Einstellungen
├── 02_Persistence.lua
├── 03_Zones.lua
├── 04_Scaling.lua    Spieler zählen, Stufe festlegen
├── 05_Red.lua
├── 06_Blue.lua
├── 07_CTLD.lua
├── 08_Tasks.lua
└── 09_Save.lua
```

## Spielstand

Liegt unter `Saved Games/DCS/Missions/Saves/Operation Ostwind/`:

| Datei | Inhalt |
| --- | --- |
| `Ostwind.sav.lua` | aktueller Stand |
| `Ostwind.sav.lua.bak` | vorheriger Stand, wird geladen, wenn der aktuelle defekt ist |
| `*.reset.bak`, `*.v<N>.bak`, `*.defekt.bak` | Sicherungen bei Reset, Versionswechsel oder defekter Datei |

**Neue Kampagne starten:** In `01_Config.lua` `Save.Reset = true` setzen, Mission einmal starten, danach wieder auf `false`.

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
| 04_Scaling.lua | fertig |
| übrige | offen |
