-- ZombieSurvival Client_AllInOne v1.0
-- Кидаешь этот LocalScript в StarterPlayerScripts -> Play
-- Содержит: WeaponClient + WaveHUD + небольшой Admin фикс
-- Требует Server_AllInOne в ServerScriptService

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotes = RS:WaitForChild("ZombieRemotes")
local fireEvent = remotes:WaitForChild("WeaponFire")
local reloadEvent = remotes:WaitForChild("Reload")
local waveEvent = remotes:WaitForChild("WaveUpdate")

-- WeaponConfig fallback
local WeaponConfig = {
    Pistol={Name="Pistol",Damage=24,FireRate=0.35,Range=400,Ammo=12,ReloadTime=1.3,Auto=false,Type="Gun",Color=Color3.fromRGB(50,50,50)},
    Shotgun={Name="Shotgun",Damage=14,Pellets=8,FireRate=0.9,Range=80,Ammo=6,ReloadTime=2.8,Auto=false,Type="Shotgun",Color=Color3.fromRGB(120,90,60)},
    AK47={Name="AK47",Damage=28,FireRate=0.13,Range=500,Ammo=30,ReloadTime=2.0,Auto=true,Type="Rifle",Color=Color3.fromRGB(90,50,20)},
    Uzi={Name="Uzi",Damage=16,FireRate=0.07,Range=250,Ammo=32,ReloadTime=1.6,Auto=true,Type="SMG",Color=Color3.fromRGB(30,30,30)},
    Sniper={Name="Sniper",Damage=120,FireRate=1.2,Range=1000,Ammo=5,ReloadTime=2.5,Auto=false,Type="Sniper",Color=Color3.fromRGB(60,80,60)},
    RPG={Name="RPG",Damage=180,FireRate=1.8,Range=600,Ammo=1,ReloadTime=3.2,Auto=false,Type="Explosive",Color=Color3.fromRGB(80,120,50)},
    Bat={Name="Bat",Damage=38,FireRate=0.6,Range=10,Ammo=-1,Type="Melee",Color=Color3.fromRGB(140,100,60)},
    Katana={Name="Katana",Damage=55,FireRate=0.45,Range=12,Ammo=-1,Type="Melee",Color=Color3.fromRGB(200,200,220)},
    Flamethrower={Name="Flamethrower",Damage=8,FireRate=0.05,Range=70,Ammo=150,ReloadTime=3.0,Auto=true,Type="Flame",Color=Color3.fromRGB(200,50,0)},
    RayGun={Name="RayGun",Damage=75,FireRate=0.5,Range=800,Ammo=10,ReloadTime=2.2,Auto=false,Type="Laser",Color=Color3.fromRGB(100,255,255)},
}

pcall(function()
    local mod = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("ZombieGame") and RS.Shared.ZombieGame:FindFirstChild("WeaponConfig")
    if mod then WeaponConfig = require(mod) end
end)

-- // WEAPON CLIENT
local currentTool=nil
local currentConfig=nil
local lastFire=0
local ammo=0
local reloading=false

local function getMouseHit()
    local cam=workspace.CurrentCamera
    if not cam then return Mouse.Hit.Position, Mouse.Hit.LookVector end
    local mp=UIS:GetMouseLocation()
    local ray=cam:ViewportPointToRay(mp.X,mp.Y)
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist; rp.FilterDescendantsInstances={LocalPlayer.Character}
    local res=workspace:Raycast(ray.Origin, ray.Direction*1000, rp)
    if res then return res.Position, (res.Position-ray.Origin).Unit, res else return ray.Origin+ray.Direction*500, ray.Direction, nil end
end

local function muzzle(origin,color)
    local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Size=Vector3.new(0.3,0.3,0.3); p.CFrame=CFrame.new(origin); p.Color=color or Color3.new(1,0.8,0.2); p.Material=Enum.Material.Neon; p.Parent=workspace; Debris:AddItem(p,0.08)
end
local function tracer(s,e,color)
    local d=(e-s).Magnitude; local m=(s+e)/2; local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Size=Vector3.new(0.1,0.1,d); p.CFrame=CFrame.new(m,e); p.Color=color or Color3.new(1,1,0.5); p.Material=Enum.Material.Neon; p.Parent=workspace; Debris:AddItem(p,0.12)
end

