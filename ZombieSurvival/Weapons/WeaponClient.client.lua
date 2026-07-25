-- ZombieSurvival / WeaponClient.client.lua
-- Клиентская часть для 10 пушек: стрельба, эффекты, перезарядка
-- Кидать в StarterPlayerScripts

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local WeaponConfig
pcall(function()
    WeaponConfig = require(RS:WaitForChild("Shared"):WaitForChild("ZombieGame"):WaitForChild("WeaponConfig"))
end)
if not WeaponConfig then
    pcall(function() WeaponConfig = require(RS.Weapons:FindFirstChild("WeaponConfig")) end)
end
if not WeaponConfig or not WeaponConfig.Pistol then
    -- fallback minimal
    WeaponConfig = {
        Pistol={Name="Pistol",Damage=24,FireRate=0.35,Range=400,Ammo=12,Type="Gun"},
        Shotgun={Name="Shotgun",Damage=14,Pellets=8,FireRate=0.9,Range=80,Ammo=6,Type="Shotgun"},
        AK47={Name="AK47",Damage=28,FireRate=0.13,Range=500,Ammo=30,Type="Rifle"},
        Uzi={Name="Uzi",Damage=16,FireRate=0.07,Range=250,Ammo=32,Type="SMG"},
        Sniper={Name="Sniper",Damage=120,FireRate=1.2,Range=1000,Ammo=5,Type="Sniper"},
        RPG={Name="RPG",Damage=180,FireRate=1.8,Range=600,Ammo=1,Type="Explosive"},
        Bat={Name="Bat",Damage=38,FireRate=0.6,Range=10,Ammo=-1,Type="Melee"},
        Katana={Name="Katana",Damage=55,FireRate=0.45,Range=12,Ammo=-1,Type="Melee"},
        Flamethrower={Name="Flamethrower",Damage=8,FireRate=0.05,Range=70,Ammo=150,Type="Flame"},
        RayGun={Name="RayGun",Damage=75,FireRate=0.5,Range=800,Ammo=10,Type="Laser"},
    }
end

local remotes = RS:WaitForChild("ZombieRemotes")
local fireEvent = remotes:WaitForChild("WeaponFire")
local reloadEvent = remotes:WaitForChild("Reload")

local currentTool = nil
local currentConfig = nil
local lastFire = 0
local ammo = 0
local isReloading = false

local function getMouseHit()
    local cam = workspace.CurrentCamera
    if not cam then return Mouse.Hit.Position, Mouse.Hit.LookVector end
    local mousePos = UIS:GetMouseLocation()
    local unitRay = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction*1000, rayParams)
    if result then
        return result.Position, (result.Position - unitRay.Origin).Unit, result
    else
        return unitRay.Origin + unitRay.Direction*500, unitRay.Direction, nil
    end
end

local function createMuzzleFlash(origin, color)
    local p = Instance.new("Part")
    p.Anchored=true; p.CanCollide=false; p.Size=Vector3.new(0.3,0.3,0.3); p.CFrame=CFrame.new(origin); p.Color=color or Color3.fromRGB(255,200,50); p.Material=Enum.Material.Neon; p.Parent=workspace
    local light = Instance.new("PointLight", p)
    light.Color = color or Color3.fromRGB(255,200,50); light.Range=8; light.Brightness=3
    Debris:AddItem(p, 0.08)
end

local function createBulletTracer(startPos, endPos, color)
    local dist = (endPos - startPos).Magnitude
    local mid = (startPos + endPos)/2
    local p = Instance.new("Part")
    p.Anchored=true; p.CanCollide=false; p.Size=Vector3.new(0.1,0.1,dist); p.CFrame=CFrame.new(mid, endPos); p.Color=color or Color3.fromRGB(255,255,100); p.Material=Enum.Material.Neon; p.Parent=workspace
    Debris:AddItem(p, 0.12)
end

local function createFlameEffect(origin, dir)
    for i=1,3 do
        local p = Instance.new("Part")
        p.Anchored=true; p.CanCollide=false
        p.Size=Vector3.new(0.5+math.random()*0.5,0.5+math.random()*0.5,0.5)
        p.CFrame = CFrame.new(origin + dir*(i*4 + math.random()*2) + Vector3.new(math.random(-2,2), math.random(-1,1), math.random(-2,2)))
        p.Color = Color3.fromRGB(255, math.random(100,200), 0)
        p.Material=Enum.Material.Neon
        p.Parent=workspace
        Debris:AddItem(p, 0.3)
    end
