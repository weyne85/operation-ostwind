# Operation Ostwind

Persistente, dynamische Kampagne für DCS World auf der Karte Caucasus. Blau befreit Georgien von West nach Ost, von der Küste bis Tiflis.

- Solo spielbar, optional Mehrspieler
- Schwierigkeit passt sich an die Spielerzahl an
- Truppen und Fracht mit CTLD für Chinook, Hind und Apache
- Blaue KI mit Besatzungen, AWACS, Tankern und Jägern
- Aufträge im F10-Menü: CAS, BAI, SEAD, Abfangen und ein Lagebericht
- Rot mit Besatzungen, Nachschub, Gegenangriffen, Luftabwehr und Jägern
- Carrier Strike Group mit AIRBOSS, Recovery-Tanker, AWACS, Rettungshubschrauber und Zufallsflügen
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
3. **Supercarrier-Modul** für den Träger CVN-75.
4. **Python 3** für `tools/pack_sounds.py`.

## Aufbau

```text
mission/
├── (Operation_Ostwind.miz)
└── sounds/
    ├── Airboss Soundfiles/   Sprachdateien für AIRBOSS (aus MOOSE_SOUND v1.4)
    └── LICENSE-MOOSE_SOUND   GPL-3.0
scripts/
├── 00_Moose.lua       MOOSE (nicht im Repo)
├── 00_Loader.lua      Lädt die Skripte beim Entwickeln direkt aus diesem Ordner
├── 01_Config.lua      Alle Einstellungen
├── 02_Persistence.lua Spielstand laden und speichern
├── 03_Zones.lua       Zonen und Frontverlauf
├── 04_Scaling.lua     Spieler zählen, Stufe festlegen
├── 05_Red.lua         Besatzungen, Nachschub, Gegenangriffe, Luftabwehr, Jäger
├── 06_Blue.lua        Blaue Besatzungen, AWACS, Tanker, Radar, Jäger
├── 07_Carrier.lua     Carrier Strike Group mit AIRBOSS
├── 08_CTLD.lua        Truppen und Fracht
├── 09_Tasks.lua       Aufträge im F10-Menü und Lagebericht
└── 10_Save.lua        Automatisches Speichern
tools/
└── pack_sounds.py     Packt die Sprachdateien in die .miz
```

---

## Anleitung Missionseditor

Diese Anleitung baut die Mission von Grund auf. Alle Namen müssen **exakt** so geschrieben werden wie hier, mit Groß- und Kleinschreibung, Leerzeichen und Unterstrichen. Die Skripte finden Einheiten und Zonen nur über den Namen.

Fehlt etwas, läuft die Mission trotzdem. Im `dcs.log` (`Saved Games\DCS\Logs\dcs.log`) steht dann eine Zeile mit `[Ostwind]` und dem fehlenden Namen.

### Schritt 1: Vorbereitung

1. In `MissionScripting.lua` `io` und `lfs` freigeben (siehe Voraussetzungen).
2. DCS starten. In den **Optionen** unter **Sonstiges** die Maßeinheit auf **imperial** stellen. Dann zeigt der Editor Radien in Fuß an, wie in dieser Anleitung.
3. Den Missionseditor öffnen und eine **neue Mission** auf der Karte **Caucasus** anlegen.
4. **Koalitionen:** Blau mit **USA**, Rot mit **Russland**. Andere Länder gehen auch, müssen aber zur jeweiligen Seite gehören.
5. **Datum und Wetter** nach Wunsch. Merk dir die **Windrichtung am Boden**. Du brauchst sie in Schritt 5 für die Route des Trägers.
6. Die Mission sofort speichern als `mission\Operation_Ostwind.miz` in diesem Repo.

### Schritt 2: Flugplätze einer Seite zuweisen

Klick im Editor auf einen Flugplatz und stell im Eigenschaftsfenster die Koalition ein.

| Flugplatz | Koalition | Warum |
| --- | --- | --- |
| Batumi, Kobuleti, Senaki-Kolkhi | **Blau** | Start von Blau, Ziele der Zufallsflüge |
| Kutaisi, Tbilisi-Lochini, Soganlug, Vaziani | **Rot** | Liegen in roten Zonen |
| Nalchik, Beslan, Mozdok | **Rot** | Flugplätze der roten Jäger. Ohne rote Koalition starten dort keine Abfangjäger. |

