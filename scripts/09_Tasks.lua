--[[
  Operation Ostwind - 09_Tasks.lua

  Aufträge für Spieler im F10-Menü mit MOOSE PLAYERTASKCONTROLLER:
    - "Aufträge Boden": Ziele von der roten Seite. Besatzungen der
      Frontzonen, laufende Gegenangriffe und Luftabwehrstellungen.
      MOOSE wählt die Auftragsart selbst, zum Beispiel CAS, BAI oder SEAD.
    - "Aufträge Luft": Abfangaufträge aus der Aufklärung von AWACS
      und Frühwarnradar.
    - "Kampagne > Lagebericht": aktuelles Ziel, befreite Zonen,
      Gegenangriffe, Feindaktivität und der nächste Transportauftrag.

  Transporte laufen über das CTLD-Menü (08_CTLD.lua). Der Lagebericht
  nennt dafür die aktuelle Zielzone.

  Nur Spieler-Slots mit dem Präfix aus Config.Slots.Prefix bekommen die
  Auftragsmenüs.

  Andere Skripte nutzen:
    OSTWIND.Tasks.Ground        -> PLAYERTASKCONTROLLER Boden oder nil
    OSTWIND.Tasks.Air           -> PLAYERTASKCONTROLLER Luft oder nil
    OSTWIND.Tasks:ScanTargets() -> neue rote Ziele sofort übernehmen
    OSTWIND.Tasks:BuildReport() -> Text des Lageberichts

  Benötigt: 01 bis 05, optional 06, MOOSE (PLAYERTASKCONTROLLER, TIMER, MESSAGE)
]]

local Cfg   = OSTWIND.Config.Tasks
local Zones = OSTWIND.Zones
local BLUE  = coalition.side.BLUE
local RED   = coalition.side.RED

local Tasks = {
  Ground = nil,
  Air    = nil,
  Added  = {},   -- Gruppenname -> true
}
OSTWIND.Tasks = Tasks

local function ShortName(Name)
  return (Name:gsub("^Zone%s+", ""))
end

local function IsGroupAlive(Group)
  return Group ~= nil and Group:IsAlive() and Group:CountAliveUnits() > 0
end

---------------------------------------------------------------------------
-- Bodenziele
---------------------------------------------------------------------------

function Tasks:_Offer(Group, MenuName)
  if not IsGroupAlive(Group) then
    return false
  end
  local Name = Group:GetName()
  if self.Added[Name] then
    return false
  end
  Group.menuname = MenuName
  self.Ground:AddTarget(Group)
  self.Added[Name] = true
  return true
end

function Tasks:ScanTargets()
  local Red = OSTWIND.Red
  if not self.Ground or not Red then
    return 0
  end
  local G = Cfg.A2G
  local New = 0

  if G.Garrisons then
    for _, ZoneName in ipairs(Zones:GetFrontZones()) do
      if Zones:GetOwner(ZoneName) == RED then
        for _, Group in ipairs(Red:GetGarrisonGroups(ZoneName)) do
          if self:_Offer(Group, "Besatzung " .. ShortName(ZoneName)) then
            New = New + 1
          end
        end
      end
    end
  end

  if G.Attacks and Red:IsAttackRunning() then
    for _, Group in ipairs(Red.Attack.Groups) do
      if self:_Offer(Group, "Gegenangriff auf " .. ShortName(Red.Attack.Target)) then
        New = New + 1
      end
    end
  end

  if G.AirDefense then
    for SiteName, Group in pairs(Red.Sites) do
      if self:_Offer(Group, "Luftabwehr " .. SiteName) then
        New = New + 1
      end
    end
  end

  if New > 0 then
    OSTWIND.Log(string.format("Tasks: %d neue Bodenziele", New))
  end
  return New
end

function Tasks:_SetupGround()
  local G = Cfg.A2G
  if not G.Enabled then
    return
  end
  local Ctrl = PLAYERTASKCONTROLLER:New("Ostwind Boden", BLUE, PLAYERTASKCONTROLLER.Type.A2G,
    OSTWIND.Config.Slots.Prefix)
  Ctrl:SetLocale(Cfg.Locale)
  Ctrl:SetMenuName(G.MenuName)
  Ctrl:SetEnableUseTypeNames()
  self.Ground = Ctrl

  TIMER:New(function()
    local Ok, Err = pcall(Tasks.ScanTargets, Tasks)
    if not Ok then
      env.error("[Ostwind] Zielsuche fehlgeschlagen: " .. tostring(Err))
    end
  end):Start(15, G.ScanInterval)

  -- Neue Front: sofort nach neuen Zielen suchen
  Zones:On("PhaseChanged", function()
    TIMER:New(function() pcall(Tasks.ScanTargets, Tasks) end):Start(5)
  end)
