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
  -- Phase 2 enthält noch Platzhalter. Namen festlegen, sobald die Zonen stehen.

  Phases = {
    [0] = { "Zone Batumi", "Zone Kobuleti", "Zone Senaki" },
    [1] = { "Zone Kutaisi" },
    [2] = { "Zone Zwischen 1", "Zone Zwischen 2" },
    [3] = { "Zone Gori" },
    [4] = { "Zone Tbilisi", "Zone Soganlug", "Zone Vaziani" },
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
