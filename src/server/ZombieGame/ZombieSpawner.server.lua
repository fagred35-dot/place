-- ZombieSurvival / ZombieSpawner.server.lua
-- Спавнит зомби волнами, управляет AI

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local CONFIG_MODULE = script.Parent:FindFirstChild("ZombieConfig") or RS:FindFirstChild("ZombieConfig")
local ZombieConfig
if script.Parent:FindFirstChild("ZombieConfig") then
    ZombieConfig = require(script.Parent.ZombieConfig)
else
    -- fallback если модуль в другом месте
    local ok, mod = pcall(function() return require(RS:WaitForChild("Shared"):WaitForChild("ZombieGame"):WaitForChild("ZombieConfig")) end)
    if ok then ZombieConfig = mod else ZombieConfig = require(workspace:FindFirstChild("ZombieMap") and script.Parent.ZombieConfig or script.Parent.ZombieConfig) end
end
-- Попытка загрузить напрямую
pcall(function() ZombieConfig = require(script.Parent:FindFirstChild("ZombieConfig") or script.Parent.Parent.Parent.Weapons:FindFirstChild("WeaponConfig") and script.Parent.ZombieConfig) end)
if not ZombieConfig or not ZombieConfig.Types then
    -- Если не нашел, используем встроенный
    ZombieConfig = {
        Types = {
            Walker={Name="Walker",Health=100,Damage=18,WalkSpeed=10,Scale=1,Color=Color3.fromRGB(85,170,85),Points=10,Cash=15},
            Runner={Name="Runner",Health=65,Damage=12,WalkSpeed=18,Scale=0.95,Color=Color3.fromRGB(255,200,100),Points=20,Cash=25},
            Tank={Name="Tank",Health=350,Damage=35,WalkSpeed=8,Scale=1.35,Color=Color3.fromRGB(120,120,120),Points=50,Cash=60},
        },
        WaveConfig={StartingZombies=6,ZombiesPerWaveGrowth=2.5,Intermission=12,MaxAlive=35,SpawnDelay=0.8},
        GetDifficultyMultiplier=function(w) return 1+(w-1)*0.12 end,
        GetRandomType=function(w) local p={"Walker","Walker","Runner"} if w>=4 then table.insert(p,"Tank") end return p[math.random(1,#p)] end
    }
end

-- Глобальное состояние
local activeZombies = {} -- {model}
local waveNumber = 0
local zombiesSpawnedThisWave = 0
local zombiesToSpawn = 0
local gameActive = true

local function getZombieSpawns()
    local map = workspace:FindFirstChild("ZombieMap")
    if not map then return {} end
    local spawnsFolder = map:FindFirstChild("ZombieSpawns")
    if not spawnsFolder then return {} end
    local spawns = {}
    for _,sp in ipairs(spawnsFolder:GetChildren()) do if sp:IsA("BasePart") then table.insert(spawns, sp) end end
    return spawns
end

local function getNearestPlayer(pos)
    local nearest = nil
    local bestDist = math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChildOfClass("Humanoid") and plr.Character.Humanoid.Health>0 then
            local d = (plr.Character.HumanoidRootPart.Position - pos).Magnitude
            if d < bestDist then
                bestDist = d
                nearest = plr
            end
        end
    end
    return nearest, bestDist
end

-- Создать модель зомби (R6 упрощенная)
local function createZombieModel(zTypeName, spawnCF)
    local typeCfg = ZombieConfig.Types[zTypeName] or ZombieConfig.Types.Walker
    local mult = ZombieConfig.GetDifficultyMultiplier and ZombieConfig.GetDifficultyMultiplier(waveNumber) or 1

    local model = Instance.new("Model")
    model.Name = "Zombie_"..typeCfg.Name

    -- Humanoid
    local hum = Instance.new("Humanoid")
    hum.Name = "Humanoid"
    hum.MaxHealth = math.floor(typeCfg.Health * mult)
    hum.Health = hum.MaxHealth
    hum.WalkSpeed = typeCfg.WalkSpeed
    hum.Parent = model

    -- Root
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2,2,1) * typeCfg.Scale
    hrp.CFrame = spawnCF + Vector3.new(0,3,0)
    hrp.Color = typeCfg.Color
    hrp.Material = Enum.Material.Slate
    hrp.Anchored = false
    hrp.CanCollide = true
    hrp.Parent = model
    model.PrimaryPart = hrp

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2,1,1) * typeCfg.Scale
    head.CFrame = hrp.CFrame * CFrame.new(0,1.5,0)
    head.Color = typeCfg.Color
    head.Material = Enum.Material.Slate
    head.Parent = model

    -- Torso
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2,2,1) * typeCfg.Scale
    torso.CFrame = hrp.CFrame
    torso.Color = typeCfg.Color
    torso.Material = Enum.Material.Slate
    torso.Parent = model

    -- Welds
    local function weld(p0,p1,c0,c1)
        local w = Instance.new("WeldConstraint")
        w.Part0 = p0; w.Part1 = p1
        w.Parent = p0
        p1.CFrame = p0.CFrame * (c0 or CFrame.new()) * (c1 or CFrame.new()):Inverse()
        return w
    end
    weld(hrp, torso, CFrame.new(), CFrame.new())
    weld(torso, head, CFrame.new(0,1,0), CFrame.new())

    -- Face tag
    local bg = Instance.new("BillboardGui", head)
    bg.Size = UDim2.fromOffset(30,20)
    bg.StudsOffset = Vector3.new(0,2.5,0)
    bg.AlwaysOnTop = false
    local lb = Instance.new("TextLabel", bg)
    lb.Size=UDim2.fromScale(1,1); lb.BackgroundTransparency=1; lb.Text = typeCfg.Name; lb.TextColor3=Color3.new(1,0,0); lb.Font=Enum.Font.GothamBold; lb.TextSize=10

    -- Stats attributes
    model:SetAttribute("ZombieType", zTypeName)
    model:SetAttribute("Damage", typeCfg.Damage)
    model:SetAttribute("Cash", typeCfg.Cash)
    model:SetAttribute("Points", typeCfg.Points)
    model:SetAttribute("IsExploder", typeCfg.Explodes or false)

    model.Parent = workspace

    -- Setup network owner nil for server control
    pcall(function() hrp:SetNetworkOwner(nil) end)

    return model