end

---------------------------------------------------------------------------
-- Luftziele
---------------------------------------------------------------------------

function Tasks:_SetupAir()
  local A = Cfg.A2A
  if not A.Enabled then
    return
  end
  local Recce
  if OSTWIND.Blue and OSTWIND.Blue.GetRecceprefixes then
    Recce = OSTWIND.Blue:GetRecceprefixes()
  else
    Recce = { "BLUE AWACS", "BLUE EWR" }
  end
  local Ctrl = PLAYERTASKCONTROLLER:New("Ostwind Luft", BLUE, PLAYERTASKCONTROLLER.Type.A2A,
    OSTWIND.Config.Slots.Prefix)
  Ctrl:SetLocale(Cfg.Locale)
  Ctrl:SetMenuName(A.MenuName)
  Ctrl:SetupIntel(Recce)
  self.Air = Ctrl
end

---------------------------------------------------------------------------
-- Lagebericht
---------------------------------------------------------------------------

function Tasks:BuildReport()
  local Lines = { "Lagebericht Operation Ostwind", "" }
  local Phase = Zones:GetActivePhase()
  local Last = 0
  for _, Name in ipairs(Zones:GetAllZones()) do
    Last = math.max(Last, Zones:GetPhase(Name) or 0)
  end

  if Zones:IsVictory() or not Phase then
    Lines[#Lines + 1] = "Alle Ziele erreicht. Georgien ist befreit."
  else
    Lines[#Lines + 1] = string.format("Phase %d von %d", Phase, Last)
    local Targets = {}
    for _, Name in ipairs(Zones:GetFrontZones()) do
      if Zones:GetOwner(Name) ~= BLUE then
        local Count = OSTWIND.Red and OSTWIND.Red:GetGarrisonCount(Name) or 0
        Targets[#Targets + 1] = string.format("%s (%d feindliche Gruppen)", ShortName(Name), Count)
      end
    end
    Lines[#Lines + 1] = "Ziel: " .. table.concat(Targets, ", ")
  end

  local Freed = {}
  for _, Name in ipairs(Zones:GetZonesByOwner(BLUE)) do
    Freed[#Freed + 1] = ShortName(Name)
  end
  Lines[#Lines + 1] = "Befreit: " .. (#Freed > 0 and table.concat(Freed, ", ") or "keine")

  local Red = OSTWIND.Red
  if Red and Red:IsAttackRunning() then
    Lines[#Lines + 1] = string.format("Gegenangriff: Feind rückt von %s auf %s vor.",
      ShortName(Red.Attack.Source), ShortName(Red.Attack.Target))
  else
    Lines[#Lines + 1] = "Gegenangriff: keiner gemeldet"
  end

  local Scaling = OSTWIND.Scaling
  if Scaling and Scaling:GetTier() then
    Lines[#Lines + 1] = string.format("Feindaktivität: %s (%d Spieler)",
      Scaling:GetTier().Name, Scaling:GetPlayers())
  end

  if Phase and not Zones:IsVictory() then
    local Front = Zones:GetFrontZones()
    if #Front > 0 then
      Lines[#Lines + 1] = ""
      Lines[#Lines + 1] = string.format(
        "Transport: Truppen in einer befreiten Zone oder auf dem Träger laden und bei %s absetzen.",
        ShortName(Front[1]))
    end
  end

  return table.concat(Lines, "\n")
end

function Tasks:_SetupReport()
  if not Cfg.Report then
    return
  end
  missionCommands.addCommandForCoalition(BLUE, "Lagebericht", OSTWIND.CampaignMenu(), function()
    local Ok, Text = pcall(Tasks.BuildReport, Tasks)
    if not Ok then
      env.error("[Ostwind] Lagebericht fehlgeschlagen: " .. tostring(Text))
      Text = "Lagebericht nicht verfügbar."
    end
    MESSAGE:New(Text, 30):ToBlue()
  end)
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not Cfg.Enabled then
    OSTWIND.Log("Tasks sind in der Config abgeschaltet")
    return
  end
  if not Zones then
    env.error("[Ostwind] 09_Tasks braucht 03_Zones.lua", true)
    return
  end
  if not PLAYERTASKCONTROLLER then
    env.error("[Ostwind] PLAYERTASKCONTROLLER fehlt in MOOSE", true)
    return
  end

  Tasks:_SetupReport()
  Tasks:_SetupGround()
  Tasks:_SetupAir()

  OSTWIND.Log(string.format("Tasks: Boden %s, Luft %s, Lagebericht %s",
    tostring(Tasks.Ground ~= nil), tostring(Tasks.Air ~= nil), tostring(Cfg.Report)))
end

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] Tasks-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Tasks geladen")
