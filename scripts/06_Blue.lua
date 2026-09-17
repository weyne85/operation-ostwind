--[[
  Operation Ostwind - 06_Blue.lua

  Blaue KI zur Unterstützung der Spieler:
    - Besatzungen in eroberten Zonen, mit Nachschub für die gefährdeten Zonen
    - AWACS und Tanker von Land, dauerhaft in der Luft
    - Frühwarnradar
    - Jäger von Kobuleti und Senaki (EASYGCICAP)

  Blau erobert keine Zonen selbst. Besatzungen entstehen nur in Zonen,
  die schon blau sind. Die Startzonen an der Küste bleiben leer.

  Schwierigkeit: Sollstärke der Besatzungen und Zahl der Abfangeinsätze
  richten sich nach dem Faktor Blau aus 04_Scaling.lua. Mit wenigen
  Spielern hilft Blau mehr.

  Andere Skripte nutzen:
    OSTWIND.Blue:GetGarrisonCount(ZoneName)
    OSTWIND.Blue:GetGarrisonGroups(ZoneName)
    OSTWIND.Blue:Reinforce()
    OSTWIND.Blue:GetRecceprefixes()   -> Namensanfänge der blauen Aufklärer
    OSTWIND.Blue.Gci                  -> EASYGCICAP-Objekt oder nil

  Speichert unter dem Schlüssel "Blue":
    Garrisons  Zone -> Zahl der lebenden Gruppen (nur blaue Zonen ab Phase 1)

  Benötigt: 01 bis 04, MOOSE (SPAWN, ZONE, TIMER, EASYGCICAP)
]]

local Cfg     = OSTWIND.Config.Blue
local Zones   = OSTWIND.Zones
local Scaling = OSTWIND.Scaling
local BLUE    = coalition.side.BLUE
local RED     = coalition.side.RED

local Blue = {
  Garrison  = {},
  Spawners  = {},
  Templates = {},
  Support   = {},
  Gci       = nil,
}
OSTWIND.Blue = Blue

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------

local function ShortName(Name)
  return (Name:gsub("^Zone%s+", ""))
end

local function TemplateExists(Name)
  if GROUP:FindByName(Name) then
    return true
  end
  env.error("[Ostwind] Blau: Vorlage fehlt im Editor: " .. tostring(Name))
  return false
end

local function Spawner(Template, Alias)
  if not Blue.Spawners[Alias] then
    Blue.Spawners[Alias] = SPAWN:NewWithAlias(Template, Alias)
  end
  return Blue.Spawners[Alias]
end

local function IsGroupAlive(Group)
  return Group ~= nil and Group:IsAlive() and Group:CountAliveUnits() > 0
end

local function Prune(List)
  local i = 1
  while i <= #List do
    if IsGroupAlive(List[i]) then
      i = i + 1
    else
      table.remove(List, i)
    end
  end
  return #List
end

local function RandomPoint(Zone, Share)
  local Surfaces = { land.SurfaceType.LAND, land.SurfaceType.ROAD }
  if Zone.GetRadius then
    return Zone:GetRandomCoordinate(0, Zone:GetRadius() * Share, Surfaces)
  end
  return Zone:GetRandomCoordinate()
end

-- Zonen, die eine blaue Besatzung bekommen dürfen
local function Holdable(ZoneName)
  return Zones:GetOwner(ZoneName) == BLUE and (Zones:GetPhase(ZoneName) or 0) >= 1
end

---------------------------------------------------------------------------
-- Besatzungen
---------------------------------------------------------------------------

local GCfg = Cfg.Garrison

function Blue:GetGarrisonGroups(ZoneName)
  local List = self.Garrison[ZoneName] or {}
  Prune(List)
  return List
end

function Blue:GetGarrisonCount(ZoneName)
  return #self:GetGarrisonGroups(ZoneName)
end

function Blue:_Target()
  return Scaling:Scale(GCfg.Groups, "blue")
end