local function onEquip(tool)
    if not tool:GetAttribute("WeaponName") then return end
    currentTool=tool; currentConfig=WeaponConfig[tool:GetAttribute("WeaponName")]; ammo=tool:GetAttribute("Ammo") or (currentConfig and currentConfig.Ammo or 30)
end
local function onUnequip() currentTool=nil; currentConfig=nil end

local function tryFire()
    if not currentTool or not currentConfig then return end
    if reloading then return end
    if tick()-lastFire < (currentConfig.FireRate or 0.2) then return end
    if currentConfig.Ammo and currentConfig.Ammo~=-1 and ammo<=0 then
        reloading=true; task.spawn(function() task.wait(currentConfig.ReloadTime or 1.5); ammo=currentConfig.Ammo; reloading=false; reloadEvent:FireServer(currentConfig.Name); if currentTool then currentTool:SetAttribute("Ammo",ammo) end end); return
    end
    lastFire=tick()
    if currentConfig.Ammo and currentConfig.Ammo~=-1 then ammo-=1; if currentTool then currentTool:SetAttribute("Ammo",ammo) end end
    local hitPos,dir,res=getMouseHit()
    local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local origin=hrp and hrp.Position+Vector3.new(0,1.5,0)+hrp.CFrame.LookVector*1.5 or hitPos
    if currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("FireSound") then currentTool.Handle.FireSound:Play() end
    muzzle(origin,currentConfig.Color)
    if res then tracer(origin,res.Position,currentConfig.Color) else tracer(origin,hitPos,currentConfig.Color) end
    fireEvent:FireServer(currentConfig.Name,origin,dir)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("WeaponName") then
            onEquip(child); child.Equipped:Connect(function() onEquip(child) end); child.Unequipped:Connect(onUnequip); child.Activated:Connect(tryFire)
        end
    end)
end)
LocalPlayer:WaitForChild("Backpack").ChildAdded:Connect(function(child)
    if child:IsA("Tool") and child:GetAttribute("WeaponName") then
        task.wait(0.1); child.Equipped:Connect(function() onEquip(child) end); child.Unequipped:Connect(onUnequip); child.Activated:Connect(tryFire)
    end
end)
RunService.RenderStepped:Connect(function() if currentTool and currentConfig and currentConfig.Auto and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then tryFire() end end)
UIS.InputBegan:Connect(function(input,gpe) if gpe then return end; if input.KeyCode==Enum.KeyCode.R then if currentConfig and currentConfig.Ammo~=-1 and ammo < currentConfig.Ammo and not reloading then reloading=true; task.spawn(function() task.wait(currentConfig.ReloadTime or 1.5); ammo=currentConfig.Ammo; reloading=false; reloadEvent:FireServer(currentConfig.Name); if currentTool then currentTool:SetAttribute("Ammo",ammo) end end) end end end)