end

local function dealDamageToPlayers(zombieModel)
    local root = zombieModel.PrimaryPart or zombieModel:FindFirstChild("HumanoidRootPart")
    local hum = zombieModel:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then return end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
            local dist = (char.HumanoidRootPart.Position - root.Position).Magnitude
            if dist < 6 then
                char.Humanoid:TakeDamage(zombieModel:GetAttribute("Damage") or 15)
            end
        end
    end
end

-- AI loop
RunService.Heartbeat:Connect(function()
    for i = #activeZombies, 1, -1 do
        local zm = activeZombies[i]
        if not zm or not zm.Parent or not zm:FindFirstChildOfClass("Humanoid") or zm.Humanoid.Health<=0 then
            table.remove(activeZombies, i)
        else
            local root = zm.PrimaryPart
            if not root then continue end
            local nearest, dist = getNearestPlayer(root.Position)
            if nearest and nearest.Character and nearest.Character:FindFirstChild("HumanoidRootPart") then
                local targetPos = nearest.Character.HumanoidRootPart.Position
                -- Simple pathfinding every 1 sec or if stuck
                if not zm:GetAttribute("LastPath") or tick() - zm:GetAttribute("LastPath") > 1.2 then
                    zm:SetAttribute("LastPath", tick())
                    pcall(function()
                        zm.Humanoid:MoveTo(targetPos)
                    end)
                end
                -- Damage
                if dist and dist < 7 then
                    dealDamageToPlayers(zm)
                    -- Exploder logic
                    if zm:GetAttribute("IsExploder") and dist < 8 then
                        local exp = Instance.new("Explosion")
                        exp.BlastRadius = 12
                        exp.BlastPressure = 0
                        exp.Position = root.Position
                        exp.Parent = workspace
                        exp.Hit:Connect(function(part, dist2)
                            local plrChar = part.Parent
                            local hum = plrChar and plrChar:FindFirstChildOfClass("Humanoid")
                            if hum then hum:TakeDamage(60) end
                        end)
                        zm.Humanoid.Health = 0
                    end
                end
            end
        end
    end
end)