function Blue:_SpawnGarrison(ZoneName, Count)
  if Count <= 0 or #self.Templates == 0 or not Holdable(ZoneName) then
    return 0
  end
  local Ops = Zones:GetOpsZone(ZoneName)
  local Zone = Ops and Ops:GetZone()
  if not Zone then
    return 0
  end
  self.Garrison[ZoneName] = self.Garrison[ZoneName] or {}

  local Spawned = 0
  for _ = 1, Count do
    local Index = math.random(1, #self.Templates)
    local Alias = string.format("BLUE GAR %s %d", ShortName(ZoneName), Index)
    local Group = Spawner(self.Templates[Index], Alias):SpawnFromCoordinate(RandomPoint(Zone, GCfg.SpawnRadius))
    if Group then
      Group:OptionAlarmStateRed()
      table.insert(self.Garrison[ZoneName], Group)
      Spawned = Spawned + 1
    end
  end
  return Spawned
end

-- Nachschub für die Zonen, die Rot als Nächstes angreift
function Blue:Reinforce()
  local Phase = Zones:GetActivePhase()
  if not Phase then
    return
  end
  for _, ZoneName in ipairs(Zones:GetAllZones()) do
    if Zones:GetPhase(ZoneName) == Phase - 1 and Holdable(ZoneName) then
      local Ops = Zones:GetOpsZone(ZoneName)
      if Ops and not Ops:IsAttacked() then
        local Alive = self:GetGarrisonCount(ZoneName)
        local Add = math.min(GCfg.Reinforce.PerRound, self:_Target() - Alive)
        if Add > 0 then
          local N = self:_SpawnGarrison(ZoneName, Add)
          OSTWIND.Log(string.format("Blau: Nachschub %s +%d", ShortName(ZoneName), N))
        end
      end
    end
  end
end

function Blue:_OnCaptured(ZoneName, NewOwner)
  if NewOwner == BLUE then
    self.Garrison[ZoneName] = {}
    local Delay = GCfg.ArrivalDelay
    TIMER:New(function()
      -- Nur wenn die Zone dann noch blau ist
      if Holdable(ZoneName) then
        local N = Blue:_SpawnGarrison(ZoneName, Blue:_Target() - Blue:GetGarrisonCount(ZoneName))
        if N > 0 then
          OSTWIND.Log(string.format("Blau: Besatzung für %s eingetroffen (%d)", ShortName(ZoneName), N))
          if OSTWIND.Config.Zones.Messages then
            MESSAGE:New(string.format("Eigene Kräfte sichern %s.", ShortName(ZoneName)), 15):ToBlue()
          end
        end
      end
    end):Start(Delay)
  elseif NewOwner == RED then
    self.Garrison[ZoneName] = {}
  end
end

---------------------------------------------------------------------------
-- AWACS, Tanker, Radar
---------------------------------------------------------------------------

function Blue:_SetupSupport()
  local S = Cfg.Support
  if not S.Enabled then
    return
  end
  for _, Entry in ipairs(S.Templates) do
    if TemplateExists(Entry.Template) then
      local Sp = SPAWN:NewWithAlias(Entry.Template, Entry.Alias)
      -- Obergrenze zählt Einheiten: genau eine Gruppe dieser Vorlage in der Luft
      local Size = GROUP:FindByName(Entry.Template):GetSize() or 1
      Sp:InitLimit(Size, 0)
      Sp:InitRepeatOnEngineShutDown()
      if S.UnlimitedFuel then
        Sp:OnSpawnGroup(function(Group)
          Group:CommandSetUnlimitedFuel(true, 5)
        end)
      end
      -- Der Zeitgeber startet sofort und erzeugt das erste Flugzeug selbst.
      -- InitLimit sorgt dafür, dass nie mehr als eins gleichzeitig fliegt.
      Sp:SpawnScheduled(S.CheckInterval, 0)
      self.Support[Entry.Alias] = Sp
    end
  end
end

function Blue:_SetupEwr()
  local E = Cfg.Ewr
  if not E.Enabled or not TemplateExists(E.Template) then
    return
  end
  local Zone = ZONE:FindByName(E.Zone)
  if not Zone then
    env.error("[Ostwind] Blau: Trigger-Zone fehlt im Editor: " .. E.Zone)
    return
  end
  local Group = SPAWN:NewWithAlias(E.Template, E.Alias):SpawnFromCoordinate(Zone:GetCoordinate())
  if Group then
    Group:OptionAlarmStateRed()
  end
end

-- Namensanfänge aller blauen Aufklärer: AWACS, Radar, AWACS vom Träger
function Blue:GetRecceprefixes()
  local List = {}
  for _, Entry in ipairs(Cfg.Support.Templates) do
    if Entry.Template:find("AWACS", 1, true) then
      List[#List + 1] = Entry.Alias
    end
  end
  List[#List + 1] = Cfg.Ewr.Alias
  local C = OSTWIND.Config.Carrier
  if C and C.Enabled and C.AWACS and C.AWACS.Enabled then
    -- RECOVERYTANKER benennt Gruppen "<Träger>_<Vorlage>_<Nr>"
    List[#List + 1] = C.UnitName .. "_" .. C.AWACS.Template
  end
  return List
end

---------------------------------------------------------------------------
-- Jäger
---------------------------------------------------------------------------

function Blue:_SetupAir()
  local F = Cfg.Air
  if not F.Enabled then
    return
  end
  if not EASYGCICAP then
    env.error("[Ostwind] EASYGCICAP fehlt in MOOSE", true)
    return
  end

  local Wings = {}
  for _, W in ipairs(F.Wings) do
    if not AIRBASE:FindByName(W.Airbase) then
      env.error("[Ostwind] Blau: Flugplatz unbekannt: " .. W.Airbase)
    elseif not STATIC:FindByName(W.Airbase, false) then
      env.error("[Ostwind] Blau: Lagerhaus fehlt im Editor. Blaues statisches Objekt mit Namen "
        .. W.Airbase .. " anlegen.")
    else
      local Squads = {}
      for _, S in ipairs(W.Squadrons) do
        if TemplateExists(S.Template) then
          Squads[#Squads + 1] = S
        end
      end
      if #Squads > 0 then
        Wings[#Wings + 1] = { Airbase = W.Airbase, CapZone = W.CapZone, Squadrons = Squads }
      end
    end
  end
  if #Wings == 0 then
    env.error("[Ostwind] Blau: keine einsatzbereiten Flugplätze, keine Jäger")
    return
  end

  local Gci = EASYGCICAP:New("Ostwind Blau GCI", Wings[1].Airbase, "blue", self:GetRecceprefixes())
  for i = 2, #Wings do
    Gci:AddAirwing(Wings[i].Airbase, "Ostwind " .. Wings[i].Airbase)
  end
  Gci:SetDefaultCAPAlt(F.CapAltitude)
  Gci:SetDefaultCAPSpeed(F.CapSpeed)
  Gci:SetDefaultCAPLeg(F.CapLeg)
  Gci:SetDefaultMissionRange(F.MissionRange)
  Gci:SetMaxAliveMissions(Scaling:Scale(F.MaxMissions, "blue"))

  local Skill = AI.Skill[F.Skill] or AI.Skill.GOOD
  for _, W in ipairs(Wings) do
    for _, S in ipairs(W.Squadrons) do
      Gci:AddSquadron(S.Template, S.Name, W.Airbase, S.Airframes, Skill)
    end
    if W.CapZone then
      local Zone = ZONE:FindByName(W.CapZone)
      if Zone then
        Gci:AddPatrolPointCAP(W.Airbase, Zone, F.CapAltitude, F.CapSpeed, 90, F.CapLeg)
      else
        env.error("[Ostwind] Blau: Trigger-Zone fehlt im Editor: " .. W.CapZone)
      end
    end
  end

  Scaling:OnChange(function()
    Gci:SetMaxAliveMissions(Scaling:Scale(F.MaxMissions, "blue"))
  end)

  self.Gci = Gci
  OSTWIND.Log(string.format("Blau: Jäger von %d Flugplätzen", #Wings))
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not Zones or not Scaling then
    env.error("[Ostwind] 06_Blue braucht 03_Zones.lua und 04_Scaling.lua", true)
    return
  end

  if GCfg.Enabled then
    for _, Name in ipairs(GCfg.Templates) do
      if TemplateExists(Name) then
        Blue.Templates[#Blue.Templates + 1] = Name
      end
    end

    local Saved = OSTWIND.Persistence:Get("Blue") or {}
    local Total = 0
    for ZoneName, Count in pairs(Saved.Garrisons or {}) do
      Total = Total + Blue:_SpawnGarrison(ZoneName, tonumber(Count) or 0)
    end
    if Total > 0 then
      OSTWIND.Log(string.format("Blau: %d Besatzungsgruppen geladen", Total))
    end

    Zones:On("Captured", function(ZoneName, NewOwner) Blue:_OnCaptured(ZoneName, NewOwner) end)

    if GCfg.Reinforce.Enabled then
      TIMER:New(function()
        local Ok, Err = pcall(Blue.Reinforce, Blue)
        if not Ok then
          env.error("[Ostwind] Blauer Nachschub fehlgeschlagen: " .. tostring(Err))
        end
      end):Start(GCfg.Reinforce.Interval, GCfg.Reinforce.Interval)
    end

    OSTWIND.Persistence:Register("Blue", function()
      local Garrisons = {}
      for _, ZoneName in ipairs(Zones:GetAllZones()) do
        if Holdable(ZoneName) then
          Garrisons[ZoneName] = Blue:GetGarrisonCount(ZoneName)
        end
      end
      return { Garrisons = Garrisons }
    end)
  end

  Blue:_SetupSupport()
  Blue:_SetupEwr()
  Blue:_SetupAir()
end

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] Blau-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Blue geladen")