### Schritt 3: Trigger-Zonen für die Front (11 Stück)

Werkzeug: **Trigger-Zone** (Kreis). Nur Kreise verwenden, keine Vierecke.

Die Skripte erzeugen die roten Besatzungen selbst, zufällig verteilt in den inneren 70 % des Radius. Eine Zone wird erobert, wenn keine Bodeneinheit des Besitzers mehr drin ist und mindestens 2 Bodeneinheiten der anderen Seite 60 Sekunden lang darin stehen.

**Mittelpunkt** ist bei Flugplätzen die Mitte der Hauptbahn, bei Städten das Stadtzentrum. Die Lage ist ein Vorschlag. Wichtig ist nur, dass die Zone überwiegend Land abdeckt.

| Phase | Name der Zone | Mittelpunkt | Radius |
| --- | --- | --- | --- |
| 0 | `Zone Batumi` | Flugplatz Batumi | 5.000 ft |
| 0 | `Zone Kobuleti` | Flugplatz Kobuleti | 5.000 ft |
| 0 | `Zone Senaki` | Flugplatz Senaki-Kolkhi | 5.000 ft |
| 1 | `Zone Kutaisi` | Flugplatz Kutaisi | 6.500 ft |
| 2 | `Zone Zestafoni` | Stadt Zestafoni, östlich von Kutaisi | 5.000 ft |
| 3 | `Zone Rikoti` | Rikoti-Pass an der Hauptstraße zwischen Zestafoni und Khashuri, am Tunnel | 4.000 ft |
| 4 | `Zone Khashuri` | Stadt Khashuri, westlich von Gori | 5.000 ft |
| 5 | `Zone Gori` | Stadt Gori | 6.500 ft |
| 6 | `Zone Tbilisi` | Flugplatz Tbilisi-Lochini | 6.500 ft |
| 6 | `Zone Soganlug` | Flugplatz Soganlug | 4.000 ft |
| 6 | `Zone Vaziani` | Flugplatz Vaziani | 5.000 ft |

**Wichtig:** Keine eigenen roten Bodeneinheiten in diese Zonen stellen. Sie würden nach dem Laden eines Spielstands eine schon befreite Zone sofort zurückerobern.

### Schritt 4: Trigger-Zonen für Luftabwehr, Radar und Jäger (13 Stück)

Bei diesen Zonen zählt nur der **Mittelpunkt**. Dort entsteht die Stellung, mit derselben Aufstellung wie in der Vorlage. Der Radius ist egal. Nimm einen kleinen Wert, damit die Karte übersichtlich bleibt.

Stell die Stellungen auf freies, flaches Gelände, nicht in Wald oder auf Gebäude.

| Name der Zone | Mittelpunkt (Vorschlag) | Radius |
| --- | --- | --- |
| `SAM Kutaisi` | 3 bis 5 NM östlich des Flugplatzes Kutaisi | 500 ft |
| `SAM Zestafoni` | am Ostrand von Zestafoni | 500 ft |
| `SAM Rikoti` | an der Hauptstraße östlich des Passes | 500 ft |
| `SAM Khashuri` | 2 bis 3 NM östlich von Khashuri | 500 ft |
| `SAM Gori` | 3 bis 5 NM östlich von Gori | 500 ft |
| `SAM Tbilisi` | 8 bis 10 NM östlich von Tiflis (SA-10, weite Reichweite) | 500 ft |
| `SAM Vaziani` | am Flugplatz Vaziani | 500 ft |
| `EWR West` | auf einer Anhöhe nördlich von Kutaisi | 500 ft |
| `EWR Ost` | auf einer Anhöhe nördlich von Gori | 500 ft |
| `RED CAP West` | über den Bergen zwischen Kutaisi und Nalchik | 5.000 ft |
| `RED CAP Ost` | über den Bergen zwischen Gori und Beslan | 5.000 ft |
| `BLUE EWR` | auf einer Anhöhe bei Kobuleti (blaues Radar) | 500 ft |
| `BLUE CAP Front` | über der Linie Senaki und Kutaisi (blaue CAP) | 5.000 ft |

Die SAM-Stellungen verschwinden, sobald Blau die zugehörige Zone erobert. Zerstörte Stellungen kommen auch nach dem Laden nicht zurück. Eine Stellung gilt als zerstört, wenn kein Radar mehr lebt.