end

local function onToolEquipped(tool)
    if not tool:GetAttribute("WeaponName") then return end
    currentTool = tool
    local wName = tool:GetAttribute("WeaponName")
    currentConfig = WeaponConfig[wName]
    if currentConfig then
        ammo = currentConfig.Ammo
        if tool:GetAttribute("Ammo") then ammo = tool:GetAttribute("Ammo") end
    end
    -- Ammo GUI could be updated here
end

local function onToolUnequipped()
    currentTool = nil
    currentConfig = nil
end

local function tryFire()
    if not currentTool or not currentConfig then return end
    if isReloading then return end
    local now = tick()
    if now - lastFire < (currentConfig.FireRate or 0.2) then return end
    if currentConfig.Ammo and currentConfig.Ammo ~= -1 and ammo <=0 then
        -- auto reload
        if reloadEvent then
            isReloading = true
            task.spawn(function()
                task.wait(currentConfig.ReloadTime or 1.5)
                ammo = currentConfig.Ammo
                isReloading = false
                reloadEvent:FireServer(currentConfig.Name)
            end)
        end
        return
    end

    lastFire = now
    if currentConfig.Ammo and currentConfig.Ammo ~= -1 then
        ammo -= 1
        currentTool:SetAttribute("Ammo", ammo)
    end

    local hitPos, dir, result = getMouseHit()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local origin = hrp and hrp.Position + Vector3.new(0,1.5,0) + (hrp.CFrame.LookVector*1.5) or hitPos

    -- Client effects
    if currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("FireSound") then
        currentTool.Handle.FireSound:Play()
    end

    if currentConfig.Type=="Flame" then
        createFlameEffect(origin, dir)
    elseif currentConfig.Type=="Melee" then
        -- swing anim
        if char and char:FindFirstChildOfClass("Humanoid") then
            -- simple
        end
    else
        createMuzzleFlash(origin, currentConfig.Color)
        if result then
            createBulletTracer(origin, result.Position, currentConfig.Color)
        else
            createBulletTracer(origin, hitPos, currentConfig.Color)
        end
    end

    -- Send to server
    fireEvent:FireServer(currentConfig.Name, origin, dir, result and result.Instance and result.Instance:GetFullName() or "")
end

-- Hook tools
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("WeaponName") then
            onToolEquipped(child)
            child.Equipped:Connect(function() onToolEquipped(child) end)
            child.Unequipped:Connect(onToolUnequipped)
            child.Activated:Connect(tryFire)
        end
    end)
    for _,tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("WeaponName") then
            onToolEquipped(tool)
            tool.Activated:Connect(tryFire)
        end
    end
end)

-- Backpack tools
LocalPlayer:WaitForChild("Backpack").ChildAdded:Connect(function(child)
    if child:IsA("Tool") and child:GetAttribute("WeaponName") then
        task.wait(0.1)
        child.Equipped:Connect(function() onToolEquipped(child) end)
        child.Unequipped:Connect(onToolUnequipped)
        child.Activated:Connect(tryFire)
    end
end)

-- Auto fire for Auto weapons
RunService.RenderStepped:Connect(function()
    if not currentTool or not currentConfig then return end
    if not currentConfig.Auto then return end
    if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        tryFire()
    end
end)

-- Reload key R
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.R then
        if currentConfig and currentConfig.Ammo and currentConfig.Ammo~=-1 then
            if ammo < currentConfig.Ammo and not isReloading then
                isReloading = true
                task.spawn(function()
                    task.wait(currentConfig.ReloadTime or 1.5)
                    ammo = currentConfig.Ammo
                    isReloading = false
                    if reloadEvent then reloadEvent:FireServer(currentConfig.Name) end
                    if currentTool then currentTool:SetAttribute("Ammo", ammo) end
                end)
            end
        end
    end
end)

print("[WeaponClient] Loaded for 10 weapons. Press R to reload, hold mouse for auto.")
