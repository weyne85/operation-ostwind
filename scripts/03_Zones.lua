--[[
  Operation Ostwind - 03_Zones.lua

  Verwaltet die eroberbaren Zonen und den Frontverlauf.

  Regeln:
    - Die aktive Phase ist die niedrigste Phase (ab 1), in der noch eine
      Zone nicht blau ist. Ihre Zonen bilden die Front.
    - Blau kann nur Zonen der aktiven Phase oder davor erobern.
      Zonen hinter der Front sind gesperrt.
    - Rot kann jede Zone zurückerobern. Die Front wandert dann zurück.
    - Sind alle Zonen blau, ist die Kampagne gewonnen.

  Wichtig für spätere Skripte:
    Der Besitzer wird aus dem Spielstand geladen. Rote Besatzungen dürfen
    deshalb nicht fest im Editor stehen, sondern müssen von 05_Red.lua
    passend zum Besitzer erzeugt werden. Sonst erobert eine im Editor
    platzierte rote Einheit eine gespeicherte blaue Zone sofort zurück.
    Für erste Tests einer neuen Kampagne sind Editor-Einheiten in Ordnung.

  Andere Skripte nutzen:
    OSTWIND.Zones:GetOwner(Name)        -> coalition.side.* oder nil
    OSTWIND.Zones:GetOpsZone(Name)      -> MOOSE OPSZONE oder nil
    OSTWIND.Zones:GetPhase(Name)        -> Phasennummer oder nil
    OSTWIND.Zones:GetActivePhase()      -> Nummer oder nil nach dem Sieg
    OSTWIND.Zones:GetFrontZones()       -> Liste der Namen in der aktiven Phase
    OSTWIND.Zones:GetZonesByOwner(Side) -> Liste der Namen
    OSTWIND.Zones:GetAllZones()         -> Liste aller Namen in Phasenreihenfolge
    OSTWIND.Zones:IsLocked(Name)        -> true, wenn Blau sie noch nicht erobern darf
    OSTWIND.Zones:IsVictory()           -> true nach dem Sieg
    OSTWIND.Zones:On(Event, Func)       -> Ereignis abonnieren:
        "Captured"      Func(Name, NewOwner, OldOwner)
        "Attacked"      Func(Name, AttackerSide)
        "Defended"      Func(Name, AttackerSide)
        "PhaseChanged"  Func(NewPhase, OldPhase)   NewPhase ist nil nach dem Sieg
        "Victory"       Func()

  Speichert unter dem Schlüssel "Zones".

  Benötigt: 01_Config.lua, 02_Persistence.lua, MOOSE (OPSZONE, ZONE, MESSAGE)
]]

local Cfg     = OSTWIND.Config
local ZoneCfg = Cfg.Zones
local BLUE    = coalition.side.BLUE
local RED     = coalition.side.RED

local Zones = {
  Ops         = {},   -- Name -> OPSZONE
  PhaseOf     = {},   -- Name -> Phase
  Order       = {},   -- alle Namen in Phasenreihenfolge
  MaxPhase    = 0,
  ActivePhase = nil,
  Victory     = false,
  Listeners   = { Captured = {}, Attacked = {}, Defended = {}, PhaseChanged = {}, Victory = {} },
}

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------

local SideName = {
  [coalition.side.NEUTRAL] = "neutral",
  [RED]  = "rot",
  [BLUE] = "blau",
}

-- "Zone Kutaisi" -> "Kutaisi"
local function ShortName(Name)
  return (Name:gsub("^Zone%s+", ""))
end

local function ToBlue(Text, Seconds)
  if ZoneCfg.Messages then
    MESSAGE:New(Text, Seconds or 15):ToBlue()
  end
end

function Zones:_Fire(Event, ...)
  for _, Func in ipairs(self.Listeners[Event]) do
    local Ok, Err = pcall(Func, ...)
    if not Ok then
      env.error("[Ostwind] Zones-Listener " .. Event .. ": " .. tostring(Err))
    end
  end
end

---------------------------------------------------------------------------
-- Abfragen
---------------------------------------------------------------------------

function Zones:On(Event, Func)
  if not self.Listeners[Event] then
    env.error("[Ostwind] Zones:On: unbekanntes Ereignis " .. tostring(Event))
    return
  end
  table.insert(self.Listeners[Event], Func)
