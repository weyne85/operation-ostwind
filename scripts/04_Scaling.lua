--[[
  Operation Ostwind - 04_Scaling.lua

  Zählt regelmäßig die blauen Spieler und legt die Schwierigkeitsstufe fest.

  Andere Skripte nutzen:
    OSTWIND.Scaling:GetTier()          -> aktuelle Stufe (Tabelle aus der Config)
    OSTWIND.Scaling:GetPlayers()       -> zuletzt gezählte Spieler
    OSTWIND.Scaling:GetRedFactor()     -> Faktor für rote Spawns
    OSTWIND.Scaling:GetBlueFactor()    -> Faktor für blaue KI-Spawns
    OSTWIND.Scaling:Scale(Base, Side)  -> Grundwert skaliert und gerundet, mindestens 1
    OSTWIND.Scaling:OnChange(Func)     -> Func(NeueStufe, AlteStufe) bei Wechsel

  Benötigt: 01_Config.lua, MOOSE (TIMER, MESSAGE)
]]

local Cfg = OSTWIND.Config.Scaling

local Scaling = {
  Tier      = nil,   -- aktuelle Stufe
  Candidate = nil,   -- zuletzt gemessene, noch nicht bestätigte Stufe
  Count     = 0,     -- wie oft der Kandidat hintereinander gemessen wurde
  Players   = 0,
  Listeners = {},
}

-- Anzahl blauer Spieler. Solo zählt der eigene Slot mit.
local function CountBluePlayers()
  local Players = coalition.getPlayers(coalition.side.BLUE)
  return Players and #Players or 0
end

-- Passende Stufe zur Spielerzahl
local function TierFor(Players)
  for _, Tier in ipairs(Cfg.Tiers) do
    if Players <= Tier.MaxPlayers then
      return Tier
    end
  end
  return Cfg.Tiers[#Cfg.Tiers]
end

function Scaling:GetTier()
  return self.Tier
end

function Scaling:GetPlayers()
  return self.Players
end

function Scaling:GetRedFactor()
  return self.Tier.RedFactor
end

function Scaling:GetBlueFactor()
  return self.Tier.BlueFactor
end

-- Side: "red" oder "blue"
function Scaling:Scale(Base, Side)
  local Factor = (Side == "blue") and self:GetBlueFactor() or self:GetRedFactor()
  return math.max(1, math.floor(Base * Factor + 0.5))
end

function Scaling:OnChange(Func)
  table.insert(self.Listeners, Func)
end

function Scaling:_SetTier(NewTier)
  local OldTier = self.Tier
  self.Tier = NewTier

  OSTWIND.Log(string.format("Stufe: %s (%d Spieler)", NewTier.Name, self.Players))
  if OldTier then
    MESSAGE:New(string.format("Lagebild: Feindaktivität jetzt %s.", NewTier.Name), 15):ToBlue()
  end

  for _, Func in ipairs(self.Listeners) do
    local Ok, Err = pcall(Func, NewTier, OldTier)
    if not Ok then
      env.error("[Ostwind] Scaling-Listener: " .. tostring(Err))
    end
  end
end

function Scaling:Check()
  self.Players = CountBluePlayers()
  local Measured = TierFor(self.Players)

  if Measured == self.Tier then
    self.Candidate, self.Count = nil, 0
    return
  end

  -- Neue Stufe erst übernehmen, wenn sie mehrfach hintereinander gemessen wurde.
  -- So springt die Stufe nicht, wenn ein Spieler kurz den Slot wechselt.
  if Measured == self.Candidate then
    self.Count = self.Count + 1
  else
    self.Candidate, self.Count = Measured, 1
  end

  OSTWIND.Debug(string.format("Spieler: %d, Kandidat: %s (%d/%d)",
    self.Players, Measured.Name, self.Count, Cfg.StableChecks))

  if self.Count >= Cfg.StableChecks then
    self.Candidate, self.Count = nil, 0
    self:_SetTier(Measured)
  end
end

-- Start: sofort eine Stufe setzen, damit andere Skripte beim Laden einen Wert haben.
-- Beim Missionsstart sitzt oft noch niemand im Slot, daher gilt meist die erste Stufe.
Scaling.Players = CountBluePlayers()
Scaling:_SetTier(TierFor(Scaling.Players))

Scaling.Timer = TIMER:New(function() Scaling:Check() end)
Scaling.Timer:Start(Cfg.CheckInterval, Cfg.CheckInterval)

OSTWIND.Scaling = Scaling
OSTWIND.Log("Scaling geladen")