-- // WAVE HUD
local screen=Instance.new("ScreenGui", PlayerGui); screen.Name="ZombieHUD"; screen.ResetOnSpawn=false
local top=Instance.new("Frame",screen); top.Size=UDim2.fromOffset(400,80); top.Position=UDim2.new(0.5,-200,0,10); top.BackgroundColor3=Color3.fromRGB(20,20,30); top.BackgroundTransparency=0.2; Instance.new("UICorner",top).CornerRadius=UDim.new(0,12); local st=Instance.new("UIStroke",top); st.Color=Color3.fromRGB(255,50,50); st.Thickness=2
local waveLabel=Instance.new("TextLabel",top); waveLabel.Size=UDim2.new(1,-20,0.5,0); waveLabel.Position=UDim2.fromOffset(10,5); waveLabel.BackgroundTransparency=1; waveLabel.Font=Enum.Font.GothamBold; waveLabel.Text="Wave: 0"; waveLabel.TextColor3=Color3.new(1,1,1); waveLabel.TextSize=20; waveLabel.TextXAlignment=Enum.TextXAlignment.Left
local zombieLabel=Instance.new("TextLabel",top); zombieLabel.Size=UDim2.new(1,-20,0.5,-5); zombieLabel.Position=UDim2.new(0,10,0.5,0); zombieLabel.BackgroundTransparency=1; zombieLabel.Font=Enum.Font.Gotham; zombieLabel.Text="Zombies: 0"; zombieLabel.TextColor3=Color3.fromRGB(200,200,200); zombieLabel.TextSize=16; zombieLabel.TextXAlignment=Enum.TextXAlignment.Left
local bottom=Instance.new("Frame",screen); bottom.Size=UDim2.fromOffset(300,60); bottom.Position=UDim2.new(0,10,1,-70); bottom.BackgroundColor3=Color3.fromRGB(20,20,30); bottom.BackgroundTransparency=0.3; Instance.new("UICorner",bottom).CornerRadius=UDim.new(0,10)
local hpLabel=Instance.new("TextLabel",bottom); hpLabel.Size=UDim2.new(1,-10,0.5,0); hpLabel.Position=UDim2.fromOffset(10,5); hpLabel.BackgroundTransparency=1; hpLabel.Font=Enum.Font.GothamBold; hpLabel.Text="HP: 100"; hpLabel.TextColor3=Color3.fromRGB(100,255,100); hpLabel.TextSize=16; hpLabel.TextXAlignment=Enum.TextXAlignment.Left
local ammoLabel=Instance.new("TextLabel",bottom); ammoLabel.Size=UDim2.new(1,-10,0.5,0); ammoLabel.Position=UDim2.new(0,10,0.5,0); ammoLabel.BackgroundTransparency=1; ammoLabel.Font=Enum.Font.Code; ammoLabel.Text="Ammo: -"; ammoLabel.TextColor3=Color3.new(1,1,1); ammoLabel.TextSize=14; ammoLabel.TextXAlignment=Enum.TextXAlignment.Left
local cashFrame=Instance.new("Frame",screen); cashFrame.Size=UDim2.fromOffset(200,40); cashFrame.Position=UDim2.new(1,-210,0,10); cashFrame.BackgroundColor3=Color3.fromRGB(20,30,20); cashFrame.BackgroundTransparency=0.2; Instance.new("UICorner",cashFrame).CornerRadius=UDim.new(0,10)
local cashLabel=Instance.new("TextLabel",cashFrame); cashLabel.Size=UDim2.fromScale(1,1); cashLabel.BackgroundTransparency=1; cashLabel.Font=Enum.Font.GothamBold; cashLabel.TextColor3=Color3.fromRGB(100,255,100); cashLabel.TextSize=18; cashLabel.Text="Cash: 500"

waveEvent.OnClientEvent:Connect(function(wave,z) if z<0 then waveLabel.Text="Wave "..wave.." completed!"; zombieLabel.Text="Next wave in "..math.abs(z).."s" else waveLabel.Text="🧟 Wave "..wave; zombieLabel.Text="Zombies to kill: "..z end end)
local function hookChar(char) local hum=char:WaitForChild("Humanoid",5); if not hum then return end; local function upd() hpLabel.Text="HP: "..math.floor(hum.Health).."/"..math.floor(hum.MaxHealth); local pct=hum.Health/hum.MaxHealth; hpLabel.TextColor3 = pct>0.6 and Color3.fromRGB(100,255,100) or pct>0.3 and Color3.fromRGB(255,200,50) or Color3.fromRGB(255,50,50) end; hum.HealthChanged:Connect(upd); upd(); char.ChildAdded:Connect(function(c) if c:IsA("Tool") and c:GetAttribute("WeaponName") then local function ua() local a=c:GetAttribute("Ammo"); ammoLabel.Text=c.Name..": "..(a==-1 and "INF" or a) end; c:GetAttributeChangedSignal("Ammo"):Connect(ua); ua(); c.Equipped:Connect(ua) end end) end
if LocalPlayer.Character then hookChar(LocalPlayer.Character) end; LocalPlayer.CharacterAdded:Connect(hookChar)
local function updCash() local ls=LocalPlayer:FindFirstChild("leaderstats"); local cash=ls and ls:FindFirstChild("Cash"); if cash then cashLabel.Text="💰 Cash: "..cash.Value; cash.Changed:Connect(function() cashLabel.Text="💰 Cash: "..cash.Value end) end end
LocalPlayer.ChildAdded:Connect(function(c) if c.Name=="leaderstats" then updCash() end end); if LocalPlayer:FindFirstChild("leaderstats") then updCash() else task.wait(1); updCash() end

print("[Client ALLINONE] Loaded - 10 weapons + HUD")
