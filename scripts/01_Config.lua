--[[
  Operation Ostwind - 01_Config.lua

  Alle Einstellungen der Mission an einer Stelle.
  Andere Skripte lesen nur aus OSTWIND.Config und ändern hier nichts.
]]

OSTWIND = OSTWIND or {}

OSTWIND.Version = "0.1.0"

OSTWIND.Config = {

  -- Allgemein ---------------------------------------------------------------

  Debug = true,               -- Zusätzliche Log- und Bildschirmmeldungen

  -- Speichern ---------------------------------------------------------------

  Save = {
    Enabled  = true,
    Interval = 300,           -- Sekunden zwischen automatischen Speicherungen
    -- Ordner unter "Saved Games/DCS/". Wird in 02_Persistence.lua angelegt.
    Folder   = "Missions/Saves/Operation Ostwind/",
    FileName = "Ostwind.sav.lua",
    -- Erhöhen, wenn sich der Aufbau des Spielstands so ändert, dass alte
    -- Spielstände nicht mehr passen. Alte Stände werden dann gesichert
    -- und die Kampagne beginnt neu.
    SchemaVersion = 1,
    -- true: Spielstand beim nächsten Start ignorieren und neu beginnen.
    -- Der alte Stand wird als .reset.bak gesichert. Danach wieder auf false.
    Reset = false,
  },

  -- Flugplätze --------------------------------------------------------------
  -- Namen exakt wie in DCS.

  Airbases = {
    Blue = { "Batumi", "Kobuleti", "Senaki-Kolkhi" },
    Red  = { "Kutaisi", "Tbilisi-Lochini", "Soganlug", "Vaziani" },
  },

  -- Frontverlauf ------------------------------------------------------------
  -- Jede Zone muss im Editor als Trigger-Zone mit genau diesem Namen existieren.
  -- Phase 0 gehört zu Beginn Blau, alle anderen Rot.
  -- Die Phasen folgen der Hauptstraße von West nach Ost. Zonen einer Phase
  -- können gleichzeitig angegriffen werden.

  Phases = {
    [0] = { "Zone Batumi", "Zone Kobuleti", "Zone Senaki" },
    [1] = { "Zone Kutaisi" },
    [2] = { "Zone Zestafoni" },
    [3] = { "Zone Rikoti" },       -- Rikoti-Pass bei Kharagauli
    [4] = { "Zone Khashuri" },
    [5] = { "Zone Gori" },
    [6] = { "Zone Tbilisi", "Zone Soganlug", "Zone Vaziani" },
  },

  -- Eroberung der Zonen ------------------------------------------------------
  -- Eine Zone wechselt den Besitzer, wenn keine Bodeneinheiten des Besitzers
  -- mehr drin sind und mindestens CaptureUnits Einheiten der anderen Seite.

  Zones = {
    ScanInterval  = 30,       -- Sekunden zwischen zwei Prüfungen je Zone
    CaptureUnits  = 2,        -- Mindestzahl Bodeneinheiten zum Erobern
    CaptureTime   = 60,       -- So viele Sekunden muss die Lage bestehen
    CountStatics  = false,    -- true: auch statische Objekte halten eine Zone
    Draw          = true,     -- Zonen farbig auf der F10-Karte zeichnen
    Mark          = true,     -- Markierung mit Status auf der F10-Karte
    Messages      = true,     -- Meldungen an Blau bei Eroberung und Angriff
    VictoryFlag   = "OstwindSieg", -- Wird 1, wenn alle Zonen blau sind
  },

  -- Carrier Strike Group (AIRBOSS) ------------------------------------------
  -- Alle Namen müssen im Editor exakt so existieren.
  -- Der Träger fährt immer seine Route aus dem Editor. Er dreht sich
  -- NICHT selbständig in den Wind. Das ist fest in 07_Carrier.lua eingebaut.
  -- Rufzeichen von Tanker und AWACS kommen aus der Vorlage im Editor.

  Carrier = {
    Enabled     = true,
    UnitName    = "CVN-75 Truman",        -- Name der Träger-EINHEIT (nicht der Gruppe)
    Alias       = "Truman",
    SoundFolder = "Airboss Soundfiles/",  -- Ordner in der .miz, siehe README
    Skill       = "NORMAL",               -- EASY, NORMAL oder HARD (Bewertung der Landungen)
    SaveGrades  = true,                   -- LSO-Noten im Speicherordner sichern

    MarshalRadio = { Freq = 305.0, Mod = "AM" },
    LSORadio     = { Freq = 264.0, Mod = "AM" },
    TACAN        = { Channel = 75, Mode = "X", Morse = "TRU" },
    ICLS         = { Channel = 5, Morse = "TRU" },

    Recovery = {
      -- Leere Liste: Das Deck ist die ganze Mission über für Landungen offen.
      -- Sonst Zeitfenster nach Uhrzeit der Mission, zum Beispiel:
      --   { Start = "08:00", Stop = "12:00", Case = 1 },
      --   { Start = "20:00", Stop = "23:00", Case = 3 },
      Windows = {},
      Case    = 1,          -- Case für das durchgehende Fenster (1, 2 oder 3)
      Offset  = 0,          -- Versatz der Warteschleife bei Case 2 und 3 in Grad
    },

    Tanker = {
      Enabled  = true,
      Template = "BLUE_TPL_CVN_Tanker",   -- S-3B Tanker, spät aktiviert, auf dem Träger
      Freq     = 261.0,
      TACAN    = { Channel = 37, Mode = "Y", Morse = "ARC" },
      Altitude = 6000,                    -- Fuß
      Speed    = 274,                     -- Knoten
      Modex    = 701,
    },

    AWACS = {
      Enabled  = true,
      Template = "BLUE_TPL_CVN_AWACS",    -- E-2D, spät aktiviert, auf dem Träger
      Freq     = 262.0,
      Altitude = 25000,                   -- Fuß
      Speed    = 300,                     -- Knoten
      Distance = { Bow = 30, Stern = 5 }, -- Rennbahn vor und hinter dem Träger in NM
      Modex    = 600,
    },

    Helo = {
      Enabled  = true,
      Template = "BLUE_TPL_CVN_Helo",     -- SH-60B, spät aktiviert, auf dem Träger
      Modex    = 42,
    },

    -- Zufällige KI-Flüge von und zum Träger (MOOSE RAT)
    RandomFlights = {
      Enabled   = true,
      -- Spät aktivierte Flugzeuggruppen, die auf dem Träger landen können,
      -- zum Beispiel F/A-18C, E-2D oder S-3B. Jede Vorlage wird genutzt.
      Templates = { "BLUE_TPL_CVN_RAT_Hornet", "BLUE_TPL_CVN_RAT_Hawkeye" },
      -- Anflüge: starten in der Luft bei diesen Flugplätzen und landen auf dem Träger
      Inbound   = { PerTemplate = 1, From = { "Batumi", "Kobuleti" }, Takeoff = "air" },
      -- Abflüge: starten vom Träger und landen an Land
      Outbound  = { PerTemplate = 1, To = { "Batumi", "Kobuleti", "Senaki-Kolkhi" }, Takeoff = "hot" },
      SpawnDelay    = 120,  -- Sekunden bis zum ersten Flug
      SpawnInterval = 300,  -- Sekunden zwischen zwei Flügen
    },
  },

  -- Schwierigkeit nach Spielerzahl ------------------------------------------
  -- Die erste Stufe, deren MaxPlayers >= Spielerzahl ist, gilt.
  -- RedFactor und BlueFactor skalieren neue Spawns (1.0 = Grundwert).

  Scaling = {
    CheckInterval = 60,       -- Sekunden zwischen zwei Zählungen
    StableChecks  = 2,        -- So oft muss eine neue Stufe hintereinander
                              -- gemessen werden, bevor sie gilt
    Tiers = {
      { Name = "Niedrig", MaxPlayers = 1,    RedFactor = 0.6, BlueFactor = 1.4 },
      { Name = "Mittel",  MaxPlayers = 3,    RedFactor = 1.0, BlueFactor = 1.0 },
      { Name = "Hoch",    MaxPlayers = 9999, RedFactor = 1.4, BlueFactor = 0.6 },
    },
  },

  -- Vorlagen ----------------------------------------------------------------
  -- Spät aktivierte Gruppen im Editor. Namen beginnen mit diesen Präfixen.

  Templates = {
    RedPrefix  = "RED_TPL_",
    BluePrefix = "BLUE_TPL_",
  },

  -- Spieler-Slots -----------------------------------------------------------
  -- Client-Slots im Editor. Gruppennamen beginnen mit diesem Präfix.

  Slots = {
    Prefix = "BLUE_SLOT_",
  },
}

-- Einheitliche Logs
function OSTWIND.Log(Text)
  env.info("[Ostwind] " .. tostring(Text))
end

-- Nur bei Debug = true: Log und Bildschirmmeldung
function OSTWIND.Debug(Text)
  if OSTWIND.Config.Debug then
    OSTWIND.Log("DEBUG " .. tostring(Text))
    trigger.action.outText("[Ostwind] " .. tostring(Text), 10)
  end
end

OSTWIND.Log("Config geladen, Version " .. OSTWIND.Version)