-- Spawner loop
local function spawnZombieAtRandom()
    local spawns = getZombieSpawns()
    if #spawns==0 then
        warn("[ZombieSpawner] No spawns found!")
        return nil
    end
    local sp = spawns[math.random(1,#spawns)]
    local tName = ZombieConfig.GetRandomType and ZombieConfig.GetRandomType(waveNumber) or "Walker"
    local zm = createZombieModel(tName, sp.CFrame)
    table.insert(activeZombies, zm)
    -- On death give rewards
    zm.Humanoid.Died:Connect(function()
        task.wait(0.1)
        local cash = zm:GetAttribute("Cash") or 10
        -- Find killer? For simplicity give to all
        for _,plr in ipairs(Players:GetPlayers()) do
            local ls = plr:FindFirstChild("leaderstats")
            local cashVal = ls and ls:FindFirstChild("Cash")
            if cashVal then cashVal.Value += cash end
            local kills = ls and ls:FindFirstChild("Kills")
            if kills then kills.Value += 1 end
        end
        -- Remove after delay
        game:GetService("Debris"):AddItem(zm, 5)
    end)
    return zm
end

-- Wave manager
local function startWave(wave)
    waveNumber = wave
    zombiesToSpawn = math.floor(ZombieConfig.WaveConfig.StartingZombies + (wave-1)*ZombieConfig.WaveConfig.ZombiesPerWaveGrowth)
    zombiesSpawnedThisWave = 0
    print("[ZombieSpawner] Wave "..wave.." starting, to spawn: "..zombiesToSpawn)

    -- Notify clients
    local remotes = RS:FindFirstChild("ZombieRemotes")
    if remotes and remotes:FindFirstChild("WaveUpdate") then
        remotes.WaveUpdate:FireAllClients(wave, zombiesToSpawn)
    end

    while zombiesSpawnedThisWave < zombiesToSpawn and gameActive do
        if #activeZombies < (ZombieConfig.WaveConfig.MaxAlive or 35) then
            spawnZombieAtRandom()
            zombiesSpawnedThisWave += 1
        end
        task.wait(ZombieConfig.WaveConfig.SpawnDelay)
    end

    -- Wait until wave cleared
    repeat task.wait(1) until #activeZombies==0 or not gameActive
    print("[ZombieSpawner] Wave "..wave.." cleared!")
end

-- Main game loop
task.spawn(function()
    -- Wait for map
    while not workspace:FindFirstChild("ZombieMap") do task.wait(1) end
    task.wait(3)
    waveNumber = 0
    while gameActive do
        waveNumber += 1
        startWave(waveNumber)
        -- Intermission
        print("[ZombieSpawner] Intermission "..ZombieConfig.WaveConfig.Intermission.."s")
        for i=ZombieConfig.WaveConfig.Intermission,1,-1 do
            local remotes = RS:FindFirstChild("ZombieRemotes")
            if remotes and remotes:FindFirstChild("WaveUpdate") then
                remotes.WaveUpdate:FireAllClients(waveNumber, -i) -- negative = intermission countdown
            end
            task.wait(1)
        end
    end
end)

print("[ZombieSpawner] Loaded, waiting for map")
