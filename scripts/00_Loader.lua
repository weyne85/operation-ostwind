--[[
  Operation Ostwind - Loader (nur zum Entwickeln)

  Lädt die Skripte direkt aus dem Repo-Ordner. Änderungen greifen beim
  nächsten Missionsstart, ohne die Skripte neu in die .miz einzubinden.

  Voraussetzung: 'io' ist in MissionScripting.lua freigegeben.
  Für die fertige Mission diesen Loader NICHT verwenden, sondern alle
  Skripte einzeln per DO SCRIPT FILE einbinden.
]]

local ScriptPath = "C:/Users/Hausmeister/Downloads/operation ostwind/scripts/"

local Files = {
  "01_Config.lua",
  "02_Persistence.lua",
  "03_Zones.lua",
  "04_Scaling.lua",
  "05_Red.lua",
  "06_Blue.lua",
  "07_Carrier.lua",
  "08_CTLD.lua",
  "09_Tasks.lua",
  "10_Save.lua",
}

if not io then
  env.error("[Ostwind] Loader: 'io' ist gesperrt. MissionScripting.lua anpassen.", true)
  return
end

for _, File in ipairs(Files) do
  local FullPath = ScriptPath .. File
  local Handle = io.open(FullPath, "r")
  if Handle then
    Handle:close()
    local Ok, Err = pcall(dofile, FullPath)
    if Ok then
      env.info("[Ostwind] Geladen: " .. File)
    else
      env.error("[Ostwind] Fehler in " .. File .. ": " .. tostring(Err), true)
    end
  else
    env.info("[Ostwind] Übersprungen (fehlt noch): " .. File)
  end
end
