--[[
  Operation Ostwind - 05_Red.lua

  Rote Seite:
    - Besatzungen der roten Zonen (SPAWN), mit Nachschub an der Front
    - Gegenangriffe auf die zuletzt befreiten Zonen
    - Luftabwehr und Frühwarnradar (MANTIS)
    - Jäger von Flugplätzen in Russland (EASYGCICAP)

  Besatzungen und Stellungen entstehen per Skript. Im Editor stehen nur
  spät aktivierte Vorlagen und Trigger-Zonen. So passt die Lage nach dem
  Laden immer zum Spielstand.

  Schwierigkeit:
    - Besatzungen einer neuen Kampagne entstehen mit dem Grundwert aus der
      Config. Beim Missionsstart sitzt meist noch kein Spieler im Slot,
      eine Skalierung wäre dort also immer "Niedrig".
    - Nachschub, Gegenangriffe und die Zahl der Abfangeinsätze richten sich
      nach der aktuellen Stufe aus 04_Scaling.lua.

  Andere Skripte nutzen:
    OSTWIND.Red:GetGarrisonCount(ZoneName) -> lebende Gruppen der Besatzung
    OSTWIND.Red:GetGarrisonGroups(ZoneName) -> Liste der MOOSE-Gruppen
    OSTWIND.Red:IsAttackRunning()          -> true, wenn ein Gegenangriff läuft
    OSTWIND.Red:LaunchCounterattack()      -> Gegenangriff sofort starten
    OSTWIND.Red:Reinforce()                -> Nachschub-Runde sofort ausführen
    OSTWIND.Red.Mantis                     -> MANTIS-Objekt oder nil
    OSTWIND.Red.Gci                        -> EASYGCICAP-Objekt oder nil

  Speichert unter dem Schlüssel "Red":
    Garrisons  Zone -> Zahl der lebenden Gruppen (nur rote Zonen)
    SitesDead  Stellung -> true, wenn zerstört oder überrannt

  Benötigt: 01 bis 04, MOOSE (SPAWN, ZONE, TIMER, MESSAGE, MANTIS, EASYGCICAP)
]]

local Cfg     = OSTWIND.Config.Red
local Zones   = OSTWIND.Zones
local Scaling = OSTWIND.Scaling
local RED     = coalition.side.RED
local BLUE    = coalition.side.BLUE

local Red = {
  Garrison  = {},   -- Zone -> Liste von GROUP
  Attack    = nil,  -- { Target = Zone, Source = Zone, Groups = {...} }
  Sites     = {},   -- Stellung -> GROUP
  SiteLink  = {},   -- Stellung -> Zone
  SitesDead = {},   -- Stellung -> true
  Spawners  = {},   -- Alias -> SPAWN
  Templates = { Garrison = {}, Attack = {} },
  Mantis    = nil,
  Gci       = nil,
}
OSTWIND.Red = Red

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
  env.error("[Ostwind] Rot: Vorlage fehlt im Editor: " .. tostring(Name))
  return false
end