### Schritt 5: Carrier Strike Group

1. **Träger:** Ein Schiff auf Blau setzen, Typ **CVN-75 Harry S. Truman** (Supercarrier).
   - Gruppenname: beliebig, zum Beispiel `CSG Truman`
   - **Einheitenname: `CVN-75 Truman`** (der Name der Einheit zählt, nicht der Gruppenname)
   - **Nicht** spät aktiviert
   - Position: etwa 30 NM westlich von Batumi auf offener See
2. **Route des Trägers:** mindestens 2 Wegpunkte, Geschwindigkeit etwa 25 bis 30 Knoten.
   - Der Träger dreht sich **nicht** selbst in den Wind. Leg die Route deshalb möglichst **gegen den Wind**. Weht der Wind aus 270°, fährt der Träger Kurs 270°.
   - Am letzten Wegpunkt fährt der Träger automatisch zum ersten zurück. Lange Strecken halten ihn länger auf gutem Kurs.
   - Genug Abstand zur Küste halten, auch am Ende der Route.
3. **Begleitschiffe** nach Wunsch in dieselbe oder eine eigene Gruppe, zum Beispiel Ticonderoga und Arleigh Burke.

Dann diese **Vorlagen** anlegen. Alle auf **Blau**, alle mit Häkchen **„Späte Aktivierung“** (Late Activation). Der Einheitenname ist frei.

| Gruppenname | Typ | Anzahl | Ort und Start | Hinweis |
| --- | --- | --- | --- | --- |
| `BLUE_TPL_CVN_Tanker` | S-3B Tanker | 1 | Auf dem Träger, Start von der Parkposition | Rufzeichen hier festlegen, zum Beispiel Arco 1 |
| `BLUE_TPL_CVN_AWACS` | E-2D | 1 | Auf dem Träger, Start von der Parkposition | Rufzeichen hier festlegen, zum Beispiel Wizard 1 |
| `BLUE_TPL_CVN_Helo` | SH-60B | 1 | Auf dem Träger | |
| `BLUE_TPL_CVN_RAT_Hornet` | F/A-18C | 2 | Beliebig, zum Beispiel Batumi | Vorlage für Zufallsflüge. Bewaffnung nach Wunsch. |
| `BLUE_TPL_CVN_RAT_Hawkeye` | E-2D | 1 | Beliebig, zum Beispiel Batumi | Vorlage für Zufallsflüge |

Frequenzen und TACAN setzen die Skripte selbst (Standard):

| Wer | Frequenz | TACAN / ICLS |
| --- | --- | --- |
| Marshal | 305.0 AM | TACAN 75X TRU, ICLS 5 |
| LSO | 264.0 AM | |
| Tanker | 261.0 AM | TACAN 37Y ARC |
| AWACS | 262.0 AM | |

### Schritt 6: Blaue Vorlagen für Truppen und Fracht (6 Stück)

Diese Gruppen setzen Chinook, Hind und Apache ab. Alle auf **Blau**, alle mit **„Späte Aktivierung“**. Ort beliebig, zum Beispiel bei Batumi. Einheitennamen sind frei.

| Gruppenname | Inhalt (Vorschlag) | Menüeintrag |
| --- | --- | --- |
| `BLUE_TPL_CTLD_Infantry` | 8 × Infanterie M4 | Infanterie (8) |
| `BLUE_TPL_CTLD_ATGM` | 4 × Infanterie mit Javelin oder RPG | Panzerabwehr (4) |
| `BLUE_TPL_CTLD_Engineers` | 4 × Infanterie M4 | Pioniere (4), können Kisten bauen |
| `BLUE_TPL_CTLD_TOW` | 1 × Humvee TOW | Humvee TOW (1 Kiste) |
| `BLUE_TPL_CTLD_Avenger` | 1 × M1097 Avenger | Avenger (2 Kisten) |
| `BLUE_TPL_CTLD_Stryker` | 1 × M1126 Stryker ICV | M1126 Stryker (2 Kisten) |

Die Anzahl der Soldaten muss zur Config passen (8, 4 und 4). Eigene Ladezonen brauchst du nicht: Jede Frontzone ist Ladezone, solange sie blau ist, dazu der Träger. Die Spieler-Slots für den Transport müssen mit `BLUE_SLOT_Chinook`, `BLUE_SLOT_Hind` oder `BLUE_SLOT_Apache` beginnen (Schritt 11).