end

function Zones:GetOpsZone(Name)
  return self.Ops[Name]
end

function Zones:GetOwner(Name)
  local Ops = self.Ops[Name]
  return Ops and Ops:GetOwner() or nil
end

function Zones:GetPhase(Name)
  return self.PhaseOf[Name]
end

function Zones:GetActivePhase()
  return self.ActivePhase
end

function Zones:IsVictory()
  return self.Victory
end

function Zones:GetAllZones()
  local List = {}
  for i, Name in ipairs(self.Order) do
    List[i] = Name
  end
  return List
end

function Zones:GetZonesByOwner(Side)
  local List = {}
  for _, Name in ipairs(self.Order) do
    if self:GetOwner(Name) == Side then
      List[#List + 1] = Name
    end
  end
  return List
end

function Zones:GetFrontZones()
  local List = {}
  if self.ActivePhase then
    for _, Name in ipairs(self.Order) do
      if self.PhaseOf[Name] == self.ActivePhase then
        List[#List + 1] = Name
      end
    end
  end
  return List
end

function Zones:IsLocked(Name)
  local Phase = self.PhaseOf[Name]
  if not Phase or not self.ActivePhase then
    return false
  end
  return Phase > self.ActivePhase
end

---------------------------------------------------------------------------
-- Front berechnen
---------------------------------------------------------------------------

local function ComputeActivePhase()
  for Phase = 1, Zones.MaxPhase do
    for _, Name in ipairs(Zones.Order) do
      if Zones.PhaseOf[Name] == Phase and Zones:GetOwner(Name) ~= BLUE then
        return Phase
      end
    end
  end
  return nil
end

function Zones:_UpdateFront(Announce)
  local Old = self.ActivePhase
  local New = ComputeActivePhase()
  self.ActivePhase = New

  if New == Old then
    return
  end

  if New then
    local Names = {}
    for i, Name in ipairs(self:GetFrontZones()) do
      Names[i] = ShortName(Name)
    end
    OSTWIND.Log(string.format("Aktive Phase: %d (%s)", New, table.concat(Names, ", ")))
    if Announce then
      if Old and New < Old then
        ToBlue("Rückschlag: Die Front ist zurückgefallen. Ziel: " .. table.concat(Names, ", "), 20)
      else
        ToBlue("Neues Ziel: " .. table.concat(Names, ", "), 20)
      end
    end
  end

  self:_Fire("PhaseChanged", New, Old)

  if not New and not self.Victory and #self.Order > 0 then
    self.Victory = true
    OSTWIND.Log("Alle Zonen blau: Kampagne gewonnen")
    trigger.action.setUserFlag(ZoneCfg.VictoryFlag, 1)
    ToBlue("Operation Ostwind erfolgreich. Georgien ist befreit.", 60)
    self:_Fire("Victory")
  end
end

---------------------------------------------------------------------------
-- Zonen anlegen
---------------------------------------------------------------------------

function Zones:_Create(Name, Phase, Owner)
  if not ZONE:FindByName(Name) then
    env.error("[Ostwind] Trigger-Zone fehlt im Editor: " .. Name)
    return
  end

  local Ops = OPSZONE:New(Name, Owner)
  if not Ops then
    env.error("[Ostwind] OPSZONE konnte nicht angelegt werden: " .. Name)
    return
  end

  Ops.UpdateSeconds = ZoneCfg.ScanInterval
  Ops:SetCaptureNunits(ZoneCfg.CaptureUnits)
  Ops:SetCaptureTime(ZoneCfg.CaptureTime)
  Ops:SetCaptureThreatlevel(0)
  Ops:SetUnitCategories({ Unit.Category.GROUND_UNIT })
  if ZoneCfg.CountStatics then
    Ops:SetObjectCategories({ Object.Category.UNIT, Object.Category.STATIC })
  else
    Ops:SetObjectCategories({ Object.Category.UNIT })
  end
  Ops:SetDrawZone(ZoneCfg.Draw)
  -- OPSZONE:New setzt die Markierung bereits. Nur abschalten, sonst doppelt.
  if not ZoneCfg.Mark then
    Ops:SetMarkZone(false)
  end
  if Cfg.Debug then
    Ops:SetVerbosity(1)
  end

  -- Blau darf nicht hinter die Front
  function Ops:OnBeforeCaptured(From, Event, To, NewOwner)
    if NewOwner == BLUE and Zones:IsLocked(Name) then
      OSTWIND.Debug(ShortName(Name) .. " ist noch gesperrt (Phase "
        .. Phase .. ", Front " .. tostring(Zones.ActivePhase) .. ")")
      return false
    end
    return true
  end

  function Ops:OnAfterCaptured(From, Event, To, NewOwner)
    local OldOwner = self:GetPreviousOwner()
    OSTWIND.Log(string.format("%s: %s -> %s", Name,
      SideName[OldOwner] or "?", SideName[NewOwner] or "?"))

    if NewOwner == BLUE then
      ToBlue(ShortName(Name) .. " ist befreit.")
    elseif OldOwner == BLUE then
      ToBlue(ShortName(Name) .. " ist an den Feind gefallen.", 20)
    end

    Zones:_Fire("Captured", Name, NewOwner, OldOwner)
    Zones:_UpdateFront(true)
  end

  function Ops:OnAfterAttacked(From, Event, To, Attacker)
    if Attacker and Attacker ~= self:GetOwner() then
      if self:GetOwner() == BLUE then
        ToBlue(ShortName(Name) .. " wird angegriffen.")
      end
      Zones:_Fire("Attacked", Name, Attacker)
    end
  end

  function Ops:OnAfterDefeated(From, Event, To, Attacker)
    if self:GetOwner() == BLUE then
      ToBlue("Angriff auf " .. ShortName(Name) .. " abgewehrt.")
    end
    Zones:_Fire("Defended", Name, Attacker)
  end

  self.Ops[Name] = Ops
  return Ops
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not OPSZONE then
    env.error("[Ostwind] OPSZONE fehlt. Ist 00_Moose.lua vor den Skripten geladen?", true)
    return
  end

  local Saved = OSTWIND.Persistence:Get("Zones")
  local SavedOwners = (Saved and Saved.Owners) or {}

  -- Phasen sortiert durchgehen, damit Order stimmt
  local Phases = {}
  for Phase in pairs(Cfg.Phases) do
    Phases[#Phases + 1] = Phase
  end
  table.sort(Phases)

  local Missing = 0
  for _, Phase in ipairs(Phases) do
    Zones.MaxPhase = math.max(Zones.MaxPhase, Phase)
    for _, Name in ipairs(Cfg.Phases[Phase]) do
      if Zones.PhaseOf[Name] then
        env.error("[Ostwind] Zone doppelt in der Config: " .. Name)
      else
        local Default = (Phase == 0) and BLUE or RED
        local Owner = tonumber(SavedOwners[Name]) or Default
        if Zones:_Create(Name, Phase, Owner) then
          Zones.PhaseOf[Name] = Phase
          Zones.Order[#Zones.Order + 1] = Name
        else
          Missing = Missing + 1
        end
      end
    end
  end

  if Missing > 0 then
    trigger.action.outText(string.format(
      "[Ostwind] %d Zone(n) fehlen im Editor. Details im dcs.log.", Missing), 30)
  end

  Zones.Victory = (Saved and Saved.Victory) and true or false

  -- Front festlegen, ohne Meldung und ohne erneute Siegmeldung
  Zones:_UpdateFront(false)

  -- Zonen erst starten, wenn die Front feststeht
  for _, Name in ipairs(Zones.Order) do
    Zones.Ops[Name]:Start()
  end

  OSTWIND.Persistence:Register("Zones", function()
    local Owners = {}
    for _, Name in ipairs(Zones.Order) do
      Owners[Name] = Zones:GetOwner(Name)
    end
    return { Owners = Owners, Victory = Zones.Victory }
  end)

  OSTWIND.Log(string.format("Zones: %d Zonen, %d blau, aktive Phase %s",
    #Zones.Order, #Zones:GetZonesByOwner(BLUE), tostring(Zones.ActivePhase)))

  -- Beim Start einmal das aktuelle Ziel nennen
  if Zones.ActivePhase then
    local Names = {}
    for i, Name in ipairs(Zones:GetFrontZones()) do
      Names[i] = ShortName(Name)
    end
    ToBlue("Operation Ostwind. Aktuelles Ziel: " .. table.concat(Names, ", "), 20)
  end
end

OSTWIND.Zones = Zones

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] Zones-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Zones geladen")
