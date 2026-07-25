-- ZombieSurvival / WeaponHandler.server.lua
-- Обрабатывает урон от 10 пушек, централизованно (не нужны скрипты в каждом Tool)

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local WeaponConfig
local cfgModule = script.Parent:FindFirstChild("WeaponConfig") or RS:FindFirstChild("WeaponConfig") or script.Parent.Parent:FindFirstChild("WeaponConfig")
if script.Parent:FindFirstChild("WeaponConfig") then
    WeaponConfig = require(script.Parent.WeaponConfig)
else
    pcall(function() WeaponConfig = require(RS.Shared.ZombieGame.WeaponConfig) end)
    if not WeaponConfig then
        WeaponConfig = require(workspace.ZombieMap and script.Parent.WeaponConfig or script.Parent.WeaponConfig)
    end
end
-- Fallback
if not WeaponConfig or not WeaponConfig.Pistol then
    WeaponConfig = {
        Pistol={Name="Pistol",Damage=24,FireRate=0.35,Range=400,Ammo=12,Type="Gun"},
        Shotgun={Name="Shotgun",Damage=14,Pellets=8,FireRate=0.9,Range=80,Ammo=6,Type="Shotgun"},
        AK47={Name="AK47",Damage=28,FireRate=0.13,Range=500,Ammo=30,Type="Rifle"},
        Uzi={Name="Uzi",Damage=16,FireRate=0.07,Range=250,Ammo=32,Type="SMG"},
        Sniper={Name="Sniper",Damage=120,FireRate=1.2,Range=1000,Ammo=5,Type="Sniper"},
        RPG={Name="RPG",Damage=180,FireRate=1.8,Range=600,Ammo=1,Type="Explosive",ExplosionRadius=14},
        Bat={Name="Bat",Damage=38,FireRate=0.6,Range=10,Ammo=-1,Type="Melee",Knockback=20},
        Katana={Name="Katana",Damage=55,FireRate=0.45,Range=12,Ammo=-1,Type="Melee",Lunge=8},
        Flamethrower={Name="Flamethrower",Damage=8,FireRate=0.05,Range=70,Ammo=150,Type="Flame",BurnDuration=3},
        RayGun={Name="RayGun",Damage=75,FireRate=0.5,Range=800,Ammo=10,Type="Laser",PiercesCount=5},
    }
end

local remotes = RS:WaitForChild("ZombieRemotes")
local fireEvent = remotes:WaitForChild("WeaponFire")
local reloadEvent = remotes:FindFirstChild("Reload")

-- Ammo per player per weapon
local playerAmmo = {} -- [plr][weaponName] = currentAmmo

local function getAmmo(plr, wName)
    if not playerAmmo[plr] then playerAmmo[plr]={} end
    if playerAmmo[plr][wName]==nil then
        local cfg = WeaponConfig[wName]
        playerAmmo[plr][wName] = cfg and cfg.Ammo or 30
    end
    return playerAmmo[plr][wName]
end

local function setAmmo(plr, wName, val)
    if not playerAmmo[plr] then playerAmmo[plr]={} end
    playerAmmo[plr][wName]=val
end

local function isZombieModel(model)
    return model and model:FindFirstChildOfClass("Humanoid") and model:GetAttribute("ZombieType")~=nil
end

local function applyDamageToZombie(zombieModel, dmg, attacker)
    local hum = zombieModel:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return end
    hum:TakeDamage(dmg)
    -- визуал урона
    if zombieModel.PrimaryPart then
        local bg = Instance.new("BillboardGui", zombieModel.PrimaryPart)
        bg.Size = UDim2.fromOffset(40,20)
        bg.StudsOffset = Vector3.new(0,3,0)
        bg.AlwaysOnTop = true
        local tl = Instance.new("TextLabel", bg)
        tl.Size=UDim2.fromScale(1,1); tl.BackgroundTransparency=1; tl.Text="-"..dmg; tl.TextColor3=Color3.new(1,0,0); tl.Font=Enum.Font.GothamBold; tl.TextSize=18
        Debris:AddItem(bg, 0.6)
    end
end

local function handleRayWeapon(plr, weaponName, origin, direction, cfg)
    local range = cfg.Range or 300
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {plr.Character}
    local result = workspace:Raycast(origin, direction*range, rayParams)

    local function damageAt(hitModel, hitPos)
        if hitModel and isZombieModel(hitModel.Parent) then
            applyDamageToZombie(hitModel.Parent, cfg.Damage, plr)
        elseif hitModel and isZombieModel(hitModel.Parent.Parent) then
            applyDamageToZombie(hitModel.Parent.Parent, cfg.Damage, plr)
        end
    end

    if cfg.Type=="Shotgun" then
        -- 8 пуль с разбросом
        for i=1,(cfg.Pellets or 8) do
            local spread = cfg.Spread or 5
            local offset = Vector3.new(math.random(-spread,spread)*0.1, math.random(-spread,spread)*0.1, math.random(-spread,spread)*0.1)
            local dirSpread = (direction + offset).Unit
            local r = workspace:Raycast(origin, dirSpread*range, rayParams)
            if r and r.Instance then
                damageAt(r.Instance, r.Position)
            end
        end
    elseif cfg.Type=="Laser" or cfg.Type=="Sniper" then
        -- Piercing
        local hits = 0
        local maxPierce = cfg.PiercesCount or (cfg.Pierces and 3 or 1)
        local curOrigin = origin
        local curDir = direction
        local ignore = {plr.Character}
        for p=1,maxPierce do
            rayParams.FilterDescendantsInstances = ignore
            local r = workspace:Raycast(curOrigin, curDir*range, rayParams)
            if not r then break end
            if r.Instance then
                if isZombieModel(r.Instance.Parent) then
                    applyDamageToZombie(r.Instance.Parent, cfg.Damage, plr)
                    hits+=1
                elseif isZombieModel(r.Instance.Parent.Parent) then
                    applyDamageToZombie(r.Instance.Parent.Parent, cfg.Damage, plr)
                    hits+=1
                end
                table.insert(ignore, r.Instance.Parent)
                curOrigin = r.Position + curDir*0.5
                if hits>=maxPierce then break end
            else
                break
            end
        end
    else
        if result and result.Instance then
            damageAt(result.Instance, result.Position)
        end
    end

    return result
