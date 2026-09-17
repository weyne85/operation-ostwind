--[[
  Operation Ostwind - 08_CTLD.lua

  Truppen und Fracht mit MOOSE CTLD für Chinook, Hind und Apache.

  So erobert Blau Zonen:
    Truppen oder gebaute Fahrzeuge in einer Frontzone absetzen. Sind dort
    keine roten Bodeneinheiten mehr, wechselt die Zone nach 60 Sekunden
    den Besitzer (03_Zones.lua).

  Zonen:
    - Ladezonen: Jede Frontzone ist Ladezone, solange sie blau ist.
      Dazu der Träger, falls in der Config eingeschaltet.
    - Zielzonen (MOVE): Die Zonen der aktuellen Phase. Abgesetzte Truppen
      laufen selbst hinein, wenn sie nah genug abgesetzt wurden.
    Im Editor sind dafür keine zusätzlichen Zonen nötig.

  Speichern:
    CTLD speichert abgesetzte Truppen und gebaute Fahrzeuge selbst in
    "Ostwind_CTLD.csv" im Speicherordner. Bei einer neuen Kampagne wird
    die Datei nicht geladen und beim nächsten Speichern überschrieben.

  Andere Skripte nutzen:
    OSTWIND.CTLD.Object       -> MOOSE CTLD oder nil
    OSTWIND.CTLD:UpdateZones() -> Zonen neu schalten
    OSTWIND.CTLD:SaveNow()     -> CTLD-Stand sofort schreiben (nur bei Missionsende)

  Benötigt: 01 bis 03, MOOSE (CTLD, CTLD_CARGO, ZONE, GROUP)
]]

local Cfg   = OSTWIND.Config.CTLD
local Zones = OSTWIND.Zones
local BLUE  = coalition.side.BLUE

local Transport = {
  Object   = nil,
  Folder   = nil,
  FileName = "Ostwind_CTLD.csv",
}
OSTWIND.CTLD = Transport

local function TemplateExists(Name)
  if GROUP:FindByName(Name) then
    return true
  end
  env.error("[Ostwind] CTLD: Vorlage fehlt im Editor: " .. tostring(Name))
  return false
end

---------------------------------------------------------------------------
-- Zonen schalten
---------------------------------------------------------------------------

function Transport:UpdateZones()
  local Ctld = self.Object
  if not Ctld then
    return
  end
  local Active = Zones:GetActivePhase()
  for _, Name in ipairs(Zones:GetAllZones()) do
    local IsBlue = Zones:GetOwner(Name) == BLUE
    Ctld:ActivateZone(Name, CTLD.CargoZoneType.LOAD, IsBlue)
    local IsTarget = (not IsBlue) and Active ~= nil and Zones:GetPhase(Name) == Active
    Ctld:ActivateZone(Name, CTLD.CargoZoneType.MOVE, IsTarget)
  end
end

---------------------------------------------------------------------------
-- Speichern
---------------------------------------------------------------------------

-- Nur bei Missionsende aufrufen. CTLD plant nach jedem Speichern das
-- nächste selbst ein, häufige Aufrufe würden die Zeitgeber vervielfachen.
function Transport:SaveNow()
  if self.Object and self.Object.enableLoadSave then
    self.Object:Save(self.Folder, self.FileName)
  end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not Cfg.Enabled then
    OSTWIND.Log("CTLD ist in der Config abgeschaltet")
    return
  end
  if not CTLD then
    env.error("[Ostwind] CTLD fehlt in MOOSE", true)
    return
  end
  if not Zones then
    env.error("[Ostwind] 08_CTLD braucht 03_Zones.lua", true)
    return
  end

  local Ctld = CTLD:New("blue", Cfg.Prefixes, "Ostwind Logistik")
  Ctld.movetroopstowpzone  = true
  Ctld.movetroopsdistance  = Cfg.MoveDistance
  Ctld.buildtime           = Cfg.BuildTime
  -- Kisten müssen einem Land der blauen Koalition gehören
  Ctld.cratecountry        = country.id.USA

  -- Fracht
  local NTroops, NCrates = 0, 0
  for _, T in ipairs(Cfg.Troops) do
    if TemplateExists(T.Template) then
      local Kind = T.Engineers and CTLD_CARGO.Enum.ENGINEERS or CTLD_CARGO.Enum.TROOPS
      Ctld:AddTroopsCargo(T.Name, { T.Template }, Kind, T.Count, T.Mass)
      NTroops = NTroops + 1
    end
  end
  for _, C in ipairs(Cfg.Crates) do
    if TemplateExists(C.Template) then
      Ctld:AddCratesCargo(C.Name, { C.Template }, CTLD_CARGO.Enum.VEHICLE, C.Crates, C.Mass)
      NCrates = NCrates + 1
    end
  end

  -- Zonen: alle Frontzonen einmal anlegen, geschaltet wird in UpdateZones
  for _, Name in ipairs(Zones:GetAllZones()) do
    Ctld:AddCTLDZone(Name, CTLD.CargoZoneType.LOAD, SMOKECOLOR.Blue, false, false)
    Ctld:AddCTLDZone(Name, CTLD.CargoZoneType.MOVE, SMOKECOLOR.Orange, false, false)
  end

  local Ship = Cfg.ShipZone
  local CarrierName = OSTWIND.Config.Carrier and OSTWIND.Config.Carrier.UnitName
  if Ship.Enabled and CarrierName and UNIT:FindByName(CarrierName) then
    Ctld:AddCTLDZone(CarrierName, CTLD.CargoZoneType.SHIP, SMOKECOLOR.Blue, true, false, Ship.Length, Ship.Width)
  end

  -- Speichern
  local Persistence = OSTWIND.Persistence
  if Persistence:IsEnabled() then
    Transport.Folder = Persistence.Path:match("^(.*)[/\\][^/\\]+$")
    Ctld.enableLoadSave = true
    Ctld.filepath       = Transport.Folder
    Ctld.filename       = Transport.FileName
    Ctld.saveinterval   = OSTWIND.Config.Save.Interval
  end

  Transport.Object = Ctld
  Transport:UpdateZones()

  Zones:On("Captured", function() Transport:UpdateZones() end)
  Zones:On("PhaseChanged", function() Transport:UpdateZones() end)

  Ctld:__Start(2)

  -- Stand nur laden, wenn die Kampagne weiterläuft und die Datei existiert
  if Ctld.enableLoadSave and not Persistence:IsNewCampaign()
    and lfs.attributes(Transport.Folder .. "\\" .. Transport.FileName) then
    Ctld:__Load(10, Transport.Folder, Transport.FileName)
    OSTWIND.Log("CTLD: Stand wird geladen")
  end

  OSTWIND.Log(string.format("CTLD: %d Truppenarten, %d Kistenarten, %d Zonen",
    NTroops, NCrates, #Zones:GetAllZones()))
end

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] CTLD-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("CTLD geladen")
