-- ZombieSurvival / WeaponBuilder.server.lua
-- Создает 10 инструментов в StarterPack и ReplicatedStorage с атрибутами, без нужды в Source

local RS = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

-- Ждем конфиг
local WeaponConfig
local configPath = script.Parent:FindFirstChild("WeaponConfig")
if configPath then
    WeaponConfig = require(configPath)
else
    -- пробуем из Shared
    local ok, mod = pcall(function() return require(RS.Shared.ZombieGame.WeaponConfig) end)
    if ok then WeaponConfig = mod else
        -- fallback встроенный
        WeaponConfig = {
            Pistol={Name="Pistol",DisplayName="🔫 Pistol",Damage=24,FireRate=0.35,Range=400,Ammo=12,Type="Gun",Color=Color3.fromRGB(50,50,50),Price=0},
            Shotgun={Name="Shotgun",DisplayName="💥 Shotgun",Damage=14,Pellets=8,FireRate=0.9,Range=80,Ammo=6,Type="Shotgun",Color=Color3.fromRGB(120,90,60),Price=400},
            AK47={Name="AK47",DisplayName="🔥 AK-47",Damage=28,FireRate=0.13,Range=500,Ammo=30,Type="Rifle",Color=Color3.fromRGB(90,50,20),Price=1200},
            Uzi={Name="Uzi",DisplayName="⚡ Uzi",Damage=16,FireRate=0.07,Range=250,Ammo=32,Type="SMG",Color=Color3.fromRGB(30,30,30),Price=800},
            Sniper={Name="Sniper",DisplayName="🎯 Sniper",Damage=120,FireRate=1.2,Range=1000,Ammo=5,Type="Sniper",Color=Color3.fromRGB(60,80,60),Price=2000},
            RPG={Name="RPG",DisplayName="💣 RPG",Damage=180,FireRate=1.8,Range=600,Ammo=1,Type="Explosive",Color=Color3.fromRGB(80,120,50),Price=3500},
            Bat={Name="Bat",DisplayName="🏏 Bat",Damage=38,FireRate=0.6,Range=10,Ammo=-1,Type="Melee",Color=Color3.fromRGB(140,100,60),Price=150},
            Katana={Name="Katana",DisplayName="⚔️ Katana",Damage=55,FireRate=0.45,Range=12,Ammo=-1,Type="Melee",Color=Color3.fromRGB(200,200,220),Price=900},
            Flamethrower={Name="Flamethrower",DisplayName="🔥 Flamethrower",Damage=8,FireRate=0.05,Range=70,Ammo=150,Type="Flame",Color=Color3.fromRGB(200,50,0),Price=2800},
            RayGun={Name="RayGun",DisplayName="👽 RayGun",Damage=75,FireRate=0.5,Range=800,Ammo=10,Type="Laser",Color=Color3.fromRGB(100,255,255),Price=5000},
            Order={"Pistol","Bat","Uzi","Shotgun","Katana","AK47","Sniper","Flamethrower","RPG","RayGun"}
        }
    end
end

local function ensureFolders()
    local wepFolder = RS:FindFirstChild("Weapons")
    if not wepFolder then
        wepFolder = Instance.new("Folder", RS)
        wepFolder.Name = "Weapons"
    end
    local remoteFolder = RS:FindFirstChild("ZombieRemotes")
    if not remoteFolder then
        remoteFolder = Instance.new("Folder", RS)
        remoteFolder.Name = "ZombieRemotes"
    end
    for _,name in ipairs({"WeaponFire","Reload","BuyWeapon","WaveUpdate"}) do
        if not remoteFolder:FindFirstChild(name) then
            Instance.new("RemoteEvent", remoteFolder).Name = name
        end
    end
    return wepFolder
end