end

fireEvent.OnServerEvent:Connect(function(plr, weaponName, origin, direction, extra)
    if not weaponName or type(weaponName)~="string" then return end
    if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then return end
    local cfg = WeaponConfig[weaponName]
    if not cfg then return end

    -- Anti-cheat: дистанция origin от игрока не больше 20
    local hrp = plr.Character.HumanoidRootPart
    if (origin - hrp.Position).Magnitude > 25 then
        -- возможно читер, но разрешим с запасом
        origin = hrp.Position + direction*2
    end

    -- Ammo check
    if cfg.Ammo and cfg.Ammo ~= -1 then
        local ammo = getAmmo(plr, weaponName)
        if ammo <=0 then return end
        setAmmo(plr, weaponName, ammo-1)
    end

    if cfg.Type=="Explosive" then
        -- RPG взрыв
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = {plr.Character}
        local result = workspace:Raycast(origin, direction*(cfg.Range or 500), rayParams)
        local expPos = result and result.Position or (origin + direction*50)
        local explosion = Instance.new("Explosion")
        explosion.BlastRadius = cfg.ExplosionRadius or 12
        explosion.BlastPressure = 0
        explosion.Position = expPos
        explosion.Parent = workspace
        explosion.Hit:Connect(function(part, dist)
            local model = part.Parent
            if isZombieModel(model) then
                local dmg = cfg.Damage * (1 - dist/(explosion.BlastRadius+1))
                applyDamageToZombie(model, math.floor(dmg), plr)
            end
        end)
        -- Effects
        local part = Instance.new("Part")
        part.Anchored=true; part.CanCollide=false; part.Size=Vector3.new(1,1,1); part.CFrame=CFrame.new(expPos); part.Transparency=1; part.Parent=workspace
        local fire = Instance.new("Fire", part)
        fire.Size=20; fire.Heat=15
        Debris:AddItem(part,1)
    elseif cfg.Type=="Flame" then
        -- Flamethrower: короткий радиус, DoT
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = {plr.Character}
        local result = workspace:Raycast(origin, direction*(cfg.Range or 70), rayParams)
        local endPos = result and result.Position or (origin + direction*(cfg.Range or 70))
        -- Check zombies in cone
        for _,zm in ipairs(workspace:GetChildren()) do
            if isZombieModel(zm) and zm.PrimaryPart then
                local dist = (zm.PrimaryPart.Position - origin).Magnitude
                local dirToZombie = (zm.PrimaryPart.Position - origin).Unit
                local dot = direction:Dot(dirToZombie)
                if dist < (cfg.Range or 70) and dot > 0.85 then
                    applyDamageToZombie(zm, cfg.Damage, plr)
                    -- Burn effect
                    if not zm:GetAttribute("Burning") then
                        zm:SetAttribute("Burning", true)
                        task.spawn(function()
                            for i=1,(cfg.BurnDuration or 3)*5 do
                                if not zm.Parent or zm.Humanoid.Health<=0 then break end
                                applyDamageToZombie(zm, 4, plr)
                                task.wait(0.2)
                            end
                            if zm.Parent then zm:SetAttribute("Burning", false) end
                        end)
                    end
                end
            end
        end
    elseif cfg.Type=="Melee" then
        -- Melee: check zombies within Range around player
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _,zm in ipairs(workspace:GetChildren()) do
            if isZombieModel(zm) and zm.PrimaryPart then
                local dist = (zm.PrimaryPart.Position - root.Position).Magnitude
                if dist < (cfg.Range or 12) then
                    -- Check forward dot
                    local dirToZombie = (zm.PrimaryPart.Position - root.Position).Unit
                    local look = root.CFrame.LookVector
                    if dirToZombie:Dot(look) > -0.2 then -- 100 deg cone
                        applyDamageToZombie(zm, cfg.Damage, plr)
                        -- Knockback / Lunge
                        if cfg.Knockback then
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(1e5,1e5,1e5)
                            bv.Velocity = root.CFrame.LookVector * cfg.Knockback + Vector3.new(0,5,0)
                            bv.Parent = zm.PrimaryPart
                            Debris:AddItem(bv, 0.15)
                        end
                        if cfg.Lunge then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * cfg.Lunge
                            end
                        end
                    end
                end
            end
        end
    else
        -- Normal gun
        handleRayWeapon(plr, weaponName, origin, direction, cfg)
    end
end)

if reloadEvent then
    reloadEvent.OnServerEvent:Connect(function(plr, weaponName)
        local cfg = WeaponConfig[weaponName]
        if not cfg or cfg.Ammo==-1 then return end
        setAmmo(plr, weaponName, cfg.Ammo)
        -- Could add delay
    end)
end

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(plr) playerAmmo[plr]=nil; if flyObjects then end end)

print("[WeaponHandler] 10 weapons ready: Pistol, Shotgun, AK47, Uzi, Sniper, RPG, Bat, Katana, Flamethrower, RayGun")
