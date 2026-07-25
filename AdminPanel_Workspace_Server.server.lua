--[[ 
    WORKSPACE SERVER VERSION v2.3 FIXED - Работает в Workspace как Server Script
    Поставь этот Script в Workspace и он будет работать без LocalScript.

    Команды в чате: !fly, !noclip, !speed 100, !heal, !pos, !tp spawn, !platform
    Fly+Noclip auto ON
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONFIG = {
    AllowStudio = true,
    AllowOwner = true,
    AdminIds = {},
    GroupRank = 200,
    BaseFlySpeed = 70,
}

local function isAdmin(plr)
    if CONFIG.AllowStudio and RunService:IsStudio() then return true end
    for _,id in ipairs(CONFIG.AdminIds) do if id==plr.UserId then return true end end
    local ok,res = pcall(function()
        if CONFIG.AllowOwner and game.CreatorType==Enum.CreatorType.User then
            return game.CreatorId==plr.UserId
        end
        if game.CreatorType==Enum.CreatorType.Group then
            return plr:GetRankInGroup(game.CreatorId) >= CONFIG.GroupRank
        end
        return false
    end)
    return ok and res
end

local playerState = {}
local noclipConns = {} -- [character] = connection
local flyConns = {} -- [player] = connection
local flyObjects = {} -- [player] = {bv, bg}

local function getState(plr)
    if not playerState[plr] then
        playerState[plr] = {fly=false, noclip=false, speed=1, flySpeed=CONFIG.BaseFlySpeed}
    end
    return playerState[plr]
end

local function setNoclip(char, enabled)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- disconnect old
    if noclipConns[char] then
        noclipConns[char]:Disconnect()
        noclipConns[char]=nil
    end
    if enabled then
        noclipConns[char] = RunService.Stepped:Connect(function()
            if not char.Parent then
                if noclipConns[char] then noclipConns[char]:Disconnect(); noclipConns[char]=nil end
                return
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    end
end

local function clearFly(plr)
    if flyObjects[plr] then
        if flyObjects[plr].bv then flyObjects[plr].bv:Destroy() end
        if flyObjects[plr].bg then flyObjects[plr].bg:Destroy() end
        flyObjects[plr]=nil
    end
    if flyConns[plr] then
        flyConns[plr]:Disconnect()
        flyConns[plr]=nil
    end
end

local function setFly(plr, enabled)
    local state = getState(plr)
    state.fly = enabled
    local char = plr.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    clearFly(plr)
    
    if enabled then
        setNoclip(char, true)
        state.noclip = true
        local bv = Instance.new("BodyVelocity")
        bv.Name = "WSFly_Vel"
        bv.MaxForce = Vector3.new(1e9,1e9,1e9)
        bv.Velocity = Vector3.zero
        bv.Parent = root
        local bg = Instance.new("BodyGyro")
        bg.Name = "WSFly_Gyro"
        bg.MaxTorque = Vector3.new(1e9,1e9,1e9)
        bg.CFrame = root.CFrame
        bg.Parent = root
        flyObjects[plr] = {bv=bv, bg=bg}
        
        flyConns[plr] = RunService.Heartbeat:Connect(function()
            local c = plr.Character
            if not c then return end
            local r = c:FindFirstChild("HumanoidRootPart")
            local h = c:FindFirstChildOfClass("Humanoid")
            if not r or not h then return end
            if not flyObjects[plr] then return end
            local md = h.MoveDirection
            local dir = Vector3.zero
            if md.Magnitude>0 then
                dir += Vector3.new(md.X,0,md.Z)
            end
            if h.Jump then
                dir += Vector3.new(0,1,0)
            end
            if h:GetAttribute("FlyDown") then
                dir -= Vector3.new(0,1,0)
            end
            if dir.Magnitude>0 then dir = dir.Unit end
            flyObjects[plr].bv.Velocity = dir * state.flySpeed
            flyObjects[plr].bg.CFrame = r.CFrame
        end)
        print("[WS Admin] Fly ON for "..plr.Name)
    else
        print("[WS Admin] Fly OFF for "..plr.Name)
    end
end

local function handleCommand(plr, msg)
    if not isAdmin(plr) then return end
    msg = msg:lower()
    local state = getState(plr)
    if msg=="!fly" then
        setFly(plr, not state.fly)
    elseif msg:sub(1,6)=="!speed" then
        local num = tonumber(msg:match("%d+"))
        if num then
            local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = num; print("[WS Admin] Speed set to "..num) end
        end
    elseif msg=="!noclip" then
        local char = plr.Character
        if char then
            state.noclip = not state.noclip
            setNoclip(char, state.noclip)
            print("[WS Admin] Noclip "..(state.noclip and "ON" or "OFF"))
        end
    elseif msg=="!heal" then
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = hum.MaxHealth end
    elseif msg=="!pos" then
        local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if root then print("[WS Admin] CFrame: "..tostring(root.CFrame)) end
    elseif msg=="!tp spawn" then
        local spawn = nil
        for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("SpawnLocation") then spawn=v; break end end
        local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if spawn and root then root.CFrame = spawn.CFrame + Vector3.new(0,5,0) end
    elseif msg=="!platform" then
        local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local p = Instance.new("Part")
            p.Anchored=true; p.Size=Vector3.new(15,1,15); p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(100,140,255)
            p.CFrame = root.CFrame * CFrame.new(0,-4,0); p.Parent=workspace
            print("[WS Admin] Platform created")
        end
    elseif msg:sub(1,5)=="!down" then
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:SetAttribute("FlyDown", true); task.delay(0.5, function() if hum.Parent then hum:SetAttribute("FlyDown", false) end end) end
    end
end

Players.PlayerAdded:Connect(function(plr)
    getState(plr)
    plr.Chatted:Connect(function(msg) handleCommand(plr, msg) end)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        local state = getState(plr)
        if state.noclip then setNoclip(char, true) end
        if state.fly then setFly(plr, true) end
        if CONFIG.AllowStudio or isAdmin(plr) then
            task.delay(1, function()
                if plr.Parent then
                    setFly(plr, true)
                end
            end)
        end
        char.AncestryChanged:Connect(function()
            if not char.Parent then
                if noclipConns[char] then noclipConns[char]:Disconnect(); noclipConns[char]=nil end
            end
        end)
    end)
    plr.AncestryChanged:Connect(function()
        if not plr.Parent then
            clearFly(plr)
            playerState[plr]=nil
        end
    end)
end)

for _,plr in ipairs(Players:GetPlayers()) do
    getState(plr)
    plr.Chatted:Connect(function(msg) handleCommand(plr, msg) end)
    if plr.Character then
        task.defer(function()
            setNoclip(plr.Character, true)
            setFly(plr, true)
        end)
    end
end

print("[WS Admin] Workspace Server Admin v2.3 FIXED loaded! Commands: !fly, !noclip, !speed 100, !heal, !pos, !tp spawn, !platform. Fly+NoClip auto ON.")