local function createTool(weaponName, cfg)
    local tool = Instance.new("Tool")
    tool.Name = cfg.DisplayName or weaponName
    tool.ToolTip = cfg.Name.." - Dmg:"..cfg.Damage.." | Ammo:"..(cfg.Ammo==-1 and "INF" or cfg.Ammo)
    tool.RequiresHandle = true
    tool.CanBeDropped = true
    tool.ManualActivationOnly = false

    -- Attributes for client handler
    tool:SetAttribute("WeaponName", weaponName)
    tool:SetAttribute("Damage", cfg.Damage)
    tool:SetAttribute("FireRate", cfg.FireRate)
    tool:SetAttribute("Range", cfg.Range or 300)
    tool:SetAttribute("Ammo", cfg.Ammo)
    tool:SetAttribute("Type", cfg.Type)
    tool:SetAttribute("Price", cfg.Price or 0)

    -- Handle
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = (cfg.Type=="Melee") and Vector3.new(1,4,1) or Vector3.new(1,1,4)
    handle.Color = cfg.Color or Color3.fromRGB(100,100,100)
    handle.Material = Enum.Material.Metal
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    -- For guns, add a small part as barrel indicator
    if cfg.Type~="Melee" then
        local barrel = Instance.new("Part")
        barrel.Name = "Barrel"
        barrel.Size = Vector3.new(0.2,0.2,1.5)
        barrel.Color = Color3.fromRGB(30,30,30)
        barrel.CanCollide = false
        barrel.Massless = true
        local wc = Instance.new("WeldConstraint", barrel)
        wc.Part0 = handle
        wc.Part1 = barrel
        barrel.CFrame = handle.CFrame * CFrame.new(0,0,-2)
        barrel.Parent = tool
    end

    -- Sound
    local sound = Instance.new("Sound", handle)
    sound.Name = "FireSound"
    sound.SoundId = cfg.SoundId or "rbxassetid://12222025"
    sound.Volume = 1
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.MaxDistance = 120

    -- No need for individual scripts, central handler will handle
    return tool
end

local wepFolder = ensureFolders()

-- Clear old tools
for _,child in ipairs(wepFolder:GetChildren()) do if child:IsA("Tool") then child:Destroy() end end
for _,child in ipairs(StarterPack:GetChildren()) do if child:GetAttribute("WeaponName") then child:Destroy() end end

-- Build 10 tools
for _,wName in ipairs(WeaponConfig.Order or {"Pistol","Shotgun","AK47","Uzi","Sniper","RPG","Bat","Katana","Flamethrower","RayGun"}) do
    local cfg = WeaponConfig[wName]
    if cfg then
        local tool = createTool(wName, cfg)
        tool.Parent = wepFolder
        -- Starter pistol for all
        if wName=="Pistol" or wName=="Bat" then
            tool:Clone().Parent = StarterPack
        end
        print("[WeaponBuilder] Created "..wName)
    end
end

-- Weapon shop pads - give weapon on touch / proximity
local function setupShop()
    task.wait(2)
    local map = workspace:FindFirstChild("ZombieMap")
    if not map then return end
    local shop = map:FindFirstChild("WeaponShop")
    if not shop then return end

    local order = WeaponConfig.Order
    for i,pad in ipairs(shop:GetChildren()) do
        if pad.Name:match("WeaponPad") and pad:IsA("BasePart") then
            local idx = tonumber(pad.Name:match("%d+")) or i
            local wName = order[idx] or order[1]
            local cfg = WeaponConfig[wName]
            if not cfg then continue end
            -- Update billboard text
            for _,child in ipairs(pad:GetChildren()) do
                if child:IsA("BillboardGui") then
                    local tl = child:FindFirstChildOfClass("TextLabel")
                    if tl then tl.Text = cfg.DisplayName.."\n$"..cfg.Price.."\n[E] Buy" end
                end
            end
            -- ProximityPrompt
            if not pad:FindFirstChild("Prox") then
                local prox = Instance.new("ProximityPrompt", pad)
                prox.Name = "Prox"
                prox.ActionText = "Buy "..cfg.DisplayName
                prox.ObjectText = "$"..cfg.Price
                prox.HoldDuration = 0.3
                prox.MaxActivationDistance = 10
                prox.Triggered:Connect(function(plr)
                    local wepFolder = RS:FindFirstChild("Weapons")
                    local toolTemplate = nil
                    for _,t in ipairs(wepFolder:GetChildren()) do
                        if t:GetAttribute("WeaponName")==wName then toolTemplate=t; break end
                    end
                    if not toolTemplate then return end
                    -- Check cash
                    local ls = plr:FindFirstChild("leaderstats")
                    local cash = ls and ls:FindFirstChild("Cash")
                    if wName~="Pistol" and cash and cash.Value < cfg.Price then
                        return
                    end
                    if cash and wName~="Pistol" then
                        cash.Value -= cfg.Price
                    end
                    -- Give weapon if not already has
                    local has = plr.Backpack:FindFirstChild(toolTemplate.Name) or (plr.Character and plr.Character:FindFirstChild(toolTemplate.Name))
                    if not has then
                        toolTemplate:Clone().Parent = plr.Backpack
                    end
                end)
            end
        end
    end
end

task.spawn(setupShop)

print("[WeaponBuilder] 10 weapons built: Pistol, Shotgun, AK47, Uzi, Sniper, RPG, Bat, Katana, Flamethrower, RayGun")
