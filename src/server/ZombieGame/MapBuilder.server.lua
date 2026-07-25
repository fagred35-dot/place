-- ZombieSurvival / MapBuilder.server.lua
-- Строит карту процедурно в Workspace, чтобы не нужен был .rbxl
-- Кидать в ServerScriptService или Workspace

local function buildMap()
    if workspace:FindFirstChild("ZombieMap") then
        print("[MapBuilder] Map already exists")
        return workspace.ZombieMap
    end

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "ZombieMap"
    mapFolder.Parent = workspace

    local function newPart(name, size, cf, color, mat, parent)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = true
        p.Color = color or Color3.fromRGB(100,100,100)
        p.Material = mat or Enum.Material.Concrete
        p.Parent = parent or mapFolder
        return p
    end

    -- Baseplate 600x600
    newPart("Baseplate", Vector3.new(800, 6, 800), CFrame.new(0,-3,0), Color3.fromRGB(60,60,60), Enum.Material.Slate, mapFolder)

    -- Perimeter walls
    local wallH = 30
    local wallT = 6
    local half = 400
    newPart("Wall_North", Vector3.new(800, wallH, wallT), CFrame.new(0, wallH/2-3, half), Color3.fromRGB(40,40,40), Enum.Material.Brick)
    newPart("Wall_South", Vector3.new(800, wallH, wallT), CFrame.new(0, wallH/2-3, -half), Color3.fromRGB(40,40,40), Enum.Material.Brick)
    newPart("Wall_East", Vector3.new(wallT, wallH, 800), CFrame.new(half, wallH/2-3, 0), Color3.fromRGB(40,40,40), Enum.Material.Brick)
    newPart("Wall_West", Vector3.new(wallT, wallH, 800), CFrame.new(-half, wallH/2-3, 0), Color3.fromRGB(40,40,40), Enum.Material.Brick)

    -- Lights for atmosphere
    local function addLight(pos, color, range)
        local att = Instance.new("Attachment", newPart("LightPos_"..tostring(pos), Vector3.new(1,1,1), CFrame.new(pos), Color3.fromRGB(0,0,0), Enum.Material.Neon, mapFolder))
        att.Parent = mapFolder
        att.WorldPosition = pos
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = range
        light.Brightness = 2
        light.Shadows = true
        light.Parent = att
        return att
    end

    -- Central Safe House 40x40
    local safeFolder = Instance.new("Folder", mapFolder)
    safeFolder.Name = "SafeHouse"
    local sfPos = Vector3.new(0,0,0)
    newPart("SafeFloor", Vector3.new(50,2,50), CFrame.new(sfPos), Color3.fromRGB(110,90,70), Enum.Material.WoodPlanks, safeFolder)
    -- 4 walls with doorway front (south)
    newPart("SafeWall_N", Vector3.new(50,12,2), CFrame.new(0,6,25), Color3.fromRGB(140,120,100), Enum.Material.Wood, safeFolder)
    newPart("SafeWall_E", Vector3.new(2,12,50), CFrame.new(25,6,0), Color3.fromRGB(140,120,100), Enum.Material.Wood, safeFolder)
    newPart("SafeWall_W", Vector3.new(2,12,50), CFrame.new(-25,6,0), Color3.fromRGB(140,120,100), Enum.Material.Wood, safeFolder)
    -- South wall split for doorway
    newPart("SafeWall_S1", Vector3.new(18,12,2), CFrame.new(-16,6,-25), Color3.fromRGB(140,120,100), Enum.Material.Wood, safeFolder)
    newPart("SafeWall_S2", Vector3.new(18,12,2), CFrame.new(16,6,-25), Color3.fromRGB(140,120,100), Enum.Material.Wood, safeFolder)
    newPart("SafeWall_Top", Vector3.new(14,4,2), CFrame.new(0,12,-25), Color3.fromRGB(140,120,100), Enum.Material.Wood, safeFolder)
    -- Roof
    newPart("SafeRoof", Vector3.new(54,2,54), CFrame.new(0,13,0), Color3.fromRGB(80,60,50), Enum.Material.Slate, safeFolder)

    -- Player spawn inside safe house
    local spawnLoc = Instance.new("SpawnLocation", safeFolder)
    spawnLoc.Name = "PlayerSpawn"
    spawnLoc.Size = Vector3.new(10,1,10)
    spawnLoc.CFrame = CFrame.new(0,1,0)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = false
    spawnLoc.Duration = 0
    spawnLoc.Neutral = true

    -- Weapon Shop near safe house
    local shopFolder = Instance.new("Folder", mapFolder)
    shopFolder.Name = "WeaponShop"
    newPart("ShopFloor", Vector3.new(60,2,30), CFrame.new(0,0,70), Color3.fromRGB(70,70,80), Enum.Material.Concrete, shopFolder)
    newPart("ShopWall", Vector3.new(60,10,2), CFrame.new(0,5,85), Color3.fromRGB(50,50,60), Enum.Material.Brick, shopFolder)
    -- 10 weapon pads
    for i=1,10 do
        local x = -27 + (i-1)*6
        local pad = newPart("WeaponPad_"..i, Vector3.new(5,1,5), CFrame.new(x,1,70), Color3.fromRGB(200,200,200), Enum.Material.Neon, shopFolder)
        pad.Name = "WeaponPad_"..i
        pad.Material = Enum.Material.Neon
        pad.Color = Color3.fromHSV((i-1)/10, 0.8, 0.9)
        local bil = Instance.new("BillboardGui", pad)
        bil.Size = UDim2.fromOffset(80,30)
        bil.StudsOffset = Vector3.new(0,3,0)
        bil.AlwaysOnTop = true
        local txt = Instance.new("TextLabel", bil)
        txt.Size = UDim2.fromScale(1,1)
        txt.BackgroundTransparency = 0.3
        txt.BackgroundColor3 = Color3.fromRGB(0,0,0)
        txt.TextColor3 = Color3.new(1,1,1)
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 10
        txt.Text = "Weapon "..i
        Instance.new("UICorner", txt)
    end

    -- Zombie Spawns at 4 corners + 4 edges = 8
    local zombieSpawnsFolder = Instance.new("Folder", mapFolder)
    zombieSpawnsFolder.Name = "ZombieSpawns"
    local spawnPositions = {
        Vector3.new(350,5,350), Vector3.new(-350,5,350),
        Vector3.new(350,5,-350), Vector3.new(-350,5,-350),
        Vector3.new(350,5,0), Vector3.new(-350,5,0),
        Vector3.new(0,5,350), Vector3.new(0,5,-350),
    }
    for i,pos in ipairs(spawnPositions) do
        local sp = newPart("ZombieSpawn_"..i, Vector3.new(8,1,8), CFrame.new(pos), Color3.fromRGB(255,0,0), Enum.Material.Neon, zombieSpawnsFolder)
        sp.Transparency = 0.5
        sp.CanCollide = false
        local light = Instance.new("PointLight", sp)
        light.Color = Color3.fromRGB(255,0,0)
        light.Range = 15
        light.Brightness = 2
        local bg = Instance.new("BillboardGui", sp)
        bg.Size = UDim2.fromOffset(60,20)
        bg.StudsOffset = Vector3.new(0,4,0)
        local tl = Instance.new("TextLabel", bg)
        tl.Size=UDim2.fromScale(1,1); tl.BackgroundTransparency=1; tl.Text="🧟 SPAWN "..i; tl.TextColor3=Color3.new(1,0,0); tl.Font=Enum.Font.GothamBold; tl.TextSize=12
    end

    -- Decor obstacles for cover
    local decor = Instance.new("Folder", mapFolder)
    decor.Name = "Decor"
    for i=1,12 do
        local pos = Vector3.new(math.random(-300,300), 0, math.random(-300,300))
        if (pos - Vector3.new(0,0,0)).Magnitude > 60 then -- not inside safe house
            local size = Vector3.new(math.random(6,14), math.random(6,14), math.random(6,14))
            newPart("Crate_"..i, size, CFrame.new(pos)*CFrame.Angles(0,math.rad(math.random(0,360)),0), Color3.fromRGB(90,70,50), Enum.Material.Wood, decor)
        end
    end

    -- Lighting atmosphere
    local Lighting = game:GetService("Lighting")
    Lighting.ClockTime = 2.5
    Lighting.FogEnd = 350
    Lighting.FogStart = 50
    Lighting.FogColor = Color3.fromRGB(30,30,40)
    Lighting.Ambient = Color3.fromRGB(80,80,90)
    Lighting.Brightness = 2

    print("[MapBuilder] Zombie map built with 8 spawns, safehouse, shop, decor")

    -- Create ReplicatedStorage folders for game
    local RS = game:GetService("ReplicatedStorage")
    local zombieFolderRS = RS:FindFirstChild("ZombieModels")
    if not zombieFolderRS then
        zombieFolderRS = Instance.new("Folder", RS)
        zombieFolderRS.Name = "ZombieModels"
    end
    local weaponFolderRS = RS:FindFirstChild("Weapons")
    if not weaponFolderRS then
        weaponFolderRS = Instance.new("Folder", RS)
        weaponFolderRS.Name = "Weapons"
    end
    local remoteFolder = RS:FindFirstChild("ZombieRemotes")
    if not remoteFolder then
        remoteFolder = Instance.new("Folder", RS)
        remoteFolder.Name = "ZombieRemotes"
    end
    for _,name in ipairs({"WeaponFire","Reload","BuyWeapon","WaveUpdate"}) do
        if not remoteFolder:FindFirstChild(name) then
            local re = Instance.new("RemoteEvent", remoteFolder)
            re.Name = name
        end
    end

    return mapFolder
end

-- Build immediately
buildMap()
