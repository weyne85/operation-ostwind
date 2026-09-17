--[[
  Operation Ostwind - 02_Persistence.lua

  Lädt den Spielstand beim Start und schreibt ihn auf Anforderung.
  Dieses Skript entscheidet nicht, WANN gespeichert wird. Das macht 09_Save.lua.

  Andere Skripte nutzen:
    OSTWIND.Persistence:IsEnabled()        -> true, wenn gespeichert werden kann
    OSTWIND.Persistence:IsNewCampaign()    -> true, wenn kein Spielstand geladen wurde
    OSTWIND.Persistence:Get(Key)           -> geladene Daten eines Moduls oder nil
    OSTWIND.Persistence:Register(Key, Fn)  -> Fn() liefert beim Speichern die Daten
                                              des Moduls als Tabelle
    OSTWIND.Persistence:Save()             -> alle Module abfragen und schreiben

  Beispiel in einem Modul:
    local Saved = OSTWIND.Persistence:Get("Zones")
    if Saved then ... Zustand wiederherstellen ... end
    OSTWIND.Persistence:Register("Zones", function()
      return { Kutaisi = "blue" }
    end)

  Erlaubt in den Daten: Tabellen, Strings, Zahlen, Booleans.
  Nicht erlaubt: Funktionen, MOOSE-Objekte, Verweise im Kreis.

  Dateien im Speicherordner:
    Ostwind.sav.lua           aktueller Spielstand
    Ostwind.sav.lua.bak       vorheriger Spielstand (Rückfall bei defekter Datei)
    Ostwind.sav.lua.v<N>.bak  Stand einer alten SchemaVersion
    Ostwind.sav.lua.reset.bak Stand vor einem Reset

  Benötigt: 01_Config.lua, freigegebene Module 'io' und 'lfs'
]]

local Cfg = OSTWIND.Config.Save

local Persistence = {
  Enabled   = false,
  Path      = nil,     -- voller Pfad zur Spielstand-Datei
  Data      = {},      -- geladene Moduldaten, Schlüssel = Modulname
  Meta      = nil,     -- geladene Metadaten
  New       = true,    -- kein Spielstand geladen
  Providers = {},      -- Schlüssel = Modulname, Wert = Funktion
  Order     = {},      -- Reihenfolge der Registrierung
  SaveCount = 0,
}

---------------------------------------------------------------------------
-- Serialisieren
---------------------------------------------------------------------------

local function SortKeys(A, B)
  local TA, TB = type(A), type(B)
  if TA ~= TB then
    return TA < TB
  end
  return A < B
end