### Schritt 7: Blaue KI (9 Vorlagen, 2 Lagerhäuser)

Alle auf **Blau**, alle mit **„Späte Aktivierung“**. Einheitennamen sind frei.

**Besatzungen** für eroberte Zonen. Ort beliebig.

| Gruppenname | Inhalt (Vorschlag) |
| --- | --- |
| `BLUE_TPL_GAR_Armor` | 2 × M1A2 Abrams |
| `BLUE_TPL_GAR_IFV` | 3 × M2A2 Bradley |
| `BLUE_TPL_GAR_AD` | 1 × M1097 Avenger, 1 × M6 Linebacker |

**AWACS und Tanker von Land.** Diese Vorlagen fliegen genau so, wie du sie im Editor anlegst. Das Skript hält sie nur dauerhaft in der Luft.

| Gruppenname | Typ | Start | Route und Aufgabe |
| --- | --- | --- | --- |
| `BLUE_TPL_AWACS` | E-3A | Kobuleti, Start von der Parkposition | Aufgabe AWACS. Wegpunkt mit „Umlaufbahn“ (Orbit) über Land zwischen Kobuleti und Senaki, 30.000 ft |
| `BLUE_TPL_TANKER_Boom` | KC-135 | Kobuleti | Aufgabe Tanker, Aktion „Tanker“ und „Umlaufbahn“ westlich von Senaki, 20.000 ft. Funk, Rufzeichen und TACAN in der Vorlage setzen, zum Beispiel 251.0 AM, Texaco 1, TACAN 51X |
| `BLUE_TPL_TANKER_Probe` | KC-135MPRS | Kobuleti | wie oben, zum Beispiel 252.0 AM, Shell 1, TACAN 52X |

**Radar und Jäger.** Ort beliebig.

| Gruppenname | Typ | Anzahl |
| --- | --- | --- |
| `BLUE_TPL_EWR` | EWR AN/FPS-117 oder 1L13 | 1 |
| `BLUE_TPL_CAP_F15` | F-15C | 2 |
| `BLUE_TPL_CAP_F16` | F-16C | 2 |

**Lagerhäuser:** Auf zwei Flugplätzen ein **statisches Objekt** auf **Blau**, Typ **Lagerhaus**. Der Name muss genau wie der Flugplatz lauten: `Kobuleti` und `Senaki-Kolkhi`.

### Schritt 8: Rote Vorlagen für Bodentruppen (6 Stück)

Alle auf **Rot**, alle mit **„Späte Aktivierung“**. Ort beliebig, am besten weit weg von der Front, zum Beispiel bei Mozdok. Einheitennamen sind frei. Die Aufstellung der Einheiten in der Vorlage wird beim Erzeugen übernommen.

| Gruppenname | Inhalt (Vorschlag) | Zweck |
| --- | --- | --- |
| `RED_TPL_GAR_Armor` | 3 × T-90 | Besatzung |
| `RED_TPL_GAR_IFV` | 3 × BMP-3 | Besatzung |
| `RED_TPL_GAR_Infantry` | 1 × BTR-80, 4 × Infanterie AK-74 | Besatzung |
| `RED_TPL_GAR_AAA` | 2 × ZSU-23-4 Shilka, 1 × 2S6 Tunguska | Besatzung mit Nahbereichsabwehr |
| `RED_TPL_ATK_Armor` | 4 × T-72B | Gegenangriff |
| `RED_TPL_ATK_Mech` | 2 × BMP-3, 2 × BTR-80 | Gegenangriff |

### Schritt 9: Rote Vorlagen für Luftabwehr und Radar (6 Stück)

Alle auf **Rot**, alle mit **„Späte Aktivierung“**. Ort beliebig. Stell die Einheiten innerhalb der Gruppe so auf, wie die Stellung später aussehen soll, zum Beispiel Radar in der Mitte und Starter im Kreis darum. Tipp: Der Editor bietet für viele Stellungen fertige Gruppen-Vorlagen an.

