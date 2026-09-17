--[[
  Operation Ostwind - 10_Save.lua

  Entscheidet, WANN gespeichert wird. Das Schreiben selbst macht
  02_Persistence.lua.

  Gespeichert wird:
    - regelmäßig alle Save.Interval Sekunden
    - kurz nach jedem Besitzerwechsel einer Zone und nach dem Sieg
      (Save.OnCapture). Mehrere Ereignisse innerhalb von Save.EventDelay
      Sekunden ergeben nur eine Speicherung.
    - beim Missionsende, dann auch der CTLD-Stand
    - auf Wunsch über das F10-Menü "Kampagne > Stand speichern" (Save.Menu)

  Muss als letztes Skript geladen werden, damit alle Module
  bei der Persistence angemeldet sind.

  Andere Skripte nutzen:
    OSTWIND.Save:Now(Reason)      -> sofort speichern
    OSTWIND.Save:Request(Reason)  -> verzögert speichern (entprellt)

  Benötigt: 01 bis 03, MOOSE (TIMER, MESSAGE)
]]

local Cfg = OSTWIND.Config.Save

local Save = {
  Pending = false,
  Count   = 0,
}
OSTWIND.Save = Save

function Save:Now(Reason)
  self.Pending = false
  local Ok, Result = pcall(OSTWIND.Persistence.Save, OSTWIND.Persistence)
  if not Ok then
    env.error("[Ostwind] Speichern fehlgeschlagen (" .. tostring(Reason) .. "): " .. tostring(Result))
    return false
  end
  if Result then
    self.Count = self.Count + 1
    OSTWIND.Debug("Gespeichert: " .. tostring(Reason))
  end
  return Result
end

function Save:Request(Reason)
  if self.Pending then
    return
  end
  self.Pending = true
  TIMER:New(function() Save:Now(Reason) end):Start(Cfg.EventDelay)
end

local function OnMissionEnd()
  Save:Now("Missionsende")
  if OSTWIND.CTLD and OSTWIND.CTLD.SaveNow then
    local Ok, Err = pcall(OSTWIND.CTLD.SaveNow, OSTWIND.CTLD)
    if not Ok then
      env.error("[Ostwind] CTLD-Speichern beim Missionsende fehlgeschlagen: " .. tostring(Err))
    end
  end
end

local function SetupMenu()
  local Root = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "Kampagne")
  missionCommands.addCommandForCoalition(coalition.side.BLUE, "Stand speichern", Root, function()
    if Save:Now("F10-Menü") then
      MESSAGE:New("Kampagne gespeichert.", 10):ToBlue()
    else
      MESSAGE:New("Speichern nicht möglich. Details im dcs.log.", 10):ToBlue()
    end
  end)
end

local function Init()
  if not OSTWIND.Persistence:IsEnabled() then
    OSTWIND.Log("Save: Speichern nicht aktiv, keine Zeitgeber")
    return
  end

  -- Regelmäßig
  TIMER:New(function() Save:Now("Intervall") end):Start(Cfg.Interval, Cfg.Interval)

  -- Bei Ereignissen der Zonen
  if Cfg.OnCapture and OSTWIND.Zones then
    OSTWIND.Zones:On("Captured", function(Name) Save:Request("Zone " .. Name) end)
    OSTWIND.Zones:On("Victory", function() Save:Request("Sieg") end)
  end

  -- Beim Missionsende
  world.addEventHandler({
    onEvent = function(_, Event)
      if Event and Event.id == world.event.S_EVENT_MISSION_END then
        OnMissionEnd()
      end
    end,
  })

  if Cfg.Menu then
    SetupMenu()
  end

  OSTWIND.Log(string.format("Save: alle %d s, bei Eroberung %s, Menü %s",
    Cfg.Interval, tostring(Cfg.OnCapture), tostring(Cfg.Menu)))
end

local Ok, Err = pcall(Init)
if not Ok then
  env.error("[Ostwind] Save-Start fehlgeschlagen: " .. tostring(Err), true)
end

OSTWIND.Log("Save geladen, Operation Ostwind " .. OSTWIND.Version .. " bereit")
