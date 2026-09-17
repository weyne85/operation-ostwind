--[[
  Operation Ostwind - 07_Carrier.lua

  Carrier Strike Group mit MOOSE AIRBOSS:
    - AIRBOSS: Marshal, LSO, Bewertung der Landungen, Funk mit Sprachdateien
    - Recovery-Tanker (RECOVERYTANKER)
    - AWACS (RECOVERYTANKER im AWACS-Modus)
    - Rettungshubschrauber (RESCUEHELO)
    - Zufällige KI-Flüge von und zum Träger (RAT)

  Der Träger dreht sich NICHT selbständig in den Wind:
    - Alle Recovery-Fenster werden mit "turnintowind = false" angelegt.
    - Das F10-Menü zum Starten einer Recovery (SetMenuRecovery) bleibt aus,
      weil es den Träger in den Wind drehen würde.
    - Der Träger fährt dauerhaft seine Route aus dem Editor (Patrouille).

  Andere Skripte nutzen:
    OSTWIND.Carrier.Airboss   -> AIRBOSS-Objekt oder nil
    OSTWIND.Carrier.Tanker    -> RECOVERYTANKER oder nil
    OSTWIND.Carrier.AWACS     -> RECOVERYTANKER oder nil
    OSTWIND.Carrier.Helo      -> RESCUEHELO oder nil
    OSTWIND.Carrier.RAT       -> Liste der RAT-Objekte

  Voraussetzungen im Editor: siehe README, Abschnitt "Carrier Strike Group".

  Benötigt: 01_Config.lua, MOOSE (AIRBOSS, RECOVERYTANKER, RESCUEHELO, RAT)
]]

local Cfg = OSTWIND.Config.Carrier

local Carrier = {
  Airboss = nil,
  Tanker  = nil,
  AWACS   = nil,
  Helo    = nil,
  RAT     = {},
}
OSTWIND.Carrier = Carrier

-- Prüft, ob eine Gruppe im Editor existiert
local function GroupExists(Name)
  if GROUP:FindByName(Name) then
    return true
  end
  env.error("[Ostwind] Carrier: Vorlage fehlt im Editor: " .. tostring(Name))
  return false
end

---------------------------------------------------------------------------
-- AIRBOSS
---------------------------------------------------------------------------

local function SetupAirboss(CarrierUnit)
  local Boss = AIRBOSS:New(Cfg.UnitName, Cfg.Alias)
  if not Boss then
    return nil
  end

  -- Träger fährt dauerhaft seine Route, ohne am letzten Wegpunkt zu stoppen
  Boss:SetPatrolAdInfinitum(true)

  -- Kein F10-Menü zum Starten einer Recovery. Es würde den Träger in den Wind drehen.
  Boss.skipperMenu = false

  Boss:SetSoundfilesFolder(Cfg.SoundFolder)
  Boss:SetMarshalRadio(Cfg.MarshalRadio.Freq, Cfg.MarshalRadio.Mod)
  Boss:SetLSORadio(Cfg.LSORadio.Freq, Cfg.LSORadio.Mod)
  Boss:SetTACAN(Cfg.TACAN.Channel, Cfg.TACAN.Mode, Cfg.TACAN.Morse)
  Boss:SetICLS(Cfg.ICLS.Channel, Cfg.ICLS.Morse)
  Boss:SetDefaultPlayerSkill(AIRBOSS.Difficulty[Cfg.Skill] or AIRBOSS.Difficulty.NORMAL)
  Boss:SetMenuSingleCarrier(true)
  Boss:SetHandleAION()
  Boss:SetDespawnOnEngineShutdown(true)
  Boss:SetWelcomePlayers(true)

  -- Recovery-Fenster: IMMER ohne Drehung in den Wind (5. Parameter = false)
  local Rec = Cfg.Recovery
  if #Rec.Windows == 0 then
    -- Ein Fenster über 7 Tage: Das Deck ist die ganze Mission offen.
    Boss:AddRecoveryWindow(15, 7 * 24 * 3600, Rec.Case, Rec.Offset, false, nil, false)
    OSTWIND.Log(string.format("Carrier: Deck durchgehend offen, Case %d, ohne Wind-Drehung", Rec.Case))
  else
    for _, W in ipairs(Rec.Windows) do
      Boss:AddRecoveryWindow(W.Start, W.Stop, W.Case or Rec.Case, W.Offset or Rec.Offset, false, nil, false)
      OSTWIND.Log(string.format("Carrier: Recovery %s bis %s, Case %d, ohne Wind-Drehung",
        tostring(W.Start), tostring(W.Stop), W.Case or Rec.Case))
    end
  end

  -- LSO-Noten laden und nach jeder Landung speichern
  if Cfg.SaveGrades and OSTWIND.Persistence:IsEnabled() then
    local Folder = OSTWIND.Persistence.Path:match("^(.*)[/\\][^/\\]+$")
    local File = "Ostwind_LSO_Noten.csv"
    Boss:SetAutoSave(Folder, File)
    -- Nur laden, wenn es die Datei schon gibt. Sonst meldet AIRBOSS einen Fehler.
    if lfs.attributes(Folder .. "\\" .. File) then
      Boss:Load(Folder, File)
    end
  end

  return Boss
end

---------------------------------------------------------------------------
-- Tanker, AWACS, Rettungshubschrauber
---------------------------------------------------------------------------