| Gruppenname | Inhalt (Vorschlag) |
| --- | --- |
| `RED_TPL_SAM_SA10` | SA-10: 1 × Suchradar Big Bird, 1 × Suchradar Clam Shell, 1 × Feuerleitradar Flap Lid, 1 × Gefechtsstand, 4 × Starter |
| `RED_TPL_SAM_SA11` | SA-11: 1 × Suchradar Snow Drift, 1 × Gefechtsstand, 4 × Starter |
| `RED_TPL_SAM_SA6` | SA-6: 1 × Radar Straight Flush, 3 × Starter |
| `RED_TPL_SAM_SA8` | 2 × SA-8 Osa |
| `RED_TPL_SAM_SA15` | 2 × SA-15 Tor |
| `RED_TPL_EWR` | 1 × EWR 1L13 oder 55G6 |

MANTIS erkennt den Typ der Stellung selbst an den Einheiten. Wichtig ist nur, dass jede Stellung mindestens ein Radar hat.

### Schritt 10: Rote Jäger

**Lagerhäuser:** Auf jedem der drei Flugplätze ein **statisches Objekt** auf **Rot** platzieren, Kategorie Gebäude, Typ **Lagerhaus** (Warehouse). Der Name muss genau wie der Flugplatz lauten:

| Name des statischen Objekts | Ort |
| --- | --- |
| `Nalchik` | Flugplatz Nalchik |
| `Beslan` | Flugplatz Beslan |
| `Mozdok` | Flugplatz Mozdok |

**Vorlagen:** Alle auf **Rot**, alle mit **„Späte Aktivierung“**, Ort beliebig. Bewaffnung für Luftkampf einstellen.

| Gruppenname | Typ | Anzahl |
| --- | --- | --- |
| `RED_TPL_CAP_MiG29` | MiG-29S | 2 |
| `RED_TPL_CAP_Su27` | Su-27 | 2 |
| `RED_TPL_GCI_MiG31` | MiG-31 | 2 |

### Schritt 11: Spieler-Slots

Für jedes Muster eine Gruppe auf **Blau**, Fähigkeit **Client**. Name mit dem Präfix `BLUE_SLOT_`. Nicht spät aktiviert.

| Gruppenname (Vorschlag) | Typ | Ort |
| --- | --- | --- |
| `BLUE_SLOT_Hornet 1` | F/A-18C | Träger CVN-75 |
| `BLUE_SLOT_Viper 1` | F-16C | Kobuleti |
| `BLUE_SLOT_Hog 1` | A-10C II | Kobuleti |
| `BLUE_SLOT_Apache 1` | AH-64D | Senaki-Kolkhi |
| `BLUE_SLOT_Chinook 1` | CH-47F | Senaki-Kolkhi |
| `BLUE_SLOT_Hind 1` | Mi-24P | Senaki-Kolkhi |

Für mehrere Spieler weitere Gruppen anlegen, zum Beispiel `BLUE_SLOT_Hornet 2`. Alle Gruppen mit `BLUE_SLOT_` am Anfang bekommen die Auftragsmenüs. Nur Gruppen mit `BLUE_SLOT_Chinook`, `BLUE_SLOT_Hind` oder `BLUE_SLOT_Apache` am Anfang bekommen das CTLD-Menü.

### Schritt 12: Skripte einbinden

1. Neuer Trigger, Typ **„Einmalig“** (Once), Name zum Beispiel `Ostwind Start`.
2. Bedingung: keine. Ereignis: **„Mission Start“**.
3. Aktion 1: **„DO SCRIPT FILE“** mit `scripts\00_Moose.lua`
4. Aktion 2: **„DO SCRIPT FILE“** mit `scripts\00_Loader.lua`

Der Loader lädt alle weiteren Skripte bei jedem Start direkt aus dem Repo-Ordner. Der Pfad steht oben in `00_Loader.lua` und muss zu deinem Rechner passen.

**Fertige Version für den Server:** Statt des Loaders alle Skripte ab `01_Config.lua` einzeln per „DO SCRIPT FILE“ einbinden, in der Reihenfolge der Nummern. Sonst fehlen sie auf einem anderen Rechner.

### Schritt 13: Speichern und Sprachdateien packen

1. Mission speichern und den Editor schließen.
2. Im Repo-Ordner ausführen:

   ```bash
   python tools/pack_sounds.py mission/Operation_Ostwind.miz
   ```

   Das Skript legt eine Sicherung `.miz.bak` an und packt die 110 Sprachdateien in den Ordner `Airboss Soundfiles` der Mission.
