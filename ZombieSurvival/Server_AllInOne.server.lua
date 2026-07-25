-- ZombieSurvival Server_AllInOne v1.0
-- Кидаешь ОДИН этот Script в ServerScriptService -> Play -> всё работает
-- Содержит: MapBuilder + GameManager + Zombie + Weapons (10 видов)
-- Требует еще Client_AllInOne в StarterPlayerScripts для эффектов и HUD

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

print("[Zombie ALLINONE] Starting...")

-- // CONFIGS INLINE
local ZombieConfig = {
    Types = {
        Walker = {Name="Walker",Health=100,Damage=18,WalkSpeed=10,Scale=1,Color=Color3.fromRGB(85,170,85),Points=10,Cash=15},
        Runner = {Name="Runner",Health=65,Damage=12,WalkSpeed=18,Scale=0.95,Color=Color3.fromRGB(255,200,100),Points=20,Cash=25},
        Tank = {Name="Tank",Health=350,Damage=35,WalkSpeed=8,Scale=1.35,Color=Color3.fromRGB(120,120,120),Points=50,Cash=60},
        Crawler = {Name="Crawler",Health=70,Damage=10,WalkSpeed=12,Scale=0.7,Color=Color3.fromRGB(70,90,70),Points=15,Cash=20},
        Exploder = {Name="Exploder",Health=80,Damage=60,WalkSpeed=11,Scale=1.1,Color=Color3.fromRGB(200,50,50),Points=40,Cash=50,Explodes=true},
    },
    WaveConfig = {StartingZombies=6,ZombiesPerWaveGrowth=2.5,Intermission=12,MaxAlive=35,SpawnDelay=0.8},
    GetDifficultyMultiplier = function(w) return 1+(w-1)*0.12 end,
    GetRandomType = function(w)
        local pool={"Walker","Walker","Walker","Runner"}
        if w>=3 then table.insert(pool,"Crawler") end
        if w>=4 then table.insert(pool,"Tank") end
        if w>=5 then table.insert(pool,"Exploder") end
        return pool[math.random(1,#pool)]
    end
}

local WeaponConfig = {
    Pistol={Name="Pistol",DisplayName="🔫 Pistol",Damage=24,FireRate=0.35,Range=400,Ammo=12,ReloadTime=1.3,Auto=false,Type="Gun",Color=Color3.fromRGB(50,50,50),Price=0},
    Shotgun={Name="Shotgun",DisplayName="💥 Shotgun",Damage=14,Pellets=8,Spread=8,FireRate=0.9,Range=80,Ammo=6,ReloadTime=2.8,Auto=false,Type="Shotgun",Color=Color3.fromRGB(120,90,60),Price=400},
    AK47={Name="AK47",DisplayName="🔥 AK-47",Damage=28,FireRate=0.13,Range=500,Ammo=30,ReloadTime=2.0,Auto=true,Type="Rifle",Color=Color3.fromRGB(90,50,20),Price=1200},
    Uzi={Name="Uzi",DisplayName="⚡ Uzi",Damage=16,FireRate=0.07,Range=250,Ammo=32,ReloadTime=1.6,Auto=true,Type="SMG",Color=Color3.fromRGB(30,30,30),Price=800},
    Sniper={Name="Sniper",DisplayName="🎯 Sniper",Damage=120,FireRate=1.2,Range=1000,Ammo=5,ReloadTime=2.5,Auto=false,Type="Sniper",Color=Color3.fromRGB(60,80,60),Price=2000,Pierces=true},
    RPG={Name="RPG",DisplayName="💣 RPG",Damage=180,ExplosionRadius=14,FireRate=1.8,Range=600,Ammo=1,ReloadTime=3.2,Auto=false,Type="Explosive",Color=Color3.fromRGB(80,120,50),Price=3500},
    Bat={Name="Bat",DisplayName="🏏 Bat",Damage=38,FireRate=0.6,Range=10,Ammo=-1,Type="Melee",Color=Color3.fromRGB(140,100,60),Price=150,Knockback=20},
    Katana={Name="Katana",DisplayName="⚔️ Katana",Damage=55,FireRate=0.45,Range=12,Ammo=-1,Type="Melee",Color=Color3.fromRGB(200,200,220),Price=900,Lunge=8},
    Flamethrower={Name="Flamethrower",DisplayName="🔥 Flamethrower",Damage=8,FireRate=0.05,Range=70,Ammo=150,ReloadTime=3.0,Auto=true,Type="Flame",Color=Color3.fromRGB(200,50,0),Price=2800,BurnDuration=3},
    RayGun={Name="RayGun",DisplayName="👽 RayGun",Damage=75,FireRate=0.5,Range=800,Ammo=10,ReloadTime=2.2,Auto=false,Type="Laser",Color=Color3.fromRGB(100,255,255),Price=5000,PiercesCount=5},
    Order={"Pistol","Bat","Uzi","Shotgun","Katana","AK47","Sniper","Flamethrower","RPG","RayGun"}
}

-- // ENSURE FOLDERS AND REMOTES
local function ensureFolders()
    local wepFolder = RS:FindFirstChild("Weapons") or Instance.new("Folder", RS); wepFolder.Name="Weapons"
    local remotes = RS:FindFirstChild("ZombieRemotes") or Instance.new("Folder", RS); remotes.Name="ZombieRemotes"
    for _,n in ipairs({"WeaponFire","Reload","BuyWeapon","WaveUpdate"}) do
        if not remotes:FindFirstChild(n) then Instance.new("RemoteEvent", remotes).Name=n end
    end
    return wepFolder, remotes
end
local WeaponsFolder, Remotes = ensureFolders()
local WeaponFireEvent = Remotes.WeaponFire
local WaveUpdateEvent = Remotes.WaveUpdate
local ReloadEvent = Remotes.Reload

-- // MAP BUILDER (simplified)
local function buildMap()
    if workspace:FindFirstChild("ZombieMap") then return workspace.ZombieMap end
    local mapFolder = Instance.new("Folder", workspace); mapFolder.Name="ZombieMap"
    local function newPart(name,size,cf,color,mat,parent)
        local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=cf; p.Anchored=true; p.CanCollide=true; p.Color=color or Color3.fromRGB(100,100,100); p.Material=mat or Enum.Material.Concrete; p.Parent=parent or mapFolder; return p
    end
    newPart("Baseplate",Vector3.new(800,6,800),CFrame.new(0,-3,0),Color3.fromRGB(60,60,60),Enum.Material.Slate,mapFolder)
    local half=400; local wallH=30; local wallT=6
    newPart("Wall_N",Vector3.new(800,wallH,wallT),CFrame.new(0,wallH/2-3,half),Color3.fromRGB(40,40,40),Enum.Material.Brick)
    newPart("Wall_S",Vector3.new(800,wallH,wallT),CFrame.new(0,wallH/2-3,-half),Color3.fromRGB(40,40,40),Enum.Material.Brick)
    newPart("Wall_E",Vector3.new(wallT,wallH,800),CFrame.new(half,wallH/2-3,0),Color3.fromRGB(40,40,40),Enum.Material.Brick)
    newPart("Wall_W",Vector3.new(wallT,wallH,800),CFrame.new(-half,wallH/2-3,0),Color3.fromRGB(40,40,40),Enum.Material.Brick)
    local safe=Instance.new("Folder",mapFolder); safe.Name="SafeHouse"
    newPart("SafeFloor",Vector3.new(50,2,50),CFrame.new(0,0,0),Color3.fromRGB(110,90,70),Enum.Material.WoodPlanks,safe)
    newPart("SafeWall_N",Vector3.new(50,12,2),CFrame.new(0,6,25),Color3.fromRGB(140,120,100),Enum.Material.Wood,safe)
    newPart("SafeWall_E",Vector3.new(2,12,50),CFrame.new(25,6,0),Color3.fromRGB(140,120,100),Enum.Material.Wood,safe)
    newPart("SafeWall_W",Vector3.new(2,12,50),CFrame.new(-25,6,0),Color3.fromRGB(140,120,100),Enum.Material.Wood,safe)
    newPart("SafeWall_S1",Vector3.new(18,12,2),CFrame.new(-16,6,-25),Color3.fromRGB(140,120,100),Enum.Material.Wood,safe)
    newPart("SafeWall_S2",Vector3.new(18,12,2),CFrame.new(16,6,-25),Color3.fromRGB(140,120,100),Enum.Material.Wood,safe)
    newPart("SafeWall_Top",Vector3.new(14,4,2),CFrame.new(0,12,-25),Color3.fromRGB(140,120,100),Enum.Material.Wood,safe)
    newPart("SafeRoof",Vector3.new(54,2,54),CFrame.new(0,13,0),Color3.fromRGB(80,60,50),Enum.Material.Slate,safe)
    local spawnLoc=Instance.new("SpawnLocation",safe); spawnLoc.Size=Vector3.new(10,1,10); spawnLoc.CFrame=CFrame.new(0,1,0); spawnLoc.Anchored=true; spawnLoc.CanCollide=false; spawnLoc.Neutral=true; spawnLoc.Name="PlayerSpawn"
    local shop=Instance.new("Folder",mapFolder); shop.Name="WeaponShop"
    newPart("ShopFloor",Vector3.new(60,2,30),CFrame.new(0,0,70),Color3.fromRGB(70,70,80),Enum.Material.Concrete,shop)
    newPart("ShopWall",Vector3.new(60,10,2),CFrame.new(0,5,85),Color3.fromRGB(50,50,60),Enum.Material.Brick,shop)
    for i=1,10 do local x=-27+(i-1)*6; local pad=newPart("WeaponPad_"..i,Vector3.new(5,1,5),CFrame.new(x,1,70),Color3.fromHSV((i-1)/10,0.8,0.9),Enum.Material.Neon,shop); local bg=Instance.new("BillboardGui",pad); bg.Size=UDim2.fromOffset(80,30); bg.StudsOffset=Vector3.new(0,3,0); bg.AlwaysOnTop=true; local txt=Instance.new("TextLabel",bg); txt.Size=UDim2.fromScale(1,1); txt.BackgroundTransparency=0.3; txt.BackgroundColor3=Color3.new(0,0,0); txt.TextColor3=Color3.new(1,1,1); txt.Font=Enum.Font.GothamBold; txt.TextSize=10; txt.Text="Weapon "..i; Instance.new("UICorner",txt) end
    local zFolder=Instance.new("Folder",mapFolder); zFolder.Name="ZombieSpawns"
    local posList={Vector3.new(350,5,350),Vector3.new(-350,5,350),Vector3.new(350,5,-350),Vector3.new(-350,5,-350),Vector3.new(350,5,0),Vector3.new(-350,5,0),Vector3.new(0,5,350),Vector3.new(0,5,-350)}
    for i,pos in ipairs(posList) do local sp=newPart("ZombieSpawn_"..i,Vector3.new(8,1,8),CFrame.new(pos),Color3.fromRGB(255,0,0),Enum.Material.Neon,zFolder); sp.Transparency=0.5; sp.CanCollide=false; local l=Instance.new("PointLight",sp); l.Color=Color3.new(1,0,0); l.Range=15; l.Brightness=2; local bg=Instance.new("BillboardGui",sp); bg.Size=UDim2.fromOffset(60,20); bg.StudsOffset=Vector3.new(0,4,0); local tl=Instance.new("TextLabel",bg); tl.Size=UDim2.fromScale(1,1); tl.BackgroundTransparency=1; tl.Text="🧟 SPAWN "..i; tl.TextColor3=Color3.new(1,0,0); tl.Font=Enum.Font.GothamBold; tl.TextSize=12 end
    local decor=Instance.new("Folder",mapFolder); decor.Name="Decor"
    for i=1,12 do local pos=Vector3.new(math.random(-300,300),0,math.random(-300,300)); if (pos-Vector3.new(0,0,0)).Magnitude>60 then local size=Vector3.new(math.random(6,14),math.random(6,14),math.random(6,14)); newPart("Crate_"..i,size,CFrame.new(pos)*CFrame.Angles(0,math.rad(math.random(0,360)),0),Color3.fromRGB(90,70,50),Enum.Material.Wood,decor) end end
    local Lighting=game:GetService("Lighting"); Lighting.ClockTime=2.5; Lighting.FogEnd=350; Lighting.FogStart=50; Lighting.FogColor=Color3.fromRGB(30,30,40); Lighting.Ambient=Color3.fromRGB(80,80,90); Lighting.Brightness=2
    print("[MapBuilder] Map built")
    return mapFolder
end

local ZombieMap = buildMap()

-- // GAME MANAGER
local function setupLeaderstats(plr)
    local ls=Instance.new("Folder"); ls.Name="leaderstats"; ls.Parent=plr
    local cash=Instance.new("IntValue",ls); cash.Name="Cash"; cash.Value=500
    local kills=Instance.new("IntValue",ls); kills.Name="Kills"; kills.Value=0
    local waves=Instance.new("IntValue",ls); waves.Name="Waves"; waves.Value=0
end
Players.PlayerAdded:Connect(setupLeaderstats)
for _,p in ipairs(Players:GetPlayers()) do setupLeaderstats(p) end

-- // WEAPON BUILDER
local StarterPack = game:GetService("StarterPack")
local function createTool(wName,cfg)
    local tool=Instance.new("Tool"); tool.Name=cfg.DisplayName or wName; tool.ToolTip=cfg.Name.." Dmg:"..cfg.Damage; tool.RequiresHandle=true; tool.CanBeDropped=true
    tool:SetAttribute("WeaponName",wName); tool:SetAttribute("Damage",cfg.Damage); tool:SetAttribute("FireRate",cfg.FireRate); tool:SetAttribute("Range",cfg.Range or 300); tool:SetAttribute("Ammo",cfg.Ammo); tool:SetAttribute("Type",cfg.Type); tool:SetAttribute("Price",cfg.Price or 0)
    local handle=Instance.new("Part"); handle.Name="Handle"; handle.Size=(cfg.Type=="Melee") and Vector3.new(1,4,1) or Vector3.new(1,1,4); handle.Color=cfg.Color or Color3.new(0.5,0.5,0.5); handle.Material=Enum.Material.Metal; handle.CanCollide=false; handle.Massless=true; handle.Parent=tool
    if cfg.Type~="Melee" then local barrel=Instance.new("Part"); barrel.Name="Barrel"; barrel.Size=Vector3.new(0.2,0.2,1.5); barrel.Color=Color3.fromRGB(30,30,30); barrel.CanCollide=false; barrel.Massless=true; local wc=Instance.new("WeldConstraint",barrel); wc.Part0=handle; wc.Part1=barrel; barrel.CFrame=handle.CFrame*CFrame.new(0,0,-2); barrel.Parent=tool end
    local sound=Instance.new("Sound",handle); sound.Name="FireSound"; sound.SoundId=cfg.SoundId or "rbxassetid://12222025"; sound.Volume=1
    return tool
end
for _,c in ipairs(WeaponsFolder:GetChildren()) do if c:IsA("Tool") then c:Destroy() end end
for _,c in ipairs(StarterPack:GetChildren()) do if c:GetAttribute("WeaponName") then c:Destroy() end end
for _,wName in ipairs(WeaponConfig.Order) do local cfg=WeaponConfig[wName]; if cfg then local t=createTool(wName,cfg); t.Parent=WeaponsFolder; if wName=="Pistol" or wName=="Bat" then t:Clone().Parent=StarterPack end end end
-- Shop prompts
task.spawn(function()
    task.wait(2)
    local map=workspace:FindFirstChild("ZombieMap"); if not map then return end
    local shop=map:FindFirstChild("WeaponShop"); if not shop then return end
    for i,pad in ipairs(shop:GetChildren()) do
        if pad.Name:match("WeaponPad") and pad:IsA("BasePart") then
            local idx=tonumber(pad.Name:match("%d+")) or i
            local wName=WeaponConfig.Order[idx] or "Pistol"
            local cfg=WeaponConfig[wName]; if not cfg then continue end
            for _,ch in ipairs(pad:GetChildren()) do if ch:IsA("BillboardGui") then local tl=ch:FindFirstChildOfClass("TextLabel"); if tl then tl.Text=cfg.DisplayName.."\n$"..cfg.Price.."\n[E] Buy" end end end
            if not pad:FindFirstChild("Prox") then
                local prox=Instance.new("ProximityPrompt",pad); prox.Name="Prox"; prox.ActionText="Buy "..cfg.DisplayName; prox.ObjectText="$"..cfg.Price; prox.HoldDuration=0.3; prox.MaxActivationDistance=10
                prox.Triggered:Connect(function(plr)
                    local tool=nil; for _,t in ipairs(WeaponsFolder:GetChildren()) do if t:GetAttribute("WeaponName")==wName then tool=t; break end end
                    if not tool then return end
                    local ls=plr:FindFirstChild("leaderstats"); local cash=ls and ls:FindFirstChild("Cash")
                    if wName~="Pistol" and cash and cash.Value < cfg.Price then return end
                    if cash and wName~="Pistol" then cash.Value -= cfg.Price end
                    if not plr.Backpack:FindFirstChild(tool.Name) and not (plr.Character and plr.Character:FindFirstChild(tool.Name)) then tool:Clone().Parent=plr.Backpack end
                end)
            end
        end
    end
end)
print("[WeaponBuilder] 10 weapons built")

-- // WEAPON HANDLER (simplified copy)
local playerAmmo={}
local function getAmmo(plr,wName) if not playerAmmo[plr] then playerAmmo[plr]={} end if playerAmmo[plr][wName]==nil then local cfg=WeaponConfig[wName]; playerAmmo[plr][wName]=cfg and cfg.Ammo or 30 end return playerAmmo[plr][wName] end
local function setAmmo(plr,wName,val) if not playerAmmo[plr] then playerAmmo[plr]={} end playerAmmo[plr][wName]=val end
local function isZombie(m) return m and m:FindFirstChildOfClass("Humanoid") and m:GetAttribute("ZombieType")~=nil end
local function dmgZombie(zm,dmg) local h=zm:FindFirstChildOfClass("Humanoid"); if not h or h.Health<=0 then return end h:TakeDamage(dmg) end

WeaponFireEvent.OnServerEvent:Connect(function(plr,wName,origin,dir)
    local cfg=WeaponConfig[wName]; if not cfg then return end
    if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp=plr.Character.HumanoidRootPart
    if (origin-hrp.Position).Magnitude>25 then origin=hrp.Position+dir*2 end
    if cfg.Ammo and cfg.Ammo~=-1 then local a=getAmmo(plr,wName); if a<=0 then return end; setAmmo(plr,wName,a-1) end
    if cfg.Type=="Explosive" then
        local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist; rp.FilterDescendantsInstances={plr.Character}
        local res=workspace:Raycast(origin,dir*(cfg.Range or 500),rp); local pos=res and res.Position or origin+dir*50
        local exp=Instance.new("Explosion"); exp.BlastRadius=cfg.ExplosionRadius or 12; exp.BlastPressure=0; exp.Position=pos; exp.Parent=workspace
        exp.Hit:Connect(function(part,dist) local mdl=part.Parent; if isZombie(mdl) then dmgZombie(mdl, math.floor(cfg.Damage*(1-dist/(exp.BlastRadius+1)))) end end)
    elseif cfg.Type=="Flame" then
        for _,zm in ipairs(workspace:GetChildren()) do if isZombie(zm) and zm.PrimaryPart then local d=(zm.PrimaryPart.Position-origin).Magnitude; local dot=dir:Dot((zm.PrimaryPart.Position-origin).Unit); if d<(cfg.Range or 70) and dot>0.85 then dmgZombie(zm,cfg.Damage) end end end
    elseif cfg.Type=="Melee" then
        local root=plr.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
        for _,zm in ipairs(workspace:GetChildren()) do if isZombie(zm) and zm.PrimaryPart then if (zm.PrimaryPart.Position-root.Position).Magnitude < (cfg.Range or 12) then dmgZombie(zm,cfg.Damage) end end end
    else
        local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist; rp.FilterDescendantsInstances={plr.Character}
        if cfg.Type=="Shotgun" then
            for i=1,(cfg.Pellets or 8) do local spread=cfg.Spread or 5; local off=Vector3.new(math.random(-spread,spread)*0.1,math.random(-spread,spread)*0.1,math.random(-spread,spread)*0.1); local d=(dir+off).Unit; local r=workspace:Raycast(origin,d*(cfg.Range or 80),rp); if r and r.Instance and isZombie(r.Instance.Parent) then dmgZombie(r.Instance.Parent,cfg.Damage) end end
        else
            local r=workspace:Raycast(origin,dir*(cfg.Range or 300),rp); if r and r.Instance and isZombie(r.Instance.Parent) then dmgZombie(r.Instance.Parent,cfg.Damage) elseif r and r.Instance and isZombie(r.Instance.Parent.Parent) then dmgZombie(r.Instance.Parent.Parent,cfg.Damage) end
        end
    end
end)
if ReloadEvent then ReloadEvent.OnServerEvent:Connect(function(plr,wName) local cfg=WeaponConfig[wName]; if not cfg or cfg.Ammo==-1 then return end; setAmmo(plr,wName,cfg.Ammo) end) end

-- // ZOMBIE SPAWNER (simplified)
local activeZombies={}
local waveNumber=0
local function getSpawns() local map=workspace:FindFirstChild("ZombieMap"); if not map then return {} end; local f=map:FindFirstChild("ZombieSpawns"); if not f then return {} end; local t={}; for _,p in ipairs(f:GetChildren()) do if p:IsA("BasePart") then table.insert(t,p) end end; return t end
local function nearestPlayer(pos)
    local best=nil; local bd=math.huge; for _,plr in ipairs(Players:GetPlayers()) do if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChildOfClass("Humanoid") and plr.Character.Humanoid.Health>0 then local d=(plr.Character.HumanoidRootPart.Position-pos).Magnitude; if d<bd then bd=d; best=plr end end end return best,bd
end
local function createZombie(tName,spawnCF)
    local cfg=ZombieConfig.Types[tName] or ZombieConfig.Types.Walker
    local mult=ZombieConfig.GetDifficultyMultiplier(waveNumber)
    local model=Instance.new("Model"); model.Name="Zombie_"..cfg.Name
    local hum=Instance.new("Humanoid"); hum.MaxHealth=math.floor(cfg.Health*mult); hum.Health=hum.MaxHealth; hum.WalkSpeed=cfg.WalkSpeed; hum.Parent=model
    local hrp=Instance.new("Part"); hrp.Name="HumanoidRootPart"; hrp.Size=Vector3.new(2,2,1)*cfg.Scale; hrp.CFrame=spawnCF+Vector3.new(0,3,0); hrp.Color=cfg.Color; hrp.Material=Enum.Material.Slate; hrp.Anchored=false; hrp.CanCollide=true; hrp.Parent=model; model.PrimaryPart=hrp
    local head=Instance.new("Part"); head.Name="Head"; head.Size=Vector3.new(2,1,1)*cfg.Scale; head.CFrame=hrp.CFrame*CFrame.new(0,1.5,0); head.Color=cfg.Color; head.Parent=model
    local torso=Instance.new("Part"); torso.Name="Torso"; torso.Size=Vector3.new(2,2,1)*cfg.Scale; torso.CFrame=hrp.CFrame; torso.Color=cfg.Color; torso.Parent=model
    local function weld(a,b) local w=Instance.new("WeldConstraint"); w.Part0=a; w.Part1=b; w.Parent=a end
    weld(hrp,torso); weld(torso,head)
    model:SetAttribute("ZombieType",tName); model:SetAttribute("Damage",cfg.Damage); model:SetAttribute("Cash",cfg.Cash); model:SetAttribute("IsExploder",cfg.Explodes or false)
    model.Parent=workspace
    pcall(function() hrp:SetNetworkOwner(nil) end)
    return model
end

RunService.Heartbeat:Connect(function()
    for i=#activeZombies,1,-1 do
        local zm=activeZombies[i]
        if not zm or not zm.Parent or not zm:FindFirstChildOfClass("Humanoid") or zm.Humanoid.Health<=0 then table.remove(activeZombies,i)
        else
            local root=zm.PrimaryPart; if not root then continue end
            local plr,dist=nearestPlayer(root.Position)
            if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if not zm:GetAttribute("LastPath") or tick()-zm:GetAttribute("LastPath")>1.2 then zm:SetAttribute("LastPath",tick()); pcall(function() zm.Humanoid:MoveTo(plr.Character.HumanoidRootPart.Position) end) end
                if dist and dist<7 then
                    if (plr.Character.HumanoidRootPart.Position-root.Position).Magnitude<6 then plr.Character.Humanoid:TakeDamage(zm:GetAttribute("Damage") or 15) end
                    if zm:GetAttribute("IsExploder") and dist<8 then
                        local exp=Instance.new("Explosion"); exp.BlastRadius=12; exp.BlastPressure=0; exp.Position=root.Position; exp.Parent=workspace
                        exp.Hit:Connect(function(part) local hum=part.Parent:FindFirstChildOfClass("Humanoid"); if hum then hum:TakeDamage(60) end end)
                        zm.Humanoid.Health=0
                    end
                end
            end
        end
    end
end)

local function spawnRandom()
    local spawns=getSpawns(); if #spawns==0 then return nil end
    local sp=spawns[math.random(1,#spawns)]
    local tName=ZombieConfig.GetRandomType(waveNumber)
    local zm=createZombie(tName,sp.CFrame)
    table.insert(activeZombies,zm)
    zm.Humanoid.Died:Connect(function()
        task.wait(0.1)
        for _,plr in ipairs(Players:GetPlayers()) do local ls=plr:FindFirstChild("leaderstats"); if ls then local cash=ls:FindFirstChild("Cash"); if cash then cash.Value+=zm:GetAttribute("Cash") or 10 end; local k=ls:FindFirstChild("Kills"); if k then k.Value+=1 end end end
        Debris:AddItem(zm,5)
    end)
    return zm
end

task.spawn(function()
    while not workspace:FindFirstChild("ZombieMap") do task.wait(1) end
    task.wait(2)
    waveNumber=0
    while true do
        waveNumber+=1
        local toSpawn=math.floor(ZombieConfig.WaveConfig.StartingZombies + (waveNumber-1)*ZombieConfig.WaveConfig.ZombiesPerWaveGrowth)
        print("[Spawner] Wave "..waveNumber.." spawning "..toSpawn)
        WaveUpdateEvent:FireAllClients(waveNumber,toSpawn)
        local spawned=0
        while spawned<toSpawn do
            if #activeZombies < ZombieConfig.WaveConfig.MaxAlive then spawnRandom(); spawned+=1 end
            task.wait(ZombieConfig.WaveConfig.SpawnDelay)
        end
        repeat task.wait(1) until #activeZombies==0
        print("[Spawner] Wave "..waveNumber.." cleared")
        for i=ZombieConfig.WaveConfig.Intermission,1,-1 do WaveUpdateEvent:FireAllClients(waveNumber,-i); task.wait(1) end
    end
end)

print("[Zombie ALLINONE] Server ready - Map + Zombies + 10 Weapons")