local function SetupTanker(CarrierUnit)
  local T = Cfg.Tanker
  if not T.Enabled or not GroupExists(T.Template) then
    return nil
  end
  local Tanker = RECOVERYTANKER:New(CarrierUnit, T.Template)
  Tanker:SetTakeoffHot()
  Tanker:SetRespawnOn()
  Tanker:SetRadio(T.Freq, "AM")
  Tanker:SetTACAN(T.TACAN.Channel, T.TACAN.Morse, T.TACAN.Mode)
  Tanker:SetAltitude(T.Altitude)
  Tanker:SetSpeed(T.Speed)
  Tanker:SetModex(T.Modex)
  -- Landung übernimmt der AIRBOSS
  Tanker:SetRecoveryAirboss(true)
  Tanker:Start()
  OSTWIND.Log(string.format("Carrier: Tanker gestartet, %.1f MHz, TACAN %d%s",
    T.Freq, T.TACAN.Channel, T.TACAN.Mode))
  return Tanker
end

local function SetupAWACS(CarrierUnit)
  local A = Cfg.AWACS
  if not A.Enabled or not GroupExists(A.Template) then
    return nil
  end
  local Awacs = RECOVERYTANKER:New(CarrierUnit, A.Template)
  Awacs:SetAWACS(true, true)
  Awacs:SetTakeoffHot()
  Awacs:SetRespawnOn()
  Awacs:SetRadio(A.Freq, "AM")
  Awacs:SetTACANoff()
  Awacs:SetAltitude(A.Altitude)
  Awacs:SetSpeed(A.Speed)
  Awacs:SetRacetrackDistances(A.Distance.Bow, A.Distance.Stern)
  Awacs:SetModex(A.Modex)
  Awacs:SetRecoveryAirboss(true)
  Awacs:Start()
  OSTWIND.Log(string.format("Carrier: AWACS gestartet, %.1f MHz", A.Freq))
  return Awacs
end

local function SetupHelo(CarrierUnit)
  local H = Cfg.Helo
  if not H.Enabled or not GroupExists(H.Template) then
    return nil
  end
  local Helo = RESCUEHELO:New(CarrierUnit, H.Template)
  Helo:SetTakeoffHot()
  Helo:SetRespawnOn()
  Helo:SetModex(H.Modex)
  Helo:Start()
  OSTWIND.Log("Carrier: Rettungshubschrauber gestartet")
  return Helo
end

---------------------------------------------------------------------------
-- Zufällige Flüge
---------------------------------------------------------------------------

-- RAT braucht für Start und Ziel verschiedene Orte. Deshalb gibt es je
-- Vorlage zwei RAT-Objekte: Land -> Träger und Träger -> Land.
local function SetupRandomFlights()
  local R = Cfg.RandomFlights
  if not R.Enabled then
    return
  end

  for i, Template in ipairs(R.Templates) do
    if GroupExists(Template) then
      if R.Inbound.PerTemplate > 0 then
        local In = RAT:New(Template, string.format("CVN_In_%d", i))
        In:SetCoalition("sameonly")
        In:SetDeparture(R.Inbound.From)
        In:SetDestination(Cfg.UnitName)
        In:SetTakeoff(R.Inbound.Takeoff)
        In:SetSpawnDelay(R.SpawnDelay)
        In:SetSpawnInterval(R.SpawnInterval)
        In:SetROE("hold")
        In:RadioOFF()
        In:Spawn(R.Inbound.PerTemplate)
        table.insert(Carrier.RAT, In)
      end

      if R.Outbound.PerTemplate > 0 then
        local Out = RAT:New(Template, string.format("CVN_Out_%d", i))
        Out:SetCoalition("sameonly")
        Out:SetDeparture(Cfg.UnitName)
        Out:SetDestination(R.Outbound.To)
        Out:SetTakeoff(R.Outbound.Takeoff)
        Out:SetSpawnDelay(R.SpawnDelay + R.SpawnInterval / 2)
        Out:SetSpawnInterval(R.SpawnInterval)
        Out:SetROE("hold")
        Out:RadioOFF()
        Out:Spawn(R.Outbound.PerTemplate)
        table.insert(Carrier.RAT, Out)
      end
    end
  end

  OSTWIND.Log(string.format("Carrier: %d RAT-Gruppen für Zufallsflüge", #Carrier.RAT))
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function Init()
  if not Cfg.Enabled then
    OSTWIND.Log("Carrier ist in der Config abgeschaltet")
    return
  end
  if not AIRBOSS then
    env.error("[Ostwind] AIRBOSS fehlt. Ist 00_Moose.lua vor den Skripten geladen?", true)
    return
  end

  local CarrierUnit = UNIT:FindByName(Cfg.UnitName)
  if not CarrierUnit then
    env.error("[Ostwind] Träger-Einheit fehlt im Editor: " .. Cfg.UnitName, true)
    return
  end

  Carrier.Airboss = SetupAirboss(CarrierUnit)
  if not Carrier.Airboss then
    env.error("[Ostwind] AIRBOSS konnte nicht angelegt werden. Ist "
      .. Cfg.UnitName .. " ein unterstützter Träger?", true)
    return
  end

  Carrier.Tanker = SetupTanker(CarrierUnit)
  Carrier.AWACS  = SetupAWACS(CarrierUnit)
  Carrier.Helo   = SetupHelo(CarrierUnit)

  if Carrier.Tanker then
    Carrier.Airboss:SetRecoveryTanker(Carrier.Tanker)
  end
  if Carrier.AWACS then
    Carrier.Airboss:SetAWACS(Carrier.AWACS)
  end

  Carrier.Airboss:Start()

  SetupRandomFlights()

  OSTWIND.Log("Carrier: " .. Cfg.Alias .. " bereit")
end

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] Carrier-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Carrier geladen")