3. Nach jedem weiteren Speichern im Editor prüfen, ob der Ordner noch in der `.miz` ist. Die `.miz` ist ein Zip-Archiv und lässt sich zum Beispiel mit 7-Zip öffnen. Fehlt der Ordner, Punkt 2 wiederholen.

### Schritt 14: Erster Test

1. Mission starten und einen Slot wählen.
2. Nach dem Start erscheint: „Operation Ostwind. Aktuelles Ziel: Kutaisi“.
3. Auf der F10-Karte sind die Zonen farbig eingezeichnet.
4. Am Träger starten nach kurzer Zeit Tanker, AWACS und Hubschrauber.
5. Nach der Mission in `dcs.log` nach `[Ostwind]` suchen. Zeilen mit `ERROR` zeigen fehlende Namen oder andere Probleme.
6. Im F10-Menü gibt es „Kampagne > Lagebericht“ und „Kampagne > Stand speichern“, dazu „Aufträge Boden“ und „Aufträge Luft“. Nach dem Speichern liegt der Stand unter `Saved Games\DCS\Missions\Saves\Operation Ostwind\`.
7. Mit einem Chinook oder Hind in einer blauen Zone landen, im F10-Menü unter CTLD Truppen laden und in `Zone Kutaisi` absetzen. Sind dort keine roten Einheiten mehr, wird die Zone nach 60 Sekunden blau.

### Checkliste

| Was | Anzahl |
| --- | --- |
| Flugplätze mit Koalition | 10 |
| Trigger-Zonen Front | 11 |
| Trigger-Zonen Luftabwehr, Radar, CAP | 13 |
| Träger-Einheit `CVN-75 Truman` | 1 |
| Blaue Vorlagen Träger (spät aktiviert) | 5 |
| Blaue Vorlagen CTLD (spät aktiviert) | 6 |
| Blaue Vorlagen KI (spät aktiviert) | 9 |
| Blaue Lagerhäuser (statisch) | 2 |
| Rote Vorlagen Boden (spät aktiviert) | 6 |
| Rote Vorlagen Luftabwehr und Radar (spät aktiviert) | 6 |
| Rote Vorlagen Jäger (spät aktiviert) | 3 |
| Rote Lagerhäuser (statisch) | 3 |
| Spieler-Slots | mindestens 1 |
| Trigger mit 2 × DO SCRIPT FILE | 1 |

---

## Ablauf der Kampagne

### Front

Die aktive Phase ist die erste Phase mit einer Zone, die nicht blau ist. Blau kann nur Zonen dieser Phase erobern, alles dahinter ist gesperrt. Rot kann jede Zone zurückerobern, die Front fällt dann zurück. Sind alle Zonen blau, wird das Flag `OstwindSieg` auf 1 gesetzt.

### Rot

- **Besatzungen:** Jede rote Zone startet mit 3 Gruppen, Kutaisi und Gori mit 4, Tiflis mit 5. Die Zahl der lebenden Gruppen wird gespeichert.
- **Nachschub:** Alle 30 Minuten bekommt jede rote Frontzone eine Gruppe dazu, bis die Sollstärke erreicht ist. Zonen unter Angriff bekommen keinen Nachschub.
- **Gegenangriffe:** Etwa alle 45 Minuten rückt Rot von einer Frontzone auf die zuletzt befreite Zone vor. Blau bekommt dazu eine Meldung. Erobert Rot die Zone, bleiben die Angreifer als Besatzung dort. Die Startzonen an der Küste werden standardmäßig nicht angegriffen.
- **Luftabwehr:** MANTIS steuert alle SAM-Stellungen und Radare. Die Radare schalten sich erst bei Bedarf ein.
- **Jäger:** EASYGCICAP schickt Abfangjäger von Nalchik, Beslan und Mozdok und hält zwei CAP-Stationen besetzt.

### Schwierigkeit

| Spieler | Stufe | Faktor Rot | Faktor blaue KI |
| --- | --- | --- | --- |
| 1 | Niedrig | 0,6 | 1,4 |
| 2 bis 3 | Mittel | 1,0 | 1,0 |
| 4 und mehr | Hoch | 1,4 | 0,6 |

Der Faktor gilt für die Sollstärke beim Nachschub, für die Größe der Gegenangriffe und für die Zahl gleichzeitiger Abfangeinsätze. Die Besatzungen einer neuen Kampagne entstehen ohne Faktor, weil beim Missionsstart noch niemand im Slot sitzt.

### Blau

- **Besatzungen:** 5 Minuten nach einer Eroberung sichern 2 blaue Gruppen die Zone, mit Faktor Blau. Die zuletzt befreiten Zonen bekommen alle 30 Minuten Nachschub.
- **AWACS und Tanker:** fliegen dauerhaft ohne Treibstoffsorgen. Geht einer verloren, startet Ersatz.
- **Jäger:** EASYGCICAP schickt F-15C und F-16C von Kobuleti und Senaki gegen rote Flugzeuge.
- Blau erobert keine Zonen selbst. Das bleibt Aufgabe der Spieler.

### Aufträge

- **„Aufträge Boden“:** Besatzungen der aktuellen Zielzonen, laufende Gegenangriffe und Luftabwehrstellungen. MOOSE wählt CAS, BAI oder SEAD.
- **„Aufträge Luft“:** Abfangaufträge gegen Flugzeuge, die AWACS oder Radar sehen.
- **„Kampagne > Lagebericht“:** Phase, Ziel mit Feindstärke, befreite Zonen, Gegenangriffe, Feindaktivität und der nächste Transportauftrag.

### Truppen und Fracht

- **Laden:** in jeder blauen Frontzone und auf dem Träger, über das F10-Menü von CTLD
- **Absetzen:** Truppen, die bis zu 5 km vor der aktuellen Zielzone abgesetzt werden, laufen selbst hinein.
- **Kisten:** Fahrzeuge kommen in Kisten und werden vor Ort gebaut (3 Minuten).
- **Speichern:** Abgesetzte Truppen und gebaute Fahrzeuge speichert CTLD in `Ostwind_CTLD.csv`.

### Speichern

- alle 5 Minuten
- kurz nach jeder Eroberung und nach dem Sieg
- beim Missionsende
- über das F10-Menü „Kampagne > Stand speichern“

### Carrier Strike Group

Gesteuert von MOOSE AIRBOSS. Der Träger fährt seine Route aus dem Editor in Schleife und dreht sich **nicht** selbständig in den Wind. Das Deck ist standardmäßig die ganze Mission offen. Feste Zeitfenster stellst du in `01_Config.lua` unter `Carrier.Recovery.Windows` ein. Die LSO-Noten werden im Speicherordner gesichert.

Zufallsflüge: F/A-18C und E-2D fliegen von Batumi und Kobuleti zum Träger und vom Träger an Land.

## Spielstand

Liegt unter `Saved Games/DCS/Missions/Saves/Operation Ostwind/`:

| Datei | Inhalt |
| --- | --- |
| `Ostwind.sav.lua` | aktueller Stand |
| `Ostwind.sav.lua.bak` | vorheriger Stand, wird geladen, wenn der aktuelle defekt ist |
| `*.reset.bak`, `*.v<N>.bak`, `*.defekt.bak` | Sicherungen bei Reset, Versionswechsel oder defekter Datei |
| `Ostwind_LSO_Noten.csv` | Noten der Trägerlandungen |
| `Ostwind_CTLD.csv` | abgesetzte Truppen und gebaute Fahrzeuge |

**Neue Kampagne starten:** In `01_Config.lua` `Save.Reset = true` setzen, Mission einmal starten, danach wieder auf `false`.

## Lizenzen

Die Sprachdateien stammen aus [MOOSE_SOUND](https://github.com/FlightControl-Master/MOOSE_SOUND) und stehen unter GPL-3.0.

## Stand

| Skript | Stand |
| --- | --- |
| 00_Loader.lua | fertig |
| 01_Config.lua | fertig |
| 02_Persistence.lua | fertig |
| 03_Zones.lua | fertig |
| 04_Scaling.lua | fertig |
| 05_Red.lua | fertig |
| 07_Carrier.lua | fertig |
| 06_Blue.lua | fertig |
| 08_CTLD.lua | fertig |
| 09_Tasks.lua | fertig |
| 10_Save.lua | fertig |
| tools/pack_sounds.py | fertig |

Alle Skripte sind außerhalb von DCS mit nachgebauten DCS- und MOOSE-Funktionen getestet. Ein Test in DCS steht noch aus.
