-- ZombieSurvival AllInOne - один скрипт который ставит всю карту и игру
-- Кинь этот Script в ServerScriptService и запусти Play

print("[AllInOne] Starting Zombie Survival setup...")

-- Требует чтобы остальные модули были рядом, но если нет - встроенный фолбек

local serverFolder = script.Parent
-- MapBuilder
require(script.Parent:FindFirstChild("Map") and script.Parent.Map:FindFirstChild("MapBuilder") or game.ServerScriptService:FindFirstChild("MapBuilder") or { } )