local function SerializeValue(Value, Indent, Seen, PathName)
  local T = type(Value)

  if T == "string" then
    return string.format("%q", Value)

  elseif T == "number" then
    if Value ~= Value or Value == math.huge or Value == -math.huge then
      error("Ungültige Zahl unter " .. PathName)
    end
    -- %d nur im 32-Bit-Bereich, unter Windows ist "long" 32 Bit breit
    if Value == math.floor(Value) and math.abs(Value) < 2^31 then
      return string.format("%d", Value)
    end
    return string.format("%.17g", Value)

  elseif T == "boolean" then
    return tostring(Value)

  elseif T == "table" then
    if Seen[Value] then
      error("Verweis im Kreis unter " .. PathName)
    end
    Seen[Value] = true

    local Keys = {}
    for K in pairs(Value) do
      local KT = type(K)
      if KT ~= "string" and KT ~= "number" then
        error("Ungültiger Schlüsseltyp " .. KT .. " unter " .. PathName)
      end
      Keys[#Keys + 1] = K
    end
    table.sort(Keys, SortKeys)

    if #Keys == 0 then
      Seen[Value] = nil
      return "{}"
    end

    local Inner = Indent .. "  "
    local Lines = { "{" }
    for _, K in ipairs(Keys) do
      local KeyText
      if type(K) == "string" and K:match("^[%a_][%w_]*$") then
        KeyText = K
      elseif type(K) == "string" then
        KeyText = "[" .. string.format("%q", K) .. "]"
      else
        KeyText = "[" .. SerializeValue(K, Inner, Seen, PathName) .. "]"
      end
      local Sub = SerializeValue(Value[K], Inner, Seen, PathName .. "." .. tostring(K))
      Lines[#Lines + 1] = Inner .. KeyText .. " = " .. Sub .. ","
    end
    Lines[#Lines + 1] = Indent .. "}"

    Seen[Value] = nil
    return table.concat(Lines, "\n")
  end

  error("Nicht speicherbarer Typ " .. T .. " unter " .. PathName)
end

local function Serialize(Tbl)
  return "return " .. SerializeValue(Tbl, "", {}, "Spielstand") .. "\n"
end

---------------------------------------------------------------------------
-- Dateien
---------------------------------------------------------------------------

local function ReadFile(Path)
  local F = io.open(Path, "rb")
  if not F then
    return nil
  end
  local Content = F:read("*a")
  F:close()
  return Content
end

local function WriteFile(Path, Content)
  local F, Err = io.open(Path, "wb")
  if not F then
    return false, Err
  end
  local Ok, WErr = F:write(Content)
  F:close()
  if not Ok then
    return false, WErr
  end
  return true
end

local function CopyFile(From, To)
  local Content = ReadFile(From)
  if not Content then
    return false
  end
  return WriteFile(To, Content)
end

-- Legt alle Ordner eines relativen Pfads unter Base an
local function MakeDirs(Base, Relative)
  local Current = Base
  for Part in Relative:gmatch("[^/\\]+") do
    Current = Current .. Part .. "\\"
    if not lfs.attributes(Current) then
      lfs.mkdir(Current)
    end
  end
  return Current
end

-- Lädt eine Spielstand-Datei in einer leeren Umgebung.
-- So kann die Datei keine Funktionen der Mission aufrufen.
local function LoadStateFile(Path)
  local Content = ReadFile(Path)
  if not Content then
    return nil, "nicht vorhanden"
  end

  local Chunk, Err = loadstring(Content, "=" .. Path)
  if not Chunk then
    return nil, "Syntaxfehler: " .. tostring(Err)
  end
  setfenv(Chunk, {})

  local Ok, Result = pcall(Chunk)
  if not Ok then
    return nil, "Fehler beim Ausführen: " .. tostring(Result)
  end
  if type(Result) ~= "table" or type(Result.Meta) ~= "table" or type(Result.Modules) ~= "table" then
    return nil, "unbekannter Aufbau"
  end
  return Result
end

---------------------------------------------------------------------------
-- Öffentliche Funktionen
---------------------------------------------------------------------------

function Persistence:IsEnabled()
  return self.Enabled
end

function Persistence:IsNewCampaign()
  return self.New
end

function Persistence:Get(Key)
  return self.Data[Key]
end

function Persistence:Register(Key, Fn)
  if type(Fn) ~= "function" then
    env.error("[Ostwind] Persistence:Register(" .. tostring(Key) .. "): keine Funktion")
    return
  end
  if not self.Providers[Key] then
    self.Order[#self.Order + 1] = Key
  end
  self.Providers[Key] = Fn
  OSTWIND.Debug("Persistence: Modul registriert: " .. tostring(Key))
end

function Persistence:Save()
  if not self.Enabled then
    return false
  end

  local Modules = {}
  for _, Key in ipairs(self.Order) do
    local Ok, Result = pcall(self.Providers[Key])
    if Ok and type(Result) == "table" then
      Modules[Key] = Result
    elseif Ok then
      env.error("[Ostwind] Speichern: Modul " .. Key .. " liefert keine Tabelle")
    else
      env.error("[Ostwind] Speichern: Modul " .. Key .. " fehlerhaft: " .. tostring(Result))
    end
    -- Bei einem Fehler bleiben die zuletzt geladenen Daten des Moduls erhalten,
    -- damit ein einzelner Fehler keinen Fortschritt löscht.
    if Modules[Key] == nil and self.Data[Key] ~= nil then
      Modules[Key] = self.Data[Key]
    end
  end

  self.SaveCount = self.SaveCount + 1
  local State = {
    Meta = {
      SchemaVersion = Cfg.SchemaVersion,
      MissionVersion = OSTWIND.Version,
      SaveCount = self.SaveCount,
      MissionTime = math.floor(timer.getAbsTime()),
      RealTime = (os and os.date) and os.date("%Y-%m-%d %H:%M:%S") or nil,
    },
    Modules = Modules,
  }

  local Ok, Text = pcall(Serialize, State)
  if not Ok then
    env.error("[Ostwind] Speichern abgebrochen: " .. tostring(Text), true)
    return false
  end

  -- Vorherigen Stand sichern, dann neu schreiben.
  -- Nur sichern, wenn er lesbar ist. Sonst würde eine defekte Datei
  -- die letzte gute Sicherung überschreiben.
  if lfs.attributes(self.Path) and LoadStateFile(self.Path) then
    CopyFile(self.Path, self.Path .. ".bak")
  end

  local Written, Err = WriteFile(self.Path, Text)
  if not Written then
    env.error("[Ostwind] Speichern fehlgeschlagen: " .. tostring(Err), true)
    return false
  end

  -- Aktuellen Stand merken, als Rückfall für fehlerhafte Module
  self.Data = Modules
  OSTWIND.Log(string.format("Gespeichert (#%d, %d Module)", self.SaveCount, #self.Order))
  return true
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not Cfg.Enabled then
    OSTWIND.Log("Speichern ist in der Config abgeschaltet")
    return
  end
  if not io or not lfs then
    env.error("[Ostwind] Speichern nicht möglich: 'io' oder 'lfs' gesperrt. "
      .. "MissionScripting.lua anpassen.", true)
    return
  end

  local Folder = MakeDirs(lfs.writedir(), Cfg.Folder)
  Persistence.Path = Folder .. Cfg.FileName
  Persistence.Enabled = true
  OSTWIND.Log("Spielstand-Datei: " .. Persistence.Path)

  local Exists = lfs.attributes(Persistence.Path) ~= nil

  if Cfg.Reset then
    if Exists then
      CopyFile(Persistence.Path, Persistence.Path .. ".reset.bak")
      -- Alten Stand sofort durch einen leeren ersetzen. Sonst würde ihn das
      -- nächste Speichern als .bak sichern und er könnte als Rückfall
      -- wieder geladen werden.
      WriteFile(Persistence.Path, Serialize({
        Meta = { SchemaVersion = Cfg.SchemaVersion, SaveCount = 0 },
        Modules = {},
      }))
      CopyFile(Persistence.Path, Persistence.Path .. ".bak")
    end
    OSTWIND.Log("Reset aktiv: neue Kampagne. In der Config wieder auf false setzen.")
    trigger.action.outText("[Ostwind] Reset aktiv: neue Kampagne gestartet.", 20)
    return
  end

  if not Exists then
    OSTWIND.Log("Kein Spielstand gefunden: neue Kampagne")
    return
  end

  local State, Err = LoadStateFile(Persistence.Path)
  if not State then
    env.error("[Ostwind] Spielstand defekt (" .. Err .. "), versuche Sicherung", true)
    State, Err = LoadStateFile(Persistence.Path .. ".bak")
    if not State then
      env.error("[Ostwind] Sicherung auch unbrauchbar (" .. Err .. "): neue Kampagne", true)
      CopyFile(Persistence.Path, Persistence.Path .. ".defekt.bak")
      return
    end
  end

  if State.Meta.SchemaVersion ~= Cfg.SchemaVersion then
    local Old = tostring(State.Meta.SchemaVersion)
    CopyFile(Persistence.Path, Persistence.Path .. ".v" .. Old .. ".bak")
    OSTWIND.Log("Spielstand hat SchemaVersion " .. Old .. ", erwartet "
      .. Cfg.SchemaVersion .. ": neue Kampagne, alter Stand gesichert")
    trigger.action.outText("[Ostwind] Alter Spielstand passt nicht mehr: neue Kampagne.", 20)
    return
  end

  Persistence.Data = State.Modules
  Persistence.Meta = State.Meta
  Persistence.SaveCount = tonumber(State.Meta.SaveCount) or 0
  Persistence.New = false

  local Count = 0
  for _ in pairs(State.Modules) do
    Count = Count + 1
  end
  OSTWIND.Log(string.format("Spielstand geladen: #%d, %d Module, gespeichert %s",
    Persistence.SaveCount, Count, tostring(State.Meta.RealTime or "unbekannt")))
end

OSTWIND.Persistence = Persistence

local Ok, Err = pcall(Init)
if not Ok then
  Persistence.Enabled = false
  env.error("[Ostwind] Persistence-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Persistence geladen")