local function Existing(List)
  local Result = {}
  for _, Name in ipairs(List or {}) do
    if TemplateExists(Name) then
      Result[#Result + 1] = Name
    end
  end
  return Result
end

local function Pick(List)
  return List[math.random(1, #List)]
end

-- Ein SPAWN je Alias. Gleiche Aliase würden Gruppennamen doppelt vergeben.
local function Spawner(Template, Alias)
  local Key = Alias
  if not Red.Spawners[Key] then
    Red.Spawners[Key] = SPAWN:NewWithAlias(Template, Alias)
  end
  return Red.Spawners[Key]
end

local function IsGroupAlive(Group)
  return Group ~= nil and Group:IsAlive() and Group:CountAliveUnits() > 0
end

-- Entfernt tote Gruppen aus einer Liste und liefert die Zahl der lebenden
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

local function MooseZone(ZoneName)
  local Ops = Zones:GetOpsZone(ZoneName)
  return Ops and Ops:GetZone() or nil
end

-- Zufälliger Punkt an Land in einer Zone
local function RandomPoint(Zone, Share)
  local Surfaces = { land.SurfaceType.LAND, land.SurfaceType.ROAD }
  if Zone.GetRadius then
    return Zone:GetRandomCoordinate(0, Zone:GetRadius() * Share, Surfaces)
  end
  return Zone:GetRandomCoordinate()
end

local function ToBlue(Text, Seconds)
  if OSTWIND.Config.Zones.Messages then
    MESSAGE:New(Text, Seconds or 20):ToBlue()
  end
end

---------------------------------------------------------------------------
-- Besatzungen
---------------------------------------------------------------------------

local GCfg = Cfg.Garrison

local function BaseCount(ZoneName)
  return GCfg.PerZone[ZoneName] or GCfg.Groups
end

function Red:GetGarrisonGroups(ZoneName)
  local List = self.Garrison[ZoneName] or {}
  Prune(List)
  return List
end

function Red:GetGarrisonCount(ZoneName)
  return #self:GetGarrisonGroups(ZoneName)
end

function Red:_SpawnGarrison(ZoneName, Count)
  if Count <= 0 or #self.Templates.Garrison == 0 then
    return 0
  end
  local Zone = MooseZone(ZoneName)
  if not Zone then
    return 0
  end
  self.Garrison[ZoneName] = self.Garrison[ZoneName] or {}

  local Spawned = 0
  for _ = 1, Count do
    local Index = math.random(1, #self.Templates.Garrison)
    local Template = self.Templates.Garrison[Index]
    local Alias = string.format("RED GAR %s %d", ShortName(ZoneName), Index)
    local Group = Spawner(Template, Alias):SpawnFromCoordinate(RandomPoint(Zone, GCfg.SpawnRadius))
    if Group then
      Group:OptionAlarmStateRed()
      table.insert(self.Garrison[ZoneName], Group)
      Spawned = Spawned + 1
    end
  end
  return Spawned
end

function Red:Reinforce()
  if not GCfg.Reinforce.Enabled then
    return
  end
  for _, ZoneName in ipairs(Zones:GetFrontZones()) do
    local Ops = Zones:GetOpsZone(ZoneName)
    -- Kein Nachschub in Zonen, die gerade angegriffen werden
    if Ops and Ops:GetOwner() == RED and not Ops:IsAttacked() then
      local Alive  = self:GetGarrisonCount(ZoneName)
      local Target = Scaling:Scale(BaseCount(ZoneName), "red")
      local Add    = math.min(GCfg.Reinforce.PerRound, Target - Alive)
      if Add > 0 then
        local N = self:_SpawnGarrison(ZoneName, Add)
        OSTWIND.Log(string.format("Rot: Nachschub %s +%d (%d/%d)", ShortName(ZoneName), N, Alive + N, Target))
      end
    end
  end
end

---------------------------------------------------------------------------
-- Gegenangriffe
---------------------------------------------------------------------------

local ACfg = Cfg.Counterattack

function Red:IsAttackRunning()
  if not self.Attack then
    return false
  end
  if Prune(self.Attack.Groups) == 0 then
    self.Attack = nil
    return false
  end
  return true
end

function Red:LaunchCounterattack()
  if #self.Templates.Attack == 0 or self:IsAttackRunning() then
    return false
  end

  local Phase = Zones:GetActivePhase()
  if not Phase then
    return false
  end
  local TargetPhase = Phase - 1
  if TargetPhase < 0 or (TargetPhase == 0 and not ACfg.AllowPhase0) then
    return false
  end

  local Targets, Sources = {}, {}
  for _, Name in ipairs(Zones:GetZonesByOwner(BLUE)) do
    if Zones:GetPhase(Name) == TargetPhase then
      Targets[#Targets + 1] = Name
    end
  end
  for _, Name in ipairs(Zones:GetFrontZones()) do
    if Zones:GetOwner(Name) == RED then
      Sources[#Sources + 1] = Name
    end
  end
  if #Targets == 0 or #Sources == 0 then
    return false
  end

  local Target, Source = Pick(Targets), Pick(Sources)
  local TargetZone, SourceZone = MooseZone(Target), MooseZone(Source)
  if not TargetZone or not SourceZone then
    return false
  end

  local Attack = { Target = Target, Source = Source, Groups = {} }
  local Count = Scaling:Scale(ACfg.Groups, "red")
  for _ = 1, Count do
    local Index = math.random(1, #self.Templates.Attack)
    local Alias = string.format("RED ATK %d", Index)
    local Group = Spawner(self.Templates.Attack[Index], Alias)
      :SpawnFromCoordinate(RandomPoint(SourceZone, GCfg.SpawnRadius))
    if Group then
      Group:OptionAlarmStateRed()
      Group:OptionROEOpenFire()
      Group:RouteGroundOnRoad(RandomPoint(TargetZone, 0.5), ACfg.Speed, 5, "Off Road")
      table.insert(Attack.Groups, Group)
    end
  end

  if #Attack.Groups == 0 then
    return false
  end
  self.Attack = Attack
  OSTWIND.Log(string.format("Rot: Gegenangriff %s -> %s mit %d Gruppen",
    ShortName(Source), ShortName(Target), #Attack.Groups))
  ToBlue(string.format("Aufklärung: Feindliche Kräfte rücken von %s auf %s vor.",
    ShortName(Source), ShortName(Target)), 30)
  return true
end

function Red:_ScheduleCounterattack(Delay)
  TIMER:New(function()
    local Ok, Err = pcall(Red.LaunchCounterattack, Red)
    if not Ok then
      env.error("[Ostwind] Gegenangriff fehlgeschlagen: " .. tostring(Err))
    end
    local V = ACfg.Variation
    local Next = ACfg.Interval * (1 + (math.random() * 2 - 1) * V)
    Red:_ScheduleCounterattack(math.max(60, Next))
  end):Start(Delay)
end

---------------------------------------------------------------------------
-- Luftabwehr
---------------------------------------------------------------------------

local DCfg = Cfg.AirDefense

-- Eine Stellung gilt als zerstört, wenn kein Radar mehr lebt.
-- Ohne Radar ist sie wirkungslos, auch wenn Starter übrig sind.
local function SiteDestroyed(Group)
  if not IsGroupAlive(Group) then
    return true
  end
  for _, U in ipairs(Group:GetUnits() or {}) do
    local DcsUnit = U:GetDCSObject()
    if DcsUnit and DcsUnit:isExist() and DcsUnit:getLife() > 0
      and DcsUnit:hasSensors(Unit.SensorType.RADAR) then
      return false
    end
  end
  return true
end

function Red:_SpawnSite(Site, Prefix)
  if self.SitesDead[Site.Name] then
    return
  end
  if Site.Link and Zones:GetOwner(Site.Link) ~= RED then
    return
  end
  if not TemplateExists(Site.Template) then
    return
  end
  local Zone = ZONE:FindByName(Site.Zone)
  if not Zone then
    env.error("[Ostwind] Rot: Trigger-Zone fehlt im Editor: " .. Site.Zone)
    return
  end
  local Group = Spawner(Site.Template, Prefix .. " " .. Site.Name):SpawnFromCoordinate(Zone:GetCoordinate())
  if Group then
    Group:OptionAlarmStateRed()
    self.Sites[Site.Name] = Group
    self.SiteLink[Site.Name] = Site.Link
  end
end

function Red:_UpdateDeadSites()
  for Name, Group in pairs(self.Sites) do
    if SiteDestroyed(Group) then
      self.SitesDead[Name] = true
      self.Sites[Name] = nil
    end
  end
end

-- Blau hat eine Zone erobert: dazugehörige Stellungen sind überrannt
function Red:_OverrunSites(ZoneName)
  for Name, Link in pairs(self.SiteLink) do
    if Link == ZoneName and self.Sites[Name] then
      if IsGroupAlive(self.Sites[Name]) then
        self.Sites[Name]:Destroy(false)
      end
      self.Sites[Name] = nil
      self.SitesDead[Name] = true
      OSTWIND.Log("Rot: Stellung überrannt: " .. Name)
    end
  end
end

function Red:_SetupAirDefense()
  if not DCfg.Enabled then
    return
  end
  if not MANTIS then
    env.error("[Ostwind] MANTIS fehlt in MOOSE", true)
    return
  end
  for _, Site in ipairs(DCfg.Sites) do
    self:_SpawnSite(Site, DCfg.SamPrefix)
  end
  for _, Site in ipairs(DCfg.Ewr) do
    self:_SpawnSite(Site, DCfg.EwrPrefix)
  end

  -- dynamic = true: MANTIS erkennt auch später erzeugte Gruppen
  self.Mantis = MANTIS:New("Ostwind Rot", DCfg.SamPrefix, DCfg.EwrPrefix, nil, "red", true)
  self.Mantis:Start()

  local Count = 0
  for _ in pairs(self.Sites) do
    Count = Count + 1
  end
  OSTWIND.Log(string.format("Rot: Luftabwehr mit %d Stellungen gestartet", Count))
end

---------------------------------------------------------------------------
-- Jäger
---------------------------------------------------------------------------

local FCfg = Cfg.Air

function Red:_SetupAir()
  if not FCfg.Enabled then
    return
  end
  if not EASYGCICAP then
    env.error("[Ostwind] EASYGCICAP fehlt in MOOSE", true)
    return
  end

  -- Nur Flugplätze mit Lagerhaus und mindestens einer vorhandenen Vorlage
  local Wings = {}
  for _, W in ipairs(FCfg.Wings) do
    if not AIRBASE:FindByName(W.Airbase) then
      env.error("[Ostwind] Rot: Flugplatz unbekannt: " .. W.Airbase)
    elseif not STATIC:FindByName(W.Airbase, false) then
      env.error("[Ostwind] Rot: Lagerhaus fehlt im Editor. Rotes statisches Objekt mit Namen "
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
    env.error("[Ostwind] Rot: keine einsatzbereiten Flugplätze, keine Jäger", true)
    return
  end

  local EwrPrefixes = { DCfg.SamPrefix, DCfg.EwrPrefix }
  local Gci = EASYGCICAP:New("Ostwind Rot GCI", Wings[1].Airbase, "red", EwrPrefixes)
  for i = 2, #Wings do
    Gci:AddAirwing(Wings[i].Airbase, "Ostwind " .. Wings[i].Airbase)
  end

  Gci:SetDefaultCAPAlt(FCfg.CapAltitude)
  Gci:SetDefaultCAPSpeed(FCfg.CapSpeed)
  Gci:SetDefaultCAPLeg(FCfg.CapLeg)
  Gci:SetDefaultMissionRange(FCfg.MissionRange)
  Gci:SetMaxAliveMissions(Scaling:Scale(FCfg.MaxMissions, "red"))

  local Skill = AI.Skill[FCfg.Skill] or AI.Skill.AVERAGE
  for _, W in ipairs(Wings) do
    for _, S in ipairs(W.Squadrons) do
      Gci:AddSquadron(S.Template, S.Name, W.Airbase, S.Airframes, Skill)
    end
    if W.CapZone then
      local Zone = ZONE:FindByName(W.CapZone)
      if Zone then
        Gci:AddPatrolPointCAP(W.Airbase, Zone, FCfg.CapAltitude, FCfg.CapSpeed, 90, FCfg.CapLeg)
      else
        env.error("[Ostwind] Rot: Trigger-Zone fehlt im Editor: " .. W.CapZone)
      end
    end
  end

  Scaling:OnChange(function()
    Gci:SetMaxAliveMissions(Scaling:Scale(FCfg.MaxMissions, "red"))
  end)

  self.Gci = Gci
  OSTWIND.Log(string.format("Rot: Jäger von %d Flugplätzen", #Wings))
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not Zones or not Scaling then
    env.error("[Ostwind] 05_Red braucht 03_Zones.lua und 04_Scaling.lua", true)
    return
  end

  Red.Templates.Garrison = Existing(GCfg.Templates)
  Red.Templates.Attack   = Existing(ACfg.Templates)

  local Saved = OSTWIND.Persistence:Get("Red") or {}
  local SavedGarrisons = Saved.Garrisons or {}
  for Name, Dead in pairs(Saved.SitesDead or {}) do
    Red.SitesDead[Name] = Dead and true or nil
  end

  -- Besatzungen
  local Total = 0
  for _, ZoneName in ipairs(Zones:GetAllZones()) do
    if Zones:GetOwner(ZoneName) == RED then
      local Count = tonumber(SavedGarrisons[ZoneName])
      if Count == nil then
        Count = BaseCount(ZoneName)
      end
      Total = Total + Red:_SpawnGarrison(ZoneName, Count)
    end
  end
  OSTWIND.Log(string.format("Rot: %d Besatzungsgruppen erzeugt", Total))

  Red:_SetupAirDefense()
  Red:_SetupAir()

  -- Ereignisse der Zonen
  Zones:On("Captured", function(ZoneName, NewOwner)
    if NewOwner == BLUE then
      Red.Garrison[ZoneName] = {}
      Red:_OverrunSites(ZoneName)
    elseif NewOwner == RED and Red.Attack and Red.Attack.Target == ZoneName then
      -- Angreifer werden zur neuen Besatzung
      Red.Garrison[ZoneName] = Red.Garrison[ZoneName] or {}
      for _, Group in ipairs(Red.Attack.Groups) do
        if IsGroupAlive(Group) then
          table.insert(Red.Garrison[ZoneName], Group)
        end
      end
      Red.Attack = nil
    end
  end)

  -- Zeitgesteuert
  if GCfg.Reinforce.Enabled then
    TIMER:New(function()
      local Ok, Err = pcall(Red.Reinforce, Red)
      if not Ok then
        env.error("[Ostwind] Nachschub fehlgeschlagen: " .. tostring(Err))
      end
    end):Start(GCfg.Reinforce.Interval, GCfg.Reinforce.Interval)
  end
  if ACfg.Enabled then
    Red:_ScheduleCounterattack(ACfg.FirstDelay)
  end
  TIMER:New(function() Red:_UpdateDeadSites() end):Start(60, 60)

  -- Speichern
  OSTWIND.Persistence:Register("Red", function()
    Red:_UpdateDeadSites()
    local Garrisons = {}
    for _, ZoneName in ipairs(Zones:GetAllZones()) do
      if Zones:GetOwner(ZoneName) == RED then
        Garrisons[ZoneName] = Red:GetGarrisonCount(ZoneName)
      end
    end
    local Dead = {}
    for Name in pairs(Red.SitesDead) do
      Dead[Name] = true
    end
    return { Garrisons = Garrisons, SitesDead = Dead }
  end)
end

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] Rot-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Red geladen")
